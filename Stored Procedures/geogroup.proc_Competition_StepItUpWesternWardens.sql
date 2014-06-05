SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 5/2/2014
-- Description:	Step It Up with western region wardens competition steps report for The Geo Group, Inc.

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [geogroup].[proc_Competition_StepItUpWesternWardens]

AS
BEGIN
	SET NOCOUNT ON;

SELECT
	mem.LastName,
	mem.FirstName,
	ISNULL(mem.AltID1,'') AS [GEOID],
	ISNULL(csf.CS1,'') AS [Location],
	ISNULL(mem.EligMemberID,'') AS [EligID],
	mem.Relationship,
	ISNULL(mem.EligMemberSuffix,'') AS [Suffix],
	ISNULL(mem.EmailAddress,'') AS [Email],
	CONVERT(VARCHAR(10),comp.RegisterDate,101) AS [RegistrationDate],
	ISNULL(SUM(CONVERT(INT,part.Value)),0) AS [TotalCumulativeSteps]
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = hpg.GroupID)
	AND	(hpg.GroupID = 181334)
JOIN
	DA_Production.prod.Competition comp
	ON	(comp.MemberID = mem.MemberID)
	AND	(comp.CompetitionID = 5450)
JOIN
	Healthyroads.dbo.OC_CompetitionParticipant part
	ON	(mem.MemberID = part.BenefitMemberID) 
	AND (part.CompetitionID = 5450)
	AND	(part.Deleted = 0)
	AND	(part.Withdrawn = 0)
LEFT JOIN
	DA_Production.prod.CSFields csf
	ON	(csf.MemberID = mem.MemberID)
GROUP BY
	mem.LastName,
	mem.FirstName,
	ISNULL(mem.AltID1,''),
	ISNULL(csf.CS1,''),
	ISNULL(mem.EligMemberID,''),
	mem.Relationship,
	ISNULL(mem.EligMemberSuffix,''),
	ISNULL(mem.EmailAddress,''),
	CONVERT(VARCHAR(10),comp.RegisterDate,101)

SELECT
	ISNULL(csf.CS1,'') AS [Location],
	ISNULL(SUM(CONVERT(INT,part.Value)),0) AS [TotalCumulativeSteps]
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = hpg.GroupID)
	AND	(hpg.GroupID = 181334)
JOIN
	DA_Production.prod.Competition comp
	ON	(comp.MemberID = mem.MemberID)
	AND	(comp.CompetitionID = 5450)
JOIN
	Healthyroads.dbo.OC_CompetitionParticipant part
	ON	(mem.MemberID = part.BenefitMemberID) 
	AND (part.CompetitionID = 5450)
	AND	(part.Deleted = 0)
	AND	(part.Withdrawn = 0)
LEFT JOIN
	DA_Production.prod.CSFields csf
	ON	(csf.MemberID = mem.MemberID)
GROUP BY
	ISNULL(csf.CS1,'')
	order by 2 desc

END
GO
