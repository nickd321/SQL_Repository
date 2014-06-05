SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-03-25
-- Description:	Trizetto Incentives Report
--
-- Notes:		According to the PM at the time (Ashley Weaver), the report will be used
--				to simply monitor activity.  This incentive report is programmed to mimic the
--				the member's web experience since this is a CS driven incentive plan.
--
--
-- Updates:			
--
-- =============================================
CREATE PROCEDURE [trizetto].[proc_Incentives] 
	@inReportType INT,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;
	
	IF @inReportType <= 0 OR @inReportType > 2
	BEGIN
	RAISERROR (N'Please pass integers 1 or 2 for the @inReportType parameter. Parameters are @inReportType INT and @inEndDate DATETIME = NULL', -- Message text.
			   10, -- Severity,
			   1  -- State,
			   )
	END
	

	-- DECLARES
	DECLARE
		@MonthBegin DATETIME, 
		@MonthEnd DATETIME
	
	-- SETS
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))
	SET @MonthBegin = DATEADD(mm,DATEDIFF(mm,0,@inEndDate)-1,0)
	SET @MonthEnd = DATEADD(mm,DATEDIFF(mm,0,@inEndDate),0)
		
	-- CLEAN UP
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
	
	-- PLAN ACTIVITY TEMP
	SELECT
		DISTINCT -- THERE MAY BE A ONE TO MANY RELATIONSHIP TO THE ActivityItemValue TABLE (i.e. CompareValue column)
		pln.ClientIncentivePlanID,
		cipvr.ValidationRuleValue,
		cipvr.CompareOperator,
		cipvr.CompareValue AS [CS4],
		pln.PlanLevel,
		pln.ActivityItemID,
		pln.ParentActivityItemID,
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
		aiv.ActivityValue AS [AIV_ActivityValue],
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
		DA_Reports.incentives.PlanActivity pln WITH (NOLOCK)
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
	WHERE
		pln.ClientIncentivePlanID IN (1270,1272)
	
			
	-- BASE POPULATION TEMP
	SELECT
		mem.MemberID,
		grp.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		mem.RelationshipID,
		mem.Birthdate,
		cs.CS4,
		cs.CS5,
		CASE
			WHEN ISNULL(RTRIM(LTRIM(cs.CS5)),'') = 'Y' THEN 1270
			WHEN ISNULL(RTRIM(LTRIM(cs.CS5)),'') != 'Y' THEN 1272
		END AS [ClientIncentivePlanID],
		elig.EffectiveDate,
		elig.TerminationDate,
		CASE
			WHEN ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)
			THEN 1
			ELSE 0
		END AS [IsCurrentlyEligible]
	INTO
		#Base
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 194354)
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
			DA_Production.prod.Eligibility
		WHERE
			GroupID = 194354
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)
	
	
	SELECT
		ROW_NUMBER() OVER (PARTITION BY MemberID, Activity ORDER BY ActivityDate, CreditDate) AS [ActivitySeq],
		CASE WHEN ActivityValue != AIC_CompareValue OR ActivityValue != AIL_MaxValue THEN ROW_NUMBER() OVER (PARTITION BY MemberID, Activity, ActivityDate, CreditDate ORDER BY ActivityDate, CreditDate) ELSE 0 END AS [MultipleActivitySeq],
		*
	INTO
		#Incentive
	FROM
		(
		SELECT 
			-- THERE MAY BE A ONE TO MANY RELATIONSHIP BETWEEN Healthyroads.dbo.IC_MemberActivityItem AND #PlanActivity
			DISTINCT
			mem.MemberID,
			mem.GroupName,
			mem.EligMemberID,
			mem.EligMemberSuffix,
			mem.FirstName,
			mem.LastName,
			mem.RelationshipID,
			mem.Birthdate,
			mem.CS4,
			mem.CS5,
			mem.EffectiveDate,
			mem.TerminationDate,
			mem.IsCurrentlyEligible,
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
			CASE
				WHEN cont.ActivityItemID IS NOT NULL THEN ISNULL(cont.AI_Instruction,cont.ActivityDescription) + ' - ' + CAST(cont.AIC_CompareValue AS VARCHAR)
				ELSE COALESCE(pln.AI_Instruction,pln.ActivityDescription)
			END AS [Activity],
			mai.ActivityDate,
			mai.AddDate AS [CreditDate]
		FROM
			#Base mem
		JOIN
			Healthyroads.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
			ON	(mem.MemberID = mai.MemberID)
			AND	(mem.ClientIncentivePlanID = mai.ClientIncentivePlanID)
			AND	(mai.Deleted = 0)
		JOIN
			#PlanActivity pln
			ON	(mai.ActivityItemID = pln.ActivityItemID)
			AND	(mai.ClientIncentivePlanID = pln.ClientIncentivePlanID)
		LEFT JOIN
			#PlanActivity cont
			ON	(pln.ActivityItemID = cont.ParentActivityItemID)
		) data
	WHERE
		CreditDate < @inEndDate

	DELETE #Incentive
	WHERE
		(ActivitySeq != 1 AND MultipleActivitySeq = 0) OR
		(MultipleActivitySeq > 1)
	
	
	IF @inReportType = 1
	BEGIN
		SELECT
			inc.GroupName,
			inc.EligMemberID,
			inc.EligMemberSuffix,
			inc.FirstName,
			inc.LastName,
			ISNULL(CONVERT(VARCHAR(10),inc.Birthdate,101),'') AS [Birthdate],
			ISNULL(inc.CS4,'') AS [LocationCode],
			ISNULL(inc.CS5,'') AS [IncentiveOption],
			ISNULL(pts.TotalPoints,0) AS [TotalDollars],
			ISNULL(actpm.PreviousMonthCredits,0) AS [PreviousMonthCredits],
			ISNULL(act.TotalCredits,0) AS [TotalCredits],
			ISNULL([Q1-2014],0) AS [Q1-2014],
			ISNULL([Q2-2014],0) AS [Q2-2014],
			ISNULL([Q3-2014],0) AS [Q3-2014],
			ISNULL([Q4-2014],0) AS [Q4-2014],
			ISNULL(CONVERT(VARCHAR(10),pha.ActivityDate,101),'') AS [PHACompletedDate],
			CASE WHEN pha.ActivityDate IS NOT NULL THEN 'Y' ELSE '' END [PHACompletedFlag]
		FROM
			#Incentive inc
		LEFT JOIN
			(
			SELECT
				*
			FROM
				(
				SELECT
					MemberID,
					'Q' +  DATENAME(qq,ActivityDate) + '-' + DATENAME(yy,ActivityDate) AS [Activity],
					ActivityDate
				FROM
					#Incentive
				WHERE
					ClientIncentivePlanID = 1270 AND
					Activity = 'ActiPed Steps - 250,000 steps'
				) act
				PIVOT
				(
				COUNT(ActivityDate) FOR Activity IN ([Q1-2014],[Q2-2014],[Q3-2014],[Q4-2014])
				) pvt
			) stps
			ON	(inc.MemberID = stps.MemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				SUM(ActivityValue) AS [TotalCredits]
			FROM
				#Incentive
			WHERE
				ClientIncentivePlanID = 1270 AND
				Activity IN (
							'ActiPed Steps - 250,000 steps',
							'E-Coaching Course - 5',
							'Phone-Based Coaching Session - 4',
							'Worksite Health Challenge',
							'Total Cholesterol is less than 200 mg/dl',
							'HDL Cholesterol is equal to or greater than 40mg/dL',
							'HDL Cholesterol is equal to or greater than 50 mg/dL',
							'Blood Pressure is less than 120/80 mm/hg',
							'Fasting Glucose is less than 100 mg/dL',
							'BMI is less than 30',
							'Waist Circumference is less than or equal to 35 inches',
							'Waist Circumference is less than or equal to 40 inches',
							'Cotinine (Negative Testing)',
							'Telephonic Coaching Sessions – Tobacco Cessation - 4'
							)
			GROUP BY
				MemberID
			) act
			ON	(inc.MemberID = act.MemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				SUM(ActivityValue) AS [PreviousMonthCredits]
			FROM
				#Incentive
			WHERE
				ClientIncentivePlanID = 1270 AND
				Activity IN (
							'ActiPed Steps - 250,000 steps',
							'E-Coaching Course - 5',
							'Phone-Based Coaching Session - 4',
							'Worksite Health Challenge',
							'Total Cholesterol is less than 200 mg/dl',
							'HDL Cholesterol is equal to or greater than 40mg/dL',
							'HDL Cholesterol is equal to or greater than 50 mg/dL',
							'Blood Pressure is less than 120/80 mm/hg',
							'Fasting Glucose is less than 100 mg/dL',
							'BMI is less than 30',
							'Waist Circumference is less than or equal to 35 inches',
							'Waist Circumference is less than or equal to 40 inches',
							'Cotinine (Negative Testing)',
							'Telephonic Coaching Sessions – Tobacco Cessation - 4'
							) AND
				CreditDate >= @MonthBegin AND 
				CreditDate < @MonthEnd
			GROUP BY
				MemberID
			) actpm
			ON	(inc.MemberID = actpm.MemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				SUM(Points) AS [TotalPoints]
			FROM
				#Incentive
			WHERE
				ClientIncentivePlanID = 1270 AND
				Activity IN (
							'Dental Exam',
							'Annual Physical',
							'Annual Well-Woman Exam',
							'Annual Pap Test',
							'Annual Mammogram',
							'Annual Prostate Exam and/or PSA Screening',
							'Colonoscopy'
							)
			GROUP BY
				MemberID
			) pts
			ON	(inc.MemberID = pts.MemberID)
		LEFT JOIN
			#Incentive pha
			ON	(inc.MemberID = pha.MemberID)
			AND	(pha.Activity = 'Personal Health Assessment (Primary)')
			AND (inc.ClientIncentivePlanID = 1270)
		WHERE
			inc.ClientIncentivePlanID = 1270
		GROUP BY
			inc.GroupName,
			inc.EligMemberID,
			inc.EligMemberSuffix,
			inc.FirstName,
			inc.LastName,
			ISNULL(CONVERT(VARCHAR(10),inc.Birthdate,101),''),
			ISNULL(inc.CS4,''),
			ISNULL(inc.CS5,''),
			ISNULL(pts.TotalPoints,0),
			ISNULL(actpm.PreviousMonthCredits,0),
			ISNULL(act.TotalCredits,0),
			ISNULL([Q1-2014],0),
			ISNULL([Q2-2014],0),
			ISNULL([Q3-2014],0),
			ISNULL([Q4-2014],0),
			ISNULL(CONVERT(VARCHAR(10),pha.ActivityDate,101),''),
			CASE WHEN pha.ActivityDate IS NOT NULL THEN 'Y' ELSE '' END
	
	END
	
	IF @inReportType = 2
	BEGIN
		SELECT
			inc.GroupName,
			inc.EligMemberID,
			inc.EligMemberSuffix,
			inc.FirstName,
			inc.LastName,
			ISNULL(CONVERT(VARCHAR(10),inc.Birthdate,101),'') AS [Birthdate],
			ISNULL(inc.CS4,'') AS [LocationCode],
			ISNULL(inc.CS5,'') AS [IncentiveOption],
			ISNULL(actpm.PreviousMonthCredits,0) AS [PreviousMonthCredits],
			ISNULL(act.TotalCredits,0) AS [TotalCredits],
			ISNULL([Q1-2014],0) AS [Q1-2014],
			ISNULL([Q2-2014],0) AS [Q2-2014],
			ISNULL([Q3-2014],0) AS [Q3-2014],
			ISNULL([Q4-2014],0) AS [Q4-2014],
			ISNULL(CONVERT(VARCHAR(10),pha.ActivityDate,101),'') AS [PHACompletedDate],
			CASE WHEN pha.ActivityDate IS NOT NULL THEN 'Y' ELSE '' END [PHACompletedFlag]
		FROM
			#Incentive inc
		LEFT JOIN
			(
			SELECT
				*
			FROM
				(
				SELECT
					MemberID,
					'Q' +  DATENAME(qq,ActivityDate) + '-' + DATENAME(yy,ActivityDate) AS [Activity],
					ActivityDate
				FROM
					#Incentive
				WHERE
					ClientIncentivePlanID = 1272 AND
					Activity = 'ActiPed Steps - 250,000 steps'
				) act
				PIVOT
				(
				COUNT(ActivityDate) FOR Activity IN ([Q1-2014],[Q2-2014],[Q3-2014],[Q4-2014])
				) pvt
			) stps
			ON	(inc.MemberID = stps.MemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				SUM(ActivityValue) AS [TotalCredits]
			FROM
				#Incentive
			WHERE
				ClientIncentivePlanID = 1272 AND
				Activity IN (
							'ActiPed Steps - 250,000 steps',
							'E-Coaching Course - 5',
							'Phone-Based Coaching Session - 4',
							'Worksite Health Challenge',
							'Total Cholesterol is less than 200 mg/dl',
							'HDL Cholesterol is equal to or greater than 40mg/dL',
							'HDL Cholesterol is equal to or greater than 50 mg/dL',
							'Blood Pressure is less than 120/80 mm/hg',
							'Fasting Glucose is less than 100 mg/dL',
							'BMI is less than 30',
							'Waist Circumference is less than or equal to 35 inches',
							'Waist Circumference is less than or equal to 40 inches',
							'Tobacco Use / Non-Use Attestation',
							'Telephonic Coaching Sessions – Tobacco Cessation - 4'
							)
			GROUP BY
				MemberID
			) act
			ON	(inc.MemberID = act.MemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				SUM(ActivityValue) AS [PreviousMonthCredits]
			FROM
				#Incentive
			WHERE
				ClientIncentivePlanID = 1272 AND
				Activity IN (
							'ActiPed Steps - 250,000 steps',
							'E-Coaching Course - 5',
							'Phone-Based Coaching Session - 4',
							'Worksite Health Challenge',
							'Total Cholesterol is less than 200 mg/dl',
							'HDL Cholesterol is equal to or greater than 40mg/dL',
							'HDL Cholesterol is equal to or greater than 50 mg/dL',
							'Blood Pressure is less than 120/80 mm/hg',
							'Fasting Glucose is less than 100 mg/dL',
							'BMI is less than 30',
							'Waist Circumference is less than or equal to 35 inches',
							'Waist Circumference is less than or equal to 40 inches',
							'Tobacco Use / Non-Use Attestation',
							'Telephonic Coaching Sessions – Tobacco Cessation - 4'
							) AND
				CreditDate >= @MonthBegin AND 
				CreditDate < @MonthEnd
			GROUP BY
				MemberID
			) actpm
			ON	(inc.MemberID = actpm.MemberID)
		LEFT JOIN
			#Incentive pha
			ON	(inc.MemberID = pha.MemberID)
			AND	(pha.Activity = 'Personal Health Assessment (Primary)')
			AND	(inc.ClientIncentivePlanID = 1272)
		WHERE
			inc.ClientIncentivePlanID = 1272
		GROUP BY
			inc.GroupName,
			inc.EligMemberID,
			inc.EligMemberSuffix,
			inc.FirstName,
			inc.LastName,
			ISNULL(CONVERT(VARCHAR(10),inc.Birthdate,101),''),
			ISNULL(inc.CS4,''),
			ISNULL(inc.CS5,''),
			ISNULL(actpm.PreviousMonthCredits,0),
			ISNULL(act.TotalCredits,0),
			ISNULL([Q1-2014],0),
			ISNULL([Q2-2014],0),
			ISNULL([Q3-2014],0),
			ISNULL([Q4-2014],0),
			ISNULL(CONVERT(VARCHAR(10),pha.ActivityDate,101),''),
			CASE WHEN pha.ActivityDate IS NOT NULL THEN 'Y' ELSE '' END	
	
	END

	-- CLEAN UP
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
