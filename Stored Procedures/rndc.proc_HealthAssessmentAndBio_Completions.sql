SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-08-23
-- Description:	Republic National Distributing Company PHA and Bio Completions Report
--
-- Notes:	Client wanted to see pha and bio completions after the incentive period.
--			This report pulls directly from the source tables.
--
-- =============================================
CREATE PROCEDURE [rndc].[proc_HealthAssessmentAndBio_Completions] 
	@inBeginDate DATETIME = NULL, 
	@inEndDate DATETIME = NULL,
	@inTermDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;
	
	-- DECLARES
	DECLARE @GroupID INT
	
	-- SETS
	SET @GroupID = 188494 
	SET @inBeginDate = ISNULL(@inBeginDate,'2012-08-01')
	SET @inEndDate = ISNULL(@inEndDate,'2014-01-01') -- PHA RESET DATE ACCORDING TO PM (ROBYN L.)
	SET @inTermDate = ISNULL(@inTermDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))

	SELECT
		grp.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.AltID1 AS EmployeeID,
		mem.FirstName,
		mem.LastName,
		mem.Relationship,
		ISNULL(mem.EmailAddress,'') AS Email,
		ISNULL(cs.CS1,'') AS Location,
		ISNULL(cs.CS3,'') AS MedicalIndicatorFlag,
		ISNULL(CONVERT(VARCHAR(10),elig.EffectiveDate,101),'') AS EffectiveDate,
		CASE WHEN elig.EffectiveDate IS NOT NULL THEN 'Y' ELSE '' END AS CurrentlyEligible,
		ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),'') AS PHA,
		ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),'') AS BIO,
		CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN 'Y' ELSE '' END AS BOTH
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = @GroupID)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			EffectiveDate,
			TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.Eligibility WITH (NOLOCK)
		WHERE
			GroupID = @GroupID
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)
		AND	(ISNULL(TerminationDate,'2999-12-31') > @inTermDate)
	LEFT JOIN
		(
		SELECT
			MemberID,
			MIN(AssessmentCompleteDate) AS 'CompletedDate'
		FROM
			DA_Production.prod.HealthAssessment WITH (NOLOCK)
		WHERE
			GroupID = @GroupID AND
			IsPrimarySurvey = 1 AND
			IsComplete = 1 AND
			AssessmentCompleteDate >= @inBeginDate AND
			AssessmentCompleteDate < @inEndDate
		GROUP BY
			MemberID
		) pha
		ON	(mem.MemberID = pha.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			MIN(ScreeningDate) AS 'CompletedDate'
		FROM
			DA_Production.prod.BiometricsScreening WITH (NOLOCK)
		WHERE
			GroupID = @GroupID AND
			ScreeningDate >= @inBeginDate AND
			ScreeningDate < @inEndDate
		GROUP BY
			MemberID
		) bio
		ON	(mem.MemberID = bio.MemberID)



END
GO
