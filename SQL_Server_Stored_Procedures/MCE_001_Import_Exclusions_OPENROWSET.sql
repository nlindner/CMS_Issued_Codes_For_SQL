/* Replace HCDatamart_Devt with your intended destination database
USE HCDatamart_Devt
GO
*/

-- If procedure does not already exist, create a stub that will then be replaced by ALTER. The BEGIN CATCH eliminate any error messages if it does already exist
BEGIN TRY
	 EXEC ('CREATE PROCEDURE dbo.MCE_001_Import_Exclusions_OPENROWSET AS DECLARE @A varchar(100); SET @A=ISNULL(OBJECT_NAME(@@PROCID), ''unknown'')+'' was not created!''; RAISERROR(@A,16,1);return 9999')
END TRY BEGIN CATCH END CATCH
GO

ALTER PROCEDURE dbo.MCE_001_Import_Exclusions_OPENROWSET (
	 @Schema_Name VARCHAR(32) = 'dbo'
	,@Table_Name VARCHAR(100) = 'MCE_Simple_Code_Exclusions_All'
	,@Source_File_Dir VARCHAR(1000) = NULL
) AS
BEGIN
/* ======================================================================================
	AUTHOR
		Nicole M. Lindner-Miles

	STORED PROCEDURE
		MCE_001_Import_Exclusions_OPENROWSET

	DESCRIPTION
		*	This is the simple (OPENROWSET) method to import this info.
			dbo.MCE_001_Import_Exclusions_AsValues does exactly the same thing, but
			does not require OPENROWSET permissions (i.e., ADMINISTER BULK OPERATIONS)
		*	This imports the simple ICD code exclusions from the 
			Medicare Code Editor (MCE), versions 26-35, to a SQL Server table.
		*	See repo LICENSE and see README for details on what the MCE is and 
			sources for files loaded here, along with field descriptions, information
			on which portions of the MCE documentation are available here, and how the
			fields loaded here map back to what is available in the MCE documentation
		*	The imported data can then be used to add MCE exclusion information to 
			existing ICD Diagnosis and Procedure code lookup/reference/dimension tables 
			*	Within this repo, see subdirectories CMS_ICD_Code_Descriptions
				and the ICD##_Diag_001_Import_Descriptions... stored procedures for a
				working example of importing the ICD-9-CM and ICD-10-CM (diagnosis) code 
				descriptions provided by CMS, if you do not already have one available.

	PARAMETERS
		@Schema_Name (Required, if other than default of 'dbo')
		@Table_Name (Required, if other than default of 'MCE_Simple_Code_Exclusions_All')
			This procedure creates permanent output table @Schema_Name.Table_Name
			and loads it with all available MCE simple code exclusions
		@Source_File_Dir
			Required input parameter. The location of the subdirectory 
			containing the source MCE_Simple_Code_Exclusions_... files

	WHAT THIS PROCEDURE DOES
		*	Create permanent output table that will be loaded with all data,
			dropping the table if it already exists
		*	Create temporary table #CMS_MCE_Release_Map and load it with all CMS
			fiscal year (FY) and MCE release versions that will be loaded in this SP
		*	Use a cursor to loop through all MCE releases, loading all available 
			MCE release files via OPENROWSET.
			*	I created these files from the MCE documentation, so they all have the same
				tab-delimited format.

	EXAMPLE CALL
		exec dbo.MCE_001_Import_Exclusions_OPENROWSET 
			@Table_Name = 'MCE_Simple_Code_Exclusions_TEST',
			@Source_File_Dir = 'C:\Users\Nicole\Documents\GitHub\CMS_MS_DRG_Grouper_Help\CMS_MCE_Simple_ICD_Code_Exclusions'

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
 *  Create permanent output table that will be loaded with all data,
 *  dropping the table if it already exists
 */
RAISERROR ('%s--- Create final output table (First drop it if it already exists) ---', 0, 1, @NewLine) 

SET @SQL = '
IF OBJECT_ID(''' + @Schema_Name + '.' + @Table_Name + ''') IS NOT NULL
BEGIN
	DROP TABLE ' + @Schema_Name + '.' + @Table_Name + '
