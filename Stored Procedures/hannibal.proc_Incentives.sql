SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-02-17
-- Description:	Hannibal Incentives Report
--
-- Notes:		Includes current and new hire population
--
-- =============================================

CREATE PROCEDURE [hannibal].[proc_Incentives] 
	
AS
BEGIN

	SET NOCOUNT ON;

	-- CLEAN UP 
	IF OBJECT_ID('tempDb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempDb.dbo.#IncentiveActivity') IS NOT NULL
	BEGIN
		DROP TABLE #IncentiveActivity
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
		clnt.ClientIncentivePlanID = 1111
	ORDER BY
		8,9

	SELECT
		mem.MemberID,
		grp.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS [Birthdate],
		ISNULL(addr.Address1,'') AS [Address1],
		ISNULL(addr.Address2,'') AS [Address2],
		ISNULL(addr.City,'') AS [City],
		ISNULL(addr.[State],'') AS [State],
		ISNULL(addr.ZipCode,'') AS [ZipCode],
		ISNULL(mem.AltID1,'') AS [EmployeeID],
		ISNULL(cs.CS1,'') AS [NewHireIndicator],
		ISNULL(cs.CS2,'') AS [HireDate],
		ISNULL(cs.CS3,'') AS [BenefitDate],
		ISNULL(cs.CS4,'') AS [HealthInsurance],
		ISNULL(cs.CS5,'') AS [Title],
		ISNULL(cs.CS6,'') AS [Status],
		ISNULL(cs.CS7,'') AS [ScheduledHours],
		mai.MemberActivityItemID,
		ISNULL(pa.AI_Instruction,pa.ActivityDescription) AS [Activity],
		mai.ActivityValue,
		mai.ActivityDate,
		mai.AddDate AS [CreditDate],
		mai.ReferenceID,
		mai.ActivityItemID,
		mai.IsWaiver,
		ROW_NUMBER() OVER (PARTITION BY mem.MemberID, ISNULL(pa.AI_Instruction,pa.ActivityDescription) ORDER BY mai.ActivityDate, mai.AddDate) AS [ActivitySeq]
	INTO
		#IncentiveActivity
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 192766)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	LEFT JOIN
		DA_Production.prod.[Address] addr WITH (NOLOCK)
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)
	JOIN
		Healthyroads.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
		ON	(mem.MemberID = mai.MemberID)
		AND (mai.Deleted = 0)
	JOIN
		#PlanActivity pa
		ON	(mai.ActivityItemID = pa.ActivityItemID)
		AND	(mai.ClientIncentivePlanID = pa.ClientIncentivePlanID)
		AND	(pa.AI_IsActionItem = 1)
	

	SELECT
		inc.GroupName,
		inc.FirstName,
		inc.LastName,
		inc.Birthdate,
		inc.Address1,
		inc.Address2,
		inc.City,
		inc.[State],
		inc.ZipCode,
		inc.EmployeeID,
		inc.NewHireIndicator,
		inc.HireDate,
		inc.BenefitDate,
		inc.HealthInsurance,
		inc.Title,
		inc.[Status],
		inc.ScheduledHours,
		CONVERT(VARCHAR(10),pha.ActivityDate,101) AS [PHACompletionDate],
		CONVERT(VARCHAR(10),bio.ActivityDate,101) AS [BiometricScreeningCompletionDate],
		CASE WHEN outc.MemberID IS NOT NULL OR alt.MemberID IS NOT NULL THEN 'Y' ELSE '' END AS [Outcomes_OR_Activities]
	FROM
		#IncentiveActivity inc
	JOIN
		#IncentiveActivity pha
		ON	(inc.MemberID = pha.MemberID)
		AND	(pha.Activity = 'Personal Health Assessment (Primary)')
		AND	(pha.ActivitySeq = 1)
	JOIN
		#IncentiveActivity bio
		ON	(inc.MemberID = bio.MemberID)
		AND	(bio.Activity = 'Biometrics Screening')
		AND	(bio.ActivitySeq = 1)
	-- OUTCOMES
	LEFT JOIN
		(
		SELECT
			MemberID,
			Activity,
			ActivityDate,
			CreditDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ActivityDate) AS OutcomesSeq
		FROM
			#IncentiveActivity
		WHERE
			ActivitySeq = 1 AND
			Activity IN (
						'<= 35 inches in Time 1 or Time 2.|Waist <= 35 inches.',
						'<= 40 inches in Time 1 or Time 2.|Waist <= 40 inches.',
						'>= 1 inch Reduction Improvement<br/>from Time 1 to Time 2.|Waist >= 1 inch Reduction Improvement from Time 1 to Time 2.',
						'<= 120/80 mmHg in Time 1 or Time 2.|Blood Pressure <= 120/80 mmHg.',
						'Improvement from 121/81 - 139/89 to <= 120/80 from Time 1 from Time 2.|Blood Pressure Improvement from 121/81 - 139/89 to <= 120/80.',
						'Improvement from >= 140/90 to 121/81 - 139/89 from Time 1 to Time 2.|Blood Pressure Improvement from >= 140/90 to 121/81 - 139/89',
						'>= 40 mg/dL in Time 1 or Time 2.|HDL >= 40 mg/dL.',
						'Minimum 5 mg/dL Increase Improvement <br/>from Time 1 to Time 2.|HDL Minimum 5 mg/dL Increase Improvement from Time 1 to Time 2.',
						'70-99 mg/dL in Time 1 or Time 2.|Glucose 70-99 mg/dL.',
						'Improvement from >=126 to 100-125 or<br/>from 100-125 to 70-99 in Time 1 to Time 2.|Glucose Improvement from >=126 to 100-125 or<br/>from 100-125 to 70-99 in Time 1 to Time 2.'
						)
		) outc
		ON	(inc.MemberID = outc.MemberID)
		AND	(outc.OutcomesSeq = 3)
	LEFT JOIN
		(
		SELECT
			MemberID,
			Activity,
			ActivityDate,
			CreditDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ActivityDate) AS AlternativesSeq
		FROM
			#IncentiveActivity
		WHERE
			ActivitySeq = 1 AND
			Activity IN (
						'Complete 4 telephonic coaching sessions with a Healthyroads health coach',
						'Complete 6 Visits with the Accountable Care Nurse',
						'Complete 750,000 steps. Manually added and re-classified steps do not qualify.',
						'Complete the Team Health Weight Loss Challenge (In it to Win It) OR 10 sessions of a 12 week course in HRHS Weight Watchers Program'
						)
		) alt
		ON	(inc.MemberID = alt.MemberID)
		AND	(alt.AlternativesSeq = 2)
	WHERE
		outc.MemberID IS NOT NULL OR
		alt.MemberID IS NOT NULL
	GROUP BY
		inc.GroupName,
		inc.FirstName,
		inc.LastName,
		inc.Birthdate,
		inc.Address1,
		inc.Address2,
		inc.City,
		inc.[State],
		inc.ZipCode,
		inc.EmployeeID,
		inc.NewHireIndicator,
		inc.HireDate,
		inc.BenefitDate,
		inc.HealthInsurance,
		inc.Title,
		inc.[Status],
		inc.ScheduledHours,
		CONVERT(VARCHAR(10),pha.ActivityDate,101),
		CONVERT(VARCHAR(10),bio.ActivityDate,101),
		CASE WHEN outc.MemberID IS NOT NULL OR alt.MemberID IS NOT NULL THEN 'Y' ELSE '' END


	-- CLEAN UP 
	IF OBJECT_ID('tempDb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempDb.dbo.#IncentiveActivity') IS NOT NULL
	BEGIN
		DROP TABLE #IncentiveActivity
	END

END
GO
