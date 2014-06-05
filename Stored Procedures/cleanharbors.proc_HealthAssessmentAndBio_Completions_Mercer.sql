SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-06
-- Description:	Clean Harbors PHA and Bio Completions Report to Mercer
--
-- Notes:		Sourcing from the primary source for each activity since 
--				there is not a programmed incentive to handle the rules
--				Members must complete activity 60 days from Medical Effective Date (CS5).
--				
--
-- Updates:		
-- =============================================
CREATE PROCEDURE [cleanharbors].[proc_HealthAssessmentAndBio_Completions_Mercer] 

AS
	BEGIN
	SET NOCOUNT ON;

	DECLARE
		@GroupID INT,
		@PHABegin DATETIME,
		@BioBegin DATETIME,
		@IncentiveEnd DATETIME

	SET	@GroupID = 192767
	SET @PHABegin = '2013-09-20'
	SET @BioBegin = '2013-07-01'
	SET @IncentiveEnd = '2014-10-01'


	SELECT
		grp.GroupName AS [GroupName],
		mem.AltID1 AS [EmployeeID],
		mem.FirstName AS [FirstName],
		mem.LastName AS [Last Name],
		ISNULL(cs.CS1,'') AS [BenefitPlan],
		ISNULL(cs.CS2,'') AS [BenefitOption],
		ISNULL(cs.CS3,'') AS [Location],
		ISNULL(cs.CS5,'') AS [MercerMedicalEffectiveDate],
		ISNULL(CONVERT(VARCHAR(10),ha.AssessmentCompleteDate,101),'') AS [PHACompletedDate],
		ISNULL(CONVERT(VARCHAR(10),bio.ScreeningDate,101),'') AS [BiometricScreeningCompletedDate],
		CASE
			WHEN ha.AssessmentCompleteDate IS NOT NULL AND bio.ScreeningDate IS NOT NULL
			THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(ha.AssessmentCompleteDate,bio.ScreeningDate),101)
			ELSE ''
		END AS [PHAandBiometricScreeningCompletedDate]
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = @GroupID) 
	LEFT JOIN
		DA_Production.prod.CSFields CS WITH (NOLOCK)
		ON	(cs.MemberID = mem.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			AssessmentCompleteDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AssessmentCompleteDate) AS PHASeq
		FROM
			DA_Production.prod.HealthAssessment WITH (NOLOCK)
		WHERE
			GroupID = @GroupID AND
			IsComplete = 1 AND
			IsPrimarySurvey = 1 AND
			AssessmentCompleteDate >= @PHABegin
		) ha
		ON	(mem.MemberID = ha.MemberID)
		AND	(ha.PHASeq = 1)
		AND	(ha.AssessmentCompleteDate < CASE ISDATE(cs.CS5) WHEN 1 THEN DATEADD(dd,60,cs.CS5) ELSE '2999-12-31' END)
		AND	(ha.AssessmentCompleteDate < @IncentiveEnd)
	LEFT JOIN
		(
		SELECT
			MemberID,
			ScreeningDate,
			SourceAddDate AS DateLoaded,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ScreeningDate, SourceAddDate) AS BioSeq
		FROM
			DA_Production.prod.BiometricsScreening WITH (NOLOCK)
		WHERE
			GroupID = 192767 AND
			ScreeningDate >= @BioBegin
		) bio
		ON	(mem.MemberID = bio.MemberID)
		AND	(bio.BioSeq = 1)
		AND	(bio.ScreeningDate < CASE ISDATE(cs.CS5) WHEN 1 THEN DATEADD(dd,60,cs.CS5) ELSE '2999-12-31' END)
		AND	(bio.ScreeningDate < @IncentiveEnd)
	WHERE
		ha.MemberID IS NOT NULL AND
		bio.MemberID IS NOT NULL

END
GO
