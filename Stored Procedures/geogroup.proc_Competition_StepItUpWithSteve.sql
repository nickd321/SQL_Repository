SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 2014-03-19
-- Description:	The Geo Group Step It Up With Steve Competition Report
--
-- Updates:		AdrienneB_20140331:  Added "AND	(part.Withdrawn= 0)" per LindseyG
--
-- =============================================

CREATE PROCEDURE [geogroup].[proc_Competition_StepItUpWithSteve]

AS
BEGIN
	SET NOCOUNT ON;

SELECT
	grp.GroupName,
	mem.FirstName,
	mem.LastName,
	CONVERT(VARCHAR(10),mem.Birthdate,101) AS [DOB],
	ISNULL(mem.AltID1,'') AS [GEOMemberID],
	ISNULL(cs.CS1,'') AS [LocationCode],
	ISNULL(mem.EligMemberID,'') AS [EligMemberID],
	mem.Relationship,
	ISNULL(mem.EligMemberSuffix,'') AS [EligMemberSuffix],
	ISNULL(CONVERT(VARCHAR(10),part.ParticipateDate,101),'') AS [RegisterDate],
	ISNULL(CAST(part.Value AS VARCHAR(25)),'') AS TotalSteps
FROM
	DA_Production.prod.HealthPlanGroup grp
JOIN
	DA_Production.prod.Member mem
	ON	(grp.GroupID = mem.GroupID)
LEFT JOIN
	DA_Production.prod.CSFields cs
	ON	(mem.MemberID = cs.MemberID)
JOIN
	Healthyroads.dbo.OC_CompetitionParticipant part
	ON	(mem.MemberID = part.BenefitMemberID) 
	AND (part.CompetitionID = 5224)
	AND	(part.Deleted = 0)
	AND	(part.Withdrawn = 0)
ORDER BY
	3,2

END


GO
