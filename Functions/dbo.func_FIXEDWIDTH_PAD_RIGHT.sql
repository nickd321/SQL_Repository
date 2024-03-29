SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[func_FIXEDWIDTH_PAD_RIGHT]
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
	LEFT(CONVERT(VARCHAR(MAX),@Column_Value) + REPLICATE(@Character, @Width), @Width) AS [Value]
)
GO
