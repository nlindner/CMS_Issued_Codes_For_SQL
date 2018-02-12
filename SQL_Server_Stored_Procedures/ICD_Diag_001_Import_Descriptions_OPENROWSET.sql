/* Replace HCDatamart_Devt with your intended destination database
USE HCDatamart_Devt
GO
*/

-- If procedure does not already exist, create a stub that will then be replaced by ALTER. The BEGIN CATCH eliminate any error messages if it does already exist
BEGIN TRY
	 EXEC ('CREATE PROCEDURE dbo.ICD_Diag_001_Import_Descriptions_OPENROWSET AS DECLARE @A varchar(100); SET @A=ISNULL(OBJECT_NAME(@@PROCID), ''unknown'')+'' was not created!''; RAISERROR(@A,16,1);return 9999')
END TRY BEGIN CATCH END CATCH
GO

ALTER PROCEDURE dbo.ICD_Diag_001_Import_Descriptions_OPENROWSET (
	 @Schema_Name VARCHAR(32) = 'dbo'
	,@Table_Name VARCHAR(100) = 'DIM_ICD_Diagnosis'
	,@Table_Action VARCHAR(16) = 'DROP_CREATE'
	,@Which_ICD_Version_To_Load VARCHAR(4) = 'ALL'
	,@Source_File_Dir VARCHAR(1000) = NULL
) AS
BEGIN
/* ======================================================================================
	AUTHOR
		Nicole M. Lindner-Miles

	STORED PROCEDURE
		ICD_Diag_001_Import_Descriptions_OPENROWSET

	DESCRIPTION
		*	Includes ICD-9 and ICD-10 diagnosis code descriptions from CMS releases FY 2010-2018
		*	This is the simple (OPENROWSET) method to import this info.
			dbo.ICD_Diag_001_Import_Descriptions_AsValues does exactly the same thing,
			but does not require OPENROWSET permissions (i.e., ADMINISTER BULK OPERATIONS)
		*	This imports flat files with ICD-9 and ICD-10 diagnosis code descriptions, 
			available for download from cms.gov, into a SQL Server table, to serve as a 
			simple lookup/reference/dimension table. 
			*	ICD-9: See repo readme for details on what cleaning was applied to generate
				the flat files with ICD-9 code descriptions (that is, save-as of Excel files)
				I did not attempt to replicate the file layout of the ICD-10 files
		*	File format/layout available here:
			*	ICD9_CM: one file, bar-delimited format, with both short and long descriptions,
				with double-quotes surrounding every field. Note that this file specification
				escapes any double-quotes within the descriptions with (e.g., "" if the code
				description includes a "), so the insert statement cleans those out again.
			*	ICD10_CM: one file, fixed-width format, with both short and long descriptions
			*	The fixed-width format means that no delimiters exist. To account for that,
				the .fmt file has placeholders (Filler_##) for them, but does not load 
				them to the permanent output table
		*	Note that the file specification for the ICD-10 order files allows
			the ICD_Desc_Long field to be up to length = 323 (400 - 77), but the
			observed length for ICD-10 files is never longer than 256. You could 
			reasonably decide to set that field length to 256 instead of 323.
		*	See repo LICENSE and see README for details and sources for files loaded here

	PARAMETERS
		@Schema_Name (Required, if other than default of 'dbo')
		@Table_Name (Required, if other than default of 'DIM_ICD_Diagnosis')
			This procedure creates permanent output table @Schema_Name.Table_Name
			and loads it with all ICD diagnosis code descriptions available in this repo
		@Table_Action (Required, if other than default of 'DROP_CREATE')
			Valid Values: 'DROP_CREATE', 'TRUNCATE', 'DELETE_ICD9', 'DELETE_ICD10'
			Specifies what to do with the permanent output table.
			DROP_CREATE: Drop it (if it already exists) and recreate it.
			TRUNCATE: Truncates the table, which must already exist
			DELETE_ICD9 or DELETE_ICD10: Deletes any codes for the specified ICD version
			from the table, which must already exist
		@Which_ICD_Version_To_Load (Required, if other than default of 'ALL')
			Valid Values: 'ALL', '9', '09', '10'
			Specifies which ICD-version codes should be loaded, defaults to loading all
		@Source_File_Dir
			Required input parameter. The location of the CMS_ICD_Code_Descriptions
			subdirectory

	WHAT THIS PROCEDURE DOES
		*	Dependent on which @Table_Action is invoked, this will either
			'DROP_CREATE': Create permanent output table for ICD diagnosis codes,
			dropping the table if it already exists
			'TRUNCATE': TRUNCATE the existing output table
			'DELETE_ICD9': Delete any ICD-9 codes from the existing output table
			'DELETE_ICD10': Delete any ICD-10 codes from the existing output table
		*	Load all ICD diagnosis codes and their descriptions:
			*	Create temporary table #CMS_ICD_Diag_Release_Map and populate it, conditional on 
				@Which_ICD_Version_To_Load, with the files that will be loaded here, and 
				the CMS release info (ICD version, CMS FY, and effective/end dates) for each file
			*	Loop through all ICD CMS FYs with a cursor, loading the permanent output 
				table with all available description files via OPENROWSET.

	EXAMPLE CALL
	exec dbo.ICD_Diag_001_Import_Descriptions_OPENROWSET 
		@Table_Name = 'DIM_ICD_Diagnosis_Test'
		,@Table_Action = 'DROP_CREATE'
		,@Which_ICD_Version_To_Load = 'ALL'
		,@Source_File_Dir = 
			'C:\Users\Nicole\Documents\GitHub\CMS_MS_DRG_Grouper_Help\CMS_ICD_Code_Descriptions'

	CHANGE LOG
		2018.02.11 NLM
			*	Added FY 2010 ICD codes
			*	Refactored the import procedure for ICD-9, simplifying this SP, because the 
				FY 2010 flat file differed from all other ICD-9 code files available on
				cms.gov. See repo README for details on how the files differed and what I did
				to create the ICD-9 files with a single layout
				*	Instead of trying to deal with different file layouts among the ICD-9 codes
					(and dealing with other ICD-9 releases that had two separate flat .txt files, 
					one with short descriptions, the other with long, I finally broke down and 
					did a save-as of the Excel files within the ICD-9 zip archives
					to be a standard file format that is importable by SQL Server (sigh, for SQL
					ignoring the de facto standard for .csv files, RFC 4180)
		2018.01.15 NLM
			*	Add documentation
		2018.01.02 NLM (Nicole Lindner-Miles) 
			*	Initial version

	INTELLECTUAL PROPERTY
		*	I, Nicole M. Lindner-Miles, developed this script on my own time 
			without company resources or proprietary/confidential information.
====================================================================================== */

	/* Define parameters used through this script 
		@NewLine is my personal preference for writing messages to the log. It inserts
		two new lines to the log before it adds the message. Remove it if you prefer
	*/
	DECLARE @NewLine CHAR(2) = CHAR(10) + CHAR(10);
	DECLARE @SQL VARCHAR(MAX);

	/**
	 *  Dependent on which @Table_Action is invoked, this will either
	 *  'DROP_CREATE': Create permanent output table for ICD diagnosis codes,
	 *  dropping the table if it already exists
	 *  'TRUNCATE': TRUNCATE the existing output table
	 *  'DELETE_ICD9': Delete any ICD-9 codes from the existing output table
	 *  'DELETE_ICD10': Delete any ICD-10 codes from the existing output table
	 */
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
			 CMS_Fiscal_Year  INT            NOT NULL
			,Effective_Date   DATE           NOT NULL
			,End_Date         DATE           NOT NULL
			,ICD_Version      INT            NOT NULL
			,Diagnosis_Code   VARCHAR(7)     NOT NULL
			,Code_Desc_Short  VARCHAR(60)    NOT NULL
			,Code_Desc_Long   VARCHAR(323)   NOT NULL
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
	

	/* Load all ICD diagnosis codes and their descriptions
	=================================================================================== */
	RAISERROR ('%s%s--- --- LOAD ICD DIAGNOSIS CODES --- ---', 0, 1, @NewLine, @NewLine) 

	/**
	 *  Create temporary table #CMS_ICD_Diag_Release_Map and populate it, conditional on 
	 *  @Which_ICD_Version_To_Load, with the files that will be loaded here, and 
	 *  the CMS release info (ICD version, CMS FY, and effective/end dates) for each file
	 */
	RAISERROR ('%s--- Create lookup table (to use in loop) with CMS fiscal years and the available source files with ICD diagnosis codes ---', 0, 1, @NewLine) 
	
	IF OBJECT_ID('tempdb..#CMS_ICD_Diag_Release_Map') IS NOT NULL
	BEGIN
		DROP TABLE #CMS_ICD_Diag_Release_Map
	END
	CREATE TABLE #CMS_ICD_Diag_Release_Map (
		 ICD_Version		VARCHAR(2)		NOT NULL
		,CMS_Fiscal_Year  VARCHAR(4) 		NOT NULL
		,Effective_Date   DATE       		NOT NULL
		,End_Date         DATE       		NOT NULL
		,ICD_File_Name		VARCHAR(200)	NULL
	);

	IF @Which_ICD_Version_To_Load IN ('ALL', '10')
	BEGIN
		INSERT INTO #CMS_ICD_Diag_Release_Map (
			 ICD_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			--,ICD_File_Name Not required for ICD-10. Has a standard naming convention
		)
		VALUES
			 ('10', '2016', '2015-10-01', '2016-09-30', 'icd10cm_order_2016.txt')
			,('10', '2017', '2016-10-01', '2017-09-30', 'icd10cm_order_2017.txt')
			,('10', '2018', '2017-10-01', '2018-09-30', 'icd10cm_order_2018.txt')
	END

	IF @Which_ICD_Version_To_Load IN ('ALL', '09', '9')
	BEGIN
		INSERT INTO #CMS_ICD_Diag_Release_Map (
			 ICD_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			,ICD_File_Name
		)
		VALUES
			 ('9', '2010', '2009-10-01', '2010-09-30', 'V27LONG_SHORT_DX_110909u021012 Sheet1.txt')
			,('9', '2011', '2010-10-01', '2011-09-30', 'CMS28_DESC_LONG_SHORT_DX Sheet1.txt')
			,('9', '2012', '2011-10-01', '2012-09-30', 'CMS29_DESC_LONG_SHORT_DX 101111u021012 Sheet1.txt')
			,('9', '2013', '2012-10-01', '2013-09-30', 'CMS30_DESC_LONG_SHORT_DX 080612 Sheet1.txt')
			,('9', '2014', '2013-10-01', '2014-09-30', 'CMS31_DESC_LONG_SHORT_DX Sheet1.txt')
			,('9', '2015', '2014-10-01', '2015-09-30', 'CMS32_DESC_LONG_SHORT_DX Sheet1.txt')
	END


	/**
	 *  Loop through all ICD CMS FYs with a cursor, loading the permanent output 
	 *  table with all available description files via OPENROWSET.
	 */
	DECLARE 
		@This_ICD_Version		  VARCHAR(2),
		@This_CMS_FY           VARCHAR(4),
		@This_Effective_Date   VARCHAR(10),
		@This_End_Date         VARCHAR(10),
		@This_ICD_File_Name	  VARCHAR(200)
	;
	DECLARE Cursor_CMS_Release CURSOR
	LOCAL READ_ONLY FORWARD_ONLY
	FOR
	SELECT 
		ICD_Version,
		CMS_Fiscal_Year,
		CAST(Effective_Date AS VARCHAR(10)) AS Effective_Date,
		CAST(End_Date AS VARCHAR(10)) AS End_Date,
		ICD_File_Name
	FROM #CMS_ICD_Diag_Release_Map
	ORDER BY 
		CMS_Fiscal_Year
	 
	OPEN Cursor_CMS_Release 
	FETCH NEXT 
	FROM Cursor_CMS_Release 
	INTO 
		@This_ICD_Version,
		@This_CMS_FY,
		@This_Effective_Date,
		@This_End_Date,
		@This_ICD_File_Name

	WHILE @@FETCH_STATUS = 0
	BEGIN

		RAISERROR ('%s--- Inserting ICD-%s diagnosis codes for CMS FY %s ---', 0, 1, @NewLine, @This_ICD_Version, @This_CMS_FY) 

		IF @This_ICD_Version = 9
		BEGIN

			SET @SQL = '
			INSERT INTO ' + @Schema_Name + '.' + @Table_Name + '(
				 ICD_Version
				,CMS_Fiscal_Year
				,Effective_Date
				,End_Date
				,Diagnosis_Code
				,Code_Desc_Short
				,Code_Desc_Long
			)
			SELECT 
				' + @This_ICD_Version + ' AS ICD_Version
				,' + @This_CMS_FY + ' AS CMS_Fiscal_Year
				,''' + @This_Effective_Date + ''' AS Effective_Date
				,''' + @This_End_Date + ''' AS End_Date
				,SUBSTRING(LTRIM(RTRIM(src.Diagnosis_Code)), 1, 5) AS Diagnosis_Code
				,SUBSTRING(LTRIM(RTRIM(REPLACE(src.Code_Desc_Short, ''""'', ''"''))), 1, 60) AS Code_Desc_Short
				,SUBSTRING(LTRIM(RTRIM(REPLACE(src.Code_Desc_Long, ''""'', ''"''))), 1, 323) AS Code_Desc_Long
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\ICD9_CM\' + @This_ICD_File_Name
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\ICD9_CM\icd9cm_format.fmt'
				+ '''
				,ERRORFILE = ''' + @Source_File_Dir + '\ICD9_CM\Errorfile_Diag_FY' + @This_CMS_FY + '.err'''
				+ '
				,FIRSTROW = 2
				,CODEPAGE = 65001
			) AS src 
			
			;'

			EXEC (@SQL)
		END

		ELSE IF @This_ICD_Version = 10
		BEGIN

			SET @SQL = '
			INSERT INTO ' + @Schema_Name + '.' + @Table_Name + '(
				 ICD_Version
				,CMS_Fiscal_Year
				,Effective_Date
				,End_Date
				,Diagnosis_Code
				,Code_Desc_Short
				,Code_Desc_Long
			)
			SELECT 
				' + @This_ICD_Version + ' AS ICD_Version
				,' + @This_CMS_FY + ' AS CMS_Fiscal_Year
				,''' + @This_Effective_Date + ''' AS Effective_Date
				,''' + @This_End_Date + ''' AS End_Date
				,SUBSTRING(LTRIM(RTRIM(src.Diagnosis_Code)), 1, 7) AS Diagnosis_Code
				,SUBSTRING(LTRIM(RTRIM(src.Code_Desc_Short)), 1, 60) AS Code_Desc_Short
				,SUBSTRING(LTRIM(RTRIM(src.Code_Desc_Long)), 1, 323) AS Code_Desc_Long
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\ICD10_CM\' + @This_ICD_File_Name
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\ICD10_CM\icd10cm_order_format.fmt'
				+ '''
				,ERRORFILE = ''' + @Source_File_Dir + '\ICD10_CM\Errorfile_Diag_FY' + @This_CMS_FY + '.err'''
				+ '
				,FIRSTROW = 1
			) AS src 
			WHERE 
				Code_Is_HIPAA_Valid = ''1''
			;'

			EXEC (@SQL)

		END

		FETCH NEXT 
		FROM Cursor_CMS_Release 
		INTO 
			@This_ICD_Version,
			@This_CMS_FY,
			@This_Effective_Date,
			@This_End_Date,
			@This_ICD_File_Name
	END
	CLOSE Cursor_CMS_Release 
	DEALLOCATE Cursor_CMS_Release 

END

GO