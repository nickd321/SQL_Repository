SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-03-06
-- Description:	RaceTrac Incentives Report
--
-- Notes: 
--
--
--
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [racetrac].[proc_Incentives]

AS
BEGIN
	
	SET NOCOUNT ON;
 
	IF OBJECT_ID('tempdb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END
	
	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END
	
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END
	
	-- Plan Activity Temp
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
		clnt.ClientIncentivePlanID IN (1222,1224)
	ORDER BY
		4,8,9
		
	-- Base Temp	
	SELECT
		mem.MemberID,
		grp.GroupName,
		mem.AltID1 AS [EE_ID],
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		mem.RelationshipID,
		mem.Relationship,
		CASE WHEN mem.RelationshipID = 1 THEN 1 ELSE 0 END AS [IsSpouse],
		cs.CS3 AS [JobCode],
		cs.CS2 AS [Area],
		cs.CS4 AS [Department],
		cs.CS1 AS [Plan],
		elig.EffectiveDate,
		elig.TerminationDate,
		CASE WHEN ISNULL(TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) THEN 1 ELSE 0 END AS [IsCurrentlyEligible]
	INTO
		#Base
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 203016)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		(
		SELECT
			MemberID,
			EffectiveDate,
			TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.Eligibility WITH (NOLOCK)
		WHERE
			GroupID = 203016
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)
	WHERE
		mem.RelationshipID IN (6,1)
	
	-- Activity Temp
	SELECT
		mem.MemberID,
		mem.EligMemberID,
		CASE WHEN mem.RelationshipID = 1 THEN 1 ELSE 0 END AS [IsSpouse],
		act.ClientIncentivePlanID,
		act.MemberActivityItemID,
		act.ActivityItemID,
		COALESCE(pln.AI_Instruction,pln.ActivityDescription,CASE WHEN chld.ActivityDescription LIKE 'Phone%' THEN chld.ActivityDescription + ' - ' + CAST(chld.AIC_CompareValue  AS VARCHAR) + ' calls' END) AS [Activity],
		act.ActivityDate,
		act.AddDate AS [CreditDate],
		CASE WHEN act.ActivityValue = 1 THEN 0 ELSE act.ActivityValue END AS [ActivityValue]
	INTO
		#Incentive
	FROM
		#Base mem
	JOIN
		Healthyroads.dbo.IC_MemberActivityItem act WITH (NOLOCK)
		ON	(mem.MemberID = act.MemberID)
		AND	(act.Deleted = 0)
	JOIN
		#PlanActivity pln
		ON	(act.ActivityItemID = pln.ActivityItemID)
		AND	(act.ClientIncentivePlanID = pln.ClientIncentivePlanID)
	LEFT JOIN
		#PlanActivity chld
		ON (pln.ActivityItemID = chld.ParentActivityItemID)
	GROUP BY
		mem.MemberID,
		mem.EligMemberID,
		CASE WHEN mem.RelationshipID = 1 THEN 1 ELSE 0 END,
		act.ClientIncentivePlanID,
		act.MemberActivityItemID,
		act.ActivityItemID,
		COALESCE(pln.AI_Instruction,pln.ActivityDescription,CASE WHEN chld.ActivityDescription LIKE 'Phone%' THEN chld.ActivityDescription + ' - ' + CAST(chld.AIC_CompareValue AS VARCHAR) + ' calls' END),
		act.ActivityDate,
		act.AddDate,
		CASE WHEN act.ActivityValue = 1 THEN 0 ELSE act.ActivityValue END
	
	
	-- SUMMARY
	SELECT
		b.GroupName,
		prm.LastName AS [EE_LastName],
		prm.FirstName AS [EE_FirstName],
		prm.JobCode AS [EE_JobCode],
		prm.Area AS [EE_Area],
		prm.Department AS [EE_Department],
		prm.[Plan] AS [EE_Plan],
		CONVERT(VARCHAR(10),prm.EffectiveDate,101) AS [EE_EffectiveDate],
		ISNULL(CONVERT(VARCHAR(10),prm.TerminationDate,101),'') AS [EE_TerminationDate],
		prm.EE_ID AS [EE_ID],
		ISNULL(sps.LastName,'') AS [SP_LastName],
		ISNULL(sps.FirstName,'') AS [SP_FirstName],
		ISNULL(CONVERT(VARCHAR(10),sps.EffectiveDate,101),'') AS [SP_EffectiveDate],
		ISNULL(CONVERT(VARCHAR(10),sps.TerminationDate,101),'') AS [SP_TerminationDate],
		CASE WHEN sps.MemberID IS NOT NULL THEN 1 ELSE 0 END AS [HasSpouse],
		ISNULL(CONVERT(VARCHAR(10),actdt.EE_PHA,101),'') AS [EE_PHA],
		ISNULL(CONVERT(VARCHAR(10),actdt.EE_Bio,101),'') AS [EE_Bio],
		CASE WHEN actdt.EE_PHA IS NOT NULL AND actdt.EE_Bio IS NOT NULL THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(actdt.EE_PHA,actdt.EE_Bio),101) ELSE '' END AS [EE_PHABio],
		ISNULL(CONVERT(VARCHAR(10),actdt.SP_PHA,101),'') AS [SP_PHA],
		ISNULL(CONVERT(VARCHAR(10),actdt.SP_Bio,101),'') AS [SP_Bio],
		CASE WHEN actdt.SP_PHA IS NOT NULL AND actdt.SP_Bio IS NOT NULL THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(actdt.SP_PHA,actdt.SP_Bio),101) ELSE '' END AS [SP_PHABio],
		CASE WHEN actdt.EE_Tobacco IS NOT NULL THEN 'Y' ELSE '' END AS [EE_Tobacco],
		CASE WHEN actdt.SP_Tobacco IS NOT NULL THEN 'Y' ELSE '' END AS [SP_Tobacco],
		ISNULL(actpts.EE_Coaching,0) AS [EE_Coaching],
		ISNULL(actpts.SP_Coaching,0) AS [SP_Coaching],
		ISNULL(actpts.EE_TotalPoints,0) AS [EE_TotalPoints],
		ISNULL(actpts.SP_TotalPoints,0) AS [SP_TotalPoints]
	FROM
		#Base b
	JOIN
		#Base prm
		ON	(b.EligMemberID = prm.EligMemberID)
		AND	(prm.IsSpouse = 0)
	LEFT JOIN
		#Base sps
		ON	(b.EligMemberID = sps.EligMemberID)
		AND	(sps.IsSpouse = 1)
	JOIN
		(
		SELECT
			EligMemberID
		FROM
			#Incentive
		GROUP BY
			EligMemberID
		) inc
		ON	(b.EligMemberID = inc.EligMemberID)
	LEFT JOIN
		(
		SELECT
			EligMemberID,
			[EE_PHA],
			[EE_Bio],
			[EE_Tobacco],
			[SP_PHA],
			[SP_Bio],
			[SP_Tobacco]
		FROM
			(
			SELECT
				EligMemberID,
				'EE_PHA' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				IsSpouse = 0 AND
				Activity = 'Personal Health Assessment'
			UNION
			SELECT
				EligMemberID,
				'EE_Bio' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				IsSpouse = 0 AND
				Activity = 'Biometrics Screening'
			UNION
			SELECT
				EligMemberID,
				'EE_Tobacco' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				IsSpouse = 0 AND
				Activity = 'Tobacco Free Attestation'
			UNION
			SELECT
				EligMemberID,
				'SP_PHA' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				IsSpouse = 1 AND
				Activity = 'Personal Health Assessment'
			UNION
			SELECT
				EligMemberID,
				'SP_Bio' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				IsSpouse = 1 AND
				Activity = 'Biometrics Screening'
			UNION
			SELECT
				EligMemberID,
				'SP_Tobacco' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				IsSpouse = 1 AND
				Activity = 'Tobacco Free Attestation'
			) data
			PIVOT
			(
			MIN(ActivityDate) FOR Activity IN ([EE_PHA],[EE_Bio],[EE_Tobacco],[SP_PHA],[SP_Bio],[SP_Tobacco])
			) pvt
		) actdt
		ON	(b.EligMemberID = actdt.EligMemberID)
	LEFT JOIN
		(
		SELECT
			EligMemberID,
			[EE_Coaching],
			[EE_TotalPoints],
			[SP_Coaching],
			[SP_TotalPoints]
		FROM
			(
			SELECT
				EligMemberID,
				'EE_Coaching' AS Activity,
				ActivityValue
			FROM
				#Incentive 
			WHERE
				IsSpouse = 0 AND
				Activity = 'Phone-Based Coaching Sessions (10/01/2013 - 09/30/2014)'
			UNION
			SELECT
				EligMemberID,
				'EE_TotalPoints' AS Activity,
				SUM(ActivityValue) AS ActivityValue
			FROM
				#Incentive
			WHERE
				IsSpouse = 0
			GROUP BY
				EligMemberID
			UNION
			SELECT
				EligMemberID,
				'SP_Coaching' AS Activity,
				ActivityValue
			FROM
				#Incentive
			WHERE
				IsSpouse = 1 AND
				Activity = 'Phone-Based Coaching Session - 4 calls'
			UNION
			SELECT
				EligMemberID,
				'SP_TotalPoints' AS Activity,
				SUM(ActivityValue) AS ActivityValue
			FROM
				#Incentive
			WHERE
				IsSpouse = 1
			GROUP BY
				EligMemberID
			) data
			PIVOT
			(
			MAX(ActivityValue) FOR Activity IN ([EE_Coaching],[EE_TotalPoints],[SP_Coaching],[SP_TotalPoints])
			) pvt
		) actpts
		ON	(b.EligMemberID = actpts.EligMemberID)
	GROUP BY
		b.GroupName,
		prm.LastName,
		prm.FirstName,
		prm.JobCode,
		prm.Area,
		prm.Department,
		prm.[Plan],
		CONVERT(VARCHAR(10),prm.EffectiveDate,101),
		ISNULL(CONVERT(VARCHAR(10),prm.TerminationDate,101),''),
		prm.EE_ID,
		ISNULL(sps.LastName,''),
		ISNULL(sps.FirstName,''),
		ISNULL(CONVERT(VARCHAR(10),sps.EffectiveDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),sps.TerminationDate,101),''),
		CASE WHEN sps.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		ISNULL(CONVERT(VARCHAR(10),actdt.EE_PHA,101),''),
		ISNULL(CONVERT(VARCHAR(10),actdt.EE_Bio,101),''),
		CASE WHEN actdt.EE_PHA IS NOT NULL AND actdt.EE_Bio IS NOT NULL THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(actdt.EE_PHA,actdt.EE_Bio),101) ELSE '' END,
		ISNULL(CONVERT(VARCHAR(10),actdt.SP_PHA,101),''),
		ISNULL(CONVERT(VARCHAR(10),actdt.SP_Bio,101),''),
		CASE WHEN actdt.SP_PHA IS NOT NULL AND actdt.SP_Bio IS NOT NULL THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(actdt.SP_PHA,actdt.SP_Bio),101) ELSE '' END,
		CASE WHEN actdt.EE_Tobacco IS NOT NULL THEN 'Y' ELSE '' END,
		CASE WHEN actdt.SP_Tobacco IS NOT NULL THEN 'Y' ELSE '' END,
		ISNULL(actpts.EE_Coaching,0),
		ISNULL(actpts.SP_Coaching,0),
		ISNULL(actpts.EE_TotalPoints,0),
		ISNULL(actpts.SP_TotalPoints,0)
	ORDER BY
		prm.EE_ID

	
	-- DETAIL	
	SELECT
		mem.GroupName,
		mem.LastName,
		mem.FirstName,
		mem.JobCode AS [EE_JobCode],
		mem.Area AS [EE_Area],
		mem.Department AS [EE_Department],
		mem.[Plan] AS [EE_Plan],
		ISNULL(CONVERT(VARCHAR(10),mem.EffectiveDate,101),'') AS EffectiveDate,
		ISNULL(CONVERT(VARCHAR(10),mem.TerminationDate,101),'') AS TerminationDate,
		mem.EE_ID,
		mem.EligMemberSuffix,
		mem.Relationship,
		ISNULL(CONVERT(VARCHAR(10),act.PHA,101),'') AS [PHA],
		ISNULL(CONVERT(VARCHAR(10),act.Bio,101),'') AS [Bio],
		CASE WHEN act.PHA IS NOT NULL AND act.Bio IS NOT NULL THEN CONVERT(VARCHAR(10),DA_Reports.dbo.func_MAX_DATETIME(act.PHA,act.Bio),101) ELSE '' END AS [PHABio],
		CASE WHEN act.Tobacco IS NOT NULL THEN 'Y' ELSE '' END AS [Tobacco],
		ISNULL(cch.SessionCount,0) AS [CoachingSessions],
		CASE WHEN act.OnlineCourse IS NOT NULL THEN 'Y' ELSE '' END AS [OnlineCourse],
		CASE WHEN act.HRDSChallenge IS NOT NULL THEN 'Y' ELSE '' END AS [HRDSChallenge],
		CASE WHEN act.CignaProgram IS NOT NULL THEN 'Y' ELSE '' END AS [CignaProgram],
		CASE WHEN act.RaceTracChallengeOrWellness IS NOT NULL THEN 'Y' ELSE '' END AS [RaceTracChallengeOrWellness],
		CASE WHEN act.RaceTracRunWalk IS NOT NULL THEN 'Y' ELSE '' END AS [RaceTracRunWalk],
		CASE WHEN act.RaceTracWeightWatchers IS NOT NULL THEN 'Y' ELSE '' END AS [RaceTracWeightWatchers]
	FROM
		#Base mem
	JOIN
		(
		SELECT
			EligMemberID
		FROM
			#Incentive
		GROUP BY
			EligMemberID
		) inc
		ON	(mem.EligMemberID = inc.EligMemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			COUNT(MemberActivityItemID) AS 'SessionCount'
		FROM
			#Incentive
		WHERE
			Activity = 'Phone-Based Coaching Session' AND
			ActivityValue = 0
		GROUP BY
			MemberID
		) cch
		ON	(mem.MemberID = cch.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			[PHA],
			[Bio],
			[Tobacco],
			[OnlineCourse],
			[HRDSChallenge],
			[CignaProgram],
			[RaceTracChallengeOrWellness],
			[RaceTracRunWalk],
			[RaceTracWeightWatchers]
		FROM
			(
			SELECT
				MemberID,
				'PHA' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				Activity = 'Personal Health Assessment'
			UNION
			SELECT
				MemberID,
				'Bio' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				Activity = 'Biometrics Screening'
			UNION
			SELECT
				MemberID,
				'Tobacco' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				Activity = 'Tobacco Free Attestation'
			UNION
			-- ANY COMBINATION OF THE FOLLOWING ACTIVITIES CAN 
			-- BE COMPLETED FOR A MAX OF 75 POINTS (25 POINTS PER ACTIVITY)
			-- FROM THE REQUEST, IT APPEARS THEY JUST WANT TO KNOW IF THEY
			-- COMPLETED ANY PARTICULAR ITEM AND DO NOT CARE ABOUT A COUNT
			SELECT
				MemberID,
				'OnlineCourse' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				Activity = 'Online e-Coaching Courses'
			UNION
			SELECT
				MemberID,
				'HRDSChallenge' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				Activity = 'Healthyroads Challenge'
			UNION
			SELECT
				MemberID,
				'CignaProgram' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				Activity = 'Cigna Healthy Pregnancy Program'
			UNION
			SELECT
				MemberID,
				'RaceTracChallengeOrWellness',
				ActivityDate
			FROM
				#Incentive
			WHERE
				Activity = 'RaceTrac Sponsored Challenge or Wellness Program'
			UNION
			SELECT
				MemberID,
				'RaceTracRunWalk' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				Activity = 'RaceTrac Approved run/walk'
			UNION
			SELECT
				MemberID,
				'RaceTracWeightWatchers' AS Activity,
				ActivityDate
			FROM
				#Incentive
			WHERE
				Activity = 'RaceTrac Sponsored Weight Watchers'
			)data
			PIVOT
			(
			MIN(ActivityDate) FOR Activity IN (
												[PHA],
												[Bio],
												[Tobacco],
												[OnlineCourse],
												[HRDSChallenge],
												[CignaProgram],
												[RaceTracChallengeOrWellness],
												[RaceTracRunWalk],
												[RaceTracWeightWatchers]
											  )
			) pvt
		) act
		ON	(mem.MemberID = act.MemberID)
	ORDER BY
		mem.EE_ID,
		mem.Relationship
	
	
	IF OBJECT_ID('tempdb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END
	
	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END
	
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END
		
END
GO
