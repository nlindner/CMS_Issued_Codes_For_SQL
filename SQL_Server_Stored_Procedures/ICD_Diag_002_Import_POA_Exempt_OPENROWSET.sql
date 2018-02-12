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
	,@Table_Action VARCHAR(16) = 'DROP_CREATE' -- available: DROP_CREATE, TRUNCATE, DELETE_ICD9, DELETE_ICD10
	,@Which_ICD_Version_To_Load VARCHAR(4) = 'ALL'
	,@Source_File_Dir VARCHAR(1000) = NULL
) AS

BEGIN

/* ======================================================================================
	AUTHOR
		Nicole M. Lindner-Miles

	STORED PROCEDURE
		ICD_Diag_002_Import_POA_Exempt_OPENROWSET

	DESCRIPTION
		*	This is the simple (OPENROWSET) method to import this info.
			dbo.ICD_Diag_002_Import_POA_Exempt_AsValues does exactly the same thing,
			but does not require OPENROWSET permissions (i.e., ADMINISTER BULK OPERATIONS)
		*	This imports flat files, available for download from cms.gov, with ICD-9 and 
			ICD-10 diagnosis codes that are exempt from Present on Arrival (POA) reporting
		*	See the repo README for an explanation of why FY 2013 is unavailable and
			the manual process required to create the FY 2011 file from the PDF available
			at cms.gov
		*	This is designed to load those flat files to a SQL Server table. In the bulk load
			process, additional standardization is being applied as the files are loaded.
			*	the ICD-10 POA files surround the Code_Desc_Long with double-quotes as
				text qualifiers to escape special characters. SQL Server does not recognize 
				that feature of the de facto .csv file standard, so a REPLACE() function 
				is used to strip those out during load.

		*	See repo LICENSE and see repo README for details and sources for files loaded here

	PARAMETERS
		@Schema_Name (Required, if other than default of 'dbo')
		@Table_Name (Required, if other than default of 'DIM_ICD_Diagnosis_POA_Exempt')
			This procedure creates permanent output table @Schema_Name.Table_Name
			and loads it with all POA exempt ICD code lists available in this repo
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
			Required input parameter. The location of the CMS_ICD_Diagnoses_POA_Exempt
			subdirectory

	WHAT THIS PROCEDURE DOES
		*	Dependent on which @Table_Action is invoked, this will either
			'DROP_CREATE': Create permanent output table for POA-exempt ICD diagnosis codes,
			dropping the table if it already exists
			'TRUNCATE': TRUNCATE the existing output table
			'DELETE_ICD9': Delete any ICD-9 codes from the existing output table
			'DELETE_ICD10': Delete any ICD-10 codes from the existing output table
		*	Create temporary table #CMS_FY_Release_Map and populate it, conditional on 
			@Which_ICD_Version_To_Load, with the files that will be loaded here, and the 
			CMS release info (ICD version, CMS FY, and effective/end dates) for each file
		*	Load all ICD diagnosis codes that are exempt from POA reporting
			*	Loop through all ICD CMS FYs with a cursor, loading the permanent output 
				table with all available POA-exempt files via OPENROWSET.
			*	Standardize what is available in the output table because of differences
				in what is available in the ICD-9 vs ICD-10 releases files (e.g., 
				ICD-9 diagnosis codes do not have a period, ICD-10 codes do)
	
	EXAMPLE CALL
	exec dbo.ICD_Diag_002_Import_POA_Exempt_OPENROWSET 
		@Table_Name = 'DIM_ICD_Diagnosis_POA_Exempt'
		,@Table_Action = 'DROP_CREATE'
		,@Which_ICD_Version_To_Load = 'ALL'
		,@Source_File_Dir = 
			'C:\Users\Nicole\Documents\GitHub\CMS_MS_DRG_Grouper_Help\CMS_ICD_Diagnoses_POA_Exempt'

	CHANGE LOG
		2018.02.11 NLM
			*	Added documentation and added all ICD-9 POA exempt lists that I could find.
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
	 *  'DROP_CREATE': Create permanent output table for POA-exempt ICD diagnosis codes,
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
			 CMS_Fiscal_Year              INT            NOT NULL
			,ICD_Version                  INT            NOT NULL
			,Effective_Date               DATE           NOT NULL
			,End_Date                     DATE           NOT NULL
			,Diagnosis_Code               VARCHAR(7)     NOT NULL
			,Diagnosis_Code_With_Period   VARCHAR(8)     NULL
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


	/* Load all ICD diagnosis codes that are exempt from POA reporting
	=================================================================================== */
	RAISERROR ('%s%s--- --- LOAD POA-EXEMPT ICD DIAGNOSIS CODES --- ---', 0, 1, @NewLine, @NewLine) 

	/**
	 *  Create temporary table #CMS_FY_Release_Map and populate it, conditional on 
	 *  @Which_ICD_Version_To_Load, with the files that will be loaded here, and the 
	 *  CMS release info (ICD version, CMS FY, and effective/end dates) for each file
	 */

	RAISERROR ('%s--- Create lookup table (to use in loop) with CMS fiscal years and the available source files with ICD diagnosis codes that are exempt from POA reporting ---', 0, 1, @NewLine) 

	IF OBJECT_ID('tempdb..#CMS_FY_Release_Map') IS NOT NULL
	BEGIN
		DROP TABLE #CMS_FY_Release_Map
	END
	CREATE TABLE #CMS_FY_Release_Map (
		 ICD_Version				VARCHAR(2)     NOT NULL
		,CMS_Fiscal_Year        VARCHAR(4)     NOT NULL
		,Effective_Date         DATE       		NOT NULL
		,End_Date               DATE       		NOT NULL
		,POA_File_Name          VARCHAR(200)   NOT NULL
	)

	IF @Which_ICD_Version_To_Load IN ('ALL', '10')
	BEGIN
		INSERT INTO #CMS_FY_Release_Map (
			 ICD_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			,POA_File_Name
		)
		VALUES
			 ('10', '2016', '2015-10-01', '2016-09-30', 'POAexemptcodes2016.txt')
			,('10', '2017', '2016-10-01', '2017-09-30', 'POAexemptcodes2017.txt')
			,('10', '2018', '2017-10-01', '2018-09-30', 'POAexemptcodes2018.txt')
	END

	IF @Which_ICD_Version_To_Load IN ('ALL', '09', '9')
	BEGIN
		INSERT INTO #CMS_FY_Release_Map (
			 ICD_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			,POA_File_Name
		)
		VALUES
			 ('9', '2011', '2010-10-01', '2011-09-30', 'POA_Exempt_Per_CMS_Transmittal_R756OTN_Oct12010_FY2011.txt')
			,('9', '2012', '2011-10-01', '2012-09-30', 'POA_Exempt_Diagnosis_Codes_Oct12011_FY2012.txt')
			-- Havent found source yet,('9', '2013', '2012-10-01', '2013-09-30', '')
			,('9', '2014', '2013-10-01', '2014-09-30', 'POA_Exempt_Diagnosis_Codes_Oct12013_FY2014.txt')
			,('9', '2015', '2014-10-01', '2015-09-30', 'ICD-9_POA_Exempt_Diagnosis_Codes_Oct12014_FY2015.txt')
	END

	RAISERROR ('%s--- Create temp table to store raw loaded codes ---', 0, 1, @NewLine) 

	/**
	 *  Loop through all ICD CMS FYs with a cursor, loading the permanent output 
	 *  table with all available POA-exempt files via OPENROWSET.
	 */
	DECLARE 
		@This_ICD_Version		  VARCHAR(2),
		@This_CMS_FY           VARCHAR(4),
		@This_Effective_Date   VARCHAR(10),
		@This_End_Date         VARCHAR(10),
		@This_POA_File_Name	  VARCHAR(200);
	;

	DECLARE Cursor_CMS_FY CURSOR
	LOCAL READ_ONLY FORWARD_ONLY
	FOR
	SELECT 
		ICD_Version,
		CMS_Fiscal_Year,
		CAST(Effective_Date AS VARCHAR(10)) AS Effective_Date,
		CAST(End_Date AS VARCHAR(10)) AS End_Date,
		POA_File_Name
	FROM #CMS_FY_Release_Map
	ORDER BY 
		CMS_Fiscal_Year
	 
	OPEN Cursor_CMS_FY 
	FETCH NEXT 
	FROM Cursor_CMS_FY 
	INTO 
		@This_ICD_Version,
		@This_CMS_FY,
		@This_Effective_Date,
		@This_End_Date,
		@This_POA_File_Name

	WHILE @@FETCH_STATUS = 0
	BEGIN

		RAISERROR ('%s--- Loading POA-exempt ICD-%s-CM codes for CMS FY %s from file %s ---', 0, 1, @NewLine, @This_ICD_Version, @This_CMS_FY , @This_POA_File_Name) 

		IF @This_ICD_Version = 9
		BEGIN

			SET @SQL = '
			INSERT INTO ' + @Schema_Name + '.' + @Table_Name + '(
				 ICD_Version
				,CMS_Fiscal_Year
				,Effective_Date
				,End_Date
				,Diagnosis_Code
				--,Diagnosis_Code_With_Period
				,Code_Desc_Long
			)
			SELECT 
				 ' + @This_ICD_Version + ' AS ICD_Version
				 ,' + @This_CMS_FY + ' AS CMS_Fiscal_Year
				,''' + @This_Effective_Date + ''' AS Effective_Date
				,''' + @This_End_Date + ''' AS End_Date
				,SUBSTRING(LTRIM(RTRIM(src.Diagnosis_Code)), 1, 5) AS Diagnosis_Code
				,LTRIM(RTRIM(src.Code_Desc_Long)) AS Code_Desc_Long
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\' + @This_POA_File_Name
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\ICD9_POAexemptcodes_format.fmt'
				+ '''
				,ERRORFILE = ''' + @Source_File_Dir + '\Errorfile_POA_Exempt_CMS_FY' + @This_CMS_FY + '.err'''
				+ '
				,FIRSTROW = 2
			) AS src
			;'
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
				,Diagnosis_Code_With_Period
				,Code_Desc_Long
			)
			SELECT 
				 ' + @This_ICD_Version + ' AS ICD_Version
				 ,' + @This_CMS_FY + ' AS CMS_Fiscal_Year
				,''' + @This_Effective_Date + ''' AS Effective_Date
				,''' + @This_End_Date + ''' AS End_Date
				,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Diagnosis_Code_With_Period)), ''.'', ''''), 1, 7) AS Diagnosis_Code
				,SUBSTRING(LTRIM(RTRIM(src.Diagnosis_Code_With_Period)), 1, 8) AS Diagnosis_Code_With_Period
				,SUBSTRING(LTRIM(RTRIM(REPLACE(src.Code_Desc_Long, ''"'', ''''))), 1, 323) AS Code_Desc_Long
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\' + @This_POA_File_Name
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\POAexemptcodes_format.fmt'
				+ '''
				,ERRORFILE = ''' + @Source_File_Dir + '\Errorfile_POA_Exempt_CMS_FY' + @This_CMS_FY + '.err'''
				+ '
				,FIRSTROW = 2
			) AS src
			;'
		END

		EXEC (@SQL)

		FETCH NEXT 
		FROM Cursor_CMS_FY 
		INTO 
			@This_ICD_Version,
			@This_CMS_FY,
			@This_Effective_Date,
			@This_End_Date,
			@This_POA_File_Name

	END
	CLOSE Cursor_CMS_FY 
	DEALLOCATE Cursor_CMS_FY 

	/**
	 *  Standardize what is available in the output table because of differences
	 *  in what is available in the ICD-9 vs ICD-10 releases files (e.g., 
	 *  ICD-9 diagnosis codes do not have a period, ICD-10 codes do)
	 */
	IF @Which_ICD_Version_To_Load IN ('ALL', '09', '9')
	BEGIN

		SET @SQL = '
			UPDATE ' + @Schema_Name + '.' + @Table_Name + '
				SET Diagnosis_Code_With_Period = 
					CASE
						WHEN LEN(Diagnosis_Code) = 4 THEN Diagnosis_Code
						ELSE SUBSTRING(Diagnosis_Code, 1, 4) + ''.'' + SUBSTRING(Diagnosis_Code, 5, LEN(Diagnosis_Code) - 4)
					END
			WHERE 
				ICD_Version = 9
				AND Diagnosis_Code LIKE ''E%''
			;
			UPDATE ' + @Schema_Name + '.' + @Table_Name + '
				SET Diagnosis_Code_With_Period = 
					CASE
						WHEN LEN(Diagnosis_Code) = 3 THEN Diagnosis_Code
						ELSE SUBSTRING(Diagnosis_Code, 1, 3) + ''.'' + SUBSTRING(Diagnosis_Code, 4, LEN(Diagnosis_Code) - 3)
					END
			WHERE 
				ICD_Version = 9
				AND Diagnosis_Code LIKE ''[V0-9]%''
		;'
		EXEC (@SQL)
	END

END

GO
