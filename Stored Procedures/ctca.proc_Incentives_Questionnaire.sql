SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-10-04
-- Description:	CTCA Incentives Questionnaire Report
--
-- Notes:		This report aggregates the total members that answered yes to each question for
--				the 2013-2014 Incentive Plan Year
--
-- =============================================

CREATE PROCEDURE [ctca].[proc_Incentives_Questionnaire]

AS
BEGIN
	SET NOCOUNT ON;

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Questionnaire') IS NOT NULL
	BEGIN
		DROP TABLE #Questionnaire
	END

	-- QUESTION TEMP
	SELECT
		mem.GroupID,
		mem.MemberID,
		mem.FirstName,
		mem.LastName,
		ISNULL(cs.CS2,'') AS Location,
		ISNULL(cs.CS4,'') AS MedicalPlan,
		act.ActivityID,
		act.Name AS ActivityName,
		act.[Description] AS ActivityDescription,
		ait.Name AS 'PointsGrouping',
		ma.ActivityDate AS AnswerActivityDate,
		ma.MemberAnswerID,
		ma.Answer,
		ma.QuestionID,
		CASE
			ma.QuestionID
			WHEN 1893 THEN 'Plan - Annual Preventive Exam '
			WHEN 1894 THEN 'Plan - Active Health Club Participation'
			WHEN 1895 THEN 'Daily - CTCA Sponsored Wellness Event'
			WHEN 1896 THEN 'Daily - Physical Activity Community Event'
		END AS QuestionText,
		ma.RewardPoint,
		ques.QuestionText AS QuestionDisplayText,
		ques.MaxRewardPoint,
		ques.MaxRewardPointLocked,
		ques.MaxRewardPointTotal,
		aiqr.MaxRewardPointPerYear,
		mai.ActivityValue,
		ques.TimePeriodID,
		aiqr.ActivityItemQuestionnaireID,
		qr.QuestionnaireID,
		qr.Name AS QuestionnaireName,
		aiqr.StartDate AS QuestionnaireStartDate,
		aiqr.EndDate AS QuestionnaireEndDate,
		mai.ClientIncentivePlanID,
		inc.StartDate AS IncentiveStartDate,
		inc.EndDate AS IncentiveEndDate
	INTO
		#Questionnaire	
	FROM
		DA_Production.prod.Member mem WITH (NOLOCK)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		Healthyroads.dbo.IC_MemberAnswer ma WITH (NOLOCK)
		ON	(mem.MemberID = ma.MemberID)
		AND	(ma.Deleted = 0)
	JOIN
		Healthyroads.dbo.IC_Question ques WITH (NOLOCK)
		ON	(ma.QuestionID = ques.QuestionID)
		AND (ques.Deleted = 0)
	JOIN
		Healthyroads.dbo.IC_QuestionType qtyp WITH (NOLOCK)
		ON	(ques.QuestionTypeID = qtyp.QuestionTypeID)
		AND	(qtyp.Deleted = 0)
	JOIN
		Healthyroads.dbo.IC_Questionnaire qr WITH (NOLOCK)
		ON	(ques.QuestionnaireID = qr.QuestionnaireID)
		AND	(qr.Deleted = 0)
	JOIN
		Healthyroads.dbo.IC_ActivityItemQuestionnaire aiqr WITH (NOLOCK)
		ON	(qr.QuestionnaireID = aiqr.QuestionnaireID)
		AND	(aiqr.Deleted = 0)
	JOIN
		(
		SELECT
			CASE ActivityItemTypeID
			WHEN -2147483648 THEN 1
			ELSE ActivityItemTypeID END AS ActivityItemTypeID,
			ActivityItemID,
			ActivityID
		FROM
			Healthyroads.dbo.IC_ActivityItem WITH (NOLOCK)
		WHERE
			Deleted = 0
		) ai
		ON	(aiqr.ActivityItemID = ai.ActivityItemID)
	JOIN
		Healthyroads.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
		ON	(ai.ActivityItemID = mai.ActivityItemID)
		AND	(ma.MemberID = mai.MemberID)
		AND	(mai.Deleted = 0)
	JOIN
		Healthyroads.dbo.IC_Activity act WITH (NOLOCK)
		ON	(ai.ActivityID = act.ActivityID)
		AND	(act.Deleted = 0)
	JOIN		
		Healthyroads.dbo.IC_ActivityItemType ait WITH (NOLOCK)
		ON	(ai.ActivityItemTypeID = ait.ActivityItemTypeID)
		AND	(ait.Deleted = 0)
	JOIN
		Healthyroads.dbo.IC_ClientIncentivePlan inc WITH (NOLOCK)
		ON	(mai.ClientIncentivePlanID = inc.ClientIncentivePlanID)
		AND	(inc.Deleted = 0)
	WHERE
		mem.GroupID = 191393 AND
		inc.ClientIncentivePlanID = 1040
	ORDER BY 
		mem.MemberID,
		ma.QuestionID,
		ma.ActivityDate
	
	-- RESULTS
	SELECT
		QuestionText,
		Location,
		MedicalPlan,
		LEFT(AnswerActivityMonth,7) AS AnswerActivityMonth,
		[Answered] AS [AnsweredYes],
		[Answered_TotalPoints] AS [AnsweredYes_TotalPoints],
		[DistinctAnswered] AS [DistinctAnsweredYes]
	FROM
		(
			SELECT
				QuestionText,
				Location,
				MedicalPlan,
				AnswerActivityMonth,
				Measure,
				MeasureValue
			FROM
				(
				SELECT
					QuestionText,
					Location,
					MedicalPlan,
					CONVERT(VARCHAR(10),DATEADD(mm,DATEDIFF(mm,0,AnswerActivityDate),0),121) AS AnswerActivityMonth,
					COUNT(MemberAnswerID) AS Answered,
					SUM(RewardPoint) AS Answered_TotalPoints,
					COUNT(DISTINCT MemberID) AS DistinctAnswered
				FROM
					#Questionnaire
				WHERE
					Answer = 1 AND
					RewardPoint != 0 -- ONLY THOSE WHO ANSWERED YES
				GROUP BY
					QuestionText,
					Location,
					MedicalPlan,
					CONVERT(VARCHAR(10),DATEADD(mm,DATEDIFF(mm,0,AnswerActivityDate),0),121)

				UNION ALL

				SELECT
					QuestionText,
					Location,
					MedicalPlan,
					'Total',
					COUNT(MemberAnswerID) AS Answered,
					SUM(RewardPoint) AS Answered_TotalPoints,
					COUNT(DISTINCT MemberID) AS DistinctAnswered
				FROM
					#Questionnaire
				WHERE
					Answer = 1 AND
					RewardPoint != 0 -- ONLY THOSE WHO ANSWERED YES
				GROUP BY
					QuestionText,
					Location,
					MedicalPlan

				) src
				UNPIVOT
				(
				 MeasureValue FOR Measure IN ([Answered],[Answered_TotalPoints],[DistinctAnswered])
				) unpvt
		) data
		PIVOT
		(
		 SUM(MeasureValue) FOR Measure IN ([Answered],[Answered_TotalPoints],[DistinctAnswered])
		) pvt
	ORDER BY 
		1,2
	
	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Questionnaire') IS NOT NULL
	BEGIN
		DROP TABLE #Questionnaire
	END

END
GO
