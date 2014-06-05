SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[func_FIXEDWIDTH_PAD_LEFT]
(
	@Character CHAR(1),
	@Width INT,
	@Column_Value VARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN
(
SELECT
	RIGHT(REPLICATE(@Character, @Width) + CONVERT(VARCHAR(MAX),@Column_Value), @Width) AS [Value]
)
GO