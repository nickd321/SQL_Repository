SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-10-11
-- Description:	Clean Harbors PHA and Bio Completion Report
-- =============================================
CREATE PROCEDURE [cleanharbors].[proc_HealthAssessmentAndBio_Completions] 

AS
BEGIN

	SET NOCOUNT ON;

	DECLARE
		@GroupID INT,
		@PHABegin DATETIME,
		@BioBegin DATETIME,
		@End DATETIME
	
	SET	@GroupID = 192767
	SET @PHABegin = '2013-09-20'
	SET @BioBegin = '2013-07-01'
	SET @End = '2014-10-01'

	SELECT
		grp.GroupName,
		ISNULL(mem.AltID1,'') AS [EmployeeID],
		mem.FirstName,
		mem.Lastname,
		ISNULL(cs.CS1,'') AS [BenefitPlan],
		ISNULL(cs.CS2,'') AS [BenefitOption],
		ISNULL(cs.CS3,'') AS [Location],
		ISNULL(cs.CS4,'') AS [MedicalEffectiveDate],
		ISNULL(CONVERT(VARCHAR(10),ha.AssessmentCompleteDate,101),'') AS [PHACompletedDate],
		ISNULL(CONVERT(VARCHAR(10),bio.ScreeningDate,101),'') AS [BiometricScreeningCompletedDate],
		CASE
			WHEN ha.AssessmentCompleteDate IS NOT NULL AND bio.ScreeningDate IS NOT NULL
			THEN CONVERT(VARCHAR(10),dbo.func_MAX_DATETIME(ha.AssessmentCompleteDate,bio.ScreeningDate),101)
			ELSE '' 
		END AS PHAandBiometricScreeningCompletedDate
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
			AssessmentCompleteDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AssessmentCompleteDate ASC) AS PHASeq
		FROM
			DA_Production.prod.HealthAssessment WITH (NOLOCK)
		WHERE
			GroupID = @GroupID AND
			IsComplete = 1 AND
			IsPrimarySurvey = 1 AND
			AssessmentCompleteDate >= @PHABegin AND
			AssessmentCompleteDate < @End
		) ha
		ON	(mem.MemberID = ha.MemberID)
		AND	(ha.PHASeq = 1)
	LEFT JOIN
		(
		SELECT
			MemberID,
			ScreeningDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ScreeningDate ASC) AS BioSeq
		FROM
			DA_Production.prod.BiometricsScreening WITH (NOLOCK)
		WHERE
			GroupID = @GroupID AND
			ScreeningDate >= @BioBegin AND
			ScreeningDate < @End
		) bio
		ON	(mem.MemberID = bio.MemberID)
		AND	(bio.BioSeq = 1)
	WHERE
		ha.AssessmentCompleteDate IS NOT NULL OR
		bio.ScreeningDate IS NOT NULL

END
GO
