# [CMS POA-Exempt ICD Diagnosis Codes](/ICD_Diag_POA_Exempt)

### Overview
  * Contains CMS releases of ICD diagnosis codes that are exempt from Present On Admission (POA) reporting, for CMS Fiscal Years (FYs) 2010-2020.
  * The flat files within this directory are read in via one of the ICD_Diag_002_Import\_POA\_Exempt_... stored procedures.

### Files Available Here
 * Note that except for FY 2010 and 2011, this preserves any discrepancies in the (long) code descriptions that exist between the CMS releases of ICD diagnosis codes and POA-exempt diagnosis codes; Those discrepancies tend to be wording differences, spelling differences, or spacing differences. At least some of the ICD-9 discrepancies seem to be related to spelling or spacing corrections that are not listed in [CMS' documentation of new, deleted, and revised codes](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/summarytables.html) but that are visible if you compare the diagnosis descriptions across years. These are usually minor. A few examples are:
   - ICD 9: 66070, V1919, 75530, V1649, E8302
   - ICD 10: O0910, T82857D, T8379XD, S02118D, S0211GD
 * __CMS FY 2015-2020:__ Files for all ICD-10 releases and the last ICD-9 release (FY 2015) listed in the table below are available at the CMS under [Hospital-Acquired Conditions (Present on Admission Indicator)](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Coding.html). 
 * __ICD-9, CMS FY 2010-2014:__ These were difficult to locate and some are only available via archive.org. Given that the [CMS site specifies that transmittals prior to 2012 should be accessed at archive.org](https://www.cms.gov/Regulations-and-Guidance/Guidance/Transmittals/index.html), then I think that's reasonable.
 * __Specifics for FY 2013:__ File was only available via an [archive.org snapshot](https://web.archive.org/web/20121008004658/https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Coding.html). The ZIP archive available there contains a single file, "POA_Exempt_Diagnosis_Codes_Oct12011_FY2012(no changes for FY 2013).txt". That file is indeed identical to the FY2012 file, so this uses the 2012 file for both 2012 and 2013.
 * __Specifics for FY 2010 and 2011:__
    - I generated the files in this repo from the [CMS ICD-9 diagnosis code releases](/INFO__CMS_ICD_Code_Descriptions.md) for FY 2010 and 2011, respectively, using the POA-exempt code ranges in Appendix I of the ICD-9-CM Official Guidelines for Coding and Reporting, effective for FY [2010](http://www.codingupdates.com/wp-content/uploads/icdguide09-Sept.pdf) or [2011](https://web.archive.org/web/20120917021503/https://www.cdc.gov/nchs/data/icd9/icdguide10.pdf), respectively. Unlike the CMS-issued files, then when possible, they provide ranges of codes that are POA-exempt, instead of listing every single exempt code. 

### Standardization Applied During Load
 * Some of the ICD-9 POA files contain lowercase letters in the diagnosis codes. SQL Server is case-insensitive, but the SP uppercases those during the load process anyway.
 * Any trailing/leading spaces are trimmed from the diagnosis code and description during load.
 * The ICD-9 POA files contain ICD diagnosis codes without a period, while the ICD-10-CM files contain ICD diagnosis codes WITH a period. Because of that, the SQL Server stored procedure that loads these files adds the diagnosis code with a period, based on the CMS documentation on the format of [ICD-9-CM diagnosis codes](https://www.cms.gov/Medicare/Quality-Initiatives-Patient-Assessment-Instruments/HospitalQualityInits/Downloads/HospitalAppendix_F.pdf).
 * The ICD-10 POA files surround the Code_Desc_Long with double-quotes as text qualifiers to escape special characters. SQL Server does not recognize that feature of the unofficial/de facto .csv file standard, so a REPLACE() function is used to strip those out during load.

---
### File Sources
| CMS FY | ICD Version | Source File for CMS POA Exempt Is |
| ------ | ----------- | -------------------------------   |
| 2020 | 10 | [FY 2020 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2020-POA-Exempt-Codes.zip) <br/> --> POAexemptCodes2020.txt |
| 2019 | 10 | [FY 2019 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Downloads/FY-2019-Present-On-Admission-POA-Exempt-List-.zip) <br/> --> POAexemptCodes2019.txt |
| 2018 | 10 | [FY 2018 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Downloads/FY-2018-Present-On-Admission-POA-Exempt-List-.zip) <br/> --> POAexemptCodes2018.txt |
| 2017 | 10 | [FY 2017 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2017-POA-Exempt-List.zip) <br/> --> POAexemptCodes2017.txt |
| 2016 | 10 | [FY 2016 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2016-POA-Exempt-List.zip) <br/> --> POAexemptCodes2016.txt |
| 2015 | 9 | [FY 2015 ICD-9-CM Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/FY2015-ICD9-POA-Exempt-List.zip) <br/> --> ICD-9_POA_Exempt_Diagnosis_Codes_Oct12014_FY2015.txt |
| 2014 | 9 | Release not listed on CMS, but available via [direct download](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/FY2014-ICD9-POA-Exempt-List.zip) <br/> --> ICD-POA_Exempt_Diagnosis_Codes_Oct12013_FY2014.txt |
| 2012-2013 | 9 | 2012 release not listed on CMS, but available via [direct download](http://www.cms.gov/HospitalAcqCond/Downloads/POA_Exempt_Diagnosis_Codes.zip) <br/> --> POA_Exempt_Diagnosis_Codes_Oct12011_FY2012.txt <br/> See [files available here](#files-available-here) for why we load the same file for both years |
| 2010-2011 | 9 | See [files available here](#files-available-here) for how the files in this repo were generated from the ICD-9-CM official guidelines for [FY 2010](http://www.codingupdates.com/wp-content/uploads/icdguide09-Sept.pdf) and [FY 2011](https://web.archive.org/web/20120917021503/https://www.cdc.gov/nchs/data/icd9/icdguide10.pdf) |

