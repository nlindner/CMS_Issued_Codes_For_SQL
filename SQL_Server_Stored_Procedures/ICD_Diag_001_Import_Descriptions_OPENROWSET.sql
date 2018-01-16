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
		*	This is the simple (OPENROWSET) method to import this info.
			dbo.ICD_Diag_001_Import_Descriptions_AsValues does exactly the same thing,
			but does not require OPENROWSET permissions (i.e., ADMINISTER BULK OPERATIONS)
		*	This imports flat files with ICD-9 and ICD-10 diagnosis code descriptions, 
			available for download from cms.gov, into a SQL Server table, to serve as a 
			simple lookup/reference/dimension table. 
		*	This loads ICD-9 and ICD-10 separately because the code-description files
			on cms.gov have a different layout and format for ICD-9 vs ICD-10, as:
			*	ICD-10: one file, fixed-length format, with both short and long descriptions
			*	ICD-9: two files, fixed-length format, one with the diagnosis code and the 
				short description, the other with the code and long description.
			*	Both files have a fixed-length format with a space between each field.
				The .fmt files have a placeholder (Filler_##) for them, but does not load 
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
			Specifies which ICD-version codes should be loaded, defaults to loading
			all of them
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
		*	LOAD ICD-9: Dependent on @Which_ICD_Version_To_Load IN ('ALL', '9', '09')
			*	Create temporary table #CMS_ICD9_Release_Map and populate it with the 
				ICD-9 CMS fiscal years (FY), and effective/end dates for all files loaded here
				along with the CMS ICD-9 code release version
				*	Note that the CMS ICD-9 code release version here differs from the 
					Medicare Code Editor (MCE) release version in the MCE SPs in this repo
			*	Create temp table #CMS_ICD9_Diag_Desc_Files and populate it with both the 
				"short" and "long" code description files to load for each CMS fiscal year
				*	Unlike the ICD-10 load process and other SPs in this repo, the only 
					non-Excel files that I could locate on cms.gov for ICD-9 diagnosis code 
					descriptions are separate "short" and "long" description files for each FY.
			*	Create temp tables #CMS_ICD9_Diag_Desc_Short and #CMS_ICD9_Diag_Desc_Long that 
				will be loaded from either the "short" or the "long" code description files
			*	Loop through all ICD-9 CMS FYs with a cursor, loading the temp tables
				with all available description files via OPENROWSET. For each CMS FY, must
				load both a short and a long description file.
				*	These files were downloaded directly from cms.gov, so they
					have a fixed-length format with a space between each field.
					The .fmt file has a placeholder for them, but does not load them
					to the permanent output table
			*	Load the permanent output table with ICD-9 codes and descriptions
		*	LOAD ICD-10: Dependent on @Which_ICD_Version_To_Load IN ('ALL', '10')
			*	Create temporary table #CMS_ICD10_Release_Map and populate it with the 
				ICD-10 CMS FYs, and effective/end dates for all files loaded here
			*	Loop through all ICD-10 CMS FYs with a cursor, loading the permanent output 
				table with all available description files via OPENROWSET.
				*	These files were downloaded directly from cms.gov, so they
					have a fixed-length format with a space between each field.
					The .fmt file has a placeholder for them, but does not load them
					to the permanent output table

	EXAMPLE CALL
	exec dbo.ICD_Diag_001_Import_Descriptions_OPENROWSET 
		@Table_Name = 'DIM_ICD_Diagnosis_Test'
		,@Table_Action = 'DROP_CREATE'
		,@Which_ICD_Version_To_Load = 'ALL'
		,@Source_File_Dir = 
			'C:\Users\Nicole\Documents\GitHub\CMS_MS_DRG_Grouper_Help\CMS_ICD_Code_Descriptions'

	CHANGE LOG
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
	

	/* LOAD ICD-9
			Dependent on @Which_ICD_Version_To_Load IN ('ALL', '9', '09')
	=================================================================================== */
	IF @Which_ICD_Version_To_Load IN ('ALL', '9', '09')
	BEGIN
		RAISERROR ('%s%s--- --- LOAD ICD-9 DIAGNOSIS CODES --- ---', 0, 1, @NewLine, @NewLine) 
		/**
		 *  Create temporary table #CMS_ICD9_Release_Map and populate it with the 
		 *  ICD-9 CMS fiscal years (FY), and effective/end dates for all files loaded here
		 *  along with the CMS ICD-9 code release version
		 */
		RAISERROR ('%s--- Create temp table with available ICD-9 FY files to import ---', 0, 1, @NewLine) 
		IF OBJECT_ID('tempdb..#CMS_ICD9_Release_Map') IS NOT NULL
		BEGIN
			DROP TABLE #CMS_ICD9_Release_Map
		END
		CREATE TABLE #CMS_ICD9_Release_Map (
			 CMS_Diag_Release_Version  VARCHAR(2)  NOT NULL
			,CMS_Fiscal_Year           VARCHAR(4)  NOT NULL
			,Effective_Date            DATE        NOT NULL
			,End_Date                  DATE        NOT NULL
		)
		INSERT INTO #CMS_ICD9_Release_Map (
			 CMS_Diag_Release_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
		)
		VALUES
			 ('28', '2011', '2010-10-01', '2011-09-30')
			,('29', '2012', '2011-10-01', '2012-09-30')
			,('30', '2013', '2012-10-01', '2013-09-30')
			,('31', '2014', '2013-10-01', '2014-09-30')
			,('32', '2015', '2014-10-01', '2015-09-30')


		/**
		 *  Create temp table #CMS_ICD9_Diag_Desc_Files and populate it with both the 
		 *  "short" and "long" code description files to load for each CMS fiscal year
		 */
		RAISERROR ('%s--- Create separate temp tables to store ICD-9 short and long descriptions ---', 0, 1, @NewLine) 
		IF OBJECT_ID('tempdb..#CMS_ICD9_Diag_Desc_Files') IS NOT NULL
		BEGIN
			DROP TABLE #CMS_ICD9_Diag_Desc_Files
		END
		CREATE TABLE #CMS_ICD9_Diag_Desc_Files (
			 CMS_Diag_Release_Version  VARCHAR(2)    NOT NULL
			,Description_Type          VARCHAR(5)    NOT NULL
			,CMS_File_Name             VARCHAR(100)  NOT NULL
		)
		INSERT INTO #CMS_ICD9_Diag_Desc_Files (
			 CMS_Diag_Release_Version
			,Description_Type
			,CMS_File_Name
		)
		VALUES
			 ('28', 'SHORT', 'CMS28_DESC_SHORT_DX.txt')
			,('28', 'LONG', 'CMS28_DESC_LONG_DX.txt')
			,('29', 'SHORT', 'CMS29_DESC_SHORT_DX.txt')
			,('29', 'LONG', 'CMS29_DESC_LONG_DX.101111.txt')
			,('30', 'SHORT', 'CMS30_DESC_SHORT_DX.txt')
			,('30', 'LONG', 'CMS30_DESC_LONG_DX 080612.txt')
			,('31', 'SHORT', 'CMS31_DESC_SHORT_DX.txt')
			,('31', 'LONG', 'CMS31_DESC_LONG_DX.txt')
			,('32', 'SHORT', 'CMS32_DESC_SHORT_DX.txt')
			,('32', 'LONG', 'CMS32_DESC_LONG_DX.txt')
		/*
		SELECT 
			 cmsInfo.CMS_Diag_Release_Version
			,cmsInfo.CMS_Fiscal_Year
			,cmsInfo.Effective_Date
			,cmsInfo.End_Date
			,cmsFile.Description_Type
			,cmsFile.CMS_File_Name

		FROM 
			#CMS_ICD9_Diag_Desc_Files cmsFile
			INNER JOIN #CMS_ICD9_Release_Map cmsInfo
				ON cmsInfo.CMS_Diag_Release_Version = cmsFile.CMS_Diag_Release_Version
		*/

		/**
		 *  Create temp tables #CMS_ICD9_Diag_Desc_Short and #CMS_ICD9_Diag_Desc_Long that 
		 *  will be loaded from either the "short" or the "long" code description files
		 */
		IF OBJECT_ID('tempdb..#CMS_ICD9_Diag_Desc_Short') IS NOT NULL
		BEGIN
			DROP TABLE #CMS_ICD9_Diag_Desc_Short
		END
		CREATE TABLE #CMS_ICD9_Diag_Desc_Short (
			 CMS_Diag_Release_Version   VARCHAR(2)  NOT NULL
			,Diagnosis_Code             VARCHAR(5)  NOT NULL
			,Code_Desc_Short            VARCHAR(60) NOT NULL
		);

		IF OBJECT_ID('tempdb..#CMS_ICD9_Diag_Desc_Long') IS NOT NULL
		BEGIN
			DROP TABLE #CMS_ICD9_Diag_Desc_Long
		END
		CREATE TABLE #CMS_ICD9_Diag_Desc_Long (
			 CMS_Diag_Release_Version   VARCHAR(2)   NOT NULL
			,Diagnosis_Code             VARCHAR(5)   NOT NULL
			,Code_Desc_Long             VARCHAR(256) NOT NULL
		);

		/**
		 *  Loop through all ICD-9 CMS FYs with a cursor, loading the temp tables
		 *  with all available description files via OPENROWSET. For each CMS FY, must
		 *  load both a short and a long description file.
		 */
		-- Parameters set within each cursor loop
		DECLARE 
			@This_File_Name_Desc_Short   VARCHAR(100),
			@This_File_Name_Desc_Long    VARCHAR(100);
		
		-- Cursor parameters
		DECLARE 
			@This_ICD9_Diag_Release  VARCHAR(2),
			@This_ICD9_CMS_FY        VARCHAR(4);

		DECLARE Cursor_ICD9_CMS_Release CURSOR
		LOCAL READ_ONLY FORWARD_ONLY
		FOR
		SELECT 
			CMS_Diag_Release_Version,
			CMS_Fiscal_Year
		FROM #CMS_ICD9_Release_Map
		 
		OPEN Cursor_ICD9_CMS_Release 
		FETCH NEXT 
		FROM Cursor_ICD9_CMS_Release 
		INTO 
			@This_ICD9_Diag_Release,
			@This_ICD9_CMS_FY
		WHILE @@FETCH_STATUS = 0
		BEGIN

			RAISERROR ('%s--- Loading ICD-9 diagnosis codes for CMS FY %s ---', 0, 1, @NewLine, @This_ICD9_CMS_FY) 
			-- Clear parameters from previous loop iterations and then set
			SET @This_File_Name_Desc_Short = NULL;
			SET @This_File_Name_Desc_Long = NULL;

			SET @This_File_Name_Desc_Short = (
				SELECT CMS_File_Name
				FROM #CMS_ICD9_Diag_Desc_Files
				WHERE CMS_Diag_Release_Version = @This_ICD9_Diag_Release
						AND Description_Type = 'SHORT'
			);

			SET @This_File_Name_Desc_Long = (
				SELECT CMS_File_Name
				FROM #CMS_ICD9_Diag_Desc_Files
				WHERE CMS_Diag_Release_Version = @This_ICD9_Diag_Release
						AND Description_Type = 'LONG'
			);

			RAISERROR ('--- Loading SHORT descriptions from file %s ---', 0, 1, @This_File_Name_Desc_Short) 
			SET @SQL = '
			INSERT INTO #CMS_ICD9_Diag_Desc_Short (
				 CMS_Diag_Release_Version
				,Diagnosis_Code
				,Code_Desc_Short
			)
			SELECT 
				 ''' + @This_ICD9_Diag_Release + ''' AS CMS_Diag_Release_Version
				,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Diagnosis_Code)), CHAR(13), ''''), 1, 5) AS Diagnosis_Code
				,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Code_Desc_Short)), CHAR(13), ''''), 1, 60) AS Code_Desc_Short
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\ICD9_CM\' + @This_File_Name_Desc_Short
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\ICD9_CM\icd9dx_desc_short_format.fmt'
				+ '''
				,ERRORFILE = ''' + @Source_File_Dir + '\ICD9_CM\Errorfile_ICD9_Diag_Desc_Short_CMS' + @This_ICD9_Diag_Release + '.err'''
				+ '
				,FIRSTROW = 1
			) AS src
			;'

			EXEC (@SQL)

			RAISERROR ('--- Loading LONG  descriptions from file %s ---', 0, 1, @This_File_Name_Desc_Long) 
			SET @SQL = '
			INSERT INTO #CMS_ICD9_Diag_Desc_Long (
				 CMS_Diag_Release_Version
				,Diagnosis_Code
				,Code_Desc_Long
			)
			SELECT 
				 ''' + @This_ICD9_Diag_Release + ''' AS CMS_Diag_Release_Version
				,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Diagnosis_Code)), CHAR(13), ''''), 1, 5) AS Diagnosis_Code
				,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Code_Desc_Long)), CHAR(13), ''''), 1, 323) AS Code_Desc_Long
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\ICD9_CM\' + @This_File_Name_Desc_Long
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\ICD9_CM\icd9dx_desc_long_format.fmt'
				+ '''
				,ERRORFILE = ''' + @Source_File_Dir + '\ICD9_CM\Errorfile_ICD9_Diag_Desc_Long_CMS' + @This_ICD9_Diag_Release + '.err'''
				+ '
				,FIRSTROW = 1
			) AS src
			;'

			EXEC (@SQL)

			FETCH NEXT 
			FROM Cursor_ICD9_CMS_Release 
			INTO 
				@This_ICD9_Diag_Release,
				@This_ICD9_CMS_FY
		END
		CLOSE Cursor_ICD9_CMS_Release 
		DEALLOCATE Cursor_ICD9_CMS_Release 

		/**
		 *  Load the permanent output table with ICD-9 codes and descriptions
		 */
		RAISERROR ('%s--- Inserting all ICD-9 diagnosis codes ---', 0, 1, @NewLine) 

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
			 9 AS Icd_Version
			,cmsInfo.CMS_Fiscal_Year
			,cmsInfo.Effective_Date
			,cmsInfo.End_Date
			,combineDesc.Diagnosis_Code
			,combineDesc.Code_Desc_Short
			,combineDesc.Code_Desc_Long
		FROM 
			#CMS_ICD9_Release_Map cmsInfo
			INNER JOIN (
				SELECT 
					ISNULL(dxS.CMS_Diag_Release_Version, dxL.CMS_Diag_Release_Version) AS CMS_Diag_Release_Version
					,ISNULL(dxS.Diagnosis_Code, dxL.Diagnosis_Code) AS Diagnosis_Code
					,dxS.Code_Desc_Short
					,dxL.Code_Desc_Long
				FROM 
					#CMS_ICD9_Diag_Desc_Short dxS
					FULL JOIN #CMS_ICD9_Diag_Desc_Long dxL
						ON dxS.CMS_Diag_Release_Version = dxL.CMS_Diag_Release_Version
						AND dxS.Diagnosis_Code = dxL.Diagnosis_Code
			) combineDesc
				ON combineDesc.CMS_Diag_Release_Version = cmsInfo.CMS_Diag_Release_Version
		;'
		EXEC (@SQL)
	END


	/* LOAD ICD-10
			Dependent on @Which_ICD_Version_To_Load IN ('ALL', '10')
	=================================================================================== */
	IF @Which_ICD_Version_To_Load IN ('ALL', '10')
	BEGIN
		RAISERROR ('%s%s--- --- LOAD ICD-10 DIAGNOSIS CODES --- ---', 0, 1, @NewLine, @NewLine) 

		/**
		 *  Create temporary table #CMS_ICD10_Release_Map and populate it with the 
		 *  ICD-10 CMS FYs, and effective/end dates for all files loaded here
		 */
		RAISERROR ('%s--- Create temp table with available ICD-10 FY files to import ---', 0, 1, @NewLine) 
		IF OBJECT_ID('tempdb..#CMS_ICD10_Release_Map') IS NOT NULL
		BEGIN
			DROP TABLE #CMS_ICD10_Release_Map
		END
		CREATE TABLE #CMS_ICD10_Release_Map (
			 CMS_Fiscal_Year   VARCHAR(4) NOT NULL
			,Effective_Date    DATE       NOT NULL
			,End_Date          DATE       NOT NULL
		);

		INSERT INTO #CMS_ICD10_Release_Map (
			 CMS_Fiscal_Year
			,Effective_Date
			,End_Date
		)
		VALUES
			 ('2016', '2015-10-01', '2016-09-30')
			,('2017', '2016-10-01', '2017-09-30')
			,('2018', '2017-10-01', '2018-09-30')


		/**
		 *  Loop through all ICD-10 CMS FYs with a cursor, loading the permanent output 
		 *  table with all available description files via OPENROWSET.
		 */
		DECLARE 
			@This_ICD10_CMS_FY           VARCHAR(4),
			@This_ICD10_Effective_Date   VARCHAR(10),
			@This_ICD10_End_Date         VARCHAR(10)
		;
		DECLARE Cursor_ICD10_CMS_Release CURSOR
		LOCAL READ_ONLY FORWARD_ONLY
		FOR
		SELECT 
			CMS_Fiscal_Year,
			CAST(Effective_Date AS VARCHAR(10)) AS Effective_Date,
			CAST(End_Date AS VARCHAR(10)) AS End_Date
		FROM #CMS_ICD10_Release_Map
		 
		OPEN Cursor_ICD10_CMS_Release 
		FETCH NEXT 
		FROM Cursor_ICD10_CMS_Release 
		INTO 
			@This_ICD10_CMS_FY,
			@This_ICD10_Effective_Date,
			@This_ICD10_End_Date
		WHILE @@FETCH_STATUS = 0
		BEGIN
			RAISERROR ('%s--- Inserting ICD-10 diagnosis codes for CMS FY %s ---', 0, 1, @NewLine, @This_ICD10_CMS_FY) 

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
				 10 AS ICD_Version
				,' + @This_ICD10_CMS_FY + ' AS CMS_Fiscal_Year
				,''' + @This_ICD10_Effective_Date + ''' AS Effective_Date
				,''' + @This_ICD10_End_Date + ''' AS End_Date
				,SUBSTRING(LTRIM(RTRIM(src.Diagnosis_Code)), 1, 7) AS Diagnosis_Code
				,SUBSTRING(LTRIM(RTRIM(src.Code_Desc_Short)), 1, 60) AS Code_Desc_Short
				,SUBSTRING(LTRIM(RTRIM(src.Code_Desc_Long)), 1, 323) AS Code_Desc_Long
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\ICD10_CM\icd10cm_order_' + @This_ICD10_CMS_FY + '.txt'
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\ICD10_CM\icd10cm_order_format.fmt'
				+ '''
				,ERRORFILE = ''' + @Source_File_Dir + '\ICD10_CM\Errorfile_ICD10_Diag_FY' + @This_ICD10_CMS_FY + '.err'''
				+ '
				,FIRSTROW = 1
			) AS src
			WHERE
				Code_Is_HIPAA_Valid = ''1''
			;'
			EXEC (@SQL)
				
				FETCH NEXT 
				FROM Cursor_ICD10_CMS_Release 
				INTO 
					@This_ICD10_CMS_FY,
					@This_ICD10_Effective_Date,
					@This_ICD10_End_Date
		END
		CLOSE Cursor_ICD10_CMS_Release 
		DEALLOCATE Cursor_ICD10_CMS_Release 
	END

END

GO