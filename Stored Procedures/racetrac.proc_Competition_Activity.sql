SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 4/30/2014
-- Description:	RaceTrac Cumulative Competition Activity

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [racetrac].[proc_Competition_Activity]

AS
BEGIN
	SET NOCOUNT ON;
	
SELECT
	hpg.GroupName,
	mem.FirstName,
	mem.LastName,
	ISNULL(csf.CS1,'') AS [PrimaryPlan],
	ISNULL(csf.CS2,'') AS [Area],
	ISNULL(csf.CS3,'') AS [PrimaryJobCode],
	ISNULL(csf.CS4,'') AS [Department],
	ISNULL(CONVERT(VARCHAR(10),elig.EffectiveDate,101),'') AS [EEEligBeginDate],
	mem.AltID1 AS [EEID#],
	comp.CompetitionName,
	CONVERT(VARCHAR(10),comp.CompetitionStartDate,101) AS [CompetitionStartDate],
	CONVERT(VARCHAR(10),comp.CompetitionEndDate,101) AS [CompetitionEndDate],
	ISNULL(comp.ChallengeTypeName,'') AS [ChallengType],
	CONVERT(VARCHAR(10),comp.RegisterDate,101) AS [RegisterDate],
	ISNULL(CONVERT(VARCHAR(10),comp.WithdrawDate,101),'') AS [WithdrawDate],
	ISNULL(comp.WinnerFlag,'') AS [WinnerFlag],
	ISNULL(comp.CompetitionCreatorFlag,'') AS [CompetitionCreatorFlag],
	ISNULL(comp.TeamID,'') AS [TeamID],
	ISNULL(comp.TeamName,'') AS [TeamName]
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = hpg.GroupID)
	AND	(hpg.GroupID = 203016)
	AND	(mem.Relationship = 'Primary')
LEFT JOIN
	DA_Production.prod.Eligibility elig
	ON	(elig.MemberID = mem.MemberID)
LEFT JOIN
	DA_Production.prod.CSFields csf
	ON	(csf.MemberID = mem.MemberID)
JOIN
	DA_Production.prod.Competition comp
	ON	(comp.MemberID = mem.MemberID)
ORDER BY 3,2
END
GO
