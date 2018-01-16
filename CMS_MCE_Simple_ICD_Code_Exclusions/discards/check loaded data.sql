use HCDataMart_Devt
go

		exec dbo.MCE_001_Import_Exclusions_OPENROWSET 
			@Table_Name = 'MCE_Simple_Code_Exclusions_TEST',
			@Source_File_Dir = 'C:\Users\Nicole\Documents\CMS_MS_DRG_Grouper_Help\CMS_MCE_Simple_ICD_Code_Exclusions'


		exec dbo.MCE_001_Import_Exclusions_AsValues 
			@Table_Name = 'MCE_Simple_Code_Exclusions_TEST2'


select top 100 *
from dbo.DIM_ICD_Diagnosis_AV
WHERE Diagnosis_Code IN ('0413', '04671', '38600', '38601', '38602', '38603', '38604')

select *
from MCE_Simple_Code_Exclusions_TEST

select *
from MCE_Simple_Code_Exclusions_TEST
where ICD_Code like '%[^0-9A-Z]%'

select LEFT(ICD_Code_Desc, 1) as CodeValue, count(*) as total
from MCE_Simple_Code_Exclusions_TEST
GROUP BY LEFT(ICD_Code_Desc, 1) 
order by 1

select RIGHT(ICD_Code_Desc, 1) as CodeValue, count(*) as total
from MCE_Simple_Code_Exclusions_TEST
GROUP BY RIGHT(ICD_Code_Desc, 1) 
order by 1



;with AV AS (
	SELECT 	 ICD_Version, ICD_Code_Type, ICD_Code, ICD_Code_Desc, MCE_Version, MCE_Section, MCE_Exclusion_Type
	FROM dbo.MCE_Simple_Code_Exclusions_TEST2
),
 ORS AS (
	SELECT 	 ICD_Version, ICD_Code_Type, ICD_Code, ICD_Code_Desc, MCE_Version, MCE_Section, MCE_Exclusion_Type
	FROM dbo.MCE_Simple_Code_Exclusions_TEST
)
SELECT 'In AV but not ORS' as src, *
FROM (
	select * from av
	except
	select * from ors
) C
UNION ALL
SELECT 'In ORS but not AV' as src, *
FROM (
	select * from ors
	except
	select * from av
) C


exec dbo.ICD10_Diag_001_Import_Descriptions_OPENROWSET
	@Table_Name = 'DIM_ICD_Diagnosis'
	,@Table_Action = 'DROP_CREATE'
	,@Source_File_Dir = 'C:\Users\Nicole\Documents\CMS_MS_DRG_Grouper_Help\CMS_ICD_Code_Descriptions\ICD10_CM'


exec dbo.ICD9_Diag_001_Import_Descriptions_OPENROWSET
	@Table_Name = 'DIM_ICD_Diagnosis'
	,@Table_Action = 'DELETE_ICD9'
	,@Source_File_Dir = 'C:\Users\Nicole\Documents\CMS_MS_DRG_Grouper_Help\CMS_ICD_Code_Descriptions\ICD9_CM'



exec dbo.ICD_Diag_001_Import_Descriptions_OPENROWSET 
	@Table_Name = 'DIM_ICD_Diagnosis'
	,@Table_Action = 'DROP_CREATE'
	,@Which_ICD_Version_To_Load = 'ALL'
	,@Source_File_Dir = 
		'C:\Users\Nicole\Documents\CMS_MS_DRG_Grouper_Help\CMS_ICD_Code_Descriptions'

exec dbo.ICD_Diag_001_Import_Descriptions_AsValues
	@Table_Name = 'DIM_ICD_Diagnosis_AV'
	,@Table_Action = 'DROP_CREATE'
	,@Which_ICD_Version_To_Load = 'ALL'




select top 100 *
from DIM_ICD_Diagnosis_POA_Exempt
where Diagnosis_Code IN ('0413', '04671', '38600', '38601', '38602', '38603', '38604')


	select CMS_Fiscal_Year, Effective_Date, End_Date, ICD_Version, COUNT(*) AS N_Row, count(DISTINCT Diagnosis_Code) AS CDist_Code
	from DIM_ICD_Diagnosis_AV
	GROUP BY CMS_Fiscal_Year, Effective_Date, End_Date, ICD_Version
	having count(*) <> count(distinct diagnosis_code)

	select top 5 *
	from DIM_ICD_Diagnosis_AV

