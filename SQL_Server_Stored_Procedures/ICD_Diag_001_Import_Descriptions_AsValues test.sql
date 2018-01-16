/* Replace HCDatamart_Devt with your intended destination database */
USE HCDatamart_Devt
GO
/* */

-- If procedure does not already exist, create a stub that will then be replaced by ALTER. The BEGIN CATCH eliminate any error messages if it does already exist
BEGIN TRY
	 EXEC ('CREATE PROCEDURE dbo.ICD_Diag_001_Import_Descriptions_AsValues_Test AS DECLARE @A varchar(100); SET @A=ISNULL(OBJECT_NAME(@@PROCID), ''unknown'')+'' was not created!''; RAISERROR(@A,16,1);return 9999')
END TRY BEGIN CATCH END CATCH
GO

ALTER PROCEDURE dbo.ICD_Diag_001_Import_Descriptions_AsValues_Test (
	 @Schema_Name VARCHAR(32) = 'dbo'
	,@Table_Name VARCHAR(100) = 'DIM_ICD_Diagnosis_Test'
	,@Table_Action VARCHAR(16) = 'DROP_CREATE'
	,@Which_ICD_Version_To_Load VARCHAR(4) = 'ALL'
	,@Source_File_Dir VARCHAR(1000) = NULL
) AS
BEGIN

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
	

	/**
	 *  Create temporary table #CMS_ICD_Release_Map and populate it with all CMS FYs
	 *  and effective/end dates to be loaded here, per @Which_ICD_Version_To_Load
	 */
	RAISERROR ('%s--- Create temp table with CMS FYs to load ---', 0, 1, @NewLine) 
	IF OBJECT_ID('tempdb..#CMS_ICD_Diag_Release_Map') IS NOT NULL
	BEGIN
		DROP TABLE #CMS_ICD_Diag_Release_Map
	END
	CREATE TABLE #CMS_ICD_Diag_Release_Map (
		 CMS_Fiscal_Year   VARCHAR(4) NOT NULL
		,Effective_Date    DATE       NOT NULL
		,End_Date          DATE       NOT NULL
		,ICD_Version       INT			NOT NULL
	);

	IF @Which_ICD_Version_To_Load IN ('ALL', '9', '09')
	BEGIN
		INSERT INTO #CMS_ICD_Diag_Release_Map (
			 CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			,ICD_Version
		)
		VALUES
			 (2011, '2010-10-01', '2011-09-30', 9)
			,(2012, '2011-10-01', '2012-09-30', 9)
			,(2013, '2012-10-01', '2013-09-30', 9)
			,(2014, '2013-10-01', '2014-09-30', 9)
			,(2015, '2014-10-01', '2015-09-30', 9)
	END

	IF @Which_ICD_Version_To_Load IN ('ALL', '10')
	BEGIN
		INSERT INTO #CMS_ICD_Diag_Release_Map (
			 CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			,ICD_Version
		)
		VALUES
			 (2016, '2015-10-01', '2016-09-30', 10)
			,(2017, '2016-10-01', '2017-09-30', 10)
			,(2018, '2017-10-01', '2018-09-30', 10)
	END



	/**
	 *  Create temporary table #DIM_ICD_Diagnosis_All that will be loaded
	 *  via INSERT...VALUES in this SP
	 */
	RAISERROR ('%s--- Create temp table to be populated from values statements ---', 0, 1, @NewLine) 
	IF OBJECT_ID('tempdb..#DIM_ICD_Diagnosis_All') IS NOT NULL
	BEGIN
		DROP TABLE #DIM_ICD_Diagnosis_All
	END
	CREATE TABLE #DIM_ICD_Diagnosis_All (
		 CMS_Fiscal_Year  INT            NOT NULL
		,Diagnosis_Code   VARCHAR(7)     NOT NULL
		,Code_Desc_Short  VARCHAR(60)    NOT NULL
		,Code_Desc_Long   VARCHAR(323)   NOT NULL
		,CONSTRAINT temp_PK_DIM_ICD_Diagnosis_All PRIMARY KEY (
			 CMS_Fiscal_Year
			,Diagnosis_Code
		)
	);


	/**
	 *  Dependent on @Which_ICD_Version is invoked (ALL, 9, 09, or 10), 
	 *  load the specified ICD diagnosis codes and descriptions to the temp table
	 */

	/* LOAD ICD-9
			Dependent on @Which_ICD_Version_To_Load IN ('ALL', '9', '09')
	=================================================================================== */
	IF @Which_ICD_Version_To_Load IN ('ALL', '9', '09')
	BEGIN
		RAISERROR ('%s%s--- --- LOAD TEST DIAGNOSIS CODES --- ---', 0, 1, @NewLine, @NewLine) 
