# CMS_ICD_Diagnoses_POA_Exempt

### Overview
  * Contains CMS releases of ICD diagnosis codes that are exempt from Present On Admission (POA) reporting, for CMS Fiscal Years (FYs) 2011-2018.
  * The flat files within this directory are read in via one of the ICD_Diag_002_Import_POA_Exempt_... stored procedures.

### Files Available Here
 * The files for CMS FY 2015-2018 listed in the table below are available at the CMS under [Hospital-Acquired Conditions (Present on Admission Indicator)](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Coding.html) 
 * Note that only fiscal years 2015-2018 are listed there and 2015 was the last CMS release for ICD-9, so I had to hunt for the other ICD-9-CM POA-exempt diagnosis codes. 
    - FY 2013: This is hard to find on the interwebs. I finally located in on archive.org, as a [2012-10-08 snapshot](https://web.archive.org/web/20121008004658/https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Coding.html) of the HAC Coding page. The POA exempt zip archive downloaded from there contained a single file, named "POA_Exempt_Diagnosis_Codes_Oct12011_FY2012(no changes for FY 2013).txt". Because I'm...precise about things like this, I compared that file and it indeed contained no changes. For that reason, I am loading the same file, POA_Exempt_Diagnosis_Codes_Oct12011_FY2012.txt for both 2012 and 2013. 
 * Differences in the ICD-9 vs ICD-10 files that are available on cms.gov
    - The ICD-9 POA files contain ICD diagnosis codes without a period, while the ICD-10-CM files contain ICD diagnosis codes WITH a period. Because of that, the SQL Server stored procedure that loads these files adds the diagnosis code with a period, based on the CMS documentation on the format of [ICD-9-CM diagnosis codes](https://www.cms.gov/Medicare/Quality-Initiatives-Patient-Assessment-Instruments/HospitalQualityInits/Downloads/HospitalAppendix_F.pdf).
    - The ICD-10 POA files surround the Code_Desc_Long with double-quotes as text qualifiers to escape special characters. SQL Server does not recognize  that feature of the unofficial/de facto .csv file standard, so a REPLACE() function  is used to strip those out during load.
    - (Some?) of the ICD-9 POA files contain lowercase letters in the diagnosis codes. SQL Server is case-insensitive, but the SP uppercases those during the load process anyway.

---
### File Sources
| CMS FY | ICD Version | Source File for CMS POA Exempt Is |
| ------ | ----------- | ------------   |
| 2018 | 10 | [FY 2018 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Downloads/FY-2018-Present-On-Admission-POA-Exempt-List-.zip) <br/> --> POAexemptCodes2018.txt |
| 2017 | 10 | [FY 2017 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2017-POA-Exempt-List.zip) <br/> --> POAexemptCodes2017.txt |
| 2016 | 10 | [FY 2016 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2016-POA-Exempt-List.zip) <br/> --> POAexemptCodes2016.txt |
| 2015 | 9 | [FY 2015 ICD-9-CM Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/FY2015-ICD9-POA-Exempt-List.zip) <br/> --> ICD-9_POA_Exempt_Diagnosis_Codes_Oct12014_FY2015.txt |
| 2014 | 9 | Release not listed on CMS, but available via [direct download](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/FY2014-ICD9-POA-Exempt-List.zip) <br/> --> ICD-POA_Exempt_Diagnosis_Codes_Oct12013_FY2014.txt |
| 2012 - 2013 | 9 | Release not listed on CMS, but available via [direct download](http://www.cms.gov/HospitalAcqCond/Downloads/POA_Exempt_Diagnosis_Codes.zip) <br/> --> POA_Exempt_Diagnosis_Codes_Oct12011_FY2012.txt |
| 2011 | 9 | Manually created list from "Attachment" section in [CMS Transmittal R756OTN](https://www.cms.gov/Regulations-and-Guidance/Guidance/Transmittals/Downloads/R756OTN.pdf) (Under Categories and Codes Exempt from Diagnosis Present on Admission Requirement). <br/> Validated differences between it and the FY 2012 file against the POA code changes specified in [CMS Transmittal R1019OTN](https://www.cms.gov/Regulations-and-Guidance/Guidance/Transmittals/downloads/r1019otn.pdf), as "Update to the Fiscal Year (FY) 2012 List of Codes Exempt from Reporting Present on Admission" |

