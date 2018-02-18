# Helpers for working with CMS Medicare Severity Grouper software and CMS-issued ICD diagnosis codes

This repo contains resources for working with the MS (Medicare Severity) DRG (Diagnostic Related Group) Grouper software with Medicare Code Editor ([MCE](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2018-IPPS-Final-Rule-Home-Page.html)), issued by the Centers for Medicare and Medicaid Services ([CMS](https://www.cms.gov)). 

## Intellectual Property
No infringement is intended on the existing rights for the MS DRG Grouper and Medicare Code Editor. The MS DRG Grouper software and ICD codes belong to others. This simply reformats, organizes, and prepares for import to SQL Server the documentation available on cms.gov. The resources contained in this GitHub repo were developed on my own time, without using my employer's equipment, supplies, facilities, or trade secret information. 

## Sample_SQL_Scripts
  * TODO: Add example usage of calling these SPs and then using them to augment an ICD diagnosis and procedure lookup tables.

## SQL_Server_Stored_Procedures
  * Stored procedures (SPs) for importing all CMS-issued source files contained in the other directories, for a base "database" (what other SQL variants call "schema") named "HCDataMart_Devt". 
  * Where possible, I've made these scripts as ANSI-compliant as I can. For example, they use CAST(Field_Name AS Data_Type) rather than CONVERT(Data_Type, Field_Name) and SUBSTRING rather than LEFT (sadly, the ANSI-expected SUBSTR function is unavailable in SQL Server). 
  * The OPENROWSET-suffixed SPs are inherently SQL Server-variants of ANSI-standard SQL, although your preferred SQL variant probably has something similar to read in flat files; the .fmt files are SQL Server non-XML format files that describe the field and row delimiters, field names, and field widths (all are assumed to be char). As time allowed, I am adding "_AsValues" variations of all SPs in an attempt to make this more broadly usable.

## CMS_ICD_Code_Descriptions
  * Note that the CMS ICD-9 code release version here differs from the Medicare Code Editor (MCE) release version
  * Contains subdirectories with CMS-issued code descriptions, read in via one of the ICD\_Diag_001_Import_Descriptions... SPs. If you do not already have a CMS-based ICD Diagnosis code lookup table (e.g., ICD-9-CM diagnosis codes and ICD-10-CM codes) table, this is an example of how to loop through to read in the annual CMS-issued files. Note that this only reads in diagnosis codes, but the process should be similar for the ICD procedure codes.
  * The flat files with the ICD-9 code descriptions available here are reformatted versions of the files I downloaded directly from CMS. I created them by saving the .xls or .xlsx file within the FY release as bar-delimited flat file, with double-quote text qualifiers around all fields in all rows. I did this because of the variations in what was available in the ICD-9 releases as the flat (non-Excel) files. For example, the flat files:
      * Did not have a single, common file structure: FY 2010 contained one flat file with both long and short descriptions; all others contained a separate short-description file and long-description file.
      * FY 2010 was also the only release where the flat file was not space-delimited. Instead it was .csv/comma-delimited AND used double-quotes as text-qualifiers, only around descriptions that contained commas. Naturally, SQL Server does not recognize the "unofficial"/de facto standard for .csv file (e.g., RFC 4180).
      * The flat files for the release did not always contain any post-effective-date corrections to the long descriptions (e.g., code 86415 for CMS FY 2010 and 2012; code 55011 for CMS FY 2013). The FY 2010 released contained a flat file with the corrections, but the ICD codes in it lacked any leading zeros (e.g., the first two diagnosis codes are "10" and "11" instead of "0010" and "0011", which already require special handling to import and map back to what the values should be).
  * File format available here (see SPs for how to import them):
	  * .\ICD9_CM: one file, bar-delimited format, with both short and long descriptions,
	  	with double-quotes surrounding every field
	  * .\ICD10_CM: one file, fixed-width format, with both short and long descriptions. The fixed-width format means that no delimiters exist. To account for that, the .fmt file has placeholders (Filler_##) for them, but does not load them to the permanent output table

| CMS FY | ICD Version | Source File for CMS Diagnosis Descriptions Is (ICD-9 from [ICD-9-CM Diagnosis and Procedure Codes: Abbreviated and Full Code Titles](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/codes.html)) |
| ------ | ----------- | ------------   |
| 2018   | 10          | [2018 ICD-10 CM and GEMs](https://www.cms.gov/Medicare/Coding/ICD10/2018-ICD-10-CM-and-GEMs.html) --> [2018 Code Descriptions in Tabular Order](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2018-ICD-10-Code-Descriptions.zip) --> icd10cm_order_2018.txt |
| 2017 | 10 | [2017 ICD-10 CM and GEMs](https://www.cms.gov/Medicare/Coding/ICD10/2017-ICD-10-CM-and-GEMs.html) --> [2017 Code Descriptions in Tabular Order](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2017-ICD10-Code-Descriptions.zip) --> icd10cm_order_2017.txt |
| 2016 | 10 | [2016 ICD-10 CM and GEMs](https://www.cms.gov/Medicare/Coding/ICD10/2016-ICD-10-CM-and-GEMs.html) --> [2016 Code Descriptions in Tabular Order](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2016-Code-Descriptions-in-Tabular-Order.zip) --> icd10cm_order_2016.txt |
| 2015 | 9 | [Version 32 Full and Abbreviated Code Titles – Effective October 1, 2014](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/ICD-9-CM-v32-master-descriptions.zip) --> CMS32_DESC_LONG_SHORT_DX.xlsx |
| 2014 | 9 |  --> [Version 31 Full and Abbreviated Code Titles – Effective October 1, 2013](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/cmsv31-master-descriptions.zip) --> CMS31_DESC_LONG_SHORT_DX.xlsx |
| 2013 | 9 | [Version 30 Full and Abbreviated Code Titles – Effective October 1, 2012: Corrections have been made to the full code descriptions for diagnosis codes 59800, 59801, 65261, and 65263.)](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/cmsv30_master_descriptions.zip) --> CMS30_DESC_LONG_SHORT_DX 080612.xlsx |
| 2012 | 9 | [Version 29 Full and Abbreviated Code Titles – Effective October 1, 2011)](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/cmsv29_master_descriptions.zip) --> CMS29_DESC_LONG_SHORT_DX 101111u021012.xls |
| 2011 | 9 | [Version 28 Full and Abbreviated Code Titles – Effective October 1, 2010)](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/cmsv28_master_descriptions.zip) --> CMS28_DESC_LONG_SHORT_DX.xls |
| 2010 | 9 | [Version 27 Full and Abbreviated Code Titles – Effective October 1, 2009)](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/FY2010Diagnosis-ProcedureCodesFullTitles.zip) --> V27LONG_SHORT_DX_110909u021012.xls |

## CMS_ICD_Diagnoses_POA_Exempt
### Sources for CMS POA Exempt Diagnoses
  * This contains CMS-issued lists of ICD diagnosis codes that are exempt from Present On Admission (POA) reporting, read in via one of the ICD_Diag_002_Import_POA_Exempt... SPs. 
  * The files for CMS FY 2015-2018 listed in the table below are available here https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Coding.html 
    * Note that only fiscal years 2015-2018 are listed there and 2015 was the last CMS release for ICD-9, so I had to hunt for the other ICD-9-CM POA-exempt diagnosis codes. 
    * FY 2013: This is hard to find on the interwebs. I finally located in on archive.org, as a [2012-10-08 snapshot](https://web.archive.org/web/20121008004658/https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Coding.html) of the HAC Coding page. The POA exempt zip archive downloaded from there contained a single file, named "POA_Exempt_Diagnosis_Codes_Oct12011_FY2012(no changes for FY 2013).txt". Just for fun, I compared that file and it indeed contained no changes. For that reason, I am loading the same file, POA_Exempt_Diagnosis_Codes_Oct12011_FY2012.txt for both 2012 and 2013. 
    * In the files available at CMS.gov, the ICD-9-CM POA files contain ICD diagnosis codes without a period, while the ICD-10-CM files contain ICD diagnosis codes WITH a period. Because of that, the SQL Server stored procedure that loads these files adds the diagnosis code with a period, based on the CMS documentation on the format of [ICD-9-CM diagnosis codes](https://www.cms.gov/Medicare/Quality-Initiatives-Patient-Assessment-Instruments/HospitalQualityInits/Downloads/HospitalAppendix_F.pdf).

| CMS FY | ICD Version | Source File for CMS POA Exempt Is |
| ------ | ----------- | ------------   |
| 2018 | 10 | [FY 2018 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/HospitalAcqCond/Downloads/FY-2018-Present-On-Admission-POA-Exempt-List-.zip) --> POAexemptCodes2018.txt |
| 2017 | 10 | [FY 2017 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2017-POA-Exempt-List.zip) --> POAexemptCodes2017.txt |
| 2016 | 10 | [FY 2016 Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD10/Downloads/2016-POA-Exempt-List.zip) --> POAexemptCodes2016.txt |
| 2015 | 9 | [FY 2015 ICD-9-CM Present On Admission (POA) Exempt List](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/FY2015-ICD9-POA-Exempt-List.zip) --> ICD-9_POA_Exempt_Diagnosis_Codes_Oct12014_FY2015.txt |
| 2014 | 9 | Release not listed on CMS, but available via [direct download](https://www.cms.gov/Medicare/Coding/ICD9ProviderDiagnosticCodes/Downloads/FY2014-ICD9-POA-Exempt-List.zip) --> ICD-POA_Exempt_Diagnosis_Codes_Oct12013_FY2014.txt |
| 2012 - 2013 | 9 | Release not listed on CMS, but available via [direct download](http://www.cms.gov/HospitalAcqCond/Downloads/POA_Exempt_Diagnosis_Codes.zip) --> POA_Exempt_Diagnosis_Codes_Oct12011_FY2012.txt |
| 2011 | 9 | Manually created list from "Attachment" (Under Categories and Codes Exempt from Diagnosis Present on Admission Requirement Effective Date: October 1, 2010) of [CMS Transmittal R756OTN](https://www.cms.gov/Regulations-and-Guidance/Guidance/Transmittals/Downloads/R756OTN.pdf). Validated this (or rather, differences between it and the FY 2012 file) against the POA code changes specified for FY 2012, as "Update to the Fiscal Year (FY) 2012 List of Codes Exempt from Reporting Present on Admission" in CMS transmittal [R1019OTN](https://www.cms.gov/Regulations-and-Guidance/Guidance/Transmittals/downloads/r1019otn.pdf) |


## CMS_MCE_Simple_ICD_Code_Exclusions
  * Contains the "simple" diagnosis and procedure code exclusions from the Medicare Code Editor documentation, versions 27 (CMS Fiscal Year (FY) 2010) through 35 (FY 2018).
  * This converts portions of the CMS documentation (PDF, typically) into delimited flat files that can be imported to a SQL database, with the goal of providing reference tables that will aid in returning usable output from batch calls to the MCE software. It will be useful within a SQL-based data mart containing final (i.e., AFTER claims have been submitted) facility medical claims that may contain only unreliable (or non-MS) DRGs. Per the "Medicare Severity Grouper with Medicare Code Editor Software"'s installation and user's manual (software version 35, October 2017), the MCE software is intended for "evaluation of patient data to help identify possible errors in coding".
  * MCE_##_Codes_Combined...txt files in this subdirectory were created as follows: 
      * Versions 32-35: Derived from the lists in each of the labeled sections (MCE_Section and MCE_Exclusion_Type fields) of the "Definition of Medicare Code Edits v##" documentation. Where no .txt version of that documentation was available, the PDF was saved as text; doing so preserved tab-delimiters between the code and description.
      * Versions 26-31: Created by working backwards through these versions. Each version started with the subsequent version as its base, then all code changes noted in the subsequent version's "Code List Changes" chapter were applied. Their reliability will depend on all changes being noted in that chapter. For these versions, saving the PDF as text did not preserve any delimiter between the code and description, so I had to use a different strategy to create these lookups.
  * **What it contains and doesn't contain:**
      * This only includes the MCE sections that list specific ICD diagnosis or procedure codes. That means that section 1 (Invalid diagnosis or procedure code), Section 2 (External causes of morbidity codes as principal diagnosis), and Section 3 (Duplicate of PDX) are not lists that can be provided here, but that logic should be applied elsewhere.
      * The includes only "simple" diagnosis and procedure code exclusions. That it, it does not include sections from the MCE Code Edits where (a) a procedure code is non-covered only when a certain set of diagnosis codes are present (e.g., section 11.D, 11.E), (b) a procedure code is non-covered except when combined with a certain set of diagnosis codes (sections 11.B and 11.C), or a procedure code has limited coverage when combined with a particular diagnosis code (section 17). It also does not include the handful of diagnosis codes that are unacceptable as a principal diagnosis unless a secondary diagnosis code is provided (e.g., for ICD-10-CM, diagnosis code "Z5189"). This also does not include the ICD-9 section 13 (Bilateral procedure). Note that in ICD-9, the wrong-procedure-performed section (18) actually lists E-codes, which are excluded per section 2.

### Sources for CMS MCE Code Exclusions
  * I was able to locate errata for v33-35 (ICD-10). None of the changes that were noted there affected which ICD codes are exclusions.

| MCE Version | ICD Version | Source File for CMS MCE Code Exclusions Is |
| ----------- | ----------- | -------        |
| 35 | 10 | [FY2018 IPPS Final Rule, FY 2018 Final Rule and Correction Notice Data Files](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2018-IPPS-Final-Rule-Home-Page-Items/FY2018-IPPS-Final-Rule-Data-Files.html) --> [Definition of Medicare Code Edits v35](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2018-CMS-1677-FR-Code-Edits.zip) --> Definitions of Medicare Code Edits_v_35.txt |
| 34 | 10 | [FY2017 IPPS Final Rule, FY 2017 Final Rule and Correction Notice Data Files](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2017-IPPS-Final-Rule-Home-Page-Items/FY2017-IPPS-Final-Rule-Data-Files.html) --> [Definition of Medicare Code Edits v34](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2017-CMS-1655-FR-Code-Edits.zip) --> Definitions of Medicare Code Edits_v_35.txt |
| 33 | 10 | [FY2016 IPPS Final Rule, FY 2016 Final Rule and Correction Notice Data Files](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2016-IPPS-Final-Rule-Home-Page-Items/FY2016-IPPS-Final-Rule-Data-Files.html) --> [Definition of Medicare Code Edits v33](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2016-CMS-1632-FR-Definition-Code-Ethics.zip) --> ICD-10 Definitions of Medicare Code Edits_v33.0.pdf |
| 32 | 9 | [Files for Download, Files for FY 2015 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/FY2015-Final-Rule-CorrectionNotice-Files.html) --> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2015-FR-MCE-v32.pdf) --> FY2015-FR-MCE-v32.pdf |
| 31 | 9 | [Files for Download, Files for FY 2014 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/FY2014-FinalRule-CorrectionNotice-Files.html) --> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_14_Definition_of-Medicare_Code_Edits_V_31_Manual.pdf) --> FY_14_Definition_of-Medicare_Code_Edits_V_31_Manual.pdf |
| 30 | 9 | [Files for Download, Files for FY 2013 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/FY2013-FinalRule-CorrectionNotice-Files.html) --> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/MCEv30_Definitions_of_Medicare_Code_Edits_User_manual.pdf) --> MCEv30_Definitions_of_Medicare_Code_Edits_User_manual.pdf |
| 28 | 9 | [Files for Download, Files for FY 2012 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/FY2012-FinalRule-CorrectionNotice-Files.html) --> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_2012_MCE_V280.pdf) --> FY_2012_MCE_V280.pdf |
| 27 | 9 | [Files for Download, Files for FY 2011 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/CMS1255464.html) --> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/definition_of_medicare_code_edits.pdf) --> definition_of_medicare_code_edits.pdf |
| 26 | 9 | [Files for Download, Files for FY 2010 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/CMS1247873.html) --> [FY 2010 Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_2010_FR_MCE.pdf) --> definition_of_medicare_code_edits.pdf |

### CMS MCE Code Exclusions: Data Dictionary and Summary Counts
#### Data Dictionary for CMS MCE Code Exclusions in this Repo
| Field Name     | Valid Values and/or Description of Values  |
| -------------- | ------------------------------------------ |
| ICD_Code_Type | Valid Values: P (ICD surgical procedure code) or D (ICD diagnosis code) |
| ICD_Desc      | The code description provided in the MCE documentation. This is the "short" description |
| MCE_Version   | The Medicare Code Editor (MCE) release version. Note that can differ from the CMS DRG Grouper software version/CMS ICD-code release version (e.g., no v29 exists), per the Installation Guide for the MS Grouper with MCE Software. |
| MCE_Section   | Within chapter 1 of the MCE documentation, the section and subsection where these codes are listed (if a subsection exists, it is the value after the period). One-to-one match between this and the MCD_Exclusion_Type combined with the ICD_Code_Type. |
| MCE_Exclusion_Type  | Short, standardized value that references the label in the MCE documentation. See "Mapping MCE Fields to Labels in MCE Documentation" section for all valid values |

#### Mapping MCE Fields to Labels in MCE Documentation
| Label in MCE Documentation | MCE_Section | MCE_Exclusion_Type | ICD_Code_Type |
| -------------------------- | ----------- | ------------------ | ------------- |
| Age conflict: Perinatal/Newborn diagnoses | 4.A  | Newborn_Only	| D |
| Age conflict: Pediatric diagnoses (age 0 through 17) | 4.B  | Pediatric_Only	| D |
| Age conflict: Maternity diagnoses (age 12 through 55) | 4.C  | Maternity_Only	| D |
| Age conflict: Adult diagnoses (age 15 through 124) | 4.D  | Adult_Only	| D |
| Sex conflict: Diagnoses for females only | 5.A  | Female_Only	| D |
| Sex conflict: Procedures for females only | 5.B  | Female_Only	| P |
| Sex conflict: Diagnoses for males only | 5.C  | Male_Only	| D |
| Sex conflict: Procedures for males only | 5.D  | Male_Only	| P |
| Manifestation code as principal diagnosis | 6    | Principal_Manifestation	| D |
| Questionable admission | 8    | Principal_Questionable_Admit	| D |
| Unacceptable principal diagnosis | 9    | Principal_Unacceptable	| D |
| Non-covered procedure: Always | 11.A | Noncovered_Always	| P |
| Non-covered procedure: Beneficiary over age 60 | 11.F | Noncovered_Over60	| P |
| Limited coverage: Always | 17.A | Limited_Coverage	| P |
| Wrong procedure performed | 18   | Wrong_Performed	| P |
| Procedure inconsistent with LOS | 19   | Noncovered_LOS_96hr	| P |

### Summary Totals for CMS MCE Code Exclusions in this Repo
| MCE Section | MCE Exclusion Type | ICD Code Type | v26 | v27| v28 | v30 | v31 | v32 | v33 | v34 | v35 |
| ----------- | ------------------ | --------------| --- |--- | --- | --- | --- | --- | --- | --- | --- |
| 4.A  | Newborn_Only	|D|287|287|287|287|287|287|27|27|27|
| 4.B  | Pediatric_Only	|D|34|35|35|35|32|32|104|104|103|
| 4.C  | Maternity_Only	|D|1144|1161|1166|1166|1166|1166|2302|2302|2354|
| 4.D  | Adult_Only	|D|128|133|135|135|135|135|759|759|759|
| 5.A  | Female_Only	|D|1515|1547|1556|1556|1556|1556|3057|3057|3107|
| 5.B  | Female_Only	|P|291|291|293|293|293|293|2171|2171|2287|
| 5.C  | Male_Only	|D|154|154|154|154|154|154|497|497|510|
| 5.D  | Male_Only	|P|114|114|114|114|114|114|1713|1713|1915|
| 6    | Principal_Manifestation	|D|271|272|274|274|274|274|392|392|393|
| 8    | Principal_Questionable_Admit	|D|14|14|14|14|14|14|27|27|27|
| 9    | Principal_Unacceptable	|D|881|934|955|955|955|955|1240|1240|2372|
| 11.A | Noncovered_Always	|P|26|26|27|26|26|25|127|127|99|
| 11.F | Noncovered_Over60	|P|1|1|1|1|1|1|2|2|2|
| 17.A | Limited_Coverage	|P|12|12|12|12|12|12|50|50|50|
| 18   | Wrong_Performed	|P|3|3|3|3|3|3|3|3|3|
| 19   | Noncovered_LOS_96hr	|P| | | |1|1|1|1|1|1|

