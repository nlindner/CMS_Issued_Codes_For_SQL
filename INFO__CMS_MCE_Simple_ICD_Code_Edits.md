# CMS_MCE_Simple_ICD_Code_Edits

### Overview
  * This is derived from the documentation for the MS (Medicare Severity) DRG (Diagnostic Related Group) Grouper software with Medicare Code Editor ([MCE](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2018-IPPS-Final-Rule-Home-Page.html)).  
  * This repo contains the "simple" diagnosis and procedure code edits from the Medicare Code Editor documentation, for CMS fiscal years (FYs) 2010-2018 (MCE versions 27-35, MCE skipped version 28 to re-align with the CMS release versions for ICD codes).
  * The flat files within this directory are read in via one of the ICD_MCE_001_Import_Simple_Code_Edits... stored procedures.
  
### Files Available Here
  * This repo converts portions of the CMS documentation (PDF, typically) into delimited flat files that can be imported to a SQL database, with the goal of providing reference tables that will aid in returning usable output from batch calls to the MCE software. It will be useful within a SQL-based data mart containing final (i.e., AFTER claims have been submitted) facility medical claims that may contain only unreliable (or non-MS) DRGs. Per the "Medicare Severity Grouper with Medicare Code Editor Software"'s installation and user's manual (software version 35, October 2017), the MCE software is intended for "evaluation of patient data to help identify possible errors in coding".
  * MCE_Simple_Code_Edits...txt files within this directory were created as follows: 
      - Versions 32-35: Derived from the lists in each of the labeled sections (MCE_Section and MCE_Edit_Type fields) of the "Definition of Medicare Code Edits v##" documentation. Where no .txt version of that documentation was available, the PDF was saved as text; doing so preserved tab-delimiters between the code and description.
      - Versions 26-31: Created by working backwards through these versions. Each version started with the subsequent version as its base, then all code changes noted in the subsequent version's "Code List Changes" chapter were applied. Their reliability will depend on all changes being noted in that chapter. For these versions, saving the PDF as text did not preserve any delimiter between the code and description, so I had to use a different strategy to create these lookups.
  
### What Are The "Simple" Code Edits That Are Included Here
  * This repo only includes the MCE sections that list specific ICD diagnosis or procedure codes. That means that **Section 1** (Invalid diagnosis or procedure code), **Section 2** (External causes of morbidity codes as principal diagnosis), and **Section 3** (Duplicate of PDX) are not lists that can be provided here, but that logic should be applied elsewhere.
  * This includes only "simple" diagnosis and procedure code edits, that is it excludes:
      -  Sections from the MCE Code Edits where (a) a procedure code is non-covered except when combined with a certain set of diagnosis codes (**Sections 11.B and 11.C**), (b) a procedure code is non-covered only when a certain set of diagnosis codes are present (e.g., **Sections 11.D and 11.E**), or a procedure code has limited coverage when combined with a particular diagnosis code (**Section 17**). 
      -  The **Section 9** diagnosis codes that are unacceptable as a principal diagnosis unless a secondary diagnosis code is provided (e.g., ICD-9 "V571" and ICD-10 "Z5189"). 
      -  ICD-9 **Section 12** (Open biopsy check), because it was only in effect for CMS FY 2010
      -  ICD-9 **Section 13** (Bilateral procedure), because I am working with claims that have already been submitted.

---
### File Sources for CMS MCE Code Edits
  * I was able to locate errata for v33-35 (ICD-10). None of the changes that were noted there affected which ICD codes are included in the edits.

| CMS FY | ICD Version | Source File for CMS Medicare Code Edits Is |
| ----------- | ----------- | -------        |
| 2018 | 10 | [FY2018 IPPS Final Rule, FY 2018 Final Rule and Correction Notice Data Files](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2018-IPPS-Final-Rule-Home-Page-Items/FY2018-IPPS-Final-Rule-Data-Files.html) <br/>--> [Definition of Medicare Code Edits v35](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2018-CMS-1677-FR-Code-Edits.zip) <br/>--> Definitions of Medicare Code Edits_v_35.txt |
| 2017 | 10 | [FY2017 IPPS Final Rule, FY 2017 Final Rule and Correction Notice Data Files](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2017-IPPS-Final-Rule-Home-Page-Items/FY2017-IPPS-Final-Rule-Data-Files.html) <br/>--> [Definition of Medicare Code Edits v34](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2017-CMS-1655-FR-Code-Edits.zip) <br/>--> Definitions of Medicare Code Edits_v_35.txt |
| 2016 | 10 | [FY2016 IPPS Final Rule, FY 2016 Final Rule and Correction Notice Data Files](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2016-IPPS-Final-Rule-Home-Page-Items/FY2016-IPPS-Final-Rule-Data-Files.html) <br/>--> [Definition of Medicare Code Edits v33](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2016-CMS-1632-FR-Definition-Code-Ethics.zip) <br/>--> ICD-10 Definitions of Medicare Code Edits_v33.0.pdf |
| 2015 | 9 | [Files for Download, Files for FY 2015 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/FY2015-Final-Rule-CorrectionNotice-Files.html) <br/>--> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY2015-FR-MCE-v32.pdf) <br/>--> FY2015-FR-MCE-v32.pdf |
| 2014 | 9 | [Files for Download, Files for FY 2014 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/FY2014-FinalRule-CorrectionNotice-Files.html) <br/>--> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_14_Definition_of-Medicare_Code_Edits_V_31_Manual.pdf) <br/>--> FY_14_Definition_of-Medicare_Code_Edits_V_31_Manual.pdf |
| 2013 | 9 | [Files for Download, Files for FY 2013 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/FY2013-FinalRule-CorrectionNotice-Files.html) <br/>--> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/MCEv30_Definitions_of_Medicare_Code_Edits_User_manual.pdf) <br/>--> MCEv30_Definitions_of_Medicare_Code_Edits_User_manual.pdf |
| 2012 | 9 | [Files for Download, Files for FY 2012 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/FY2012-FinalRule-CorrectionNotice-Files.html) <br/>--> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_2012_MCE_V280.pdf) <br/>--> FY_2012_MCE_V280.pdf |
| 2011 | 9 | [Files for Download, Files for FY 2011 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/CMS1255464.html) <br/>--> [Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/definition_of_medicare_code_edits.pdf) <br/>--> definition_of_medicare_code_edits.pdf |
| 2010 | 9 | [Files for Download, Files for FY 2010 Final Rule and Correction Notice](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Acute-Inpatient-Files-for-Download-Items/CMS1247873.html) <br/>--> [FY 2010 Definition of Medicare Code Edits](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/Downloads/FY_2010_FR_MCE.pdf) <br/>--> definition_of_medicare_code_edits.pdf |

