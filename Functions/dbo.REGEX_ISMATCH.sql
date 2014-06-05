CREATE FUNCTION [dbo].[REGEX_ISMATCH] (@Expression [nvarchar] (4000), @Pattern [nvarchar] (4000))
RETURNS [bit]
WITH EXECUTE AS CALLER
EXTERNAL NAME [CLR_REGEX].[UserDefinedFunctions].[REGEX_ISMATCH]
GO
