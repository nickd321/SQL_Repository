SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2014-04-28
-- Description:	Harland Clarke Incentive Family Report
--
-- Notes:		Please note that the current incentive plan (as of 2014-04-28) for 
--				Harland Clarke is a family level plan. There are certain rules that apply 
--				at the system level. For example, if at anytime there is an eligible spouse in the system
--				during the incentive plan period, the spouse is also expected to complete activity 
--				in order for the primary to show as a 100 percent complete. 
--				You will notice I created an IsCurrentlyEligible flag, but I am not filtering out any members
--				based on that flag. I simply have it in the code in the case that I need to reference it for research purposes.
--
--				Also, this incentive plan is CS driven.  So, I am also mimicking the incentive system by evaluating the member based on 
--				a specific CS value at the point in time the report is run.
--
--				For this family level report, I am definiing eligibility as being effective at any point in time during the incentive plan period.
--				The latter is a rule that is used by source system when its determing whether criteria has been met at the family level.
--
-- Updates:
--
--
--
-- =============================================

CREATE PROCEDURE [harlandclarke].[proc_Incentives_FamilySummary]

AS
BEGIN
	
	-- CLEAN UP
	
	IF OBJECT_ID('tempDb.dbo.#PlanHierarchy') IS NOT NULL
	BEGIN
		DROP TABLE #PlanHierarchy
	END
	
	IF OBJECT_ID('tempDb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempDb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END
	
	IF OBJECT_ID('tempDb.dbo.#Incentive') IS NOT NULL
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
		clnt.ClientIncentivePlanID IN (1113,1115,1117,1119)
	ORDER BY
		4,8,9

	-- GET PLAN INFORMATION
	SELECT
		DISTINCT -- THERE MAY BE A ONE TO MANY RELATIONSHIP TO THE ActivityItemValue TABLE (i.e. CompareValue column)
		pln.ClientIncentivePlanID,
		pln.PlanLevel,
		pln.ActivityItemID,
		--pln.ParentActivityItemID, -- MORE THAN ONE PARENTACTIVITYITEMID IN SOME CASES
		pln.ActivityItemOperator,
		pln.ActivityName,
		pln.ActivityDescription,
		pln.AI_Name,
		pln.AI_Instruction,
		pln.AI_Start,
		pln.AI_End,
		pln.AI_NumDaysToComplete,
		pln.AI_IsRequired,
		pln.AI_IsRequiredStep,
		pln.AI_IsActionItem,
		pln.AI_IsHidden,
		--aiv.ActivityValue AS [AIV_ActivityValue], -- MORE THAN ONE ActivityValue IN SOME CASES
		aiv.IsCount AS [AIV_IsCount],
		pln.AIC_ActivityValue,
		pln.AIC_CompareValue,
		aic.IsCount AS [AIC_IsCount],
		pln.AIL_MaxValue,
		pln.TimePeriodName,
		ail.IsCount AS [AIL_IsCount]
	INTO
		#PlanActivity
	FROM
		#PlanHierarchy pln
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemValue aiv WITH (NOLOCK)
		ON	(pln.ActivityItemID = aiv.ActivityItemID)
		AND	(aiv.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemComplete aic WITH (NOLOCK)
		ON	(pln.ActivityItemID = aic.ActivityItemID)
		AND	(aic.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemLimit ail WITH (NOLOCK)
		ON	(pln.ActivityItemID = ail.ActivityItemID)
		AND	(ail.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ClientIncentivePlanValidationRule cipvr WITH (NOLOCK)
		ON	(pln.ClientIncentivePlanID = cipvr.ClientIncentivePlanID)
		AND	(cipvr.Deleted = 0)
		
		
	SELECT
		mem.MemberID,
		REPLACE(grp.GroupName,',','') AS [GroupName],
		grp.GroupNumber,
		ISNULL(mem.EligMemberID,'') AS [EligMemberID],
		ISNULL(mem.EligMemberSuffix,'') AS [EligMemberSuffix],
		mem.FirstName,
		ISNULL(mem.MiddleInitial,'') AS [MiddleInitial],
		mem.LastName,
		mem.RelationshipID,
		mem.Relationship,
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS [Birthdate],
		ISNULL(addr.Address1,'') AS [Address1],
		ISNULL(addr.Address2,'') AS [Address2],
		ISNULL(addr.City,'') AS [City],
		ISNULL(addr.[State],'') AS [State],
		ISNULL(addr.ZipCode,'') AS [ZipCode],
		ISNULL(mem.HomePhone,'') AS [HomePhone],
		ISNULL(mem.WorkPhone,'') AS [WorkPhone],
		ISNULL(mem.CellPhone,'') AS [CellPhone],
		ISNULL(mem.AlternatePhone,'') AS [AlternatePhone],
		ISNULL(mem.EmailAddress,'') AS [Email],
		ISNULL(mem.SubscriberSSN,'') AS [SSN],
		ISNULL(cs.CS1,'') AS [CS1],
		ISNULL(cs.CS2,'') AS [CS2],
		ISNULL(cs.CS3,'') AS [CS3],
		ISNULL(cs.CS4,'') AS [CS4],
		ISNULL(cs.CS5,'') AS [CS5],
		ISNULL(cs.CS6,'') AS [CS6],
		ISNULL(cs.CS7,'') AS [CS7],
		ISNULL(cs.CS8,'') AS [CS8],
		ISNULL(cs.CS9,'') AS [CS9],
		ISNULL(cs.CS10,'') AS [CS10],
		ISNULL(cs.CS11,'') AS [CS11],
		ISNULL(cs.CS12,'') AS [CS12],
		ISNULL(mem.AltID1,'') AS [AltID1],
		ISNULL(mem.AltID2,'') AS [AltID2],
		CASE WHEN ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) THEN 1 ELSE 0 END AS [IsCurrentlyEligible],	
		elig.EffectiveDate,
		elig.TerminationDate,
		CASE
			WHEN CAST(cs.CS5 AS DATETIME) <= '2013-12-31' THEN 1113
			WHEN cs.CS5 IS NULL THEN 1115
			WHEN CAST(cs.CS5 AS DATETIME) >= '2014-01-01' AND CAST(cs.CS5 AS DATETIME) < '2014-04-01' THEN 1117
			WHEN CAST(cs.CS5 AS DATETIME) >= '2014-04-01' AND CAST(cs.CS5 AS DATETIME) < '2014-07-01' THEN 1119
		END AS [ClientIncentivePlanID]
	INTO
		#Base
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND (mem.GroupID = 198713)
	LEFT JOIN
		DA_Production.prod.[Address] addr WITH (NOLOCK)
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		(
		SELECT
			mem.MemberID,
			elig.EffectiveDate,
			elig.TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY mem.MemberID ORDER BY ISNULL(elig.TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.Member mem WITH (NOLOCK)
		JOIN
			DA_Production.prod.Eligibility elig WITH (NOLOCK)
			ON	(mem.MemberID = elig.MemberiD)
		WHERE
			mem.GroupID = 198713
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)
	WHERE
		cs.CS5 IS NULL OR CAST(cs.CS5 AS DATETIME) < '2014-07-01'
		
		
	SELECT 
		mem.MemberID,
		prmem.GroupName,
		prmem.GroupNumber,
		prmem.EligMemberID,
		prmem.EligMemberSuffix,
		prmem.FirstName,
		prmem.MiddleInitial,
		prmem.LastName,
		prmem.Birthdate,
		prmem.Address1,
		prmem.Address2,
		prmem.City,
		prmem.[State],
		prmem.ZipCode,
		prmem.HomePhone,
		prmem.WorkPhone,
		prmem.CellPhone,
		prmem.AlternatePhone,
		prmem.Email,
		prmem.SSN,
		prmem.CS1,
		prmem.CS2,
		prmem.CS3,
		prmem.CS4,
		prmem.CS5,
		sps.CS5 AS [SpouseCS5],
		prmem.CS6,
		prmem.CS7,
		prmem.CS8,
		prmem.CS9,
		prmem.CS10,
		prmem.CS11,
		prmem.CS12,
		prmem.AltID1,
		prmem.AltID2,
		CASE WHEN prmem.IsCurrentlyEligible = 1 THEN 1 ELSE 0 END AS [PrimaryCurrentlyEligible],
		prmem.EffectiveDate AS [PrimaryEffDate],
		prmem.TerminationDate AS [PrimaryTermDate],
		CASE WHEN sps.IsCurrentlyEligible = 1 THEN 1 ELSE 0 END AS [SpouseCurrentlyEligible],
		sps.EffectiveDate AS [SpouseEffDate],
		sps.TerminationDate AS [SpouseTermDate],
		CASE WHEN mem.RelationshipID IN (1,2) THEN 1 ELSE 0 END AS [IsSpouse],
		ISNULL(sps.FirstName,'') AS [SpouseFirstName],
		ISNULL(sps.LastName,'') AS [SpouseLastName],
		mai.ClientIncentivePlanID,
		mai.MemberActivityItemID,
		mai.ActivityItemID,
		pln.AIV_IsCount,
		pln.AIC_CompareValue,
		CASE
			WHEN pln.AIV_IsCount = 1 THEN 1
			ELSE 0
		END AS [IsActivity],
		CASE
			WHEN pln.AIV_IsCount = 0 THEN 1
			ELSE 0
		END AS [IsPoints],
		mai.ActivityValue,
		pln.AIL_MaxValue,
		CASE
			WHEN pln.AIV_IsCount = 1 THEN 0
			WHEN pln.AIC_CompareValue > 1 THEN 0
			ELSE mai.ActivityValue
		END AS [Points],
		COALESCE(pln.AI_Instruction,pln.ActivityDescription) AS [Activity],
		mai.ActivityDate,
		mai.AddDate AS [CreditDate]
	INTO
		#Incentive
	FROM
		#Base mem
	JOIN
		#Base prmem
		ON	(mem.EligMemberID = prmem.EligMemberID)
		AND	(prmem.RelationshipID = 6)
	LEFT JOIN
		#Base sps
		ON	(mem.EligMemberID = sps.EligMemberID)
		AND	(sps.RelationshipID IN (1,2))
		AND	(sps.EffectiveDate < '2014-10-01')
		AND	(ISNULL(sps.TerminationDate,'2999-12-31') >= '2013-10-01')
	JOIN
		Healthyroads.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
		ON	(mem.MemberID = mai.MemberID)
		AND	(mem.ClientIncentivePlanID = mai.ClientIncentivePlanID)
		AND	(mai.Deleted = 0)
	JOIN
		#PlanActivity pln
		ON	(mai.ClientIncentivePlanID = pln.ClientIncentivePlanID)
		AND	(mai.ActivityItemID = pln.ActivityItemID)
	WHERE
		mem.EffectiveDate < '2014-10-01' AND
		ISNULL(mem.TerminationDate,'2999-12-31') >= '2013-10-01'
	

	-- SUMMARY
	SELECT
		*,
		CASE
			WHEN 
				CAST(HireDate AS DATETIME) < '2014-01-01' AND 
				SpouseEffDate != '' AND
				PHA_EE IS NOT NULL AND 
				PHA_SP IS NOT NULL AND
				TotalPoints_EE >= 125 AND
				TotalPoints_SP >= 125 
			THEN 'Y'
			WHEN
				CAST(HireDate AS DATETIME) < '2014-01-01' AND 
				SpouseEffDate = '' AND
				PHA_EE IS NOT NULL AND
				TotalPoints_EE >= 125
			THEN 'Y'
			WHEN 
				(CAST(HireDate AS DATETIME) >= '2014-01-01' AND CAST(HireDate AS DATETIME) < '2014-04-01') AND
				SpouseEffDate != '' AND
				PHA_EE IS NOT NULL AND 
				PHA_SP IS NOT NULL AND
				TotalPoints_EE >= 50 AND
				TotalPoints_SP >= 50
			THEN 'Y'
			WHEN
				(CAST(HireDate AS DATETIME) >= '2014-01-01' AND CAST(HireDate AS DATETIME) < '2014-04-01') AND
				SpouseEffDate = '' AND
				PHA_EE IS NOT NULL AND
				TotalPoints_EE >= 50
			THEN 'Y'
			WHEN
				(CAST(HireDate AS DATETIME) >= '2014-04-01' AND CAST(HireDate AS DATETIME) < '2014-07-01') AND
				SpouseEffDate != '' AND
				PHA_EE IS NOT NULL AND 
				PHA_SP IS NOT NULL
			THEN 'Y'
			WHEN
				(CAST(HireDate AS DATETIME) >= '2014-04-01' AND CAST(HireDate AS DATETIME) < '2014-07-01') AND
				SpouseEffDate = '' AND
				PHA_EE IS NOT NULL
			THEN 'Y'
			ELSE ''
		END AS [FamilyCriteriaMet]
	FROM
		(
		SELECT
			inc.AltID1 AS [EmployeeID],
			inc.GroupName,
			inc.GroupNumber,
			inc.EligMemberID,
			inc.EligMemberSuffix,
			inc.FirstName,
			inc.MiddleInitial,
			inc.LastName,
			inc.Birthdate,
			inc.Address1,
			inc.Address2,
			inc.City,
			inc.[State],
			inc.ZipCode,
			inc.HomePhone,
			inc.WorkPhone,
			inc.Email,
			inc.CS1 AS [Location],
			inc.CS2 AS [Company],
			inc.CS3 AS [MedicalPlan],
			inc.CS4 AS [Coverage/Tier],
			inc.CS5 AS [HireDate],
			CASE WHEN inc.PrimaryCurrentlyEligible = 1 THEN 'Y' ELSE '' END AS [PrimaryCurrentlyEligible],
			ISNULL(CONVERT(VARCHAR(10),inc.PrimaryEffDate,101),'') AS [PrimaryEffDate],
			ISNULL(CONVERT(VARCHAR(10),inc.PrimaryTermDate,101),'') AS [PrimaryTermDate],
			CASE WHEN inc.SpouseCurrentlyEligible = 1 THEN 'Y' ELSE '' END AS [SpouseCurrentlyEligible],
			ISNULL(CONVERT(VARCHAR(10),inc.SpouseEffDate,101),'') AS [SpouseEffDate],
			ISNULL(CONVERT(VARCHAR(10),inc.SpouseTermDate,101),'') AS [SpouseTermDate],
			inc.SpouseFirstName,
			inc.SpouseLastName,
			CASE WHEN pha.PHA_EE IS NOT NULL THEN 'Y' ELSE '' END AS [PHA_EE],
			ISNULL(CAST(ptsEE.TotalPoints AS VARCHAR(4)),'') AS [TOTALPOINTS_EE],
			CASE WHEN pha.PHA_SP IS NOT NULL THEN 'Y' ELSE '' END AS [PHA_SP],
			ISNULL(CAST(ptsSP.TotalPoints AS VARCHAR(4)),'') AS [TOTALPOINTS_SP]
		FROM
			#Incentive inc
		JOIN
			(
			SELECT
				EligMemberID,
				SpouseCurrentlyEligible,
				[PHA_EE],
				[PHA_SP]
			FROM
				(
				SELECT 
					MemberID,
					EligMemberID,
					SpouseCurrentlyEligible,
					'PHA_EE' AS Activity
				FROM
					#Incentive
				WHERE
					Activity = 'Personal Health Assessment' AND
					IsSpouse = 0
			
				UNION ALL

				SELECT 
					MemberID,
					EligMemberID,
					SpouseCurrentlyEligible,
					'PHA_SP' AS Activity
				FROM
					#Incentive
				WHERE
					Activity = 'Personal Health Assessment' AND
					IsSpouse = 1					
				) act
				PIVOT
				(
				MAX(MemberID) FOR Activity IN ([PHA_EE],[PHA_SP])
				) pvt
			) pha
			ON	(inc.EligMemberID = pha.EligMemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				EligMemberID,
				IsSpouse,
				SUM(Points) AS TotalPoints
			FROM
				#Incentive
			WHERE
				IsSpouse = 0
			GROUP BY
				MemberID,
				EligMemberID,
				IsSpouse
			) ptsEE
			ON	(inc.EligMemberID = ptsEE.EligMemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				EligMemberID,
				IsSpouse,
				SUM(Points) AS TotalPoints
			FROM
				#Incentive
			WHERE
				IsSpouse = 1
			GROUP BY
				MemberID,
				EligMemberID,
				IsSpouse
			) ptsSP
			ON	(inc.EligMemberID = ptsSP.EligMemberID)	
		GROUP BY
			inc.AltID1,
			inc.GroupName,
			inc.GroupNumber,
			inc.EligMemberID,
			inc.EligMemberSuffix,
			inc.FirstName,
			inc.MiddleInitial,
			inc.LastName,
			inc.Birthdate,
			inc.Address1,
			inc.Address2,
			inc.City,
			inc.[State],
			inc.ZipCode,
			inc.HomePhone,
			inc.WorkPhone,
			inc.Email,
			inc.CS1,
			inc.CS2,
			inc.CS3,
			inc.CS4,
			inc.CS5,
			CASE WHEN inc.PrimaryCurrentlyEligible = 1 THEN 'Y' ELSE '' END,
			ISNULL(CONVERT(VARCHAR(10),inc.PrimaryEffDate,101),''),
			ISNULL(CONVERT(VARCHAR(10),inc.PrimaryTermDate,101),''),
			CASE WHEN inc.SpouseCurrentlyEligible = 1 THEN 'Y' ELSE '' END,
			ISNULL(CONVERT(VARCHAR(10),inc.SpouseEffDate,101),''),
			ISNULL(CONVERT(VARCHAR(10),inc.SpouseTermDate,101),''),
			inc.SpouseFirstName,
			inc.SpouseLastName,
			CASE WHEN pha.PHA_EE IS NOT NULL THEN 'Y' ELSE '' END,
			ISNULL(CAST(ptsEE.TotalPoints AS VARCHAR(4)),''),
			CASE WHEN pha.PHA_SP IS NOT NULL THEN 'Y' ELSE '' END,
			ISNULL(CAST(ptsSP.TotalPoints AS VARCHAR(4)),'')
		) data
		
		
	-- CLEAN UP
	IF OBJECT_ID('tempDb.dbo.#PlanHierarchy') IS NOT NULL
	BEGIN
		DROP TABLE #PlanHierarchy
	END
	
	IF OBJECT_ID('tempDb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempDb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END
	
	IF OBJECT_ID('tempDb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

END
GO
