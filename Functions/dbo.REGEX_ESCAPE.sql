CREATE FUNCTION [dbo].[REGEX_ESCAPE] (@Input [nvarchar] (4000))
RETURNS [nvarchar] (4000)
WITH EXECUTE AS CALLER
EXTERNAL NAME [CLR_REGEX].[UserDefinedFunctions].[REGEX_ESCAPE]
GO
