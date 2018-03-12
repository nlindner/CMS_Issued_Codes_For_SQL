/* Replace HCDatamart_Devt with your intended destination database
USE HCDatamart_Devt
GO
*/

-- If procedure does not already exist, create a stub that will then be replaced by ALTER. The BEGIN CATCH eliminate any error messages if it does already exist
BEGIN TRY
	 EXEC ('CREATE PROCEDURE dbo.ICD_Proc_001_Import_Descriptions_OPENROWSET AS DECLARE @A varchar(100); SET @A=ISNULL(OBJECT_NAME(@@PROCID), ''unknown'')+'' was not created!''; RAISERROR(@A,16,1);return 9999')
END TRY BEGIN CATCH END CATCH
GO

ALTER PROCEDURE dbo.ICD_Proc_001_Import_Descriptions_OPENROWSET (
	 @Schema_Name                   VARCHAR(32)    = 'dbo'
	,@Table_Name                    VARCHAR(100)   = 'DIM_ICD_Procedure'
	,@Table_Action                  VARCHAR(16)    = 'DROP_CREATE'
	,@Which_ICD_Version_To_Load     VARCHAR(3)     = 'ALL'
	,@Source_File_Dir               VARCHAR(1000)  = NULL
	,@FieldNm_CMS_Fiscal_Year       VARCHAR(100)   = 'CMS_Fiscal_Year'
	,@FieldNm_Effective_Date        VARCHAR(100)   = 'Effective_Date'
	,@FieldNm_End_Date              VARCHAR(100)   = 'End_Date'
	,@FieldNm_ICD_Version           VARCHAR(100)   = 'ICD_Version'
	,@FieldNm_ICD_Code              VARCHAR(100)   = 'Procedure_Code'
	,@FieldNm_Code_Desc_Short       VARCHAR(100)   = 'Code_Desc_Short'
	,@FieldNm_Code_Desc_Long        VARCHAR(100)   = 'Code_Desc_Long'
) AS
BEGIN
/* ======================================================================================
	AUTHOR
		Nicole M. Lindner-Miles

	STORED PROCEDURE
		ICD_Proc_001_Import_Descriptions_OPENROWSET

	DESCRIPTION
		*	See repo LICENSE and README for general information
		*	See INFO__CMS_ICD_Code_Descriptions for details and sources for files loaded 
			here and details on what was done to generate the ICD-9 flat files
			from the Excel files that are available on cms.gov
		*	Loads table with ICD-9 and ICD-10 procedure code descriptions from CMS 
			releases for Fiscal Years (FY) 2010-2018, available for download from cms.gov,
			to serve as a simple lookup/reference/dimension table. 
		*	This is the simple (OPENROWSET) method to import this info.
			dbo.ICD_Proc_001_Import_Descriptions_AsValues does exactly the same thing,
			but does not require OPENROWSET permissions (i.e., ADMINISTER BULK OPERATIONS)

	PARAMETERS
		@Schema_Name (Required, if other than default of 'dbo')
		@Table_Name (Required, if other than default of 'DIM_ICD_Procedure')
			This procedure creates permanent output table @Schema_Name.Table_Name
			and loads it with all ICD procedure code descriptions available in this repo
		@Table_Action (Required, if other than default of 'DROP_CREATE')
			Valid Values: 'DROP_CREATE', 'TRUNCATE', 'DELETE_ICD9', 'DELETE_ICD10'
			Specifies what to do with the permanent output table.
			*	DROP_CREATE: Drop it (if it already exists) and recreate it.
			*	TRUNCATE: Truncates the table, which must already exist
			*	DELETE_ICD9 or DELETE_ICD10: Deletes any codes for the specified ICD 
				version from the table, which must already exist
			NOTE: If you call this with anything other than DROP_CREATE and the
			table exists, then the @FieldNm_... parameters MUST match the 
			field names in the existing table.
		@Which_ICD_Version_To_Load (Required, if other than default of 'ALL')
			Valid Values: 'ALL', '9', '09', '10'
			Specifies which ICD-version codes should be loaded, defaults to loading all
		@Source_File_Dir
			Required input parameter. The location of the CMS_ICD_Code_Descriptions
			subdirectory
		@FieldNm_... parameters: Optional, if other than defaulted values.
			Valid values: In SQL Server, Any field name that is legal (e.g., either no
			special characters or is enclosed by [] and not a reserved name)
			Use these customize the field names in the final output table

	WHAT THIS PROCEDURE DOES
		*	Dependent on which @Table_Action is invoked, prepare the permanent output 
			table (@Schema_Name.@Table_Name), via either DROP_CREATE, TRUNCATE, 
			DELETE_ICD9, or DELETE_ICD10
		*	Load all ICD procedure codes and their descriptions:
			*	Create temporary table #CMS_FY_Release_Map and populate it with all CMS FYs
				and effective/end dates to be loaded, per @Which_ICD_Version_To_Load
			*	Loop through all ICD CMS FYs with a cursor, loading the permanent output 
				table with all available description files via OPENROWSET.

	EXAMPLE CALL
	exec dbo.ICD_Proc_001_Import_Descriptions_OPENROWSET 
		@Table_Name = 'DIM_ICD_Procedure_All'
		,@Table_Action = 'DROP_CREATE'
		,@Which_ICD_Version_To_Load = 'ALL'
		,@Source_File_Dir = 
			'C:\Users\Nicole\Documents\GitHub\CMS_MS_DRG_Grouper_Help\CMS_ICD_Code_Descriptions'

	CHANGE LOG
		2018.03.11 NLM
			*	Edited documentation to accommodate the new directory INFO__ file
			*	Added @FieldNm_... parameters to allow customizing the field names
				in the final output table.
			*	Outside of this SP, changed the line delimiter for the .fmt files
				called here. Git's default gitattributes normalizes all Windows-style
				line endings (\r\n) to *nix ending (\n). D'oh!
		2018.02.25 NLM
			*	Minor fixes to documentation in change log vs. code body. *sigh*
		2018.02.18 NLM (Nicole Lindner-Miles) 
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
	 *  Dependent on which @Table_Action is invoked, prepare the permanent output 
	 *  table (@Schema_Name.@Table_Name), via either DROP_CREATE, TRUNCATE, 
	 *  DELETE_ICD9, or DELETE_ICD10
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
			 ' + @FieldNm_CMS_Fiscal_Year + '  INT            NOT NULL
			,' + @FieldNm_Effective_Date + '   DATE           NOT NULL
			,' + @FieldNm_End_Date + '         DATE           NOT NULL
			,' + @FieldNm_ICD_Version + '      INT            NOT NULL
			,' + @FieldNm_ICD_Code + '         VARCHAR(7)     NOT NULL
			,' + @FieldNm_Code_Desc_Short + '  VARCHAR(60)    NOT NULL
			,' + @FieldNm_Code_Desc_Long + '   VARCHAR(323)   NOT NULL
			,CONSTRAINT PK_' + @Table_Name + ' PRIMARY KEY (
				 ' + @FieldNm_CMS_Fiscal_Year + '
				,' + @FieldNm_ICD_Version + '
				,' + @FieldNm_ICD_Code + '
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
		+ ' WHERE ' + @FieldNm_ICD_Version + ' = 9 '

		EXEC(@SQL)
	END

	IF @Table_Action = 'DELETE_ICD10'
	BEGIN
		RAISERROR ('--- Delete any ICD-10 data that exists ---', 0, 1) 

		SET @SQL = '
		DELETE FROM ' + @Schema_Name + '.' + @Table_Name 
		+ ' WHERE ' + @FieldNm_ICD_Version + ' = 9 '

		EXEC(@SQL)
	END
	


	/* Load all ICD procedure codes and their descriptions
	=================================================================================== */
	RAISERROR ('%s%s--- --- LOAD ICD PROCEDURE CODES --- ---', 0, 1, @NewLine, @NewLine) 

	/**
	 *  Create temporary table #CMS_FY_Release_Map and populate it with all CMS FYs
	 *  and effective/end dates to be loaded, per @Which_ICD_Version_To_Load
	 */
	RAISERROR ('%s--- Create temp table with CMS FYs that will be loaded here ---', 0, 1, @NewLine) 
	
	IF OBJECT_ID('tempdb..#CMS_FY_Release_Map') IS NOT NULL
	BEGIN
		DROP TABLE #CMS_FY_Release_Map
	END
	CREATE TABLE #CMS_FY_Release_Map (
		 ICD_Version		INT       	   NOT NULL
		,CMS_Fiscal_Year  INT      	   NOT NULL
		,Effective_Date   DATE       	   NOT NULL
		,End_Date         DATE       	   NOT NULL
		,CMS_File_Name		VARCHAR(200)   NOT NULL
	);

	IF @Which_ICD_Version_To_Load IN ('ALL', '10')
	BEGIN
		INSERT INTO #CMS_FY_Release_Map (
			 ICD_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			,CMS_File_Name
		)
		VALUES
			 (10, 2016, '2015-10-01', '2016-09-30', 'icd10pcs_order_2016.txt')
			,(10, 2017, '2016-10-01', '2017-09-30', 'icd10pcs_order_2017.txt')
			,(10, 2018, '2017-10-01', '2018-09-30', 'icd10pcs_order_2018.txt')
	END

	IF @Which_ICD_Version_To_Load IN ('ALL', '09', '9')
	BEGIN
		INSERT INTO #CMS_FY_Release_Map (
			 ICD_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			,CMS_File_Name
		)
		VALUES
			 (9, 2010, '2009-10-01', '2010-09-30', 'CMS27_DESC_LONG_SHORT_SG_092709 Sheet1.txt')
			,(9, 2011, '2010-10-01', '2011-09-30', 'CMS28_DESC_LONG_SHORT_SG Sheet1.txt')
			,(9, 2012, '2011-10-01', '2012-09-30', 'CMS29_DESC_LONG_SHORT_SG Sheet1.txt')
			,(9, 2013, '2012-10-01', '2013-09-30', 'CMS30_DESC_LONG_SHORT_SG 051812 Sheet1.txt')
			,(9, 2014, '2013-10-01', '2014-09-30', 'CMS31_DESC_LONG_SHORT_SG Sheet1.txt')
			,(9, 2015, '2014-10-01', '2015-09-30', 'CMS32_DESC_LONG_SHORT_SG Sheet1.txt')
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
		@This_CMS_File_Name	  VARCHAR(200)
	;
	DECLARE Cursor_CMS_Release CURSOR
	LOCAL READ_ONLY FORWARD_ONLY
	FOR
	SELECT 
		CAST(ICD_Version AS VARCHAR(2)) AS ICD_Version,
		CAST(CMS_Fiscal_Year AS VARCHAR(4)) AS CMS_Fiscal_Year,
		CAST(Effective_Date AS VARCHAR(10)) AS Effective_Date,
		CAST(End_Date AS VARCHAR(10)) AS End_Date,
		CMS_File_Name
	FROM #CMS_FY_Release_Map
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
		@This_CMS_File_Name

	WHILE @@FETCH_STATUS = 0
	BEGIN

		RAISERROR ('%s--- Inserting ICD-%s procedure codes for CMS FY %s from file %s ---', 0, 1, @NewLine, @This_ICD_Version, @This_CMS_FY, @This_CMS_File_Name) 

		IF @This_ICD_Version = 9
		BEGIN

			SET @SQL = '
			INSERT INTO ' + @Schema_Name + '.' + @Table_Name + '( '
				+ @FieldNm_ICD_Version
				+ ',' + @FieldNm_CMS_Fiscal_Year
				+ ',' + @FieldNm_Effective_Date
				+ ',' + @FieldNm_End_Date
				+ ',' + @FieldNm_ICD_Code
				+ ',' + @FieldNm_Code_Desc_Short
				+ ',' + @FieldNm_Code_Desc_Long + '
			)
			SELECT 
				' + @This_ICD_Version + ' AS ' + @FieldNm_ICD_Version
				+ ',' + @This_CMS_FY + ' AS ' + @FieldNm_CMS_Fiscal_Year
				+ ',''' + @This_Effective_Date + ''' AS ' + @FieldNm_Effective_Date
				+ ',''' + @This_End_Date + ''' AS ' + @FieldNm_End_Date
				+ ',SUBSTRING(LTRIM(RTRIM(src.ICD_Code)), 1, 5) AS ' + @FieldNm_ICD_Code
				+ ',SUBSTRING(LTRIM(RTRIM(REPLACE(src.Code_Desc_Short, ''""'', ''"''))), 1, 60) AS ' + @FieldNm_Code_Desc_Short
				+ ',SUBSTRING(LTRIM(RTRIM(REPLACE(src.Code_Desc_Long, ''""'', ''"''))), 1, 323) AS ' + @FieldNm_Code_Desc_Long
			+ '
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\ICD_9\' + @This_CMS_File_Name
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\ICD_9\icd9_desc_long_short_format.fmt'
				+ '''
				,ERRORFILE = ''' + @Source_File_Dir + '\ICD_9\Errorfile_Proc_FY' + @This_CMS_FY + '.err'''
				+ '
				,FIRSTROW = 2
				-- ,CODEPAGE = 65001
			) AS src 
			;'

		END

		ELSE IF @This_ICD_Version = 10
		BEGIN

			SET @SQL = '
			INSERT INTO ' + @Schema_Name + '.' + @Table_Name + '( '
				 + @FieldNm_ICD_Version
				+ ',' + @FieldNm_CMS_Fiscal_Year
				+ ',' + @FieldNm_Effective_Date
				+ ',' + @FieldNm_End_Date
				+ ',' + @FieldNm_ICD_Code
				+ ',' + @FieldNm_Code_Desc_Short
				+ ',' + @FieldNm_Code_Desc_Long + '
			)
			SELECT 
				' + @This_ICD_Version + ' AS ' + @FieldNm_ICD_Version
				+ ',' + @This_CMS_FY + ' AS ' + @FieldNm_CMS_Fiscal_Year
				+ ',''' + @This_Effective_Date + ''' AS ' + @FieldNm_Effective_Date
				+ ',''' + @This_End_Date + ''' AS ' + @FieldNm_End_Date
				+ ',SUBSTRING(LTRIM(RTRIM(src.ICD_Code)), 1, 7) AS ' + @FieldNm_ICD_Code
				+ ',SUBSTRING(LTRIM(RTRIM(src.Code_Desc_Short)), 1, 60) AS ' + @FieldNm_Code_Desc_Short
				+ ',SUBSTRING(LTRIM(RTRIM(src.Code_Desc_Long)), 1, 323) AS ' + @FieldNm_Code_Desc_Long
			+ '
			FROM OPENROWSET(
				BULK ''' + @Source_File_Dir + '\ICD_10\' + @This_CMS_File_Name
				+ '''
				,FORMATFILE = ''' + @Source_File_Dir + '\ICD_10\icd10_order_format.fmt'
				+ '''
				,ERRORFILE = ''' + @Source_File_Dir + '\ICD_10\Errorfile_Proc_FY' + @This_CMS_FY + '.err'''
				+ '
				,FIRSTROW = 1
				-- ,CODEPAGE = 65001
			) AS src 
			WHERE 
				Code_Is_HIPAA_Valid = ''1''
			;'

		END

		EXEC (@SQL)

		FETCH NEXT 
		FROM Cursor_CMS_Release 
		INTO 
			@This_ICD_Version,
			@This_CMS_FY,
			@This_Effective_Date,
			@This_End_Date,
			@This_CMS_File_Name
	END
	CLOSE Cursor_CMS_Release 
	DEALLOCATE Cursor_CMS_Release 

END

GO