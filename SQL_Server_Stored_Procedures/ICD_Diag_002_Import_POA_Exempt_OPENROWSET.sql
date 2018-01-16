/* Replace HCDatamart_Devt with your intended destination database
USE HCDatamart_Devt
GO
*/

-- If procedure does not already exist, create a stub that will then be replaced by ALTER. The BEGIN CATCH eliminate any error messages if it does already exist
BEGIN TRY
	 EXEC ('CREATE PROCEDURE dbo.ICD_Diag_002_Import_POA_Exempt_OPENROWSET AS DECLARE @A varchar(100); SET @A=ISNULL(OBJECT_NAME(@@PROCID), ''unknown'')+'' was not created!''; RAISERROR(@A,16,1);return 9999')
END TRY BEGIN CATCH END CATCH
GO

ALTER PROCEDURE dbo.ICD_Diag_002_Import_POA_Exempt_OPENROWSET (
	 @Schema_Name VARCHAR(32) = 'dbo'
	,@Table_Name VARCHAR(100) = 'DIM_ICD_Diagnosis_POA_Exempt'
	,@Table_Action VARCHAR(16) = 'DROP_CREATE' -- available: DROP_CREATE, TRUNCATE, DELETE_ICD10
	,@Source_File_Dir VARCHAR(1000) = NULL
) AS

BEGIN

