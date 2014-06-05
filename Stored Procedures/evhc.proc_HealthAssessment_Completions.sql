SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Domokos
-- Create date: 2014-02-11
-- Description:	EVHC (Envision Healthcare) PHA Completion Report
--
--		NickD 2014-03-24: 
--		Filtered by CS3 = Y per work order 3573
--
--		NickD 2014-05-06: 
--		Per work order 3744:
--		Added CS 3 Field to output
--		Removed code "AND (mem.CS4 = 'ACDHP1500')"
--
-- =============================================
CREATE PROCEDURE [evhc].[proc_HealthAssessment_Completions] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

--	DECLARE @inBeginDate DATETIME, @inEndDate DATETIME
		
	SET	@inBeginDate = ISNULL(@inBeginDate,'2014-01-01')
	SET @inEndDate = ISNULL(@inEndDate,'2015-01-01')

	SELECT
		grp.GroupName,
		mem.EligMemberID,
		ISNULL(mem.AltID1,'') AS [EmployeeID],
		mem.FirstName,
		mem.LastName,
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS [Birthdate],
		rel.RelationshipDescription AS [Relationship],
		ISNULL(mem.CS2,'') AS [UnionIndicator],
		ISNULL(mem.CS1,'') AS [BenefitGroupCode],
		ISNULL(mem.CS4,'') AS [HealthPlan],
		ISNULL(mem.CS5,'') AS [HealthPlanTier],
		ISNULL(mem.CS3,'') AS [CS 3],
		CONVERT(VARCHAR(10),pha.AssessmentBeginDate,101) AS PHACompletedDate
	FROM
		Benefits.dbo.[Group] grp WITH (NOLOCK)
	JOIN
		Benefits.dbo.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(grp.GroupID = 194355)
		AND (mem.CS3 = 'Y')
		AND	(mem.Deleted = 0)
	JOIN
		Benefits.dbo.Relationship rel WITH (NOLOCK)
		ON	(mem.RelationshipID = rel.RelationshipID)
	JOIN
		(
		SELECT
			MemberID,
			AssessmentBeginDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AssessmentBeginDate) AS PhaSeq 
		FROM
			DA_Production.prod.HealthAssessment pha WITH (NOLOCK)
		WHERE
			(pha.IsPrimarySurvey = 1)
			AND	(pha.IsComplete = 1)
			AND	(pha.AssessmentBeginDate >= @inBeginDate)
			AND (pha.AssessmentBeginDate < @inEndDate)
		) pha
		ON	(mem.MemberID = pha.MemberID)
		AND	(pha.PhaSeq = 1)
		
		
	ORDER BY
		2,7
		
END


GO
