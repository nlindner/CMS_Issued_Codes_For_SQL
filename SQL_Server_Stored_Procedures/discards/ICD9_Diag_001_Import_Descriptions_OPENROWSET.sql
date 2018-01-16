/* Replace HCDatamart_Devt with your intended destination database
USE HCDatamart_Devt
GO
*/

-- If procedure does not already exist, create a stub that will then be replaced by ALTER. The BEGIN CATCH eliminate any error messages if it does already exist
BEGIN TRY
	 EXEC ('CREATE PROCEDURE dbo.ICD9_Diag_001_Import_Descriptions_OPENROWSET AS DECLARE @A varchar(100); SET @A=ISNULL(OBJECT_NAME(@@PROCID), ''unknown'')+'' was not created!''; RAISERROR(@A,16,1);return 9999')
END TRY BEGIN CATCH END CATCH
GO

ALTER PROCEDURE dbo.ICD9_Diag_001_Import_Descriptions_OPENROWSET (
	 @Schema_Name VARCHAR(32) = 'dbo'
	,@Table_Name VARCHAR(100) = 'DIM_ICD_Diagnosis'
	,@Table_Action VARCHAR(16) = 'DELETE_ICD9'
	,@Source_File_Dir VARCHAR(1000) = NULL
) AS
BEGIN
/* ======================================================================================
	AUTHOR
		Nicole M. Lindner-Miles

	STORED PROCEDURE
		ICD9_Diag_001_Import_Descriptions_OPENROWSET

	DESCRIPTION
		*	This is the simple (OPENROWSET) method to import this info.
			dbo.ICD9_Diag_001_Import_Descriptions_AsValues does exactly the same thing,
			but does not require OPENROWSET permissions (i.e., ADMINISTER BULK OPERATIONS)
		*	This imports the flat files with ICD-9-CM code descriptions, available for 
			download from cms.gov, into a SQL Server table, to serve as a simple
			lookup/reference/dimension table. 
			*	Note that the file specification for the ICD-10 order files allows
				the ICD_Desc_Long field to be up to length = 323 (400 - 77), but the
				observed length for ICD-10 files is never longer than 256. You could 
				reasonably decide to set that field length to 256 instead of 323.
			*	Also, just for fun, the ICD-9 CMS v28 long-description file 
				uses CRLF (\r\n) as the line delimiter, while all other files use \n.
				Am handling that via replace in the insert.
		*	This is designed to be called together with its ICD-10 counterpart
			(ICD10_Diag_001_Import_Descriptions_OPENROWSET) to populate a common lookup
			table with all ICD diagnosis codes and their short and long descriptions,
			from flat files available on cms.gov
		*	The separate ICD-9 and ICD-10 SPs exist because the code-description files
			on cms.gov have a different layout and format for ICD-9 vs ICD-10, as:
			*	ICD-10: one file, fixed-length format, with both short and long descriptions
			*	ICD-9: two files, fixed-length format, one with the diagnosis code and the 
				short description, the other with the code and long description.
		*	See repo LICENSE and see README for details and sources for files loaded here

	PARAMETERS
		@Schema_Name (Required, if other than default of 'dbo')
		@Table_Name (Required, if other than default of 'DIM_ICD_Diagnosis')
			This procedure creates permanent output table @Schema_Name.Table_Name
			and loads it with all ICD-9-CM diagnosis code descriptions
		@Table_Action (Required, if other than default of 'DROP_CREATE')
			Valid Values: DROP_CREATE, TRUNCATE, DELETE_ICD9
			Because ICD-9 and ICD-10 codes need to be loaded in separate SPs, this allows
			you to load a common table with both ICD-9 and ICD-10 codes
		@Source_File_Dir
			Required input parameter. The location of the subdirectory 
			containing the source CMS##_Desc_... files

	WHAT THIS PROCEDURE DOES
		*	Dependent on which @Table_Action is invoked, this will either
			'DROP_CREATE': Create permanent output table for ICD diagnosis codes,
			dropping the table if it already exists
			'TRUNCATE': TRUNCATE the existing output table
			'DELETE_ICD9': Delete any ICD-9 codes in the the existing output table
		*	Create temporary table #CMS_ICD9_Release_Map and populate it with the CMS
			fiscal year (FY), and effective/end dates for all files loaded here
			*	Note that the CMS ICD-code release version here differs from the 
				Medicare Code Editor (MCE) release version in the MCE SPs
		*	Create temp table #CMS_ICD9_Diag_Desc_Files and populate it with both the 
			"short" and "long" code description files to load for each CMS fiscal year
			*	Unlike the other SPs in this repo, the only non-Excel files that I could
				locate on cms.gov for ICD-9 diagnosis code descriptions are separate 
				"short" and "long" description files for each FY. 
		*	Create temp tables #CMS_ICD9_Diag_Desc_Short and #CMS_ICD9_Diag_Desc_Long that 
			will be loaded from either the "short" or the "long" code description files
		*	Use a cursor to loop through all CMS FYs, loading all available 
			description files via OPENROWSET. Must load both a short and a long 
			description file for each CMS FY.
			*	These files were downloaded directly from cms.gov, so they
				have a fixed-length format with a space between each field.
				The .fmt file has a placeholder for them, but does not load them
				to the permanent output table
		*	Load the permanent output table with ICD-9 codes and the short and long descriptions

	EXAMPLE CALL
		exec dbo.ICD9_Diag_001_Import_Descriptions_OPENROWSET 
	 		@Table_Name = 'DIM_ICD_Diagnosis_Test'
			,@Table_Action = 'DELETE_ICD9'
			,@Source_File_Dir = 'C:\Users\Nicole\Documents\GitHub\CMS_MS_DRG_Grouper_Help\CMS_ICD_Code_Descriptions'

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
	 *  'DELETE_ICD10': Delete any ICD-10 codes in the the existing output table
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

	/**
	 *  Create temporary table #CMS_ICD9_Release_Map and populate it with the CMS
	 *  fiscal year (FY), and effective/end dates for all files loaded here
	 */
	RAISERROR ('%s--- Create temp table with available FY files to import ---', 0, 1, @NewLine) 
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
	RAISERROR ('%s--- Create separate temp tables to store short and long descriptions ---', 0, 1, @NewLine) 
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
	 *  Use a cursor to loop through all CMS FYs, loading all available 
	 *  description files via OPENROWSET. Must load both a short and a long 
	 *  description file for each CMS FY.
	 */
	-- Parameters set within the cursor
	DECLARE 
		@This_File_Name_Desc_Short   VARCHAR(100),
		@This_File_Name_Desc_Long    VARCHAR(100);
	
	-- Cursor parameters
	DECLARE 
		@This_Diag_Release  VARCHAR(2),
		@This_CMS_FY        VARCHAR(4);

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
		@This_Diag_Release,
		@This_CMS_FY
	WHILE @@FETCH_STATUS = 0
	BEGIN

		RAISERROR ('%s--- Loading ICD diagnosis descriptions for CMS FY %s ---', 0, 1, @NewLine, @This_CMS_FY) 
		-- Clear parameters from previous loop iterations and then set
		SET @This_File_Name_Desc_Short = NULL;
		SET @This_File_Name_Desc_Long = NULL;

		SET @This_File_Name_Desc_Short = (
			SELECT CMS_File_Name
			FROM #CMS_ICD9_Diag_Desc_Files
			WHERE CMS_Diag_Release_Version = @This_Diag_Release
					AND Description_Type = 'SHORT'
		);

		SET @This_File_Name_Desc_Long = (
			SELECT CMS_File_Name
			FROM #CMS_ICD9_Diag_Desc_Files
			WHERE CMS_Diag_Release_Version = @This_Diag_Release
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
			 ''' + @This_Diag_Release + ''' AS CMS_Diag_Release_Version
			,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Diagnosis_Code)), CHAR(13), ''''), 1, 5) AS Diagnosis_Code
			,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Code_Desc_Short)), CHAR(13), ''''), 1, 60) AS Code_Desc_Short
		FROM OPENROWSET(
			BULK ''' + @Source_File_Dir + '\ICD9_CM\' + @This_File_Name_Desc_Short
			+ '''
			,FORMATFILE = ''' + @Source_File_Dir + '\ICD9_CM\icd9dx_desc_short_format.fmt'
			+ '''
			,ERRORFILE = ''' + @Source_File_Dir + '\ICD9_CM\Errorfile_ICD9_Diag_Desc_Short_CMS' + @This_Diag_Release + '.err'''
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
			 ''' + @This_Diag_Release + ''' AS CMS_Diag_Release_Version
			,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Diagnosis_Code)), CHAR(13), ''''), 1, 5) AS Diagnosis_Code
			,SUBSTRING(REPLACE(LTRIM(RTRIM(src.Code_Desc_Long)), CHAR(13), ''''), 1, 256) AS Code_Desc_Long
		FROM OPENROWSET(
			BULK ''' + @Source_File_Dir + '\ICD9_CM\' + @This_File_Name_Desc_Long
			+ '''
			,FORMATFILE = ''' + @Source_File_Dir + '\ICD9_CM\icd9dx_desc_long_format.fmt'
			+ '''
			,ERRORFILE = ''' + @Source_File_Dir + '\ICD9_CM\Errorfile_ICD9_Diag_Desc_Long_CMS' + @This_Diag_Release + '.err'''
			+ '
			,FIRSTROW = 1
		) AS src
		;'

		EXEC (@SQL)

		FETCH NEXT 
		FROM Cursor_ICD9_CMS_Release 
		INTO 
			@This_Diag_Release,
			@This_CMS_FY
	END
	CLOSE Cursor_ICD9_CMS_Release 
	DEALLOCATE Cursor_ICD9_CMS_Release 


	/**
	 *  Load the permanent output table with ICD-9 codes and the short and long descriptions
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

GO