/* ======================================================================================
	AUTHOR
		Nicole M. Lindner-Miles

	TODO: DOCUMENT, including:
		*	POA 9 - is from XXXXX on cms.gov. Validated it against
			"ICD-9-CM Official Guidelines for Coding and Reporting Effective October 1, 2011"
			As best I can tell, CMS did not provide annual releases of the ICD-9 codes
			that were exempt from POA reporting. I am loading the FY 2015 file that is
			available there, and I THINK that it should be valid for CMS FY 2011-2014 too, 
			but am not certain.
			That file also only provides the Diagnosis code WITHOUT the period. Just for fun.

	STORED PROCEDURE
		ICD_Diag_002_Import_POA_Exempt_OPENROWSET

	DESCRIPTION
		*	This is the simple (OPENROWSET) method to import this info.
			dbo.ICD_Diag_002_Import_POA_Exempt_AsValues does exactly the same thing,
			but does not require OPENROWSET permissions (i.e., ADMINISTER BULK OPERATIONS)

	PARAMETERS
		@Schema_Name (Required, if other than default of 'dbo')
		@Table_Name (Required, if other than default of 'DIM_ICD_Diagnosis_POA_Exempt')
			This procedure creates permanent output table @Schema_Name.Table_Name
			and loads it with all ICD diagnosis code that are POA exempt
		@Table_Action (Required, if other than default of 'DROP_CREATE')
			Valid Values: 'DROP_CREATE', 'TRUNCATE', 'DELETE_ICD9', 'DELETE_ICD10'
			Specifies what to do with the permanent output table.
			DROP_CREATE: Drop it (if it already exists) and recreate it.
			TRUNCATE: Truncates the table, which must already exist
			DELETE_ICD9 or DELETE_ICD10: Deletes any codes for the specified ICD version
			from the table, which must already exist
		@Source_File_Dir
			Required input parameter. The location of the CMS_ICD_Diagnoses_POA_Exempt
			subdirectory

	WHAT THIS PROCEDURE DOES
		*	Dependent on which @Table_Action is invoked, this will either
			'DROP_CREATE': Create permanent output table for ICD diagnosis codes,
			dropping the table if it already exists
			'TRUNCATE': TRUNCATE the existing output table
			'DELETE_ICD9': Delete any ICD-9 codes from the existing output table
			'DELETE_ICD10': Delete any ICD-10 codes from the existing output table

	EXAMPLE CALL
	exec dbo.ICD_Diag_002_Import_POA_Exempt_OPENROWSET 
		@Table_Name = 'DIM_ICD_Diagnosis_POA_Exempt'
		,@Table_Action = 'DROP_CREATE'
		,@Source_File_Dir = 
			'C:\Users\Nicole\Documents\GitHub\CMS_MS_DRG_Grouper_Help\DIM_ICD_Diagnosis_POA_Exempt'

	CHANGE LOG
		2018.01.15 NLM
			*	Add documentation
		2018.01.02 NLM (Nicole Lindner-Miles) 
			*	Initial version

	INTELLECTUAL PROPERTY
		*	I, Nicole M. Lindner-Miles, developed this script on my own time 
			without company resources or proprietary/confidential information.
====================================================================================== */

	DECLARE @NewLine CHAR(2) = CHAR(10) + CHAR(10);
	DECLARE @SQL VARCHAR(MAX);

	RAISERROR ('%s--- Prep final output table %s.%s via %s ---', 0, 1, @NewLine, @Schema_Name, @Table_Name, @Table_Action) 
	IF @Table_Action = 'DROP_CREATE'
	BEGIN
		RAISERROR ('--- Drop (if it already exists) and recreate ---', 0, 1) 

		SET @SQL = '
		IF OBJECT_ID(''' + @Schema_Name + '.' + @Table_Name + ''') IS NOT NULL
		BEGIN
			DROP TABLE ' + @Schema_Name + '.' + @Table_Name + '
		END
		CREATE TABLE ' + @Schema_Name + '.' + @Table_Name + '(
			 Diagnosis_Code               VARCHAR(7)     NOT NULL
			,ICD_Version                  INT            NOT NULL
			,CMS_Fiscal_Year              INT            NOT NULL
			,Diagnosis_Code_With_Period   VARCHAR(8)     NOT NULL
			,Code_Desc_Long               VARCHAR(323)   NOT NULL
			,CONSTRAINT PK_' + @Table_Name + ' PRIMARY KEY (
				 CMS_Fiscal_Year
				,ICD_Version
				,Diagnosis_Code
			 )
		);'

		EXEC(@SQL)
	END

	IF @Table_Action = 'TRUNCATE'
	BEGIN
		RAISERROR ('--- Truncate existing data---', 0, 1) 

		SET @SQL = '
		TRUNCATE TABLE ' + @Schema_Name + '.' + @Table_Name 

		EXEC(@SQL)
	END

	IF @Table_Action = 'DELETE_ICD9'
	BEGIN
		RAISERROR ('--- Delete any ICD-9 data that exists ---', 0, 1) 

		SET @SQL = '
		DELETE FROM ' + @Schema_Name + '.' + @Table_Name 
		+ ' WHERE ICD_Version = 9 '

		EXEC(@SQL)
	END

	IF @Table_Action = 'DELETE_ICD10'
	BEGIN
		RAISERROR ('--- Delete any ICD-10 data that exists ---', 0, 1) 

		SET @SQL = '
		DELETE FROM ' + @Schema_Name + '.' + @Table_Name 
		+ ' WHERE ICD_Version = 10 '

		EXEC(@SQL)
	END

	RAISERROR ('%s--- Create lookup table (to use in loop) with CMS fiscal years and the available source files with ICD diagnosis codes that are exempt from POA reporting ---', 0, 1, @NewLine) 

	IF OBJECT_ID('tempdb..#CMS_Fiscal_Year_File_Map') IS NOT NULL
	BEGIN
		DROP TABLE #CMS_Fiscal_Year_File_Map
	END
	CREATE TABLE #CMS_Fiscal_Year_File_Map (
		 CMS_Fiscal_Year        VARCHAR(4)     NOT NULL
		,ICD_Version				VARCHAR(2)     NOT NULL
		,POA_File_Name_Diag     VARCHAR(100)   NOT NULL
		,POA_File_Name_Format   VARCHAR(100)   NOT NULL
	)
	INSERT INTO #CMS_Fiscal_Year_File_Map (
		 CMS_Fiscal_Year
		,ICD_Version
		,POA_File_Name_Diag
		,POA_File_Name_Format
	)
	VALUES
		 ('2015', '9', 'ICD-9_POA_Exempt_Diagnosis_Codes_Oct12014_FY2015.txt', 'ICD9_POAexemptcodes_format.fmt')
		--,('2015', '10', 'FY2015 Detailed List  of Codes Exempt from POA.txt', 'FY2015_POAexemptcodes_format.fmt')
		,('2016', '10', 'POAexemptcodes2016.txt', 'POAexemptcodes_format.fmt')
		,('2017', '10', 'POAexemptcodes2017.txt', 'POAexemptcodes_format.fmt')
		,('2018', '10', 'POAexemptcodes2018.txt', 'POAexemptcodes_format.fmt')


	RAISERROR ('%s--- Create temp table to store raw loaded codes ---', 0, 1, @NewLine) 

	-- Cursor parameters
	DECLARE 
		@This_CMS_Fiscal_Year   VARCHAR(4),
		@This_ICD_Version			VARCHAR(2),
		@This_File_Name_Diag    VARCHAR(100),
		@This_File_Name_Format  VARCHAR(100);


	DECLARE Cursor_CMS_FY CURSOR
	LOCAL READ_ONLY FORWARD_ONLY
	FOR
	SELECT 
		CMS_Fiscal_Year,
		ICD_Version,
		POA_File_Name_Diag,
		POA_File_Name_Format
	FROM #CMS_Fiscal_Year_File_Map
	 
	OPEN Cursor_CMS_FY 
	FETCH NEXT 
	FROM Cursor_CMS_FY 
	INTO 
		@This_CMS_Fiscal_Year,
		@This_ICD_Version,
		@This_File_Name_Diag,
		@This_File_Name_Format
	WHILE @@FETCH_STATUS = 0
	BEGIN

		RAISERROR ('%s--- Loading POA-exempt ICD-%s-CM codes for CMS FY %s from file %s ---', 0, 1, @NewLine, @This_ICD_Version, @This_CMS_Fiscal_Year, @This_File_Name_Diag) 

		SET @SQL = '
		INSERT INTO ' + @Schema_Name + '.' + @Table_Name + '(
			 ICD_Version
			,CMS_Fiscal_Year
			,Diagnosis_Code_With_Period
			,Diagnosis_Code
			,Code_Desc_Long
		)
			SELECT 
				 ' + @This_ICD_Version + ' AS ICD_Version
				 ,' + @This_CMS_Fiscal_Year + ' AS CMS_Fiscal_Year
				,SUBSTRING(LTRIM(RTRIM(src.Diagnosis_Code_With_Period)), 1, 8) AS Diagnosis_Code_With_Period
				,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Diagnosis_Code_With_Period)), ''.'', ''''), 1, 7) AS Diagnosis_Code
				,LTRIM(RTRIM(src.Code_Desc_Long)) AS Code_Desc_Long
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\' + @This_File_Name_Diag
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\' + @This_File_Name_Format + '''
				,ERRORFILE = ''' + @Source_File_Dir + '\Errorfile_POA_Exempt_CMS_FY' + @This_CMS_Fiscal_Year + '.err'''
				+ '
				,FIRSTROW = 2
			) AS src
			'
			--print @SQL
			EXEC (@SQL)


			
		FETCH NEXT 
		FROM Cursor_CMS_FY 
		INTO 
			@This_CMS_Fiscal_Year,
			@This_ICD_Version,
			@This_File_Name_Diag,
			@This_File_Name_Format
	END
	CLOSE Cursor_CMS_FY 
	DEALLOCATE Cursor_CMS_FY 

	/* Updates to clean up known issues from source file
		First, populating the Diagnosis_Code_With_Period for the ICD-9 file

	 	Also, there are tabs (ASCII character 9) in the source files after the description ends.
		And some descriptions (I think per the CSV standard, which Microsoft does not follow?)
		are surrounded by double-quotes. Because those are not present on every single row,
		I believe that OPENROWSET cannot clean that up during the import


update DIM_ICD_Diagnosis_ICD9
	SET 
		Diagnosis_Parent = LEFT(Diagnosis_Code, 4)
		,Diagnosis_Code_With_Period =
		CASE
			WHEN LEN(Diagnosis_Code) = 4 THEN Diagnosis_Code
			ELSE LEFT(Diagnosis_Code, 4) + '.' + RIGHT(Diagnosis_Code, LEN(Diagnosis_Code) - 4)
		END
WHERE
	Diagnosis_Code LIKE 'E%'


update DIM_ICD_Diagnosis_ICD9
	SET 
		Diagnosis_Parent = LEFT(Diagnosis_Code, 3)
		,Diagnosis_Code_With_Period =
		CASE
			WHEN LEN(Diagnosis_Code) = 3 THEN Diagnosis_Code
			ELSE LEFT(Diagnosis_Code, 3) + '.' + RIGHT(Diagnosis_Code, LEN(Diagnosis_Code) - 3)
		END
WHERE
	

	*/
	SET @SQL = '
		UPDATE ' + @Schema_Name + '.' + @Table_Name + '
			SET Diagnosis_Code_With_Period = 
				CASE
					WHEN LEN(Diagnosis_Code) = 4 THEN Diagnosis_Code
					ELSE LEFT(Diagnosis_Code, 4) + ''.'' + RIGHT(Diagnosis_Code, LEN(Diagnosis_Code) - 4)
				END
		WHERE 
			ICD_Version = 9
			AND Diagnosis_Code LIKE ''E%''
		;
		UPDATE ' + @Schema_Name + '.' + @Table_Name + '
			SET Diagnosis_Code_With_Period = 
				CASE
					WHEN LEN(Diagnosis_Code) = 3 THEN Diagnosis_Code
					ELSE LEFT(Diagnosis_Code, 3) + ''.'' + RIGHT(Diagnosis_Code, LEN(Diagnosis_Code) - 3)
				END
		WHERE 
			ICD_Version = 9
			AND Diagnosis_Code LIKE ''[V0-9]%''
	;'
	EXEC (@SQL)

	SET @SQL = '
		UPDATE ' + @Schema_Name + '.' + @Table_Name + '
			SET Code_Desc_Long = LTRIM(RTRIM(REPLACE(Code_Desc_Long, CHAR(9), '''')))
	;'
	EXEC (@SQL)

	SET @SQL = '
		UPDATE ' + @Schema_Name + '.' + @Table_Name + '
			SET Code_Desc_Long = SUBSTRING(Code_Desc_Long, 2, LEN(Code_Desc_Long) - 2)
		WHERE Code_Desc_Long like ''"%''
	;'
	EXEC (@SQL)


END

GO
