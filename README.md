# CMS Releases of ICD Codesets, Including Code Helpers to Import to SQL (Server)

This project contains CMS releases of ICD codesets for recent fiscal years (FYs), currently FY 2010 through 2020, with resources for loading them to SQL Server (MSSQL) tables. CMS is the Centers for Medicare and Medicaid Services ([CMS](https://www.cms.gov)), and their fiscal years run from October 1 to September 30th (e.g., fiscal year 2016 ran from October 1, 2015 to September 30, 2016). 

## This project currently includes subdirectories with
 * **MSSQL Stored Procedures** ([more info](/INFO__MSSQL_SProcs.md)) and **MSSQL_format** files: Stored procedures (SPROCs) for importing the CMS-issued flat files contained in the other subdirectories. These were developed and tested in SQL Server 2016 and have been tested in SQL Server 2012.
    - [MSSQL_format](/MSSQL_format): MSSQL requires format (*.fmt) files to bulk insert flat files. They're rather kludgy compared some other SQL dialects (e.g., have to load to (VAR)CHAR, every row of a field must be quote-delimited if any cells require it).
 * **CMS ICD (Diagnosis and Procedure) Codes and Descriptions** ([more info](/INFO__CMS_ICD_Code_Descriptions.md)): CMS releases for ICD-9 and ICD-10 diagnosis and procedure codes, starting with CMS FY 2010.
  	- MSSQL SPs: ICD_Diag_001_Import_Descriptions... and ICD_Proc_001_Import_Descriptions... . If you do not already have ICD Diagnosis and Procedure code lookup tables, then look no further.
 * **CMS POA-Exempt ICD Diagnoses** ([more info](/INFO__ICD_Diag_POA_Exempt.md)): CMS releases of ICD diagnosis codes that are exempt from Present On Admission (POA) reporting, starting with CMS FY 2010.
  	- MSSQL SP: ICD_Diag_002_Import_POA_Exempt...
 * **"Simple" Code Edits from MS-DRG MCE** ([more info](/INFO__CMS_MCE_Simple_ICD_Code_Edits.md)): Code edits from the MS (Medicare Severity) DRG (Diagnostic Related Group) Grouper software with Medicare Code Editor ([MCE](https://www.cms.gov/Medicare/Medicare-Fee-for-Service-Payment/AcuteInpatientPPS/FY2018-IPPS-Final-Rule-Home-Page.html)). This repo contains the "simple" ICD diagnosis and procedure code edits from the Medicare Code Editor documentation, starting with version 27 (FY 2010). 
  	- MSSQL SPs: ICD_MCE_001_Import_Simple_Code_Edits...

## Intellectual Property
No infringement is intended on the existing rights for ICD diagnosis/procedure codes or the MS-DRG Grouper and Medicare Code Editor. They all belong to others. For a tiny subset of the documentation available on cms.gov, this simply centralizes, organizes, reformats (for ICD-9 and MCE code edits), and prepares for import to SQL Server.

The resources contained in this GitHub repo were developed on my own time, without using my employer's equipment, supplies, facilities, or trade secret information. 

## [License](/LICENSE.MD)
