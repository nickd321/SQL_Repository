SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-12-17
-- Description:	Providence Incentives Data
--
-- Notes:		This stored procedure will be referenced in 
--				three other reports (HSA, HRA, HMO).
--
-- Updates:		WilliamPe 20131226
--				Added @inReportType parameter to select the base data report type
--				1 will mostly be used for the reports that are used for fulfillment.
--				2 will mostly be used for the reports used to monitor activity
--
--				WilliamPe 20131230
--				Added @inReportType 3 
--
--				WilliamPe 20140205
--				Added Logic to remove members where the primary and spouse do not have the same Benefit Coverage Tier to 
--				report @inReportType = 1
--
--				WilliamPe 20140206
--				Added logic to remove members where there is more than one currently eligible member under a family where 
--				the CS1 value is 'Tier3' (EE + Dependents) or 'Tier1' (EE Only)
--
--				WilliamPe 20140325
--				Modified the JOINS to DA_Production.prod.Eligibility
--				
-- =============================================

CREATE PROCEDURE [providence].[proc_Incentives_BaseData] 
	@inProduct VARCHAR(50) = NULL, --'All','HSA','HRA','PRE'
	@inReportType INT = NULL -- 1 = Shows Eligible Only Member Level Data w/ Subscriber Demographics and Incentive Activity
							 -- 2 = Shows Member Level Data w/ Member Demographics and Incentive Activity
							 -- 3 = Shows Member Level Data w/ Member Demographics Only
