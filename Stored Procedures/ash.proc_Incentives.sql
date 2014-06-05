SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-02-10
-- Description:	ASH Incentives Report for Current Employees
--
-- Notes:		Current Employee is defined as an employee
--				with an effective date less than '2013-10-01'
--
-- Updates:		WilliamPe 20140410
--				Took out logic that was filtering on activity date for the Tier1 and Tier2 activities.
--				This was preventing waived connected activities that have the same activity date as the 
--				credit date from being passed. I also added logic to account for other waived activities.
--				Added a waived record history tab.
--
-- =============================================

CREATE PROCEDURE [ash].[proc_Incentives] 
	@inBeginMonth DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	-- FOR TESTING
	-- DECLARE @inBeginMonth DATETIME, @inEndDate DATETIME

	-- SETS
	SET @inBeginMonth = ISNULL(@inBeginMonth,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))

	-- CLEAN UP
	IF OBJECT_ID('tempDb.dbo.#Activity') IS NOT NULL
	BEGIN
		DROP TABLE #Activity
	END
	
	-- ACTIVITY TEMP INSERT
	SELECT
		MemberID,
		ActivityItemID,
		Activity,
		ActivityDate,
		ConnectedCreditMonth,
		CreditDate,
		IsWaiver,
		ReferenceID,
		[Description],
		ROW_NUMBER() OVER (PARTITION BY MemberID, Activity ORDER BY ActivityDate, CreditDate) AS ActivitySeq
	INTO
		#Activity
	FROM
		(
		SELECT
			mai.MemberID,
			mai.ActivityItemID,
			mai.ActivityDate,
			mai.ReferenceID,
			mai.AddDate AS [CreditDate],
			mai.IsWaiver,
			ai.Instruction,
			act.[Description],
			CASE
				WHEN mai.ActivityItemID = 6261 THEN 'PHA'
				WHEN mai.ActivityItemID = 6262 THEN 'Bio'
				WHEN mai.ActivityItemID IN (6264,6265) THEN 'Tobacco'
				WHEN mai.ActivityItemID = 6266 THEN 'Coaching'
				WHEN mai.ActivityItemID IN (6269,6270) THEN 'NOV_Tier1'
				WHEN mai.ActivityItemID IN (6272,6273) THEN 'NOV_Tier2'
				WHEN mai.ActivityItemID IN (6275,6276) THEN 'DEC_Tier1'
				WHEN mai.ActivityItemID IN (6278,6279) THEN 'DEC_Tier2'
				WHEN mai.ActivityItemID IN (6281,6282) THEN 'JAN_Tier1'
				WHEN mai.ActivityItemID IN (6284,6285) THEN 'JAN_Tier2'
				WHEN mai.ActivityItemID IN (6287,6288) THEN 'FEB_Tier1'
				WHEN mai.ActivityItemID IN (6290,6291) THEN 'FEB_Tier2'
				WHEN mai.ActivityItemID IN (6293,6294) THEN 'MAR_Tier1'
				WHEN mai.ActivityItemID IN (6296,6297) THEN 'MAR_Tier2'
				WHEN mai.ActivityItemID IN (6299,6300) THEN 'APR_Tier1'
				WHEN mai.ActivityItemID IN (6302,6303) THEN 'APR_Tier2'
				WHEN mai.ActivityItemID IN (6305,6306) THEN 'MAY_Tier1'
				WHEN mai.ActivityItemID IN (6308,6309) THEN 'MAY_Tier2'
				WHEN mai.ActivityItemID IN (6311,6312) THEN 'JUN_Tier1'
				WHEN mai.ActivityItemID IN (6314,6315) THEN 'JUN_Tier2'
				WHEN mai.ActivityItemID IN (6317,6318) THEN 'JUL_Tier1'
				WHEN mai.ActivityItemID IN (6320,6321) THEN 'JUL_Tier2'
				WHEN mai.ActivityItemID IN (6323,6324) THEN 'AUG_Tier1'
				WHEN mai.ActivityItemID IN (6326,6327) THEN 'AUG_Tier2'
				WHEN mai.ActivityItemID IN (6329,6330) THEN 'SEP_Tier1'
				WHEN mai.ActivityItemID IN (6332,6333) THEN 'SEP_Tier2'
			END AS [Activity],
			-- Hard coding a connected credit date mainly due to the waiver process
			-- Meaning, the day the waiver was processed shows up as the activity date.
			-- If I were then to try and filter by the activity date, I could potentially miss activity records
			CASE 
				WHEN mai.ActivityItemID IN (6269, 6270, 6272, 6273) THEN CAST('2014-01-01' AS DATETIME)
				WHEN mai.ActivityItemID IN (6275, 6276, 6278, 6279) THEN CAST('2014-02-01' AS DATETIME)
				WHEN mai.ActivityItemID IN (6281, 6282, 6284, 6285) THEN CAST('2014-03-01' AS DATETIME)
			    WHEN mai.ActivityItemID IN (6287, 6288, 6290, 6291) THEN CAST('2014-04-01' AS DATETIME)
				WHEN mai.ActivityItemID IN (6293, 6294, 6296, 6297) THEN CAST('2014-05-01' AS DATETIME)
			    WHEN mai.ActivityItemID IN (6299, 6300, 6302, 6303) THEN CAST('2014-06-01' AS DATETIME)
				WHEN mai.ActivityItemID IN (6305, 6306, 6308, 6309) THEN CAST('2014-07-01' AS DATETIME)
				WHEN mai.ActivityItemID IN (6311, 6312, 6314, 6315) THEN CAST('2014-08-01' AS DATETIME)
				WHEN mai.ActivityItemID IN (6317, 6318, 6320, 6321) THEN CAST('2014-09-01' AS DATETIME)
				WHEN mai.ActivityItemID IN (6323, 6324, 6326, 6327) THEN CAST('2014-10-01' AS DATETIME)
			    WHEN mai.ActivityItemID IN (6329, 6330, 6332, 6333) THEN CAST('2014-11-01' AS DATETIME)
			END AS [ConnectedCreditMonth]
		FROM
			Healthyroads.dbo.IC_MemberActivityItem mai
		LEFT JOIN
			Healthyroads.dbo.IC_ActivityItem ai
			ON	(mai.ActivityItemID = ai.ActivityItemID)
		LEFT JOIN
			Healthyroads.dbo.IC_Activity act
			ON	(ai.ActivityID = act.ActivityID)
			AND	(act.Deleted = 0)
		WHERE
			mai.Deleted = 0 AND
			mai.ClientIncentivePlanID = 1239 AND
			mai.ActivityItemID IN
			(
			6261, -- PHA
			6262, -- BIO
			6264, 6265, -- Tobacco
			6266, -- Coaching
			6269, 6270, -- NovT1
			6272, 6273, -- NovT2
			6275, 6276, -- DecT1
			6278, 6279, -- DecT2
			6281, 6282, -- JanT1
			6284, 6285, -- JanT2
			6287, 6288, -- FebT1
			6290, 6291, -- FebT2
			6293, 6294, -- MarT1
			6296, 6297, -- MarT2
			6299, 6300, -- AprT1
			6302, 6303, -- AprT2
			6305, 6306, -- MayT1
			6308, 6309, -- MayT2
			6311, 6312, -- JunT1
			6314, 6315, -- JunT2
			6317, 6318, -- JulT1
			6320, 6321, -- JulT2
			6323, 6324, -- AugT1
			6326, 6327, -- AugT2
			6329, 6330, -- SepT1
			6332, 6333  -- SepT2
			)
		) act


	SELECT
		CONVERT(VARCHAR(10),@inBeginMonth,101) AS [ReportMonth],
		CONVERT(VARCHAR(10),DATEADD(mm,2,@inBeginMonth),101) AS [CreditMonth],
		GroupName,
		FirstName,
		LastName,
		Relationship,
		Suffix,
		EEID,
		EffectiveDate,
		PHACompletedDate,
		BiometricsCompletedDate,
		CASE WHEN CoachingCompletedDate != '' THEN 1 ELSE 0 END AS [CoachingFlag],
		Coaching_IsWaiver,
		CoachingCompletedDate,
		CoachingCreditDate,
		PHA_BIO_Percent,
		Tobacco_Coaching_Percent,
		TierOne_Percent,
		TierTwo_Percent,
		PHA_BIO_Percent + Tobacco_Coaching_Percent + TierOne_Percent + TierTwo_Percent AS [Total_Percent]
	FROM
		(
		SELECT
			grp.GroupName,
			mem.FirstName,
			mem.LastName,
			mem.Relationship,
			ISNULL(mem.EligMemberSuffix,'') AS [Suffix],
			ISNULL(mem.AltID1,'') AS [EEID],
			CONVERT(VARCHAR(10),elig.EffectiveDate,101) AS [EffectiveDate],
			ISNULL(CONVERT(VARCHAR(10),pha.ActivityDate,101),'') AS [PHACompletedDate],
			ISNULL(CONVERT(VARCHAR(10),pha.CreditDate,101),'') AS [PHACreditDate],
			ISNULL(CONVERT(VARCHAR(10),bio.ActivityDate,101),'') AS [BiometricsCompletedDate],
			ISNULL(CONVERT(VARCHAR(10),bio.CreditDate,101),'') AS [BiometricsCreditDate],
			ISNULL(CONVERT(VARCHAR(10),cch.ActivityDate,101),'') AS [CoachingCompletedDate],
			ISNULL(CONVERT(VARCHAR(10),cch.CreditDate,101),'') AS [CoachingCreditDate],
			ISNULL(CONVERT(VARCHAR(10),tob.ActivityDate,101),'') AS [TobaccoCompletedDate],
			ISNULL(CONVERT(VARCHAR(10),tob.CreditDate,101),'') AS [TobaccoCreditDate],
			CASE WHEN pha.MemberID IS NOT NULL AND bio.MemberID IS NOT NULL THEN 10 ELSE 0 END AS [PHA_BIO_Percent],
			CASE WHEN tob.MemberID IS NOT NULL OR cch.MemberID IS NOT NULL THEN 10 ELSE 0 END AS [Tobacco_Coaching_Percent],
			CASE WHEN trone.MemberID IS NOT NULL OR trtwo.MemberID IS NOT NULL THEN 10 ELSE 0 END AS [TierOne_Percent],
			CASE WHEN trtwo.MemberID IS NOT NULL THEN 10 ELSE 0 END AS [TierTwo_Percent],
			CASE WHEN pha.IsWaiver = 1 THEN 1 ELSE 0 END AS [PHA_IsWaiver],
			CASE WHEN bio.IsWaiver = 1 THEN 1 ELSE 0 END AS [Biometrics_IsWaiver],
			CASE WHEN tob.IsWaiver = 1 THEN 1 ELSE 0 END AS [Tobacco_IsWaiver],
			CASE WHEN cch.IsWaiver = 1 THEN 1 ELSE 0 END AS [Coaching_IsWaiver],
			CASE WHEN trone.IsWaiver = 1 THEN 1 ELSE 0 END AS [TierOne_IsWaiver],
			CASE WHEN trtwo.IsWaiver = 1 THEN 1 ELSE 0 END AS [TierTwo_IsWaiver]
		FROM
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)	
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(grp.GroupID = mem.GroupID)
			AND	(mem.GroupID = 1110)
			AND	(mem.RelationshipID IN (6,1)) -- Primary/Spouse there was no note of domestic partnership (RelationshipID = 2) so DP was not included
		JOIN
			DA_Production.prod.Eligibility elig WITH (NOLOCK)
			ON	(mem.MemberID = elig.MemberID)
			AND	(elig.TerminationDate IS NULL)
			AND	(elig.EffectiveDate < '2013-10-01') -- Current Employee
		LEFT JOIN
			#Activity pha
			ON	(mem.MemberID = pha.MemberID)
			AND	(pha.Activity = 'PHA')
			AND	(pha.ActivitySeq = 1)
			AND	(pha.ActivityDate < 
					CASE
						WHEN @inBeginMonth < '2014-01-01' 
						THEN '2014-02-01' 
						WHEN pha.IsWaiver = 1
						THEN @inEndDate 
						ELSE DATEADD(mm,1,@inBeginMonth) 
					END
				)
			AND	(pha.CreditDate < @inEndDate)
		LEFT JOIN
			#Activity bio
			ON	(mem.MemberID = bio.MemberID)
			AND	(bio.Activity = 'Bio')
			AND	(bio.ActivitySeq = 1)
			AND	(bio.ActivityDate < 
					CASE
						WHEN @inBeginMonth < '2014-01-01' 
						THEN '2014-02-01' 
						WHEN bio.IsWaiver = 1
						THEN @inEndDate 
						ELSE DATEADD(mm,1,@inBeginMonth) 
					END
				)
			AND (bio.CreditDate < @inEndDate)
		LEFT JOIN
			#Activity tob
			ON	(mem.MemberID = tob.MemberID)
			AND	(tob.Activity = 'Tobacco')
			AND	(tob.ActivitySeq = 1)
			AND	(tob.ActivityDate < 
					CASE
						WHEN @inBeginMonth < '2014-01-01' 
						THEN '2014-02-01' 
						WHEN tob.IsWaiver = 1
						THEN @inEndDate 
						ELSE DATEADD(mm,1,@inBeginMonth) 
					END
				)
			AND	(tob.CreditDate < @inEndDate)
		LEFT JOIN
			#Activity cch
			ON	(mem.MemberID = cch.MemberID)
			AND	(cch.Activity = 'Coaching')
			AND	(cch.ActivitySeq = 1) 
			AND	(cch.ActivityDate < 
					CASE
						WHEN @inBeginMonth < '2014-01-01' 
						THEN '2014-02-01' 
						WHEN cch.IsWaiver = 1
						THEN @inEndDate 
						ELSE DATEADD(mm,1,@inBeginMonth) 
					END
				)
			AND	(cch.CreditDate < @inEndDate)
		LEFT JOIN
			#Activity trone
			ON	(mem.MemberID = trone.MemberID)
			AND	(trone.Activity LIKE '%Tier1%')
			AND	(trone.ConnectedCreditMonth IS NOT NULL)
			AND	(trone.ConnectedCreditMonth = DATEADD(mm,2,@inBeginMonth))
			AND	(trone.CreditDate < @inEndDate)
		LEFT JOIN
			#Activity trtwo
			ON	(mem.MemberID = trtwo.MemberID)
			AND	(trtwo.Activity LIKE '%Tier2%')
			AND	(trtwo.ConnectedCreditMonth IS NOT NULL)
			AND	(trtwo.ConnectedCreditMonth = DATEADD(mm,2,@inBeginMonth))
			AND	(trtwo.CreditDate < @inEndDate)
		) final
	ORDER BY
		EEID,
		Relationship

	-- WAIVED ACTIVITIES
	SELECT
		grp.GroupName,
		mem.FirstName,
		mem.LastName,
		mem.Relationship,
		ISNULL(mem.EligMemberSuffix,'') AS [Suffix],
		ISNULL(mem.AltID1,'') AS [EEID],
		act.Activity,
		CONVERT(VARCHAR(10),act.ActivityDate,101) AS [ActivityDate],
		ISNULL(CONVERT(VARCHAR(10),act.ConnectedCreditMonth,101),'') AS [ConnectedCreditMonth],
		CONVERT(VARCHAR(10),act.CreditDate,101) AS [CreditDate],
		CASE WHEN act.IsWaiver = 1 THEN 1 ELSE 0 END AS [IsWaiver] -- TASK AUTOMATION CHANGES THIS TO TRUE/FALSE (Changed simply for consistency with the logic above
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)	
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 1110)
		AND	(mem.RelationshipID IN (6,1)) -- Primary/Spouse there was no note of domestic partnership (RelationshipID = 2) so DP was not included
	JOIN
		DA_Production.prod.Eligibility elig WITH (NOLOCK)
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.TerminationDate IS NULL)
		AND	(elig.EffectiveDate < '2013-10-01') -- Current Employee
	JOIN
		#Activity act 
		ON	(mem.MemberID = act.MemberID)
		AND	(act.ActivitySeq = 1)
	WHERE
		(
		act.ActivityDate < CASE WHEN act.Activity NOT LIKE '%Tier%' THEN @inEndDate END
		OR
		act.ConnectedCreditMonth <= DATEADD(mm,2,@inBeginMonth)
		) AND
		act.CreditDate < @inEndDate AND
		act.IsWaiver = 1
	ORDER BY
		ISNULL(mem.AltID1,''),
		mem.Relationship
		
	-- CLEAN UP
	IF OBJECT_ID('tempDb.dbo.#Activity') IS NOT NULL
	BEGIN
		DROP TABLE #Activity
	END

END
GO
