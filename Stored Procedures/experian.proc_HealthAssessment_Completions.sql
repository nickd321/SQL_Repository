SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-10-10
-- Description:	Experian PHA Completions Report
--
-- Notes:		
--
-- Updates:
--
-- =============================================
CREATE PROCEDURE [experian].[proc_HealthAssessment_Completions]
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	
	-- DECLARES
	DECLARE
		@GroupID INT,
		@PHABegin DATETIME,
		@PHAEnd DATETIME

	-- SETS
	SET @GroupID = 200846
	SET @PHABegin = '2013-08-01'
	SET @PHAEnd = '2014-09-01' -- Exclusive

	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))

	-- RESULTS

	SELECT
		grp.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		mem.AltID1 AS [EmployeeID],
		cs.CS2 AS [LocationCode],
		cs.CS1 AS [NewHire],
		CONVERT(VARCHAR(10),ha.AssessmentCompleteDate,101) AS [PHACompletedDate],
		CASE WHEN elig.MemberID IS NOT NULL THEN 'Y' ELSE '' END AS [IsCurrentlyEligible]
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = @GroupID)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		(
		SELECT
			MemberID,
			AssessmentCompleteDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AssessmentCompleteDate) AS CompleteDateSeq
		FROM
			DA_Production.prod.HealthAssessment WITH (NOLOCK)
		WHERE
			GroupID = @GroupID AND
			IsComplete = 1 AND
			IsPrimarySurvey = 1 AND
			AssessmentCompleteDate >= @PHABegin AND
			AssessmentCompleteDate < @PHAEnd
		) ha
		ON	(mem.MemberID = ha.MemberID)
		AND	(CompleteDateSeq = 1)
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
		AND	(ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))

END
GO