INSERT INTO #DIM_ICD_Diagnosis_All VALUES (2011, '0413', 'Klebsiella pneumoniae', 'Friedländer''s bacillus infection in conditions classified elsewhere and of unspecified site')
	,(2011, '04671', 'Gerstmn-Straus-Schnk syn', 'Gerstmann-Sträussler-Scheinker syndrome')
	,(2011, '38600', 'Meniere''s disease NOS', 'Ménière''s disease, unspecified')
	,(2011, '38601', 'Actv Meniere,cochlvestib', 'Active Ménière''s disease, cochleovestibular')
	,(2011, '38602', 'Active Meniere, cochlear', 'Active Ménière''s disease, cochlear')
	,(2011, '38603', 'Actv Meniere, vestibular', 'Active Ménière''s disease, vestibular')
	,(2011, '38604', 'Inactive Meniere''s dis', 'Inactive Ménière''s disease')
	,(2012, '0413', 'Klebsiella pneumoniae', 'Friedländer''s bacillus infection in conditions classified elsewhere and of unspecified site')
	,(2012, '04671', 'Gerstmn-Straus-Schnk syn', 'Gerstmann-Sträussler-Scheinker syndrome')
	,(2012, '38600', 'Meniere''s disease NOS', 'Ménière''s disease, unspecified')
	,(2012, '38601', 'Actv Meniere,cochlvestib', 'Active Ménière''s disease, cochleovestibular')
	,(2012, '38602', 'Active Meniere, cochlear', 'Active Ménière''s disease, cochlear')
	,(2012, '38603', 'Actv Meniere, vestibular', 'Active Ménière''s disease, vestibular')
	,(2012, '38604', 'Inactive Meniere''s dis', 'Inactive Ménière''s disease')
	,(2013, '0413', 'Klebsiella pneumoniae', 'Friedländer''s bacillus infection in conditions classified elsewhere and of unspecified site')
	,(2013, '04671', 'Gerstmn-Straus-Schnk syn', 'Gerstmann-Sträussler-Scheinker syndrome')
	,(2013, '38600', 'Meniere''s disease NOS', 'Ménière''s disease, unspecified')
	,(2013, '38601', 'Actv Meniere,cochlvestib', 'Active Ménière''s disease, cochleovestibular')
	,(2013, '38602', 'Active Meniere, cochlear', 'Active Ménière''s disease, cochlear')
	,(2013, '38603', 'Actv Meniere, vestibular', 'Active Ménière''s disease, vestibular')
	,(2013, '38604', 'Inactive Meniere''s dis', 'Inactive Ménière''s disease')
	,(2014, '0413', 'Klebsiella pneumoniae', 'Friedländer''s bacillus infection in conditions classified elsewhere and of unspecified site')
	,(2014, '04671', 'Gerstmn-Straus-Schnk syn', 'Gerstmann-Sträussler-Scheinker syndrome')
	,(2014, '38600', 'Meniere''s disease NOS', 'Ménière''s disease, unspecified')
	,(2014, '38601', 'Actv Meniere,cochlvestib', 'Active Ménière''s disease, cochleovestibular')
	,(2014, '38602', 'Active Meniere, cochlear', 'Active Ménière''s disease, cochlear')
	,(2014, '38603', 'Actv Meniere, vestibular', 'Active Ménière''s disease, vestibular')
	,(2014, '38604', 'Inactive Meniere''s dis', 'Inactive Ménière''s disease')
	,(2015, '0413', 'Klebsiella pneumoniae', 'Friedländer''s bacillus infection in conditions classified elsewhere and of unspecified site')
	,(2015, '04671', 'Gerstmn-Straus-Schnk syn', 'Gerstmann-Sträussler-Scheinker syndrome')
	,(2015, '38600', 'Meniere''s disease NOS', 'Ménière''s disease, unspecified')
	,(2015, '38601', 'Actv Meniere,cochlvestib', 'Active Ménière''s disease, cochleovestibular')
	,(2015, '38602', 'Active Meniere, cochlear', 'Active Ménière''s disease, cochlear')
	,(2015, '38603', 'Actv Meniere, vestibular', 'Active Ménière''s disease, vestibular')
	,(2015, '38604', 'Inactive Meniere''s dis', 'Inactive Ménière''s disease')
	END
	/**
	 *  Load the permanent output table with ICD diagnosis codes and descriptions
	 */
	RAISERROR ('%s--- Inserting all ICD diagnosis codes to %s.%s ---', 0, 1, @NewLine, @Schema_Name, @Table_Name) 

	SET @SQL = '
		INSERT INTO ' + @Schema_Name + '.' + @Table_Name + '(
			 CMS_Fiscal_Year
			,Effective_Date
			,End_Date
			,ICD_Version
			,Diagnosis_Code
			,Code_Desc_Short
			,Code_Desc_Long
		)
		SELECT
			 cmsInfo.CMS_Fiscal_Year
			,cmsInfo.Effective_Date
			,cmsInfo.End_Date
			,cmsInfo.ICD_Version
			,diag.Diagnosis_Code
			,diag.Code_Desc_Short
			,diag.Code_Desc_Long
	FROM #DIM_ICD_Diagnosis_All diag
		INNER JOIN #CMS_ICD_Diag_Release_Map cmsInfo
			ON cmsInfo.CMS_Fiscal_Year = diag.CMS_Fiscal_Year
	;'

	EXEC(@SQL)


END

GO