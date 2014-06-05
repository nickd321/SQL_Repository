SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-02-24
-- Description:	Emblem Health PHA Completions Report
-- =============================================

CREATE PROCEDURE [emblemhealth].[proc_HealthAssessment_Completions] 
	@inBeginDate DATETIME = NULL, 
	@inEndDate DATETIME = NULL

AS
BEGIN

	SET NOCOUNT ON;	

	SET @inBeginDate = ISNULL(@inBeginDate, DATEADD(dd,20,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0)))
	SET @inEndDate = ISNULL(@inEndDate, DATEADD(dd,20,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)))

	SELECT
		GroupName,
		EmployeeID,
		FirstName,
		LastName,
		CONVERT(VARCHAR(10),AssessmentCompleteDate,101) AS PHACompletedDate
	FROM
		(
		SELECT
			grp.GroupName,
			mem.AltID1 AS [EmployeeID],
			mem.FirstName,
			mem.LastName,
			pha.AssessmentCompleteDate,
			ROW_NUMBER() OVER (PARTITION BY mem.MemberID ORDER BY pha.AssessmentCompleteDate) AS PHASeq
		FROM
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(grp.GroupID = mem.GroupID)
			AND	(mem.GroupID = 197697)
		JOIN
			DA_Production.prod.HealthAssessment pha WITH (NOLOCK)
			ON	(mem.MemberID = pha.MemberID)
		WHERE
			mem.RelationshipID = 6 AND
			pha.IsComplete = 1 AND
			pha.IsPrimarySurvey = 1 AND
			pha.AssessmentCompleteDate >= '2014-01-27' AND
			pha.AssessmentCompleteDate < '2015-01-01'
		) pha
	WHERE
		PHASeq = 1 AND
		AssessmentCompleteDate >= @inBeginDate AND
		AssessmentCompleteDate < @inEndDate
	ORDER BY
		2
		
END
GO
