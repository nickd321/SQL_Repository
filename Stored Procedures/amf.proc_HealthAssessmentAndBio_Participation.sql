SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 4/21/2014
-- Description:	Bowlmor AMF PHA and Bio Participation Report

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [amf].[proc_HealthAssessmentAndBio_Participation]

AS
BEGIN
	SET NOCOUNT ON;

SELECT
	hpg.GroupName,
	ISNULL(mem.EligMemberID,'') AS [EligMemberID],
	mem.FirstName,
	mem.LastName,
	ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS [Birthdate],
	mem.Relationship,
	ISNULL(csf.CS1,'') AS [Location],
	ISNULL(mem.AltID1,'') AS [EmployeeID],
	ISNULL(CONVERT(VARCHAR(10),pha.PHACompletedDate,101),'') AS [PHACompletedDate],
	ISNULL(CONVERT(VARCHAR(10),bio.BiometricScreeningCompletedDate,101),'') AS [BiometricScreeningCompletedDate]
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = hpg.GroupID)
	AND	(hpg.GroupID = 181006)
LEFT JOIN
	(
	SELECT
		MemberID,
		MIN(AssessmentBeginDate) AS [PHACompletedDate]
	FROM
		DA_Production.prod.HealthAssessment
	WHERE
		AssessmentBeginDate >= '4/1/2014'
		AND GroupID = 181006
		AND	IsComplete = 1
		AND SurveyID in (1,22)
		AND	IsPrimarySurvey = 1
	GROUP BY
		MemberID
	) pha
	ON	(pha.MemberID = mem.MemberID)
LEFT JOIN
	(
	SELECT
		MemberID,
		MIN(ScreeningDate) AS [BiometricScreeningCompletedDate]
	FROM
		DA_Production.prod.BiometricsScreening
	WHERE
		GroupID = 181006
		AND	ScreeningDate >='3/1/2014'
	GROUP BY
		MemberID
	) bio
	ON	(bio.MemberID = mem.MemberID)
LEFT JOIN
	DA_Production.prod.CSFields csf
	ON	(csf.MemberID = mem.MemberID)
WHERE
	bio.MemberID IS NOT NULL OR
	pha.MemberID IS NOT NULL

END
GO
