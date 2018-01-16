use HCDataMart_Devt
go

select *
from information_Schema.columns
where table_Name = 'MCE_Simple_Code_Exclusions_All'

select top 100 *
from MCE_Simple_Code_Exclusions_All


/*
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B900',10,2015,'B90.0','Sequelae of central nervous system tuberculosis')
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B900',10,2016,'B90.0','Sequelae of central nervous system tuberculosis')
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B900',10,2017,'B90.0','Sequelae of central nervous system tuberculosis')
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B900',10,2018,'B90.0','Sequelae of central nervous system tuberculosis')
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B901',10,2015,'B90.1','Sequelae of genitourinary tuberculosis')
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B901',10,2016,'B90.1','Sequelae of genitourinary tuberculosis')
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B901',10,2017,'B90.1','Sequelae of genitourinary tuberculosis')
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B901',10,2018,'B90.1','Sequelae of genitourinary tuberculosis')
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B902',10,2015,'B90.2','Sequelae of tuberculosis of bones and joints')
INSERT INTO [DIM_ICD_Diagnosis_POA_Exempt] VALUES('B902',10,2016,'B90.2','Sequelae of tuberculosis of bones and joints')
*/

/*
	RAISERROR ('%s--- Inserting ICD- CM release v%s for CMS FY %s---', 0, 1, @NewLine, @This_MCE_Version, @This_CMS_FY) 
*/

