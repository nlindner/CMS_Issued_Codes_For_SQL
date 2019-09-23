# Helpers to Import CMS-Issued Codes to SQL

This project contains resources for loading SQL Server tables with CMS-issued codesets for recent fiscal years (FYs), currently FY 2010 or 2011 through 2020. CMS is the Centers for Medicare and Medicaid Services ([CMS](https://www.cms.gov)), and their fiscal years run from October 1 to September 30th (e.g., fiscal year 2016 ran from October 1, 2015 to September 30, 2016). 

## This project currently includes
 * **SQL_Server_Stored_Procedures** ([more info](/INFO__SQL_Server_Stored_Procedures.md)): Stored procedures (SPs) for importing the CMS-issued flat files contained in the other subdirectories. These were developed and tested in SQL Server 2016 and have been tested in SQL Server 2012.
 * **CMS ICD Codes and Descriptions** ([more info](/INFO__CMS_ICD_Code_Descriptions.md)): CMS releases for ICD-9 and ICD-10 diagnosis and procedure codes, starting with CMS FY 2010.
  	- SQL Server SPs: ICD_Diag_001_Import_Descriptions... and ICD_Proc_001_Import_Descriptions... . If you do not already have ICD Diagnosis and Procedure code lookup tables, then look no further. Otherwise, the \_OPENROWSET procedures serve as examples of how to loop through and load annual CMS-issued files.
 * **CMS POA-Exempt ICD Diagnoses** ([more info](/INFO__CMS_ICD_Diagnoses_POA_Exempt.md)): CMS releases of ICD diagnosis codes that are exempt from Present On Admission (POA) reporting, starting with CMS FY 2011.
  	- SQL Server SP: ICD_Diag_002_Import_POA_Exempt...
 * **"Simple" Code Edits from MS-DRG MCE** ([more info](/INFO__CMS_MCE_Simple_ICD_Code_Edits.md)): Code edits from the MS (Medicare Severity) DRG (Diagnostic Related Group) Grouper software with Medicare Code Editor ([MCE](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2018-IPPS-Final-Rule-Home-Page.html)). This repo contains the "simple" ICD diagnosis and procedure code edits from the Medicare Code Editor documentation, starting with version 27 (FY 2010). 
  	- SQL Server SPs: ICD_MCE_001_Import_Simple_Code_Edits...

## Intellectual Property
No infringement is intended on the existing rights for ICD codes or the MS DRG Grouper and Medicare Code Editor. The MS DRG Grouper software and ICD codes belong to others. This simply reformats, organizes, and prepares for import to SQL Server the documentation available on cms.gov. The resources contained in this GitHub repo were developed on my own time, without using my employer's equipment, supplies, facilities, or trade secret information. 

## [License](/LICENSE.MD)
