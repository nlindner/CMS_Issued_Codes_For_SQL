# Helpers to Import CMS-Issued Codes to SQL

This project contains resources for loading SQL Server tables with CMS-issued codesets for recent fiscal years (FYs). CMS is the Centers for Medicare and Medicaid Services ([CMS](https://www.cms.gov)), and their fiscal years run from October 1 to September 30th (e.g., fiscal year 2016 ran from October 1, 2015 to September 30, 2016). 

### This project currently includes
 * [SQL_Server_Stored_Procedures](../SQL_Server_Stored_Procedures): Stored procedures (SPs) for importing the CMS-issued flat files contained in the other subdirectories. These were developed and tested in SQL Server 2014 and have been tested in SQL Server 2012.
  	- See [more information](../INFO__SQL_Server_Stored_Procedures.md) 
 * [CMS_ICD_Code_Descriptions](../CMS_ICD_Code_Descriptions): CMS releases for ICD-9 and ICD-10 diagnosis and procedure codes, for CMS FYs 2010-2018.
  	- See [codeset-specific](../INFO__CMS_ICD_Code_Descriptions.md) information
  	- These codesets are loaded via the ICD_Diag_001_Import_Descriptions... and ICD_Proc_001_Import_Descriptions... stored procedures. If you do not already have ICD Diagnosis and Procedure code lookup tables, then look no further. Otherwise, the \_OPENROWSET procedures serve as examples of how to loop through and load annual CMS-issued files.
 * [CMS_ICD_Diagnoses_POA_Exempt](../CMS_ICD_Diagnoses_POA_Exempt): CMS releases of ICD diagnosis codes that are exempt from Present On Admission (POA) reporting, for CMS FY 2011-2018.
  	- See [codeset-specific](../INFO__CMS_ICD_Diagnoses_POA_Exempt.md) information
  	- These codesets are loaded via either of the ICD_Diag_002_Import_POA_Exempt... stored procedures
 * [CMS_MCE_Simple_ICD_Code_Edits](/CMS_MCE_Simple_ICD_Code_Edits): Code edits from the MS (Medicare Severity) DRG (Diagnostic Related Group) Grouper software with Medicare Code Editor ([MCE](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2018-IPPS-Final-Rule-Home-Page.html)). This repo contains the "simple" ICD diagnosis and procedure code edits from the Medicare Code Editor documentation, versions 27 (FY 2010) through 35 (FY 2018). 
  	- See [codeset-specific](/INFO__CMS_MCE_Simple_ICD_Code_Edits.md) information
  	- These codesets are loaded via either of the ICD_MCE_001_Import_Simple_Code_Edits... stored procedures

## Intellectual Property
No infringement is intended on the existing rights for ICD codes or the MS DRG Grouper and Medicare Code Editor. The MS DRG Grouper software and ICD codes belong to others. This simply reformats, organizes, and prepares for import to SQL Server the documentation available on cms.gov. The resources contained in this GitHub repo were developed on my own time, without using my employer's equipment, supplies, facilities, or trade secret information. 

## [License](../LICENSE.MD)