select 1002 % 1000
select top 5 *
from INFORMATION_SCHEMA.columns
where table_name = 'DIM_ICD_Diagnosis_POA_Exempt'
select top 34344
	CASE 
		WHEN Diagnosis_Code = 'B900'
			THEN 'RAISERROR (''%s--- Loading ICD-' + CAST(ICD_Version AS VARCHAR(2)) + ' POA exempt diagnosis codes for CMS FY ' + CAST(CMS_Fiscal_Year AS VARCHAR(4)) + ' ---'', 0, 1, @NewLine)' + CHAR(10)
				+ 'INSERT INTO ##DIM_ICD_Diagnosis_POA_Exempt VALUES '
		ELSE 
			CASE 
				WHEN 
					(ROW_NUMBER() OVER ( ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code) )% 1000 = 0 -- every 1000 rows
					OR ROW_NUMBER() OVER ( ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code) = 1
					THEN 'INSERT INTO ##DIM_ICD_Diagnosis_POA_Exempt VALUES '
				ELSE CHAR(9) + ','
			END
	END /*+ 
	CASE 
		WHEN 
			(ROW_NUMBER() OVER ( ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code) )% 1000 = 0 -- every 1000 rows
			OR ROW_NUMBER() OVER ( ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code) = 1
			THEN 'INSERT INTO ##DIM_ICD_Diagnosis_POA_Exempt VALUES '
		ELSE ','
	END*/
	+ '(''' + LTRIM(RTRIM(Diagnosis_Code)) + ''', ' + CAST(ICD_Version AS VARCHAR(2)) + ', ' 
	+ CAST(CMS_Fiscal_Year AS VARCHAR(4)) + ', ''' + LTRIM(RTRIM(Diagnosis_Code_With_Period))
	+ ''', ''' + LTRIM(RTRIM(replace(Code_Desc_Long, '''', '''''')))
	+ ''')'
from dbo.DIM_ICD_Diagnosis_POA_Exempt
ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code

select CMS_Fiscal_Year, ICD_Version, count(*) as total, count(distinct Diagnosis_Code) as CDist_Distinct, min(DIagnosis_Code) as Diag_Min
from DIM_ICD_Diagnosis
GROUP BY CMS_Fiscal_Year, ICD_Version
order by 1, 2

select top 5 * from DIM_ICD_Diagnosis
/*
			 CMS_Fiscal_Year  INT            NOT NULL
			,Effective_Date   DATE           NOT NULL
			,End_Date         DATE           NOT NULL
			,ICD_Version      INT            NOT NULL
*/
/* SELECT Query_Txt
FROM ( */
select 
	ROW_NUMBER() OVER ( ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code) as Dx_RN
	,CASE 
		WHEN (ICD_Version = 9 AND Diagnosis_Code = '0010')
			OR (ICD_Version = 10 AND Diagnosis_Code = 'A000')
			THEN 'RAISERROR (''%s--- Loading ICD-' + CAST(ICD_Version AS VARCHAR(2)) + ' diagnosis codes for CMS FY ' + CAST(CMS_Fiscal_Year AS VARCHAR(4)) + ' ---'', 0, 1, @NewLine)' + CHAR(10)
				+ 'INSERT INTO #DIM_ICD_Diagnosis_All VALUES '
		ELSE 
			CASE 
				WHEN 
					(ROW_NUMBER() OVER ( ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code) )% 1000 = 0 -- every 1000 rows
					OR ROW_NUMBER() OVER ( ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code) = 1
					THEN 'INSERT INTO #DIM_ICD_Diagnosis_All VALUES '
				ELSE CHAR(9) + ','
			END
	END /*+ 
	CASE 
		WHEN 
			(ROW_NUMBER() OVER ( ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code) )% 1000 = 0 -- every 1000 rows
			OR ROW_NUMBER() OVER ( ORDER BY CMS_Fiscal_Year, ICD_Version, Diagnosis_Code) = 1
			THEN 'INSERT INTO ##DIM_ICD_Diagnosis_POA_Exempt VALUES '
		ELSE ','
	END*/
	+ '(' + CAST(CMS_Fiscal_Year AS VARCHAR(4)) + ', ''' 
	/*+ CONVERT(VARCHAR(10), Effective_Date) + ''', ''' 
	+ CONVERT(VARCHAR(10), End_Date) + ''', ' 
	+ CAST(ICD_Version AS VARCHAR(2)) + ', ''' */
	+ LTRIM(RTRIM(Diagnosis_Code)) 
	+ ''', ''' + LTRIM(RTRIM(replace(Code_Desc_Short , '''', '''''')))
	+ ''', ''' + LTRIM(RTRIM(replace(Code_Desc_Long, '''', ''''''))) + ''')' AS Query_Txt
	,*
from dbo.DIM_ICD_Diagnosis
WHERE Diagnosis_Code IN ('0413', '04671', '38600', '38601', '38602', '38603', '38604')
/*where ICD_Version = 10
) src
WHERE 
	Dx_RN IN ( 1, 2, 3)
	OR Dx_RN % 1000 IN (0, 1, 2, 998, 999)
	OR (ICD_Version = 9 AND Diagnosis_Code = '0010')
	OR (ICD_Version = 10 AND Diagnosis_Code = 'A000')
ORDER BY 
	Dx_RN
*/
/*
RAISERROR ('%s--- Inserting ICD-10 diagnosis codes for CMS FY %s ---', 0, 1, @NewLine, @This_ICD10_CMS_FY) 
*/
select *, ascii(right(Code_Desc_Long, 1)) as nlm
from dbo.DIM_ICD_Diagnosis
where ICD_Version = 9
	and Diagnosis_Code IN ('0010', '0011')


select *, ascii(right(Code_Desc_Long, 1)) as nlm, ascii(right(Code_Desc_Short, 1)) as nlm3
from dbo.DIM_ICD_Diagnosis
where ICD_Version = 9
	and Diagnosis_Code IN ('0010', '0011')


select ascii(right(Code_Desc_Long, 1)) as lastchar, count(*) as total
from dbo.DIM_ICD_Diagnosis
where 
	CMS_Fiscal_Year = 2011
GROUP BY ascii(right(Code_Desc_Long, 1))
order by 1

select CMS_Fiscal_Year, count(*) as total
from dbo.DIM_ICD_Diagnosis
where 
	ascii(right(Code_Desc_Long, 1)) < 32
GROUP BY CMS_Fiscal_Year

select CMS_Fiscal_Year, count(*) as total
from dbo.DIM_ICD_Diagnosis
where 
	ascii(right(Code_Desc_Short, 1)) < 32
GROUP BY CMS_Fiscal_Year

select CMS_Fiscal_Year, count(*) as total
from dbo.DIM_ICD_Diagnosis
where 
	ascii(right(Code_Desc_Short, 1)) = 13
GROUP BY CMS_Fiscal_Year



select CMS_Fiscal_Year, count(*) as total
	,count(case when Code_Desc_Short = Code_Desc_Long THEN Diagnosis_Code ELSE NULL END) AS Total_Same
from dbo.DIM_ICD_Diagnosis
GROUP BY CMS_Fiscal_Year
order by 1


/*
RAISERROR ('%s--- Loading ICD-9 MCE Code Exclusions v27 CMS FY 2011 ---', 0, 1, @NewLine) 
*/

select CMS_Fiscal_Year, ICD_Version, min(Diagnosis_Code) as Dx_Min, count(*)
from dbo.DIM_ICD_Diagnosis_POA_Exempt
GROUP BY CMS_Fiscal_Year, ICD_Version
order by 1, 2

select top 5 *, replace(Code_Desc_Long, '''', '''''') as nlm
from dbo.DIM_ICD_Diagnosis_POA_Exempt
where code_Desc_Long like '%''%'

select count(*)
from dbo.DIM_ICD_Diagnosis_POA_Exempt


select CMS_Fiscal_Year, CHARINDEX('.', Diagnosis_Code_With_Period) as Period_LOcation, count(*) as total, max(len(Diagnosis_Code_With_Period)) AS Len_Max
from dbo.DIM_ICD_Diagnosis_POA_Exempt
where icd_version = 10
GROUP BY CMS_Fiscal_Year, CHARINDEX('.', Diagnosis_Code_With_Period) 
order by 1, 2

exec dbo.ICD_Diag_001_Import_Descriptions_OPENROWSET 
	@Table_Name = 'DIM_ICD_Diagnosis_ICD9'
	,@Table_Action = 'DROP_CREATE'
	,@Which_ICD_Version_To_Load = '9'
	,@Source_File_Dir = 
		'C:\Users\Nicole\Documents\CMS_MS_DRG_Grouper_Help\CMS_ICD_Code_Descriptions'

alter table dbo.DIM_ICD_Diagnosis_ICD9
	ADD Diagnosis_Code_With_Period VARCHAR(8)
		,Diagnosis_Parent	VARCHAR(5)



update DIM_ICD_Diagnosis_ICD9
	SET 
		Diagnosis_Parent = LEFT(Diagnosis_Code, 4)
		,Diagnosis_Code_With_Period =
		CASE
			WHEN LEN(Diagnosis_Code) = 4 THEN Diagnosis_Code
			ELSE LEFT(Diagnosis_Code, 4) + '.' + RIGHT(Diagnosis_Code, LEN(Diagnosis_Code) - 4)
		END
WHERE
	Diagnosis_Code LIKE 'E%'


update DIM_ICD_Diagnosis_ICD9
	SET 
		Diagnosis_Parent = LEFT(Diagnosis_Code, 3)
		,Diagnosis_Code_With_Period =
		CASE
			WHEN LEN(Diagnosis_Code) = 3 THEN Diagnosis_Code
			ELSE LEFT(Diagnosis_Code, 3) + '.' + RIGHT(Diagnosis_Code, LEN(Diagnosis_Code) - 3)
		END
WHERE
	Diagnosis_Code LIKE '[V0-9]%'


select *
from DIM_ICD_Diagnosis_ICD9
where 
	Diagnosis_Code_With_Period BETWEEN 'V49.60' AND 'V49.77'

select *
from DIM_ICD_Diagnosis_POA_Exempt
where 
	ICD_Version = 9
	AND Diagnosis_Code_With_Period BETWEEN 'V49.60' AND 'V49.77'

if object_id('tempdb..#DIM_ICD_Diagnosis_POA_Exempt_ICD9') IS NOT NULL
BEGIN
	drop table #DIM_ICD_Diagnosis_POA_Exempt_ICD9
end
select CMS_Fiscal_Year, ICD_Version, Diagnosis_Parent, Diagnosis_Code, Diagnosis_Code_With_Period, Code_Desc_Long
into #DIM_ICD_Diagnosis_POA_Exempt_ICD9
from DIM_ICD_Diagnosis_POA_Exempt
where 
	ICD_Version = 9

if object_id('tempdb..#DIM_ICD_Diagnosis_ICD9') IS NOT NULL
BEGIN
	drop table #DIM_ICD_Diagnosis_ICD9
end
SELECT CMS_Fiscal_Year, ICD_Version, Diagnosis_Parent, Diagnosis_Code, Diagnosis_Code_With_Period, Code_Desc_Long
into #DIM_ICD_Diagnosis_ICD9
from DIM_ICD_Diagnosis_ICD9
where 
	CMS_Fiscal_Year = 2015
	AND (
		Diagnosis_Parent BETWEEN '137' AND '139'
		OR Diagnosis_Parent BETWEEN '740' AND '759'
		OR Diagnosis_Parent BETWEEN '905' AND '909'
		OR Diagnosis_Parent BETWEEN 'V30' AND 'V39'
		OR Diagnosis_Parent BETWEEN 'E001' AND 'E030'
		OR Diagnosis_Parent BETWEEN 'E800' AND 'E807'
		OR Diagnosis_Parent BETWEEN 'E810' AND 'E819'
		OR Diagnosis_Parent BETWEEN 'E820' AND 'E825'
		OR Diagnosis_Parent BETWEEN 'E826' AND 'E829'
		OR Diagnosis_Parent BETWEEN 'E830' AND 'E838'
		OR Diagnosis_Parent BETWEEN 'E840' AND 'E845'
		OR Diagnosis_Parent BETWEEN 'E846' AND 'E848'
		OR Diagnosis_Parent BETWEEN 'E970' AND 'E978'
		OR Diagnosis_Parent BETWEEN 'E990' AND 'E999'

		OR Diagnosis_Code_With_Period BETWEEN 'V49.60' AND 'V49.77'
		OR Diagnosis_Code_With_Period BETWEEN 'V49.81' AND 'V49.85'
		OR Diagnosis_Code_With_Period BETWEEN 'E890.0' AND 'E890.9'
		OR Diagnosis_Code_With_Period BETWEEN 'E928.0' AND 'E928.8'
		OR Diagnosis_Code_With_Period BETWEEN 'E929.0' AND 'E929.9'
		OR Diagnosis_Code_With_Period IN ('268.1', 'V87.32', 'V87.4', 'E883.1', 'E883.2', 'E884.0', 'E884.1', 'E885.0', 'E885.1', 'E885.2', 'E885.3', 'E885.4', 'E886.0', 'E893.0', 'E893.2', 'E917.0', 'E917.1', 'E917.2', 'E917.5', 'E917.6', 'E926.2', 'E987.0', 'E987.2')
		OR Diagnosis_Parent IN ('326', '412', '438', '650', '677', 'V02', 'V03', 'V04', 'V05', 'V06', 'V07', 'V10', 'V11', 'V12', 'V13', 'V14', 'V15', 'V16', 'V17', 'V18', 'V19', 'V20', 'V21', 'V22', 'V23', 'V24', 'V25', 'V26', 'V27', 'V28', 'V29', 'V42', 'V43', 'V44', 'V45', 'V46', 'V50', 'V51', 'V52', 'V53', 'V54', 'V55', 'V56', 'V57', 'V58', 'V59', 'V60', 'V61', 'V62', 'V64', 'V65', 'V66', 'V67', 'V68', 'V69', 'V70', 'V71', 'V72', 'V73', 'V74', 'V75', 'V76', 'V77', 'V78', 'V79', 'V80', 'V81', 'V82', 'V83', 'V84', 'V85', 'V86', 'V88', 'V89', 'V90', 'V91', 'E000', 'E894', 'E895', 'E897', 'E921', 'E922', 'E959', 'E979', 'E981', 'E982', 'E985', 'E989')
		OR ( Diagnosis_Parent = 'E849' AND Diagnosis_Code_With_Period <> 'E849.7')
		OR ( Diagnosis_Parent = 'E919' AND Diagnosis_Code_With_Period <> 'E919.2')
		OR Diagnosis_Code_With_Period LIKE '660.7%' 
		OR Diagnosis_Code_With_Period LIKE 'V87.4%' 
	)

select count(*)
from #DIM_ICD_Diagnosis_ICD9

select count(*)
from #DIM_ICD_Diagnosis_POA_Exempt_ICD9

;with Dx as (
	SELECT CMS_Fiscal_Year, ICD_Version, Diagnosis_Parent, Diagnosis_Code --, Diagnosis_Code_With_Period, Code_Desc_Long
	FROM #DIM_ICD_Diagnosis_ICD9
), POA AS (
	SELECT CMS_Fiscal_Year, ICD_Version, Diagnosis_Parent, Diagnosis_Code --, Diagnosis_Code_With_Period, Code_Desc_Long
	FROM #DIM_ICD_Diagnosis_POA_Exempt_ICD9
)
SELECT 'In Dx  but not POA' as src, *
FROM (
	select * from Dx
	except
	select * from poa
) C
UNION ALL
SELECT 'In POA but not Dx' as src, *
FROM (
	select * from poa
	except
	select * from Dx
) C
order by diagnosis_parent, diagnosis_code, src

select Diagnosis_Code
	, MIN(CMS_Fiscal_Year) AS FY_Min
	,Max(CMS_Fiscal_Year) AS FY_Max
	,count(*) as N_Year
from DIM_ICD_Diagnosis_ICD9
WHERE Diagnosis_Code IN ('66070', '66071', '66073', 'V8741', 'V8742', 'V8743', 'V8744', 'V8745', 'V8746', 'V8749')
GROUP BY Diagnosis_Code
order by 1

select *
from DIM_ICD_Diagnosis_ICD9
WHERE Diagnosis_Code_With_Period LIKE 'V874'

select top 5 * from #DIM_ICD_Diagnosis_POA_Exempt_ICD9
select top 5 * from #DIM_ICD_Diagnosis_ICD9

select count(*) from #DIM_ICD_Diagnosis_POA_Exempt_ICD9
select count(*) from #DIM_ICD_Diagnosis_ICD9
select *
from #DIM_ICD_Diagnosis_POA_Exempt_ICD9
where diagnosis_parent is null
	or (Diagnosis_Parent <> diagnosis_code_with_Period AND diagnosis_code_with_Period not like '%.%')

exec dbo.ICD_Diag_002_Import_POA_Exempt_OPENROWSET 
		@Table_Name = 'DIM_ICD_Diagnosis_POA_Exempt'
		,@Table_Action = 'DROP_CREATE'
		,@Source_File_Dir = 
			'C:\Users\Nicole\Documents\CMS_MS_DRG_Grouper_Help\CMS_ICD_Diagnoses_POA_Exempt'


alter table dbo.DIM_ICD_Diagnosis_POA_Exempt
	ADD Diagnosis_Parent	VARCHAR(5)

update DIM_ICD_Diagnosis_POA_Exempt
	SET 
		Diagnosis_Parent = LEFT(Diagnosis_Code, 4)
WHERE
	ICD_Version = 9
	AND Diagnosis_Code LIKE 'E%'


update DIM_ICD_Diagnosis_POA_Exempt
	SET 
		Diagnosis_Parent = LEFT(Diagnosis_Code, 3)
WHERE
	ICD_Version = 9
	AND Diagnosis_Code LIKE '[V0-9]%'




