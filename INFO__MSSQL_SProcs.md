# [SQL Server Stored Procedures](/MSSQL_SPROCS)

### Overview
  * Contains stored procedures (SPs/SPROCs) for importing all CMS-issued source files contained in the other directories, for a base "database" (what other SQL dialects call "schema") named "HCDataMart_Devt". These were developed and tested in SQL Server 2014 and have been tested in SQL Server 2012.
  * Where possible, I've made these scripts as ANSI-compliant as I can. For example, they use CAST(Field_Name AS Data_Type) rather than CONVERT(Data_Type, Field_Name) and SUBSTRING rather than LEFT (sadly, the ANSI-expected SUBSTR function is unavailable in SQL Server). 

### Why both \_OPENROWSET and \_AsValues SPs exist
  * The _OPENROWSET-suffixed SPs are inherently MSSQL-variants of ANSI-standard SQL, although your preferred SQL dialect probably has something similar to read in flat files; the .fmt files in [MSSQL_format](/MSSQL_format) are SQL Server non-XML format files that describe the field and row delimiters, field names, and field widths (SQL Server assumes that all are char unless you cast them as a more specific data type). 
  * The _AsValues-suffixed SPs contain SQL values statements to be inserted to a table, in an attempt to make this usable in other SQL flavors/variants. Also, at least in the healthcare industry, bulk load permissions are generally locked down and will not be granted for anything short of a dispensation from G-d.