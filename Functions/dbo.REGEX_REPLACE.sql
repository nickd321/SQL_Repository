CREATE FUNCTION [dbo].[REGEX_REPLACE] (@Expression [nvarchar] (4000), @Pattern [nvarchar] (4000), @Replacement [nvarchar] (4000))
RETURNS [nvarchar] (4000)
WITH EXECUTE AS CALLER
EXTERNAL NAME [CLR_REGEX].[UserDefinedFunctions].[REGEX_REPLACE]
GO
