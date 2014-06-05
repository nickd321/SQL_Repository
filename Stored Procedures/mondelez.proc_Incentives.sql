SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-02-24
-- Description:	Mondelez Incentives Report
--
-- Update Eric H 06022014: Added Alt ID 1 to 
-- report per WO 3930
-- =============================================

CREATE PROCEDURE [mondelez].[proc_Incentives]

AS
BEGIN
	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
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
		aic.ActivityValue AS [AIC_ActivityValue],
		aic.CompareValue AS [AIC_CompareValue],
		aic.CompareOperator AS [AIC_CompareOperator],
		lim.MaxValue AS [AIL_MaxValue],
		lim.TimePeriodID AS [AIL_TimePeriod],
		per.Name AS [TimePeriodName],
		bio.Pregnant AS [AIB_Pregnant],
		bio.Smoking AS [AIB_Smoking],
		bio.Fasting AS [AIB_Fasting],
		bio.ExamTypeCode AS [AIB_ExamTypeCode]
	INTO
		#PlanActivity
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
		clnt.ClientIncentivePlanID IN (1264,1266,1268)
	ORDER BY
		4,8,9

	SELECT
		mem.MemberID,
		grp.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS [Birthdate],
		mem.altid1,
		cs.CS1 AS [Location],
		cs.CS2 AS [EmployeeGroup],
		cs.CS3 AS [EmployeeSubGroup],
		cs.CS4 AS [MedicalIndicator],
		cs.CS5 AS [FunctionCode],
		mai.MemberActivityItemID,
		mai.ActivityItemID,
		COALESCE(act.AI_Instruction,act.ActivityDescription,chld.ActivityDescription) AS [Activity],
		mai.ActivityValue AS [Points],
		CONVERT(VARCHAR(10),mai.ActivityDate,101) AS [ActivityDate],
		CONVERT(VARCHAR(10),mai.AddDate,101) AS [CreditDate]
	INTO
		#Incentive
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 204296)
	JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		Healthyroads.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
		ON	(mem.MemberID = mai.MemberID)
		AND	(mai.Deleted = 0)
	JOIN
		#PlanActivity act
		ON	(mai.ClientIncentivePlanID = act.ClientIncentivePlanID)
		AND	(mai.ActivityItemID = act.ActivityItemID)
	LEFT JOIN
		#PlanActivity chld
		ON	(act.ActivityItemID = chld.ParentActivityItemID)
	WHERE
		mem.RelationshipID = 6 AND
		cs.CS4 IN ('AETNA','KAISER','WAIVED') AND
		mai.ActivityValue > 1
	GROUP BY
		mem.MemberID,
		grp.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		mem.AltID1,
		CONVERT(VARCHAR(10),mem.Birthdate,101),
		cs.CS1,
		cs.CS2,
		cs.CS3,
		cs.CS4,
		cs.CS5,
		mai.MemberActivityItemID,
		mai.ActivityItemID,
		COALESCE(act.AI_Instruction,act.ActivityDescription,chld.ActivityDescription),
		mai.ActivityValue,
		CONVERT(VARCHAR(10),mai.ActivityDate,101),
		CONVERT(VARCHAR(10),mai.AddDate,101) 


	SELECT
		GroupName,
		EligMemberID,
		EligMemberSuffix,
		FirstName,
		LastName,
		AltID1 as 'Employee ID', 
		Birthdate,
		Location,
		EmployeeGroup,
		EmployeeSubGroup,
		MedicalIndicator,
		FunctionCode,
		Activity,
		Points,
		ActivityDate,
		CreditDate
	FROM
		#Incentive
	WHERE
		MedicalIndicator = 'AETNA'
	ORDER BY
		EligMemberID,
		Activity,
		ActivityDate

	SELECT
		GroupName,
		EligMemberID,
		EligMemberSuffix,
		FirstName,
		LastName,
		AltID1 as 'Employee ID',
		Birthdate,
		Location,
		EmployeeGroup,
		EmployeeSubGroup,
		MedicalIndicator,
		FunctionCode,
		Activity,
		Points,
		ActivityDate,
		CreditDate
	FROM
		#Incentive
	WHERE
		MedicalIndicator = 'KAISER'
	ORDER BY
		EligMemberID,
		Activity,
		ActivityDate

	SELECT
		GroupName,
		EligMemberID,
		EligMemberSuffix,
		FirstName,
		LastName,
		AltID1 as 'Employee ID',
		Birthdate,
		Location,
		EmployeeGroup,
		EmployeeSubGroup,
		MedicalIndicator,
		FunctionCode,
		Activity,
		Points,
		ActivityDate,
		CreditDate
	FROM
		#Incentive
	WHERE
		MedicalIndicator = 'WAIVED'
	ORDER BY
		EligMemberID,
		Activity,
		ActivityDate


	IF OBJECT_ID('tempdb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

END
GO