AS
BEGIN

	SET NOCOUNT ON;

	--DECLARE @inProduct VARCHAR(50), @inReportType INT
	-- SETS
	SET @inProduct = ISNULL(@inProduct,'All')
	SET @inReportType = ISNULL(@inReportType, 1)

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempdb.dbo.#PopulationEligible') IS NOT NULL
	BEGIN
		DROP TABLE #PopulationEligible
	END

	IF OBJECT_ID('tempdb.dbo.#PopulationAll') IS NOT NULL
	BEGIN
		DROP TABLE #PopulationAll
	END

	-- PLAN ACTIVITY TEMP
	SELECT
		pln.GroupID,
		pln.ClientIncentivePlanID,
		pln.PlanID,
		pln.PlanStart,
		pln.PlanEnd,
		act.PlanLevel,
		act.ActivityItemID,
		act.ParentActivityItemID,
		act.ActivityItemOperator,
		act.ActivityName,
		act.ActivityDescription,
		act.AI_Name,
		act.AI_Instruction,
		ISNULL(act.AI_Instruction,act.ActivityDescription) AS [Activity],
		act.AI_IsRequired,
		act.AI_IsActionItem
	INTO
		#PlanActivity
	FROM
		DA_Reports.incentives.[Plan] pln
	JOIN
		DA_Reports.incentives.PlanActivity act
		ON	(pln.ClientIncentivePlanID = act.ClientIncentivePlanID)
		AND	(act.Expired = 0)
	WHERE
		pln.Expired = 0 AND
		pln.GroupID = 173174 AND
		act.AI_IsActionItem = 1 AND
		pln.ClientIncentivePlanID IN (1044,1046,1048,1050)
		

	IF @inReportType = 1
	BEGIN
		-- POPULATION TEMP
		SELECT
			*
		INTO
			#PopulationEligible
		FROM
			(
			SELECT
				mem.MemberID,
				mem.RelationshipID,
				mem.EligMemberID,
				mem.EligMemberSuffix,
				mem.EligMemberID + '-' + mem.EligMemberSuffix AS [EligMemberID_Suffix],
				mem.FirstName,
				mem.MiddleInitial,
				mem.LastName,
				cs.CS1, --[BenefitCoverageTier]
				cs.CS3, --[IncentivePlan]
				cs.CS4, --[ProcessLevel]
				cs.CS6, --[Product] 
				cs.CS8, --[EmployeeID]
				cs.CS9, --[HireDate]
				cs.CS10, --[PlanCode]
				ISNULL(dbo.func_NullIfNaN(RIGHT(cs.CS1,1)),0) AS [CS1_INT],
				CASE
					WHEN
						ISNULL(DATEADD(dd,DATEDIFF(dd,0,elig.TerminationDate),0),'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) AND
						ISNULL(DATEADD(dd,DATEDIFF(dd,0,elig.TerminationDate),0),'2999-12-31') >= '2014-01-01'
					THEN 1 ELSE 0
				END AS [IsCurrentlyEligible],
				elig.EffectiveDate,
				elig.TerminationDate
			FROM
				DA_Production.prod.Member mem WITH (NOLOCK)
			JOIN
				DA_Production.prod.CSFields cs WITH (NOLOCK)
				ON	(mem.MemberID = cs.MemberID)
			JOIN
				(SELECT GroupID FROM #PlanActivity GROUP BY GroupID) grp
				ON	(mem.GroupID = grp.GroupID)
			LEFT JOIN
				(
				SELECT
					e.MemberID,
					e.EffectiveDate,
					e.TerminationDate,
					ROW_NUMBER() OVER (PARTITION BY e.MemberID ORDER BY ISNULL(e.TerminationDate,'2999-12-31') DESC) AS RevTermSeq
				FROM
					DA_Production.prod.Eligibility e WITH (NOLOCK)
				JOIN
					(SELECT GroupID FROM #PlanActivity GROUP BY GroupID) grp
					ON	(e.GroupID = grp.GroupID)
				) elig
				ON	(mem.MemberID = elig.MemberID)
				AND	(elig.RevTermSeq = 1)
			WHERE
				mem.RelationshipID IN (1,2,6) AND
				cs.CS3 IN ('1','2','3','4') AND
				(cs.CS6 IN ('HSA','HRA') OR (cs.CS6 = 'PRE' AND cs.CS10 IN ('MM91', 'MM92', 'MM93')) ) AND
				cs.CS10 NOT IN ('MS91','MR91') AND
				CASE WHEN ISDATE(cs.CS9) = 1 THEN CAST(cs.CS9 AS DATETIME) END < '2014-07-01'
			) data
		WHERE
			IsCurrentlyEligible = 1

		DELETE elig
		FROM
			#PopulationEligible elig
		JOIN
			(
			SELECT
				mem.EligMemberID
			FROM
				#PopulationEligible mem
			JOIN
				#PopulationEligible prm
				ON	(mem.EligMemberID = prm.EligMemberID)
				AND	(prm.RelationshipID = 6)
			JOIN
				#PopulationEligible sps
				ON	(prm.EligMemberID = sps.EligMemberID)
				AND	(sps.RelationshipID IN (1,2))
			WHERE
				prm.CS1_INT != sps.CS1_INT
			GROUP BY
				mem.EligMemberID
			) mis
			ON	(elig.EligMemberID = mis.EligMemberID)

		DELETE elig
		FROM
			#PopulationEligible elig
		JOIN
			(
			SELECT
				EligMemberID,
				COUNT(EligMemberiD) AS MemberCount
			FROM
				#PopulationEligible
			WHERE
				CS1_INT IN (1,3)
			GROUP BY
				EligMemberID
			HAVING
				COUNT(EligMemberID) > 1
			) dup
			ON	(elig.EligMemberID = dup.EligMemberID)

		SELECT
			*
		FROM
			(
			SELECT
				mem.MemberID,
				prmem.MemberID AS [SubscriberMemberID],
				mem.RelationshipID,
				mem.EligMemberID,
				mem.EligMemberSuffix,
				mem.EligMemberID_Suffix,
				prmem.FirstName AS [SubscriberFirstName],
				ISNULL(prmem.MiddleInitial,'') AS [SubscriberMiddleInitial],
				prmem.LastName AS [SubscriberLastName],
				prmem.CS1,
				prmem.CS3,
				prmem.CS4,
				prmem.CS6,
				prmem.CS8,
				prmem.CS9,
				prmem.CS10,
				prmem.CS1_INT,
				mem.IsCurrentlyEligible,
				mem.EffectiveDate,
				mem.TerminationDate,
				inc.ClientIncentivePlanID,
				inc.ActivityItemID,
				pa.Activity,
				CASE
					WHEN Activity LIKE '%Coaching%' THEN 'Coaching'
					WHEN Activity = 'TC:HDL Ratio <5:1' THEN 'Cholesterol'
					WHEN Activity = 'Total Cholesterol less than 240 mg/dl' THEN 'Cholesterol'
					WHEN Activity = 'BMI less than 30' THEN 'BMI'
					WHEN Activity = 'Biometrics Screening' THEN 'BIO'
					WHEN Activity = 'Statement of Treatment Form' THEN 'SoTF'
					WHEN Activity = 'No Tobacco Use' THEN 'Tobacco'
					WHEN Activity = 'Blood pressure less than 140/90 mmHg' THEN 'BP'
				END AS ConformedActivity,		
				inc.ActivityDate,
				inc.ActivityValue,
				inc.AddDate AS [ActivityCreditDate]
			FROM
				#PopulationEligible mem
			JOIN
				#PopulationEligible prmem
				ON	(mem.EligMemberID = prmem.EligMemberID)
				AND	(prmem.RelationshipID = 6)
			JOIN
				Healthyroads.dbo.IC_MemberActivityItem inc WITH (NOLOCK)
				ON	(mem.MemberID = inc.MemberID)
				AND	(inc.Deleted = 0)
			JOIN
				#PlanActivity pa
				ON	(inc.ActivityItemID = pa.ActivityItemID)
				AND	(inc.ClientIncentivePlanID = pa.ClientIncentivePlanID)
				AND	(inc.ActivityItemID NOT IN (5099,5100)) -- Systolic, Diastolic
			UNION
			-- SPOUSE ADDED MID YEAR POPULATION
			SELECT
				mem.MemberID,
				prmem.MemberID AS [SubscriberMemberID],
				mem.RelationshipID,
				mem.EligMemberID,
				mem.EligMemberSuffix,
				mem.EligMemberID_Suffix,
				prmem.FirstName AS [SubscriberFirstName],
				ISNULL(prmem.MiddleInitial,'') AS [SubscriberMiddleInitial],
				prmem.LastName AS [SubscriberLastName],
				prmem.CS1,
				CASE -- HAVE TO MANIPULATE THE CS3 EXPERIENCE TO A "NEW HIRE" PLAN
					WHEN prmem.CS3 = '1' THEN '3'
					WHEN prmem.CS3 = '2' THEN '4'
					ELSE prmem.CS3
				END AS CS3,
				prmem.CS4,
				prmem.CS6,
				prmem.CS8,
				prmem.CS9,
				prmem.CS10,
				prmem.CS1_INT,
				mem.IsCurrentlyEligible,
				mem.EffectiveDate,
				mem.TerminationDate,
				-1 AS ClientIncentivePlandID,
				-1 AS ActivityItemID,
				'Biometrics Screening' AS [Activity],
				'BIO' AS [ConformedActivity],
				scr.ScreeningDate AS [ActivityDate],
				-1 AS ActivityValue,
				scr.SourceAddDate AS [ActivityCreditDate]
			FROM
				#PopulationEligible mem
			JOIN
				#PopulationEligible prmem
				ON	(mem.EligMemberID = prmem.EligMemberID)
				AND	(prmem.RelationshipID = 6)
			JOIN
				DA_Reports.providence.Spouse_MidYearAdd_List mid
				ON	(mem.MemberID = mid.MemberID)
			JOIN
				DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
				ON	(mem.MemberID = scr.MemberID)
				AND	(scr.ScreeningDate >= '2013-01-01')
				AND	(scr.ScreeningDate < '2014-08-01')
			) data
		WHERE
			@inProduct = 'All' OR CS6 IN (SELECT * FROM [DA_Reports].[dbo].[SPLIT] (@inProduct,','))
	END

	IF @inReportType = 2
	BEGIN
		-- POPULATION TEMP
		SELECT
			mem.MemberID,
			mem.RelationshipID,
			mem.EligMemberID,
			mem.EligMemberSuffix,
			mem.EligMemberID + '-' + mem.EligMemberSuffix AS [EligMemberID_Suffix],
			mem.FirstName,
			mem.MiddleInitial,
			mem.LastName,
			cs.CS1, --[BenefitCoverageTier]
			cs.CS3, --[IncentivePlan]
			cs.CS4, --[ProcessLevel]
			cs.CS6, --[Product] 
			cs.CS8, --[EmployeeID]
			cs.CS9, --[HireDate]
			cs.CS10, --[PlanCode]
			ISNULL(dbo.func_NullIfNaN(RIGHT(cs.CS1,1)),0) AS [CS1_INT],
			CASE
				WHEN
					ISNULL(DATEADD(dd,DATEDIFF(dd,0,elig.TerminationDate),0),'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) AND
					ISNULL(DATEADD(dd,DATEDIFF(dd,0,elig.TerminationDate),0),'2999-12-31') >= '2014-01-01'
				THEN 1 ELSE 0
			END AS [IsCurrentlyEligible],
			elig.EffectiveDate,
			elig.TerminationDate
		INTO
			#PopulationAll
		FROM
			DA_Production.prod.Member mem WITH (NOLOCK)
		JOIN
			DA_Production.prod.CSFields cs WITH (NOLOCK)
			ON	(mem.MemberID = cs.MemberID)
		JOIN
			(SELECT GroupID FROM #PlanActivity GROUP BY GroupID) grp
			ON	(mem.GroupID = grp.GroupID)
		LEFT JOIN
			(
			SELECT
				e.MemberID,
				e.EffectiveDate,
				e.TerminationDate,
				ROW_NUMBER() OVER (PARTITION BY e.MemberID ORDER BY ISNULL(e.TerminationDate,'2999-12-31') DESC) AS RevTermSeq
			FROM
				DA_Production.prod.Eligibility e WITH (NOLOCK)
			JOIN
				(SELECT GroupID FROM #PlanActivity GROUP BY GroupID) grp
				ON	(e.GroupID = grp.GroupID)
			) elig
			ON	(mem.MemberID = elig.MemberID)
			AND	(elig.RevTermSeq = 1)
		WHERE
			mem.RelationshipID IN (1,2,6) AND
			cs.CS3 IN ('1','2','3','4') AND
			(cs.CS6 IN ('HSA','HRA') OR (cs.CS6 = 'PRE' AND cs.CS10 IN ('MM91', 'MM92', 'MM93')) ) AND
			cs.CS10 NOT IN ('MS91','MR91') AND
			CASE WHEN ISDATE(cs.CS9) = 1 THEN CAST(cs.CS9 AS DATETIME) END < '2014-07-01'

		SELECT
			*
		FROM
			(
			SELECT
				mem.MemberID,
				mem.RelationshipID,
				mem.EligMemberID,
				mem.EligMemberSuffix,
				mem.EligMemberID_Suffix,
				mem.FirstName,
				ISNULL(mem.MiddleInitial,'') AS [MiddleInitial],
				mem.LastName,
				mem.CS1,
				mem.CS3,
				mem.CS4,
				mem.CS6,
				mem.CS8,
				mem.CS9,
				mem.CS10,
				mem.CS1_INT,
				mem.IsCurrentlyEligible,
				mem.EffectiveDate,
				mem.TerminationDate,
				inc.ClientIncentivePlanID,
				inc.ActivityItemID,
				pa.Activity,
				CASE
					WHEN Activity LIKE '%Coaching%' THEN 'Coaching'
					WHEN Activity = 'TC:HDL Ratio <5:1' THEN 'Cholesterol'
					WHEN Activity = 'Total Cholesterol less than 240 mg/dl' THEN 'Cholesterol'
					WHEN Activity = 'BMI less than 30' THEN 'BMI'
					WHEN Activity = 'Biometrics Screening' THEN 'BIO'
					WHEN Activity = 'Statement of Treatment Form' THEN 'SoTF'
					WHEN Activity = 'No Tobacco Use' THEN 'Tobacco'
					WHEN Activity = 'Blood pressure less than 140/90 mmHg' THEN 'BP'
				END AS ConformedActivity,		
				inc.ActivityDate,
				inc.ActivityValue,
				inc.AddDate AS [ActivityCreditDate]
			FROM
				#PopulationAll mem
			JOIN
				Healthyroads.dbo.IC_MemberActivityItem inc
				ON	(mem.MemberID = inc.MemberID)
				AND	(inc.Deleted = 0)
			JOIN
				#PlanActivity pa
				ON	(inc.ActivityItemID = pa.ActivityItemID)
				AND	(inc.ClientIncentivePlanID = pa.ClientIncentivePlanID)
				AND	(inc.ActivityItemID NOT IN (5099,5100)) -- Systolic, Diastolic
			) data
		WHERE
			@inProduct = 'All' OR CS6 IN (SELECT * FROM [DA_Reports].[dbo].[SPLIT] (@inProduct,','))
	END

	IF @inReportType = 3
	BEGIN
		-- POPULATION TEMP
		SELECT
			*
		FROM
			(
			SELECT
				mem.MemberID,
				mem.RelationshipID,
				mem.EligMemberID,
				mem.EligMemberSuffix,
				mem.EligMemberID + '-' + mem.EligMemberSuffix AS [EligMemberID_Suffix],
				mem.FirstName,
				mem.MiddleInitial,
				mem.LastName,
				cs.CS1, --[BenefitCoverageTier]
				cs.CS3, --[IncentivePlan]
				cs.CS4, --[ProcessLevel]
				cs.CS6, --[Product] 
				cs.CS8, --[EmployeeID]
				cs.CS9, --[HireDate]
				cs.CS10, --[PlanCode]
				ISNULL(dbo.func_NullIfNaN(RIGHT(cs.CS1,1)),0) AS [CS1_INT],
				CASE
					WHEN
						ISNULL(DATEADD(dd,DATEDIFF(dd,0,elig.TerminationDate),0),'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) AND
						ISNULL(DATEADD(dd,DATEDIFF(dd,0,elig.TerminationDate),0),'2999-12-31') >= '2014-01-01'
					THEN 1 ELSE 0
				END AS [IsCurrentlyEligible],
				elig.EffectiveDate,
				elig.TerminationDate
			FROM
				DA_Production.prod.Member mem WITH (NOLOCK)
			JOIN
				DA_Production.prod.CSFields cs WITH (NOLOCK)
				ON	(mem.MemberID = cs.MemberID)
			JOIN
				(SELECT GroupID FROM #PlanActivity GROUP BY GroupID) grp
				ON	(mem.GroupID = grp.GroupID)
			LEFT JOIN
				(
				SELECT
					e.MemberID,
					e.EffectiveDate,
					e.TerminationDate,
					ROW_NUMBER() OVER (PARTITION BY e.MemberID ORDER BY ISNULL(e.TerminationDate,'2999-12-31') DESC) AS RevTermSeq
				FROM
					DA_Production.prod.Eligibility e WITH (NOLOCK)
				JOIN
					(SELECT GroupID FROM #PlanActivity GROUP BY GroupID) grp
					ON	(e.GroupID = grp.GroupID)
				) elig
				ON	(mem.MemberID = elig.MemberID)
				AND	(elig.RevTermSeq = 1)
			WHERE
				mem.RelationshipID IN (1,2,6) AND
				cs.CS3 IN ('1','2','3','4') AND
				(cs.CS6 IN ('HSA','HRA') OR (cs.CS6 = 'PRE' AND cs.CS10 IN ('MM91', 'MM92', 'MM93')) ) AND
				cs.CS10 NOT IN ('MS91','MR91') AND
				CASE WHEN ISDATE(cs.CS9) = 1 THEN CAST(cs.CS9 AS DATETIME) END < '2014-07-01'
			) data
		WHERE
			@inProduct = 'All' OR CS6 IN (SELECT * FROM [DA_Reports].[dbo].[SPLIT] (@inProduct,','))
	END

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempdb.dbo.#PopulationEligible') IS NOT NULL
	BEGIN
		DROP TABLE #PopulationEligible
	END

	IF OBJECT_ID('tempdb.dbo.#PopulationAll') IS NOT NULL
	BEGIN
		DROP TABLE #PopulationAll
	END


END
GO
