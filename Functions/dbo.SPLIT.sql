CREATE FUNCTION [dbo].[SPLIT] (@Input [nvarchar] (4000), @Delimiter [nvarchar] (4000))
RETURNS TABLE (
[Segment] [nvarchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL)
WITH EXECUTE AS CALLER
EXTERNAL NAME [CLR_STANDARD].[UserDefinedFunctions].[SPLIT]
GO