---

### CMS MCE Code Edits: Data Dictionary and Summary Counts
#### Data Dictionary for CMS MCE Code Edits in this Repo
| Field Name     | Valid Values and/or Description of Values  |
| -------------- | ------------------------------------------ |
| ICD_Code_Type | Valid Values: P (ICD surgical procedure code) or D (ICD diagnosis code) |
| ICD_Desc      | The code description provided in the MCE documentation. This is the "short" description |
| MCE_Section and MCE_Subsection   | Within chapter 1 of the MCE documentation, the section and subsection where these codes are listed (if subsections do not exist, that is represented with "\_") ). One-to-one match between this and the MCE_Edit_Type combined with the ICD_Code_Type. |
| MCE_Edit_Type  | Short, standardized value that references the label in the MCE documentation. See "Mapping MCE Fields to Labels in MCE Documentation" section for all valid values |

#### Mapping MCE Fields to Labels in MCE Documentation
| Label in MCE Documentation | MCE_Section Subsection | MCE_Edit_Type | ICD_Code_Type |
| -------------------------- | ----------- | ------------------ | ------------- |
| Age conflict: Perinatal/Newborn diagnoses | 4 A  | Newborn_Only	| D |
| Age conflict: Pediatric diagnoses (age 0 through 17) | 4 B  | Pediatric_Only	| D |
| Age conflict: Maternity diagnoses (age 12 through 55) | 4 C  | Maternity_Only	| D |
| Age conflict: Adult diagnoses (age 15 through 124) | 4 D  | Adult_Only	| D |
| Sex conflict: Diagnoses for females only | 5 A  | Female_Only	| D |
| Sex conflict: Procedures for females only | 5 B  | Female_Only	| P |
| Sex conflict: Diagnoses for males only | 5 C  | Male_Only	| D |
| Sex conflict: Procedures for males only | 5 D  | Male_Only	| P |
| Manifestation code as principal diagnosis | 6    | Principal_Manifestation	| D |
| Questionable admission | 8    | Principal_Questionable_Admit	| D |
| Unacceptable principal diagnosis | 9    | Principal_Unacceptable	| D |
| Non-covered procedure: Always | 11 A | Noncovered_Always	| P |
| Non-covered procedure: Beneficiary over age 60 | 11 F | Noncovered_Over60	| P |
| Limited coverage: Always | 17 A | Limited_Coverage	| P |
| Wrong procedure performed | 18   | Wrong_Performed	| D |
| Procedure inconsistent with LOS | 19   | Noncovered_LOS_96hr	| P |

#### Summary Totals for CMS MCE Code Edits in this Repo
| MCE Section Subsection | MCE Edit Type | ICD Code Type | 2010 | 2011| 2012 | 2013 | 2014 | 2015 | 2016 | 2017 | 2018 |
| ----------- | ------------------ | --------------| --- |--- | --- | --- | --- | --- | --- | --- | --- |
| 4 A  | Newborn_Only	|D|287|287|287|287|287|287|441|27|27|
| 4 B  | Pediatric_Only	|D|34|35|35|35|32|32|124|104|103|
| 4 C  | Maternity_Only	|D|1144|1161|1166|1166|1166|1166|2240|2302|2354|
| 4 D  | Adult_Only	|D|128|133|135|135|135|135|721|759|759|
| 5 A  | Female_Only	|D|1515|1547|1556|1556|1556|1556|2969|3057|3107|
| 5 B  | Female_Only	|P|291|291|293|293|293|293|2171|2171|2287|
| 5 C  | Male_Only	|D|154|154|154|154|154|154|483|497|510|
| 5 D  | Male_Only	|P|114|114|114|114|114|114|1713|1713|1915|
| 6    | Principal_Manifestation	|D|271|272|274|274|274|274|326|392|393|
| 8    | Principal_Questionable_Admit	|D|14|14|14|14|14|14|31|27|27|
| 9    | Principal_Unacceptable	|D|881|934|955|955|955|955|1227|1240|2372|
| 11 A | Noncovered_Always	|P|26|26|27|26|26|25|216|127|99|
| 11 F | Noncovered_Over60	|P|1|1|1|1|1|1|2|2|2|
| 17 A | Limited_Coverage	|P|12|12|12|12|12|12|50|50|50|
| 18   | Wrong_Performed	|D|3|3|3|3|3|3|3|3|3|
| 19   | Noncovered_LOS_96hr	|P| | | |1|1|1|1|1|1|
