SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2014-04-22
-- Description:	True Value Incentives Report to Business Solver
--
-- Notes:		Uses Alpha Code that vendor uses to translate payout points
--
-- Updates:		
--
-- =============================================
CREATE PROCEDURE [truevalue].[proc_Incentives_BusinessSolver_NewHire]

AS
BEGIN

	SET NOCOUNT ON;
	
	-- CLEAN UP	
	IF OBJECT_ID('tempdb.dbo.#PlanHierarchy') IS NOT NULL
	BEGIN
		DROP TABLE #PlanHierarchy
	END

	IF OBJECT_ID('tempdb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#ActivityScale') IS NOT NULL
	BEGIN
		DROP TABLE #ActivityScale
	END


	;WITH ActivityItemHierarchy_HRDS
		AS
		(
			SELECT
				cip.ClientIncentivePlanID,
				ip.IncentivePlanID,
				ap.ActivityPlanID,
				ap.ActivityItemID AS [PlanActivityItemID],
				ai.ActivityItemID,
				CAST(NULL AS INT) AS [ParentActivityItemID],			
				CAST(0 AS INT) AS [PlanLevel]
			FROM
				Healthyroads.dbo.IC_IncentivePlan ip WITH (NOLOCK)
			JOIN
				Healthyroads.dbo.IC_ClientIncentivePlan cip WITH (NOLOCK)
				ON	(ip.IncentivePlanID = cip.IncentivePlanID)
				AND	(cip.Deleted = 0)
			JOIN
				Healthyroads.dbo.IC_ActivityPlan ap WITH (NOLOCK) 
				ON	(ip.IncentivePlanID = ap.IncentivePlanID)
				AND	(ap.Deleted = 0)
			JOIN 
				Healthyroads.dbo.IC_ActivityItem ai WITH (NOLOCK) 
				ON	(ap.ActivityItemID = ai.ActivityItemID)
				AND	(ai.Deleted = 0)
			
		UNION ALL 

			SELECT
				aih.ClientIncentivePlanID,
				aih.IncentivePlanID,
				aih.ActivityPlanID,
				aih.PlanActivityItemID,
				ai.ActivityItemID,
				sai.ActivityItemID AS [ParentActivityItemID],			
				aih.PlanLevel + 1 AS [PlanLevel]
			FROM
				Healthyroads.dbo.IC_ActivityItem ai WITH (NOLOCK) 
			JOIN
				Healthyroads.dbo.IC_SubActivityItem sai WITH (NOLOCK)
				ON	(ai.ActivityItemID = sai.SubActivityItemID)
			JOIN
				ActivityItemHierarchy_HRDS aih
				ON	(sai.ActivityItemID = aih.ActivityItemID)
			WHERE
				ai.Deleted = 0
		)

	SELECT
		grp.HealthPlanID,
		grp.GroupID,
		clnt.ClientID,
		aih.ClientIncentivePlanID,
		aih.IncentivePlanID,
		aih.ActivityPlanID,
		aih.PlanActivityItemID,
		aih.PlanLevel,
		aih.ActivityItemID,
		aih.ParentActivityItemID,
		ai.ActivityItemOperator,
		'' AS [ActivityItemCode],
		ai.ActivityID,
		act.Name AS [ActivityName],
		act.[Description] AS [ActivityDescription],
		ai.OrderBy AS [AI_OrderBy],
		ai.Name AS [AI_Name],
		ai.Instruction AS [AI_Instruction],
		ai.StartDate AS [AI_Start],
		ai.EndDate AS [AI_End],
		ai.NumberOfDaysToComplete AS [AI_NumDaysToComplete],
		ai.IsRequired AS [AI_IsRequired],
		ai.IsRequiredStep AS [AI_IsRequiredStep],
		ai.IsActionItem AS [AI_IsActionItem],
		ai.IsHidden AS [AI_IsHidden],
		-1 AS [UnitID],
		'' AS [UnitName],
		aiv.ActivityValue AS [AIV_ActivityValue],
		aiv.IsCount AS [AIV_IsCount],
		aic.ActivityValue AS [AIC_ActivityValue],
		aic.IsCount AS [AIC_IsCount],
		aic.CompareValue AS [AIC_CompareValue],
		aic.CompareOperator AS [AIC_CompareOperator],
		lim.MaxValue AS [AIL_MaxValue],
		lim.IsCount AS [AIL_IsCount],
		lim.TimePeriodID AS [AIL_TimePeriod],
		per.Name AS [TimePeriodName],
		bio.Pregnant AS [AIB_Pregnant],
		bio.Smoking AS [AIB_Smoking],
		bio.Fasting AS [AIB_Fasting],
		bio.ExamTypeCode AS [AIB_ExamTypeCode],
		CASE
			WHEN aiv.IsCount = 1 THEN 1
			ELSE 0
		END AS [IsActivity],
		CASE
			WHEN aiv.IsCount = 0 THEN 1
			ELSE 0
		END AS [IsPoints]
	INTO
		#PlanHierarchy
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.GroupIncentivePlan clnt WITH (NOLOCK)
		ON	(grp.GroupID = clnt.GroupID)
	JOIN
		ActivityItemHierarchy_HRDS aih
		ON	(clnt.ClientIncentivePlanID = aih.ClientIncentivePlanID)
	JOIN
		Healthyroads.dbo.IC_ActivityItem ai WITH (NOLOCK)
		ON	(aih.ActivityItemID = ai.ActivityItemID)
		AND	(ai.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_Activity act WITH (NOLOCK)
		ON	(ai.ActivityID = act.ActivityID)
		AND	(act.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemValue aiv WITH (NOLOCK)
		ON	(ai.ActivityItemID = aiv.ActivityItemID)
		AND	(aiv.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemComplete aic WITH (NOLOCK)
		ON	(ai.ActivityItemID = aic.ActivityItemID)
		AND	(aic.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemLimit lim WITH (NOLOCK)
		ON	(ai.ActivityItemID = lim.ActivityItemID)
		AND	(lim.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_TimePeriod per WITH (NOLOCK)
		ON	(lim.TimePeriodID = per.TimePeriodID)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemBiometric bio WITH (NOLOCK)
		ON	(ai.ActivityItemID = bio.ActivityItemID)
		AND	(bio.Deleted = 0)
	WHERE
		clnt.ClientIncentivePlanID = 1342
	ORDER BY
		8,9
	
	-- GET PLAN INFORMATION
	SELECT
		DISTINCT -- THERE MAY BE A ONE TO MANY RELATIONSHIP TO THE ActivityItemValue TABLE (i.e. CompareValue column)
		hi.ClientIncentivePlanID,
		hi.PlanLevel,
		hi.ActivityItemID,
		--hi.ParentActivityItemID, -- MORE THAN ONE PARENTACTIVITYITEMID IN SOME CASES
		hi.ActivityItemOperator,
		hi.ActivityName,
		hi.ActivityDescription,
		hi.AI_Name,
		hi.AI_Instruction,
		hi.AI_Start,
		hi.AI_End,
		hi.AI_NumDaysToComplete,
		hi.AI_IsRequired,
		hi.AI_IsRequiredStep,
		hi.AI_IsActionItem,
		hi.AI_IsHidden,
		--hi.AIV_ActivityValue, -- MORE THAN ONE ActivityValue IN SOME CASES
		hi.AIV_IsCount,
		hi.AIC_ActivityValue,
		hi.AIC_IsCount,
		hi.AIC_CompareValue,
		hi.AIL_MaxValue,
		hi.AIL_IsCount,
		hi.TimePeriodName,
		hi.IsActivity,
		hi.IsPoints
	INTO
		#PlanActivity
	FROM
		#PlanHierarchy hi
		
	-- INCENTIVE ACTIVITY TEMP
	SELECT
		mem.MemberID,
		grp.GroupName,
		mem.EligMemberID,
		mem.FirstName,
		mem.LastName,
		mem.RelationshipID,
		mem.AltID1 AS [EID],
		cs.CS4 AS [HireDate],
		mai.ClientIncentivePlanID,
		mai.MemberActivityItemID,
		mai.ActivityItemID,
		pln.AIV_IsCount,
		pln.AIC_CompareValue,
		pln.IsActivity,
		pln.IsPoints,
		mai.ActivityValue,
		pln.AIL_MaxValue,
		CASE
			WHEN pln.IsActivity = 1 THEN 0
			WHEN pln.AIC_CompareValue > 1 THEN 0
			ELSE mai.ActivityValue
		END AS [Points],
		COALESCE(pln.AI_Instruction,pln.ActivityDescription) AS [Activity],
		mai.ActivityDate,
		mai.AddDate AS [CreditDate]
	INTO
		#Incentive
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 202586)
	JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		Healthyroads.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
		ON	(mem.MemberID = mai.MemberID)
		AND	(mai.Deleted = 0)
	JOIN
		#PlanActivity pln
		ON	(mai.ActivityItemID = pln.ActivityItemID)
		AND	(mai.ClientIncentivePlanID = pln.ClientIncentivePlanID)
	WHERE
		RTRIM(LTRIM(cs.CS3)) = 'Y' AND 
		mem.AltID1 IS NOT NULL AND
		CAST(cs.CS4 AS DATETIME) >= '2013-10-01' -- CURRENT EMPLOYEE POPULATION ONLY
	
	SELECT
		MemberID,
		EligMemberID,
		FirstName,
		LastName,
		RelationshipID,
		EID,
		PHA + BIO + Tobacco_OR_Coaching + Outcomes AS [Total]
	INTO
		#ActivityScale
	FROM
		(
		SELECT
			inc.MemberID,
			inc.EligMemberID,
			inc.FirstName,
			inc.LastName,
			inc.RelationshipID,
			inc.EID,
			-- MUST COMPLETE PHA AND BIO IN ORDER TO 100
			CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN .5 ELSE 0 END AS [PHA],
			CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN .5 ELSE 0 END AS [BIO],
			-- TOBACCO ATTESTATION OR CALLS IS NOT TIED TO PHA AND BIO
			CASE WHEN tob.CompletedDate IS NOT NULL OR cch.CompletedDate IS NOT NULL THEN 3 ELSE 0 END AS [Tobacco_OR_Coaching],
			-- MUST COMPLETE PHA AND BIO IN ORDER TO EARN OUTCOME VALUES
			CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN ISNULL((.75 * outc.OutcomesCount),0) ELSE 0 END AS [Outcomes]
		FROM
			#Incentive inc
		LEFT JOIN
			(
			SELECT
				MemberID,
				MIN(ActivityDate) AS 'CompletedDate'
			FROM
				#Incentive
			WHERE
				Activity = 'Biometrics Screening'
			GROUP BY
				MemberID
			) bio
			ON	(inc.MemberID = bio.MemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				MIN(ActivityDate) AS 'CompletedDate'
			FROM
				#Incentive
			WHERE
				Activity = 'Personal Health Assessment (Primary)'
			GROUP BY
				MemberID
			) pha
			ON	(inc.MemberID = pha.MemberID)
		LEFT JOIN
			(
			SELECT 
				MemberID,
				MIN(ActivityDate) AS 'CompletedDate'
			FROM
				#Incentive
			WHERE
				Activity = 'Tobacco Use / Non-Use Attestation (Complete within 90 days from effective date)' AND
				ActivityValue = 1
			GROUP BY
				MemberID
			) tob
			ON	(inc.MemberID = tob.MemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				Activity,
				ActivityDate AS 'CompletedDate',
				ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ActivityDate) AS CoachSeq
			FROM
				#Incentive
			WHERE
				Activity = 'Phone-Based Coaching Session'
			) cch
			ON	(inc.MemberID = cch.MemberID)
			AND	(cch.CoachSeq = 4)
		LEFT JOIN
			(
			SELECT
				MemberID,
				COUNT(Activity) AS 'OutcomesCount'
			FROM
				#Incentive
			WHERE
				Activity IN ('Met or improved BMI or Waist Circumference','Met or improved Glucose','Met or improved Blood Pressure','Met or improved Total Cholesterol')
			GROUP BY
				MemberID
			) outc
			ON	(inc.MemberID = outc.MemberID)
		WHERE
			(pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL) OR
			(tob.CompletedDate IS NOT NULL OR cch.CompletedDate IS NOT NULL)
		GROUP BY
			inc.MemberID,
			inc.EligMemberID,
			inc.FirstName,
			inc.LastName,
			inc.RelationshipID,
			inc.EID,
			CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN .5 ELSE 0 END,
			CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN .5 ELSE 0 END,
			CASE WHEN tob.CompletedDate IS NOT NULL OR cch.CompletedDate IS NOT NULL THEN 3 ELSE 0 END,
			CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN ISNULL((.75 * outc.OutcomesCount),0) ELSE 0 END
		) data

	SELECT
		EID,
		ISNULL(Associate,'A') AS [Associate],
		ISNULL(Spouse,'A') AS [Spouse]
	FROM
		(
		SELECT
			EID,
			'Associate' AS [Measure],
			CASE
				Total
				WHEN 1 THEN 'B'
				WHEN 1.75 THEN 'C'
				WHEN 2.5 THEN 'D'
				WHEN 3 THEN 'E'
				WHEN 3.25 THEN 'F'
				WHEN 4 THEN 'G'
				WHEN 4.75 THEN 'H'
				WHEN 5.5 THEN 'I'
				WHEN 6.25 THEN 'J'
				WHEN 7 THEN 'K'
			END AS [MeasureValue]
		FROM
			#ActivityScale
		WHERE
			RelationshipID = 6

		UNION ALL

		SELECT
			EID,
			'Spouse' AS [Measure],
			CASE
				Total
				WHEN 1 THEN 'B'
				WHEN 1.75 THEN 'C'
				WHEN 2.5 THEN 'D'
				WHEN 3 THEN 'E'
				WHEN 3.25 THEN 'F'
				WHEN 4 THEN 'G'
				WHEN 4.75 THEN 'H'
				WHEN 5.5 THEN 'I'
				WHEN 6.25 THEN 'J'
				WHEN 7 THEN 'K'
			END AS [MeasureValue]
		FROM
			#ActivityScale
		WHERE
			RelationshipID = 1
		) data
		PIVOT
		(
		MAX(MeasureValue) FOR Measure IN ([Associate],[Spouse])
		) pvt

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#ActivityScale') IS NOT NULL
	BEGIN
		DROP TABLE #ActivityScale
	END

END
GO