;with ORS AS (
	select CMS_Fiscal_Year, Effective_Date, End_Date, ICD_Version, COUNT(*) AS N_Row, count(DISTINCT Diagnosis_Code) AS CDist_Code
	from DIM_ICD_Diagnosis_NLM
	GROUP BY CMS_Fiscal_Year, Effective_Date, End_Date, ICD_Version
), AV AS (
	select CMS_Fiscal_Year, Effective_Date, End_Date, ICD_Version, COUNT(*) AS N_Row, count(DISTINCT Diagnosis_Code) AS CDist_Code
	from DIM_ICD_Diagnosis_AV
	GROUP BY CMS_Fiscal_Year, Effective_Date, End_Date, ICD_Version
)
SELECT 'IN ORS but not AV' as src, *
FROM (
	SELECT * FROM ORS
	EXCEPT
	SELECT * FROM AV
) C
UNION ALL
SELECT 'IN AV but not ORS' as src, *
FROM (
	SELECT * FROM AV
	EXCEPT
	SELECT * FROM ORS
) C
ORDER BY CMS_Fiscal_Year, ICD_Version, src

select *
from information_schema.columns
where table_name IN ('DIM_ICD_Diagnosis_NLM', 'DIM_ICD_Diagnosis_AV')
ORDER BY Column_Name, Table_Name

;with ORS AS (
	select CMS_Fiscal_Year, Effective_Date, End_Date, ICD_Version, Diagnosis_Code, Code_Desc_Short, Code_Desc_Long
	from DIM_ICD_Diagnosis
), AV AS (
	select CMS_Fiscal_Year, Effective_Date, End_Date, ICD_Version, Diagnosis_Code, Code_Desc_Short, Code_Desc_Long
	from DIM_ICD_Diagnosis_AV
)
SELECT 'IN ORS but not AV' as src, *
FROM (
	SELECT * FROM ORS
	EXCEPT
	SELECT * FROM AV
) C
UNION ALL
SELECT 'IN AV but not ORS' as src, *
FROM (
	SELECT * FROM AV
	EXCEPT
	SELECT * FROM ORS
) C
ORDER BY CMS_Fiscal_Year, Diagnosis_Code, src

select top 100 *
from dbo.DIM_ICD_Diagnosis_AV
WHERE Diagnosis_Code IN ('0413', '04671', '38600', '38601', '38602', '38603', '38604')

select top 100 *
from dbo.DIM_ICD_Diagnosis_Test
WHERE Diagnosis_Code IN ('0413', '04671', '38600', '38601', '38602', '38603', '38604')

select top 20 *
from dbo.DIM_ICD_Diagnosis_Test

select ICD_Version, max(len(COde_Desc_Short)) AS Short_Max, max(len(COde_Desc_Long)) AS Long_Max
from dbo.DIM_ICD_Diagnosis
GROUP BY ICD_Version

select top 5 last_altered as Modify_Date, *
from information_schema.routines
order by last_altered desc


select *
from DIM_ICD_Diagnosis
where Diagnosis_Code like '%[^0-9A-Z]%'


select LEFT(Diagnosis_Code, 1) as CodeValue, count(*) as total
from DIM_ICD_Diagnosis
GROUP BY LEFT(Diagnosis_Code, 1) 
order by 1

select RIGHT(Diagnosis_Code, 1) as CodeValue, count(*) as total
from DIM_ICD_Diagnosis
GROUP BY RIGHT(Diagnosis_Code, 1) 
order by 1

select LEFT(Code_Desc_Short, 1) as CodeValue, count(*) as total
from DIM_ICD_Diagnosis
GROUP BY LEFT(Code_Desc_Short, 1) 
order by 1

select RIGHT(Code_Desc_Short, 1) as CodeValue, count(*) as total
from DIM_ICD_Diagnosis
GROUP BY RIGHT(Code_Desc_Short, 1) 
order by 1

select *
from DIM_ICD_Diagnosis
where Code_Desc_Short like '"%'

select *
from DIM_ICD_Diagnosis
where Code_Desc_Long like '"%'

select *
from DIM_ICD_Diagnosis
where Code_Desc_Long like '%"'

select LEFT(Code_Desc_Long, 1) as CodeValue, count(*) as total
from DIM_ICD_Diagnosis
GROUP BY LEFT(Code_Desc_Long, 1) 
order by 1

select RIGHT(Code_Desc_Long, 1) as CodeValue, count(*) as total
from DIM_ICD_Diagnosis
GROUP BY RIGHT(Code_Desc_Long, 1) 
order by 1

