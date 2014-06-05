SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [magellan].[MemberAssessments]

@BeginDate DATETIME = NULL,
@EndDate DATETIME = NULL

AS BEGIN

	SET @BeginDate = ISNULL(@BeginDate,DATEADD(MM,DATEDIFF(MM,0,GETDATE())-1,0))
	SET @EndDate = ISNULL(@EndDate,DATEADD(MM,DATEDIFF(MM,0,GETDATE()),0))

	SELECT
		REPLACE(grp.GroupName,',',' ') [GroupName],
		grp.GroupNumber [GroupID],
		mem.AltID1 [UniqueID],
		CASE grp.GroupNumber WHEN '8677' THEN '' ELSE mem.FirstName END [Member First Name],
		CASE grp.GroupNumber WHEN '8677' THEN '' ELSE mem.LastName END [Member Last Name],
		CONVERT(CHAR(10),mem.BirthDate,101) [EligDateOfBirth],
		CONVERT(CHAR(10),ha.AssessmentCompleteDate,101) [PHACompletedDate],
		dom.Activity AS [Activity Score],
		dom.Diet AS [Diet Score],
		dom.Tobacco AS [Tobacco Use Score],
		dom.Screening AS [Screening Score],
		dom.Stress AS [Stress Score],
		dom.Sleep AS [Sleep Score],
		CAST(ROUND(dom.TotalScore,0) AS INT) [Total Score],
		ISNULL(dom.Presenteeism,'') [Presenteeism Score],
		ha.MemberAssessmentID [UniqueSurveyID],
		CASE ha.SurveyID
			WHEN 2 THEN 'F'
			ELSE 'I'
		END [SurveyType]
	FROM
		DA_Production.prod.HealthPlanGroup grp
	JOIN
		DA_Production.prod.Member mem
		ON	(grp.GroupID = mem.GroupID)
	JOIN
		DA_Production.prod.HealthAssessment ha
		ON	(mem.MemberID = ha.MemberID)
		AND	(ha.SurveyID IN (1,22,2,18))
		AND	(ha.AssessmentCompleteDate >= @BeginDate)
		AND	(ha.AssessmentCompleteDate < @EndDate)
	JOIN
		(
		SELECT
			MemberAssessmentID,
			MAX(Activity) AS Activity,
			MAX(Diet) AS Diet,
			MAX(Tobacco) AS Tobacco,
			MAX([Preventive Health]) AS Screening,
			MAX(Stress) AS Stress,
			MAX(Sleep) AS Sleep,
			MAX(Presenteeism) AS Presenteeism,
			MAX(TotalScore) AS TotalScore
		FROM
			DA_Production.prod.HealthAssessment_DomainScore ds
		PIVOT
			(
			MAX(Score) FOR Domain IN (	Activity,
										Diet,
										Tobacco,
										[Preventive Health],
										Stress,
										Sleep,
										Presenteeism,
										TotalScore
									)
			) pvt
		WHERE
			HealthPlanID = 154
		GROUP BY
			MemberAssessmentID
		) dom
		ON	(ha.MemberAssessmentID = dom.MemberAssessmentID)
	WHERE
		grp.HealthPlanID = 154

END
GO
