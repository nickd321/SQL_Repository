SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [internal].[proc_MVP_ManualStratificationOutreach]

	@BeginDate DATETIME = NULL,
	@EndDate DATETIME = NULL

AS BEGIN

	SET @BeginDate = ISNULL(@BeginDate,DATEADD(wk,DATEDIFF(wk,0,GETDATE())-1,0))
	SET @EndDate = ISNULL(@EndDate,DATEADD(wk,DATEDIFF(wk,0,GETDATE()),0))

	SELECT
		mem.EligMemberID,
		mem.EligMemberSuffix,
		strat.MemberStratificationName
	FROM
		DA_Production.prod.Member mem
	JOIN
		DA_Production.prod.CSFields cs
		ON	(mem.MemberID = cs.MemberID)
		AND	(cs.CS8 = 'X')
	JOIN
		DA_Production.prod.Stratification strat
		ON	(mem.MemberID = strat.MemberID)
		AND	(strat.StratificationSourceID = 1) --Manual strats only
	WHERE
		mem.HealthPlanID = 71 AND
		strat.AddDate >= @BeginDate AND
		strat.AddDate < @EndDate

END
GO
