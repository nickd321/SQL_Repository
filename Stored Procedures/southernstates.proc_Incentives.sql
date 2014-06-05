SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2014-05-16
-- Description:	Southern States Incentives Report
--
-- Notes:		Incentive Summary (cumulative); Time-Off Report (Monthly data only)
--				The time-off report was originally requested to 
--				deter members from completing a paper pha. The rules are still to 
--				complete a PHA where the entry method is by the 'Member' (online).
--
-- Updates:
--
-- =============================================
CREATE PROCEDURE [southernstates].[proc_Incentives]

AS
BEGIN

	SET NOCOUNT ON;	
	
	-- DECLARES
	DECLARE
		@MonthBegin DATETIME,
		@MonthEnd DATETIME
	
	-- SETS
	SET @MonthBegin = DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0)
	SET @MonthEnd = DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)

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
	
	-- PLAN HIERARCHY TEMP
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
		clnt.ClientIncentivePlanID = 1304
	ORDER BY
		8,9
	
	-- PLAN ACTIVITY TEMP
	SELECT
		DISTINCT -- THERE MAY BE A ONE TO MANY RELATIONSHIP TO THE ActivityItemValue TABLE (i.e. CompareValue column)
		hi.ClientIncentivePlanID,
		hi.PlanLevel,
		hi.ActivityItemID,
		hi.ParentActivityItemID, -- MORE THAN ONE PARENTACTIVITYITEMID IN SOME CASES
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
		hi.IsPoints,
		hi.AIB_ExamTypeCode
	INTO
		#PlanActivity
	FROM
		#PlanHierarchy hi
	WHERE
		ISNULL(hi.AIB_ExamTypeCode,'') NOT IN ('SYSBP','DIABP')
		
	
	-- SUMMARY	
	SELECT
		mem.MemberID,
		ISNULL(REPLACE(grp.GroupName,',',''),'') AS [Group Name],
		mem.FirstName AS [First Name],
		mem.LastName AS [Last Name],
		ISNULL(mem.EmailAddress,'') AS [Email Address],
		ISNULL(cs.CS3,'') AS [Location],
		ISNULL(cs.CS5,'') AS [Region],
		ISNULL(cs.CS6,'') AS [District],
		ISNULL(cs.CS7,'') AS [HR Roll-up],
		ISNULL(mem.AltID1,'') AS [Employee ID],
		ISNULL(mem.EligMemberSuffix,'') AS [Suffix],
		mem.Relationship,
		mai.ClientIncentivePlanID,
		mai.MemberActivityItemID,
		mai.ActivityItemID,
		mai.ReferenceID,
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
		AND	(mem.GroupID = 185798)
	LEFT JOIN
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
	
	SELECT
		inc.[Group Name],
		inc.[First Name],
		inc.[Last Name],
		inc.[Email Address],
		inc.Location,
		inc.Region,
		inc.District,
		inc.[HR Roll-up],
		inc.[Employee ID],
		inc.Suffix,
		inc.Relationship,
		SUM(inc.Points) AS [Points Earned],
		ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),'') AS [PHACompletedDate],
		ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),'') AS [BiometricScreeningCompletedDate],
		CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN 'Y' ELSE '' END AS [PHAandBiometricScreeningCompletedFlag],
		CASE WHEN SUM(Points) >= 100 THEN 'Y' ELSE '' END AS [100PtsFlag],
		CASE WHEN SUM(POints) >= 150 THEN 'Y' ELSE '' END AS [150PtsFlag],
		CASE WHEN outc.MemberID IS NOT NULL THEN 'Y' ELSE '' END AS [HealthyValuesFlag]
	FROM
		#Incentive	inc
	JOIN
		(
		SELECT
			MemberID,
			MIN(ActivityDate) AS 'CompletedDate'
		FROM
			#Incentive
		WHERE
			Activity = 'Personal Health Assessment'
		GROUP BY
			MemberID
		) pha
		ON	(inc.MemberID = pha.MemberID)
	JOIN
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
			Activity,
			ActivityDate,
			CreditDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY CreditDate) AS 'OutcomesSeq'
		FROM
			#Incentive
		WHERE
			Activity IN (
						'Blood Pressure is less than 130/84*',
						'BMI is between 18.5 - 29.9*',
						'Fasting Glucose is less than 100*',
						'HDL Cholesterol is more than 40*',
						'Total Cholesterol is less than 200*',
						'Tobacco-Free Pledge*'
						)
		) outc
		ON	(inc.MemberID = outc.MemberID)
		AND	(outc.OutcomesSeq = 4)
	GROUP BY
		inc.[Group Name],
		inc.[First Name],
		inc.[Last Name],
		inc.[Email Address],
		inc.Location,
		inc.Region,
		inc.District,
		inc.[HR Roll-up],
		inc.[Employee ID],
		inc.Suffix,
		inc.Relationship,
		ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),''),
		CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN 'Y' ELSE '' END,
		CASE WHEN outc.MemberID IS NOT NULL THEN 'Y' ELSE '' END	
	
	-- TIME OFF
	SELECT
		inc.[Group Name],
		inc.[First Name],
		inc.[Last Name],
		inc.[Email Address],
		inc.Location,
		inc.Region,
		inc.District,
		inc.[HR Roll-up],
		inc.[Employee ID],
		inc.Suffix,
		inc.Relationship,
		CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(pha.CreditDate,bio.CreditDate),101) AS [Date Qualified]
	FROM
		#Incentive inc
	JOIN
		(
		SELECT
			inc.MemberID,
			MIN(inc.CreditDate) AS 'CreditDate'
		FROM
			#Incentive inc
		JOIN
			DA_Production.prod.HealthAssessment pha WITH (NOLOCK)
			ON	(inc.MemberID = pha.MemberID)
			AND	(inc.ReferenceID = pha.MemberAssessmentID)
			AND	(pha.EntryMethodName = 'Member') -- ONLINE ENTRY ONLY
		WHERE
			inc.Activity LIKE '%Personal%'
		GROUP BY
			inc.MemberID
		) pha
		ON	(inc.MemberID = pha.MemberID)
	JOIN
		(
		SELECT
			MemberID,
			MIN(CreditDate) AS 'CreditDate'
		FROM
			#Incentive
		WHERE
			Activity = 'Biometrics Screening'
		GROUP BY
			MemberID
		) bio
		ON	(inc.MemberID = bio.MemberID)
	WHERE
		DA_Reports.dbo.func_MAX_DATETIME(pha.CreditDate,bio.CreditDate) >= @MonthBegin AND
		DA_Reports.dbo.func_MAX_DATETIME(pha.CreditDate,bio.CreditDate) < @MonthEnd
	GROUP BY
		inc.[Group Name],
		inc.[First Name],
		inc.[Last Name],
		inc.[Email Address],
		inc.Location,
		inc.Region,
		inc.District,
		inc.[HR Roll-up],
		inc.[Employee ID],
		inc.Suffix,
		inc.Relationship,
		CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(pha.CreditDate,bio.CreditDate),101)		

END
GO
