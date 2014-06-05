SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		William Perez
-- Create date: 2013-06-01
-- Description:	Mercedes Benz Incentive Redemption Report
--
-- Notes:		Currently this is specific to the incentive plan that began on 3/1/2013
--
-- Updates:		NickD 20140324:
--				The report has been updated for the 2014 incentive plan.
--
-- =============================================

CREATE PROCEDURE [mercedesbenz].[proc_IncentiveRedemptions]

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

	IF OBJECT_ID('tempdb.dbo.#RunningPointsTotal') IS NOT NULL
	BEGIN
		DROP TABLE #RunningPointsTotal
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
		clnt.IncentiveBeginDate,
		clnt.IncentiveEndDate,
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
		clnt.ClientIncentivePlanID = 1311
	ORDER BY
		8,9
	
	-- PLAN ACTIVITY TEMP
	SELECT
		DISTINCT -- THERE MAY BE A ONE TO MANY RELATIONSHIP TO THE ActivityItemValue TABLE (i.e. CompareValue column)
		hi.ClientIncentivePlanID,
		hi.IncentiveBeginDate,
		hi.IncentiveEndDate,
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
	
	-- INCENTIVE TEMP		
	SELECT
		mem.MemberID,
		grp.GroupName,
		ISNULL(mem.EligMemberID,'') AS [EligMemberID],
		ISNULL(mem.EligMemberSuffix,'') AS [EligMemberSuffix],
		mem.FirstName,
		mem.LastName,
		ISNULL(mem.AltID1,'') AS [EmployeeID],
		ISNULL(cs.CS1,'') AS [Location],
		ISNULL(cs.CS2,'') AS [CompanyCode],
		mem.RelationshipID,
		mem.Relationship,
		mai.ClientIncentivePlanID,
		pln.IncentiveBeginDate,
		pln.IncentiveEndDate,
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
		AND	(mem.GroupID = 197698)
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
	WHERE
		mem.RelationshipID = 6	

	-- RUNNING TOTAL
	SELECT
		ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ActivityDate) AS 'MemberRowID',
		MemberID,
		Activity,
		ActivityDate,
		Points,
		NULL AS [RunningTotal]
	INTO 
		#RunningPointsTotal
	FROM 
		#Incentive

	-- ENSURE THE DATA IS PHYSICALLY ORDERED THE WAY WE WANT, SO THE UPDATE WORKS
	-- AS NEEDED
	CREATE UNIQUE CLUSTERED INDEX idx_temp_MemberActivity
	ON #RunningPointsTotal (MemberID, MemberRowID)

	-- CREATE A VARIABLE THAT WILL BE USED THROUGHOUT THE UPDATE
	DECLARE 
		@RunningTotal INT
	SET 
		@RunningTotal = 0

	UPDATE 
		#RunningPointsTotal
	SET 
		@RunningTotal = RunningTotal = Points + CASE WHEN MemberRowID = 1 THEN 0 ELSE @RunningTotal END
	FROM 
		#RunningPointsTotal
	
	-- FINAL OUTPUT		
	SELECT
		inc.GroupName,
		inc.EligMemberID,
		inc.EligMemberSuffix,
		inc.FirstName,
		inc.LastName,
		inc.EmployeeID,
		inc.Location,
		inc.CompanyCode,
		CASE 
			WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL
			THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(pha.CompletedDate,bio.CompletedDate),101) 
			ELSE ''
		END AS [PHAandBiometricCompletedDate],
		ISNULL(CONVERT(VARCHAR(10),[125pts].CompletedDate,101),'') AS [125PointsCompletedDate],
		ISNULL(CONVERT(VARCHAR(10),red.RequestDate,101),'') AS [RedeemedDate],
		ISNULL(CAST((red.Quantity * red.RedeemedAmount) AS VARCHAR(25)),'') AS [RedeemedAmount],
		CASE
			WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND [125pts].CompletedDate IS NOT NULL
			THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME([125pts].CompletedDate,DA_Reports.dbo.func_MAX_DATETIME(pha.CompletedDate,bio.CompletedDate)),101)
			ELSE ''
		END AS [PHABiometric125ptsCompletedDate]
	FROM
		#Incentive inc
	LEFT JOIN
		(
		SELECT
			MemberID,
			MIN(ActivityDate) AS [CompletedDate]
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
			MIN(ActivityDate) AS [CompletedDate]
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
			MIN(ActivityDate) AS [CompletedDate]
		FROM
			#RunningPointsTotal
		WHERE
			RunningTotal >= 125
		GROUP BY
			MemberID
		) [125pts]
		ON	(inc.MemberID = [125pts].MemberID)
	LEFT JOIN
		(
		SELECT 
			red.MemberID,
			red.MemberRedeemedID,
			red.DateCreated AS [RequestDate],
			-- PLEASE NOTE CHECKS ARE TRACKED IF THEY WERE 'ACTUALLY' SENT BY
			-- A DIFFERENT PROCESS IN IHIS; THIS DATE IS REALLY A PROCESS DATE
			red.SentDate,  
			red.RedeemedStatusID,
			stat.[Description] AS [RedeemedStatusName],
			red.RewardTypeID,
			typ.[Description] AS [RewardTypeName],
			red.Quantity,
			red.RedeemedAmount,
			red.AddDate AS [SourceAddDate]
		FROM
			(
			SELECT
				MemberID,
				IncentiveBeginDate,
				IncentiveEndDate
			FROM
				#Incentive
			GROUP BY 
				MemberID,
				IncentiveBeginDate,
				IncentiveEndDate
			) mem
		JOIN
			Healthyroads.dbo.IC_MemberRedeemed red
			ON	(mem.MemberID = red.MemberID)
			AND	(red.Deleted = 0)
		JOIN
			Healthyroads.dbo.IC_RedeemedStatus stat
			ON	(red.RedeemedStatusID = stat.RedeemedStatusID)
			AND	(stat.Deleted = 0)
		JOIN
			Healthyroads.dbo.IC_RewardType typ
			ON	(red.RewardTypeID = typ.RewardTypeID)
			AND	(typ.Deleted = 0)
		WHERE
			red.DateCreated >= mem.IncentiveBeginDate AND
			-- 30 DAYS AUTO REDEEM 'AFTER' PLAN ENDS PLUS 1 DAY 
			-- SINCE THE INCENTIVE END DATE IS FLOORED (WITHOUT TIME)
			-- PLUS 1 DAY TO ACCOUNT FOR THE NEXT DAY WHERE THE AUTO REDEMPTION WOULD TAKE PLACE
			-- TOTAL OF 32 DAYS
			red.DateCreated < DATEADD(dd,32,mem.IncentiveEndDate) 
		) red
		ON	(inc.MemberID = red.MemberID)
	WHERE
		(pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL)
	GROUP BY
		inc.GroupName,
		inc.EligMemberID,
		inc.EligMemberSuffix,
		inc.FirstName,
		inc.LastName,
		inc.EmployeeID,
		inc.Location,
		inc.CompanyCode,
		CASE 
			WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL
			THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(pha.CompletedDate,bio.CompletedDate),101) 
			ELSE ''
		END,
		ISNULL(CONVERT(VARCHAR(10),[125pts].CompletedDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),red.RequestDate,101),''),
		ISNULL(CAST((red.Quantity * red.RedeemedAmount) AS VARCHAR(25)),''),
		CASE
			WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND [125pts].CompletedDate IS NOT NULL
			THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME([125pts].CompletedDate,DA_Reports.dbo.func_MAX_DATETIME(pha.CompletedDate,bio.CompletedDate)),101)
			ELSE ''
		END
		
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

	IF OBJECT_ID('tempdb.dbo.#RunningPointsTotal') IS NOT NULL
	BEGIN
		DROP TABLE #RunningPointsTotal
	END

END
GO
