/* Replace HCDatamart_Devt with your intended destination database
USE HCDatamart_Devt
GO
*/

-- If procedure does not already exist, create a stub that will then be replaced by ALTER. The BEGIN CATCH eliminate any error messages if it does already exist
BEGIN TRY
	 EXEC ('CREATE PROCEDURE dbo.ICD10_Diag_001_Import_Descriptions_OPENROWSET AS DECLARE @A varchar(100); SET @A=ISNULL(OBJECT_NAME(@@PROCID), ''unknown'')+'' was not created!''; RAISERROR(@A,16,1);return 9999')
END TRY BEGIN CATCH END CATCH
GO

ALTER PROCEDURE dbo.ICD10_Diag_001_Import_Descriptions_OPENROWSET (
	 @Schema_Name VARCHAR(32) = 'dbo'
	,@Table_Name VARCHAR(100) = 'DIM_ICD_Diagnosis'
	,@Table_Action VARCHAR(16) = 'DELETE_ICD10'
	,@Source_File_Dir VARCHAR(1000) = NULL
) AS
BEGIN
/* ======================================================================================
	AUTHOR
		Nicole M. Lindner-Miles

	STORED PROCEDURE
		ICD10_Diag_001_Import_Descriptions_OPENROWSET

	DESCRIPTION
		*	This is the simple (OPENROWSET) method to import this info.
			dbo.ICD10_Diag_001_Import_Descriptions_AsValues does exactly the same thing,
			but does not require OPENROWSET permissions (i.e., ADMINISTER BULK OPERATIONS)
		*	This imports the flat files with ICD-10-CM code descriptions, available for 
			download from cms.gov, into a SQL Server table, to serve as a simple
			lookup/reference/dimension table. 
			*	Note that the file specification for the ICD-10 order files allows
				the ICD_Desc_Long field to be up to length = 323 (400 - 77), but the
				observed length for ICD-10 files is never longer than 256. You could 
				reasonably decide to set that field length to 256 instead of 323.
		*	This is designed to be called together with its ICD-9 counterpart
			(ICD9_Diag_001_Import_Descriptions_OPENROWSET) to populate a common lookup
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
			and loads it with all ICD-10-CM diagnosis code descriptions
		@Table_Action (Required, if other than default of 'DROP_CREATE')
			Valid Values: DROP_CREATE, TRUNCATE, DELETE_ICD10
			Because ICD-9 and ICD-10 codes need to be loaded in separate SPs, this allows
			you to load a common table with both ICD-9 and ICD-10 codes
		@Source_File_Dir
			Required input parameter. The location of the subdirectory 
			containing the source icd10cm_order... files

	WHAT THIS PROCEDURE DOES
		*	Dependent on which @Table_Action is invoked, this will either
			'DROP_CREATE': Create permanent output table for ICD diagnosis codes,
			dropping the table if it already exists
			'TRUNCATE': TRUNCATE the existing output table
			'DELETE_ICD10': Delete any ICD-10 codes in the the existing output table
		*	Create temporary table #CMS_FY_List and populate it with the CMS fiscal year
			(FY), and effective/end dates for all files loaded here
		*	Use a cursor to loop through all CMS FYs, loading all available 
			description files via OPENROWSET.
			*	These files were downloaded directly from cms.gov, so they
				have a fixed-length format with a space between each field.
				The .fmt file has a placeholder for them, but does not load them
				to the permanent output table

	EXAMPLE CALL
		exec dbo.ICD10_Diag_001_Import_Descriptions_OPENROWSET 
	 		@Table_Name = 'DIM_ICD_Diagnosis_Test'
			,@Table_Action = 'DROP_CREATE'
			,@Source_File_Dir = 'C:\Users\Nicole\Documents\GitHub\CMS_MS_DRG_Grouper_Help\CMS_ICD_Code_Descriptions\ICD10_CM'

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
	DECLARE @ICD_Version VARCHAR(2) = '10';

	/**
	 *  Dependent on which @Table_Action is invoked, this will either
	 *  'DROP_CREATE': Create permanent output table for ICD diagnosis codes,
	 *  dropping the table if it already exists
	 *  'TRUNCATE': TRUNCATE the existing output table
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


	IF @Table_Action = 'DELETE_ICD10'
	BEGIN
		RAISERROR ('--- Delete any ICD-10 data that exists ---', 0, 1) 

		SET @SQL = '
		DELETE FROM ' + @Schema_Name + '.' + @Table_Name 
		+ ' WHERE ICD_Version = 10 '

		EXEC(@SQL)
	END


	/**
	 *  Create temporary table #CMS_FY_List and populate it with the CMS fiscal year
	 *  (FY), and effective/end dates for all files loaded here
	 */
	RAISERROR ('%s--- Create temp table with available FY files to import ---', 0, 1, @NewLine) 

	IF OBJECT_ID('tempdb..#CMS_FY_List') IS NOT NULL
	BEGIN
		DROP TABLE #CMS_FY_List
	END
	CREATE TABLE #CMS_FY_List (
		 CMS_Fiscal_Year   VARCHAR(4) NOT NULL
		,Effective_Date    DATE       NOT NULL
		,End_Date          DATE       NOT NULL
	);

	INSERT INTO #CMS_FY_List (
		 CMS_Fiscal_Year
		,Effective_Date
		,End_Date
	)
	VALUES
		 ('2016', '2015-10-01', '2016-09-30')
		,('2017', '2016-10-01', '2017-09-30')
		,('2018', '2017-10-01', '2018-09-30')


	/**
	 *  Use a cursor to loop through all CMS FYs, loading all available 
	 *  description files via OPENROWSET.
	 */
	DECLARE 
		@This_CMS_FY           VARCHAR(4),
		@This_Effective_Date   VARCHAR(10),
		@This_End_Date         VARCHAR(10)
	;
	DECLARE Cursor_CMS_FY CURSOR
	LOCAL READ_ONLY FORWARD_ONLY
	FOR
	SELECT 
		CMS_Fiscal_Year,
		CAST(Effective_Date AS VARCHAR(10)) AS Effective_Date,
		CAST(End_Date AS VARCHAR(10)) AS End_Date
	FROM #CMS_FY_List
	 
	OPEN Cursor_CMS_FY 
	FETCH NEXT 
	FROM Cursor_CMS_FY 
	INTO 
		@This_CMS_FY,
		@This_Effective_Date,
		@This_End_Date
	WHILE @@FETCH_STATUS = 0
	BEGIN
		RAISERROR ('%s--- Inserting ICD-10 diagnosis codes for CMS FY %s ---', 0, 1, @NewLine, @This_CMS_FY) 

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
			 ' + @ICD_Version + ' AS ICD_Version
			,' + @This_CMS_FY + ' AS CMS_Fiscal_Year
			,''' + @This_Effective_Date + ''' AS Effective_Date
			,''' + @This_End_Date + ''' AS End_Date
			,SUBSTRING(LTRIM(RTRIM(src.Diagnosis_Code)), 1, 7) AS Diagnosis_Code
			,SUBSTRING(LTRIM(RTRIM(src.Code_Desc_Short)), 1, 60) AS Code_Desc_Short
			,SUBSTRING(LTRIM(RTRIM(src.Code_Desc_Long)), 1, 323) AS Code_Desc_Long
		FROM OPENROWSET(
			BULK ''' + @Source_File_Dir + '\icd10cm_order_' + @This_CMS_FY + '.txt'
			+ '''
			,FORMATFILE = ''' + @Source_File_Dir + '\icd10cm_order_format.fmt'
			+ '''
			,ERRORFILE = ''' + @Source_File_Dir + '\Errorfile_ICD10_Diag_FY' + @This_CMS_FY + '.err'''
			+ '
			,FIRSTROW = 1
		) AS src
		WHERE
			Code_Is_HIPAA_Valid = ''1''
		;'
		EXEC (@SQL)
			
			FETCH NEXT 
			FROM Cursor_CMS_FY 
			INTO 
				@This_CMS_FY,
				@This_Effective_Date,
				@This_End_Date
	END
	CLOSE Cursor_CMS_FY 
	DEALLOCATE Cursor_CMS_FY 

END

GO

