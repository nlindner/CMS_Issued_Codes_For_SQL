/* Replace HCDatamart_Devt with your intended destination database
USE HCDatamart_Devt
GO
*/

-- If procedure does not already exist, create a stub that will then be replaced by ALTER. The BEGIN CATCH eliminate any error messages if it does already exist
BEGIN TRY
	 EXEC ('CREATE PROCEDURE dbo.ICD_MCE_001_Import_Simple_Code_Edits_OPENROWSET AS DECLARE @A varchar(100); SET @A=ISNULL(OBJECT_NAME(@@PROCID), ''unknown'')+'' was not created!''; RAISERROR(@A,16,1);return 9999')
END TRY BEGIN CATCH END CATCH
GO

ALTER PROCEDURE dbo.ICD_MCE_001_Import_Simple_Code_Edits_OPENROWSET (
	 @Schema_Name                VARCHAR(32)   = 'dbo'
	,@Table_Name                 VARCHAR(100)  = 'DIM_ICD_MCE_Simple_Code_Edits'
	,@Table_Action               VARCHAR(16)   = 'DROP_CREATE'
	,@Which_ICD_Version_To_Load  VARCHAR(3)    = 'ALL'
	,@Source_File_Dir            VARCHAR(1000) = NULL
) AS
BEGIN
/* ======================================================================================
	AUTHOR
		Nicole M. Lindner-Miles

	STORED PROCEDURE
		ICD_MCE_001_Import_Simple_Code_Edits_OPENROWSET

	DESCRIPTION
		*	See repo LICENSE and repo README for general information.
		*	See INFO__CMS_MCE_Simple_ICD_Code_Edits for details on what the MCE is and 
			sources for files loaded here, along with field descriptions, information
			on which portions of the MCE documentation are available here, and how the
			fields loaded here map back to what is available in the MCE documentation		
		*	Loads table with the single-code ICD code edits from the CMS releases for 
			the Medicare Code Editor (MCE) for Fiscal Years (FY) 2010-2019
		*	The imported data can then be used to add MCE edit information to 
			existing ICD Diagnosis and Procedure code lookup/reference/dimension tables 
			*	See INFO__CMS_ICD_Code_Descriptions and the ICD_Diag/ICD_Proc
				001_Import_Descriptions... stored procedures for working examples 
				of building those, if you do not already have them.
		*	This is the simple (OPENROWSET) method to import this info.
			dbo.ICD_MCE_001_Import_Simple_Code_Edits_AsValues does exactly the same thing,
			but does not require OPENROWSET permissions (i.e., ADMINISTER BULK OPERATIONS)

	PARAMETERS
		@Schema_Name (Required, if other than default of 'dbo')
		@Table_Name (Required, if other than default of 'DIM_ICD_MCE_Simple_Code_Edits')
			This procedure creates permanent output table @Schema_Name.Table_Name
			and loads it with all available MCE simple code edits
		@Table_Action (Required, if other than default of 'DROP_CREATE')
			Valid Values: 'DROP_CREATE', 'TRUNCATE', 'DELETE_ICD9', 'DELETE_ICD10'
			Specifies what to do with the permanent output table.
			*	DROP_CREATE: Drop it (if it already exists) and recreate it.
			*	TRUNCATE: Truncates the table, which must already exist
			*	DELETE_ICD9 or DELETE_ICD10: Deletes any codes for the specified ICD
				version from the table, which must already exist
		@Which_ICD_Version_To_Load (Required, if other than default of 'ALL')
			Valid Values: 'ALL', '9', '09', '10'
			Specifies which ICD-version codes should be loaded, defaults to loading all
		@Source_File_Dir
			Required input parameter. The location of the subdirectory 
			containing the source MCE_Simple_Code_Edits_... files

	WHAT THIS PROCEDURE DOES
		*	Dependent on which @Table_Action is invoked, prepare the permanent output 
			table (@Schema_Name.@Table_Name), via either DROP_CREATE, TRUNCATE, 
			DELETE_ICD9, or DELETE_ICD10
		*	Load ICD codes noted in MCE Code Edits
			*	Create temporary table #CMS_FY_Release_Map and populate it with all CMS FYs
				and effective/end dates to be loaded, per @Which_ICD_Version_To_Load
			*	Loop through all ICD CMS FYs with a cursor, loading the permanent output 
				table with all available MCE code files via OPENROWSET.

	EXAMPLE CALL
	exec dbo.ICD_MCE_001_Import_Simple_Code_Edits_OPENROWSET 
		@Table_Name = 'DIM_ICD_MCE_Simple_Code_Edits'
		,@Table_Action = 'DROP_CREATE'
		,@Which_ICD_Version_To_Load = 'ALL'
		,@Source_File_Dir = 
			'C:\Users\Nicole\Documents\GitHub\CMS_MS_DRG_Grouper_Help\CMS_MCE_Simple_ICD_Code_Edits'

	CHANGE LOG
		2019.09.22 NLM
			*	Added FY 2020 to file load
		2018.08.19 NLM
			*	Added FY 2019 to file load
		2018.03.11 NLM
			*	I disliked the sort order that results from storing MCE section and 
				MCE subsection as a single field (e.g., 11.A, 4.A, 6, 8, 9), so I have 
				modified this to store them as separate fields (MCE_Section is now int, 
				and MCE_Subsection is "_" if no subsection exists).
			*	Edited documentation to accommodate the new directory INFO__ file
				and align with the newly-created _AsValues version of this SP
			*	Outside of this SP, changed the flat files to separate the MCE_Section
				and MCE_Subsection and changed the line delimiter for the .fmt files
				called here. Git's default gitattributes normalizes all Windows-style
				line endings (\r\n) to *nix ending (\n). D'oh!
		2018.02.25 NLM
			*	Re-deploy this with changed SP name and changed file naming conventions 
				and labels (e.g., from MCE Simple Code Exclusions to MCE Simple Code Edits) 
				to match CMS nomenclature
			*	Refactored the procedure to align similar code logic between this
				and the ICD_(Diag|Proc)_001_Import_Descriptions SPs and to add input 
				parameters from other SPs (that is, @Table_Action, @Which_ICD_Version)
				to control what can be done here.
			*	Fixed boneheaded mistake: I had previously created CMS FY 2016
				from MCE v34 file instead of v33. Caught it while QAing discrepancies
				between data loaded here and in ICD_(Diag|Proc)_001. Blargh.
			*	Fixed boneheaded mistake: to join between the output table here and in
				the DIM_ICD_(Diagnosis|Procedure) tables, need to add CMS_Fiscal_Year field
				to the final output table. While I'm adding it, adding effective/end dates too.
				*	Because the MCE version is MCE-specific (it does not match the DRG 
					version/CMS ICD release), I dropped it from the final output table.
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
			 CMS_Fiscal_Year        INT			NOT NULL
			,Effective_Date			DATE			NOT NULL
			,End_Date					DATE			NOT NULL
			,ICD_Version            INT         NOT NULL
			,ICD_Code_Type          CHAR(1)     NOT NULL
			,ICD_Code               VARCHAR(7)  NOT NULL
			,ICD_Code_Desc          VARCHAR(64) NOT NULL
			,MCE_Section            INT         NOT NULL
			,MCE_Subsection			CHAR(1)     NOT NULL
			,MCE_Edit_Type          VARCHAR(32) NOT NULL
			,CONSTRAINT PK_' + @Table_Name + ' PRIMARY KEY (
					 CMS_Fiscal_Year
					,ICD_Version
					,MCE_Section
					,MCE_Subsection
					,ICD_Code_Type
					,ICD_Code
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


	/* Load ICD codes noted in MCE Code Edits
	=================================================================================== */
	RAISERROR ('%s%s--- --- LOAD MCE ICD CODES --- ---', 0, 1, @NewLine, @NewLine) 

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
		 MCE_Release_Version	CHAR(2)	NOT NULL
		,ICD_Version			INT      NOT NULL
		,CMS_Fiscal_Year  	INT      NOT NULL
		,Effective_Date   	DATE     NOT NULL
		,End_Date         	DATE     NOT NULL
	);

	IF @Which_ICD_Version_To_Load IN ('ALL', '10')
	BEGIN
		INSERT INTO #CMS_FY_Release_Map (
			 MCE_Release_Version
			,ICD_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
		)
		VALUES
			 ('33', 10, 2016, '2015-10-01', '2016-09-30')
			,('34', 10, 2017, '2016-10-01', '2017-09-30')
			,('35', 10, 2018, '2017-10-01', '2018-09-30')
			,('36', 10, 2019, '2018-10-01', '2019-09-30')
			,('37', 10, 2020, '2019-10-01', '2020-09-30')
	END

	IF @Which_ICD_Version_To_Load IN ('ALL', '09', '9')
	BEGIN
		INSERT INTO #CMS_FY_Release_Map (
			 MCE_Release_Version
			,ICD_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
		)
		VALUES
			 ('26', 9, 2010, '2009-10-01', '2010-09-30')
			,('27', 9, 2011, '2010-10-01', '2011-09-30')
			,('28', 9, 2012, '2011-10-01', '2012-09-30')
			,('30', 9, 2013, '2012-10-01', '2013-09-30')
			,('31', 9, 2014, '2013-10-01', '2014-09-30')
			,('32', 9, 2015, '2014-10-01', '2015-09-30')
	END


	/**
	 *  Loop through all ICD CMS FYs with a cursor, loading the permanent output 
	 *  table with all available MCE code files via OPENROWSET.
	 */
	DECLARE 
		@This_MCE_Version		  CHAR(2),
		@This_ICD_Version		  VARCHAR(2),
		@This_CMS_FY           VARCHAR(4),
		@This_Effective_Date   VARCHAR(10),
		@This_End_Date         VARCHAR(10)
	;
	DECLARE Cursor_CMS_FY CURSOR
	LOCAL READ_ONLY FORWARD_ONLY
	FOR
	SELECT 
		MCE_Release_Version,
		CAST(ICD_Version AS VARCHAR(2)) AS ICD_Version,
		CAST(CMS_Fiscal_Year AS VARCHAR(4)) AS CMS_Fiscal_Year,
		CAST(Effective_Date AS VARCHAR(10)) AS Effective_Date,
		CAST(End_Date AS VARCHAR(10)) AS End_Date
	FROM #CMS_FY_Release_Map
	ORDER BY 
		CMS_Fiscal_Year
	 
	OPEN Cursor_CMS_FY 
	FETCH NEXT 
	FROM Cursor_CMS_FY 
	INTO 
		@This_MCE_Version,
		@This_ICD_Version,
		@This_CMS_FY,
		@This_Effective_Date,
		@This_End_Date

	WHILE @@FETCH_STATUS = 0
	BEGIN
		RAISERROR ('%s--- Inserting ICD-%s codes for MCE release for CMS FY %s ---', 0, 1, @NewLine, @This_ICD_Version, @This_CMS_FY) 

		SET @SQL = '
		INSERT INTO ' + @Schema_Name + '.' + @Table_Name + '(
			 ICD_Version
			,CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			,ICD_Code_Type
			,ICD_Code
			,ICD_Code_Desc
			,MCE_Section
			,MCE_Subsection
			,MCE_Edit_Type
		)
		SELECT 
			 CAST(ICD_Version AS INT) AS ICD_Version
			,' + @This_CMS_FY + ' AS CMS_Fiscal_Year
			,''' + @This_Effective_Date + ''' AS Effective_Date
			,''' + @This_End_Date + ''' AS End_Date
			,ICD_Code_Type
			,ICD_Code
			,ICD_Code_Desc
			,CAST(MCE_Section AS INT) AS MCE_Section
			,MCE_Subsection
			,MCE_Edit_Type 
		FROM OPENROWSET(
			BULK ''' + @Source_File_Dir + '\MCE_Simple_Code_Edits_v' + @This_MCE_Version + '.txt'
			+ '''
			,FORMATFILE = ''' + @Source_File_Dir + '\MCE_Simple_Code_Edits_Format.fmt'
			+ '''
			,ERRORFILE = ''' + @Source_File_Dir + '\MCE_Edits_v' + @This_MCE_Version + '.err'''
			+ '
			,FIRSTROW=2
		) AS src
		;'
		EXEC (@SQL)
			
		FETCH NEXT 
		FROM Cursor_CMS_FY 
		INTO 
			@This_MCE_Version,
			@This_ICD_Version,
			@This_CMS_FY,
			@This_Effective_Date,
			@This_End_Date

		END
		CLOSE Cursor_CMS_FY 
		DEALLOCATE Cursor_CMS_FY 

	END

GO