END
CREATE TABLE ' + @Schema_Name + '.' + @Table_Name + '(
	 ICD_Version            INT         NOT NULL
	,ICD_Code_Type          CHAR(1)     NOT NULL
	,ICD_Code               VARCHAR(7)  NOT NULL
	,ICD_Code_Desc          VARCHAR(64) NOT NULL
	,MCE_Version            INT         NOT NULL
	,MCE_Section            VARCHAR(4)  NOT NULL
	,MCE_Exclusion_Type     VARCHAR(32) NOT NULL
	 ,CONSTRAINT PK_' + @Table_Name + ' PRIMARY KEY (
			 MCE_Version
			,MCE_Section
			,ICD_Version
			,ICD_Code_Type
			,ICD_Code
		)
);'

EXEC(@SQL)

/**
 *  Create temporary table #CMS_MCE_Release_Map and load it with all CMS
 *  fiscal year (FY) and MCE release versions that will be loaded in this SP
 */
RAISERROR ('%s--- Create table with available MCE releases to import ---', 0, 1, @NewLine) 

/* Create table for the looping, with all file versions that will be imported here */
IF OBJECT_ID('tempdb..#CMS_MCE_Release_Map') IS NOT NULL
BEGIN
	DROP TABLE #CMS_MCE_Release_Map
END
CREATE TABLE #CMS_MCE_Release_Map (
	 CMS_Fiscal_Year        VARCHAR(4)  NOT NULL
	,MCE_Release_Version    CHAR(2)     NOT NULL
);
INSERT INTO #CMS_MCE_Release_Map (
	 CMS_Fiscal_Year
	,MCE_Release_Version
)
VALUES
	 ('2010', '26')
	,('2011', '27')
	,('2012', '28')
	,('2013', '30')
	,('2014', '31')
	,('2015', '32')
	,('2016', '33')
	,('2017', '34')
	,('2018', '35');


/**
 *  Use a cursor to loop through all MCE releases, loading all available 
 *  MCE release files via OPENROWSET.
 */
DECLARE 
	@This_CMS_FY VARCHAR(4),
	@This_MCE_Version VARCHAR(2)
;
DECLARE Cursor_CMS_FY CURSOR
LOCAL READ_ONLY FORWARD_ONLY
FOR
SELECT 
	CMS_Fiscal_Year,
	MCE_Release_Version
FROM #CMS_MCE_Release_Map;
 
OPEN Cursor_CMS_FY 
FETCH NEXT 
FROM Cursor_CMS_FY 
INTO 
	@This_CMS_FY,
	@This_MCE_Version
WHILE @@FETCH_STATUS = 0
BEGIN
	RAISERROR ('%s--- Inserting MCE release v%s for CMS FY %s ---', 0, 1, @NewLine, @This_MCE_Version, @This_CMS_FY) 

	SET @SQL = '
	INSERT INTO ' + @Schema_Name + '.' + @Table_Name + '(
		 ICD_Version
		,ICD_Code_Type
		,ICD_Code
		,ICD_Code_Desc
		,MCE_Version
		,MCE_Section
		,MCE_Exclusion_Type
	)
	SELECT 
		CAST(ICD_Version AS INT) AS ICD_Version
		,ICD_Code_Type
		,ICD_Code
		,ICD_Code_Desc
		,CAST(MCE_Version AS INT)
		,MCE_Section
		,MCE_Exclusion_Type 
	FROM OPENROWSET(
		BULK ''' + @Source_File_Dir + '\MCE_Simple_Code_Exclusions_v' + @This_MCE_Version + '.txt'
		+ '''
		,FORMATFILE = ''' + @Source_File_Dir + '\MCE_Simple_Code_Exclusions_Format.fmt'
		+ '''
		,ERRORFILE = ''' + @Source_File_Dir + '\MCE_Exclusions_v' + @This_MCE_Version + '.err'''
		+ '
		,FIRSTROW=2
	) AS Test
	;'
	EXEC (@SQL)
		
	FETCH NEXT 
	FROM Cursor_CMS_FY 
	INTO @This_CMS_FY, @This_MCE_Version
END
CLOSE Cursor_CMS_FY 
DEALLOCATE Cursor_CMS_FY 

END

GO
