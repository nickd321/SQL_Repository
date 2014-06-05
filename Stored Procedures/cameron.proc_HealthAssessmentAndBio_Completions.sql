SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-12-12
-- Description:	Cameron International PHA and Biometrics Completions
--
-- =============================================

CREATE PROCEDURE [cameron].[proc_HealthAssessmentAndBio_Completions]

AS
BEGIN

	SET NOCOUNT ON;

	-- DECLARES
	DECLARE
		@BeginDate DATETIME,
		@EndDate DATETIME,
		@NewHireBegin DATETIME

	-- SETS
	SET @BeginDate = '2013-09-01'
	SET @EndDate = '2014-09-01'
	SET @NewHireBegin = '2013-09-01'

	SELECT
		base.GroupName,
		base.EligMemberID,
		base.EligMemberSuffix,
		base.FirstName,
		base.LastName,
		base.Relationship,
		base.DateofHire,
		base.Location,
		base.ProcessCenterCode,
		base.MedicalPlan,
		base.UniqueID,
		CASE
			WHEN ha.AssessmentCompleteDate IS NOT NULL AND bio.ScreeningDate IS NOT NULL 
			THEN 'Y' 
			ELSE ''
		END AS [PHAandBiometricsScreeningCompletedFlag]
	FROM
		(
		SELECT
			mem.MemberID,
			grp.GroupName,
			mem.EligMemberID,
			mem.EligMemberSuffix,
			mem.FirstName,
			mem.LastName,
			mem.Relationship,
			cs.CS1 AS [DateofHire],
			cs.CS2 AS [Location],
			cs.CS3 AS [ProcessCenterCode],
			cs.CS4 AS [MedicalPlan],
			mem.AltID1 AS [UniqueID],
			CAST(cs.CS1 AS DATETIME) AS [DOH_DateTime],
			DATEADD(dd,90,cs.CS1) AS [Activity_DueDate]
		FROM
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(grp.GroupID = mem.GroupID)
			AND	(mem.GroupID = 202584)
		JOIN
			DA_Production.prod.CSFields cs WITH (NOLOCK)
			ON	(mem.MemberID = cs.MemberID)
		WHERE
			CASE WHEN ISDATE(cs.CS1) = 1 THEN CAST(cs.CS1 AS DATETIME) END >= @NewHireBegin AND -- NEW HIRE
			cs.CS4 IN ('Open Access Plus OAP','Out of Area - OOA','Choice Fund - CFOAP','Choice Fund - CFOOA') 
		) base
	JOIN
		DA_Production.prod.HealthAssessment ha WITH (NOLOCK)
		ON	(base.MemberID = ha.MemberID)
		AND	(ha.IsPrimarySurvey = 1)
		AND	(ha.IsComplete = 1)
		AND	(ha.AssessmentCompleteDate >= @BeginDate)
		AND	(ha.AssessmentCompleteDate < @EndDate)
		AND (ha.AssessmentCompleteDate < base.Activity_DueDate)
	JOIN
		DA_Production.prod.BiometricsScreening bio WITH (NOLOCK)
		ON	(base.MemberID = bio.MemberID)
		AND	(bio.ScreeningDate >= @BeginDate)
		AND	(bio.ScreeningDate < @EndDate)
		AND	(bio.ScreeningDate < base.Activity_DueDate)
	
END
GO
