SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-02-10
-- Description:	ASH Incentives Report for New Hire 
--
-- Notes:		New Hire is defined as a member with an effective date of
--				'2013-10-01' or greater
--
-- Updates:     WilliamPe 20140220
--				Added relationship filter
--
--				WilliamPe 20140410
--				Took out logic filtering on ActivityDate for the waivers
-- =============================================

CREATE PROCEDURE [ash].[proc_Incentives_NewHire]
	@inBeginMonth DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	-- FOR TESTING
	 --DECLARE @inBeginMonth DATETIME, @inEndDate DATETIME

	-- SETS
	SET @inBeginMonth = ISNULL(@inBeginMonth,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))

	-- CLEAN UP
	IF OBJECT_ID ('tempDb.dbo.#NewHire') IS NOT NULL
	BEGIN
		DROP TABLE #NewHire
	END

	IF OBJECT_ID('tempDb.dbo.#WaivedActivity') IS NOT NULL
	BEGIN
		DROP TABLE #WaivedActivity
	END

	IF OBJECT_ID('tempDb.dbo.#Activity') IS NOT NULL
	BEGIN
		DROP TABLE #Activity
	END

	-- BASE TEMP INSERT
	SELECT
		mem.MemberID,
		grp.GroupName,
		mem.FirstName,
		mem.LastName,
		mem.Relationship,
		mem.EligMemberSuffix AS [Suffix],
		mem.AltID1 AS [EEID],
		elig.EffectiveDate
	INTO
		#NewHire
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 1110)
	JOIN
		DA_Production.prod.Eligibility elig WITH (NOLOCK)
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.TerminationDate IS NULL)
		AND	(elig.EffectiveDate >= '2013-10-01') -- New Hire
	WHERE
		mem.RelationshipID IN (1,6) 

	
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
		#WaivedActivity
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
			mai.IsWaiver = 1 AND
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

	-- NEW HIRE ACTIVITY TEMP
	SELECT
		MemberID,
		Activity,
		ActivityDate,
		CreditDate,
		IsWaiver,
		ROW_NUMBER() OVER (PARTITION BY MemberID, Activity ORDER BY ActivityDate) AS ActivitySeq
	INTO
		#Activity
	FROM
		(
		-- Bio
		SELECT
			bio.MemberID,
			'Bio' AS [Activity],
			bio.ScreeningDate AS [ActivityDate],
			bio.SourceAddDate AS [CreditDate],
			0 AS [IsWaiver]
		FROM
			#NewHire mem
		JOIN
			DA_Production.prod.BiometricsScreening bio WITH (NOLOCK)
			ON	(mem.MemberID = bio.MemberID)
		JOIN
			DA_Production.prod.BiometricsScreeningResults res WITH (NOLOCK)
			ON	(bio.MemberScreeningID = res.MemberScreeningID)
		WHERE
			bio.ScreeningDate >= (CASE WHEN mem.EffectiveDate < '2013-11-01' THEN '2013-08-01' ELSE '2013-10-01' END) AND
			bio.ScreeningDate < DATEADD(dd,90,mem.EffectiveDate) AND
			bio.ScreeningDate < DATEADD(mm,1,@inBeginMonth) AND
			bio.ScreeningDate < '2014-10-01' AND
			bio.SourceAddDate < @inEndDate

		UNION

		-- Tobacco
		SELECT
			tob.MemberID,
			'Tobacco' AS [Activity],
			tob.ScreeningDate AS [ActivityDate],
			tob.SourceAddDate AS [CreditDate],
			0 AS [IsWaiver]
		FROM
			#NewHire mem
		JOIN
			DA_Production.prod.BiometricsScreening tob WITH (NOLOCK)
			ON	(mem.MemberID = tob.MemberID)
		JOIN
			DA_Production.prod.BiometricsScreeningResults res WITH (NOLOCK)
			ON	(tob.MemberScreeningID = res.MemberScreeningID)
		WHERE
			tob.ScreeningDate >= (CASE WHEN mem.EffectiveDate < '2013-11-01' THEN '2013-08-01' ELSE '2013-10-01' END) AND
			tob.ScreeningDate < DATEADD(dd,90,mem.EffectiveDate) AND
			tob.ScreeningDate < DATEADD(mm,1,@inBeginMonth) AND
			tob.ScreeningDate < '2014-10-01' AND
			tob.SourceAddDate < @inEndDate AND
			(
				CASE
					WHEN tob.FileSource = 'Manual' AND (res.SmokeFlag = 0 OR res.CotinineFlag = 0) THEN 0 -- Physican Form: No Tobacco 
					WHEN tob.FileSource = 'Quest' AND res.CotinineFlag = 0 THEN 0 -- Quest: Cotinine Negative
					ELSE 1
				END
			) = 0

		UNION

		-- PHA
		SELECT
			mem.MemberID,
			'PHA' AS [Activity],
			pha.AssessmentCompleteDate AS [ActivityDate],
			pha.SourceAddDate AS [CreditDate],
			0 AS [IsWaiver]
		FROM
			#NewHire mem
		JOIN
			DA_Production.prod.HealthAssessment pha WITH (NOLOCK)
			ON	(mem.MemberiD = pha.MemberID)
		WHERE
			pha.IsPrimarySurvey = 1 AND
			pha.IsComplete = 1 AND
			pha.AssessmentCompleteDate >= (CASE WHEN mem.EffectiveDate < '2013-11-01' THEN '2013-09-23' ELSE '2013-10-01' END) AND
			pha.AssessmentCompleteDate < DATEADD(dd,90,mem.EffectiveDate) AND
			pha.AssessmentCompleteDate < DATEADD(mm,1,@inBeginMonth) AND
			pha.AssessmentCompleteDate < '2014-10-01' AND
			pha.SourceAddDate < @inEndDate

		UNION

		-- Coaching
		SELECT
			MemberID,
			'Coaching' AS [Activity],
			AppointmentBeginDate AS [ActivityDate],
			SourceAddDate AS [CreditDate],
			0 AS [IsWaiver]
		FROM
			(
			SELECT
				mem.MemberID,
				cch.AppointmentBeginDate,
				cch.SourceAddDate,
				ROW_NUMBER() OVER (PARTITION BY mem.MemberID ORDER BY cch.AppointmentBeginDate) AS CoachSeq
			FROM
				#NewHire mem
			JOIN
				DA_Production.prod.Appointment cch
				ON	(mem.MemberID = cch.MemberID)
			WHERE
				cch.AppointmentStatusID = 4 AND
				cch.AppointmentBeginDate >= (CASE WHEN mem.EffectiveDate < '2013-11-01' THEN '2013-08-01' ELSE '2013-10-01' END) AND
				cch.AppointmentBeginDate < DATEADD(mm,1,@inBeginMonth) AND
				cch.AppointmentBeginDate < '2014-10-01' AND
				cch.SourceAddDate < @inEndDate
			) cch
		WHERE
			cch.CoachSeq = 6

		UNION

		-- Tier1
		SELECT
			MemberID,
			UPPER(LEFT(DATENAME(mm,@inBeginMonth),3)) + '_Tier1' AS [Activity],
			@inBeginMonth AS [ActivityDate],
			@inBeginMonth AS [CreditDate],
			0 AS [IsWaiver]
		FROM
			(
			SELECT
				stp.MemberID,
				SUM(stp.TotalSteps) AS 'TotalSteps'
			FROM
				#NewHire mem
			JOIN
				DA_Production.prod.ActivityMonitorLog stp WITH (NOLOCK)
				ON	(mem.MemberID = stp.MemberID)
			WHERE
				DATEADD(mm,DATEDIFF(mm,0,stp.ActivityDate),0) = @inBeginMonth AND
				stp.ActivityDate < '2014-10-01' AND
				stp.SourceAddDate < @inEndDate AND
				stp.ActivityType = 'Actiped' -- DEVICE ONLY
			GROUP BY
				stp.MemberID
			) stp
		WHERE
			TotalSteps >= 75000

		UNION

		-- Tier2
		SELECT
			MemberID,
			UPPER(LEFT(DATENAME(mm,@inBeginMonth),3)) + '_Tier2' AS [Activity],
			@inBeginMonth AS [ActivityDate],
			@inBeginMonth AS [CreditDate],
			0 AS [IsWaiver]
		FROM
			(
			SELECT
				stp.MemberID,
				SUM(stp.TotalSteps) AS 'TotalSteps'
			FROM
				#NewHire mem
			JOIN
				DA_Production.prod.ActivityMonitorLog stp WITH (NOLOCK)
				ON	(mem.MemberID = stp.MemberID)
			WHERE
				DATEADD(mm,DATEDIFF(mm,0,stp.ActivityDate),0) = @inBeginMonth AND
				stp.ActivityDate < '2014-10-01' AND
				stp.SourceAddDate < @inEndDate AND
				stp.ActivityType = 'Actiped' -- DEVICE ONLY
			GROUP BY
				stp.MemberID
			) stp
		WHERE
			TotalSteps >= 125000

		UNION

		-- Bio Waiver
		SELECT
			mem.MemberID,
			bio.Activity,
			bio.ActivityDate,
			bio.CreditDate,
			bio.IsWaiver
		FROM
			#NewHire mem 
		JOIN
			#WaivedActivity bio
			ON	(mem.MemberID = bio.MemberID)
		WHERE		
			bio.Activity = 'Bio' AND
			bio.CreditDate < @inEndDate
			
		UNION
	
		-- Tobacco Waiver
		SELECT
			mem.MemberID,
			tob.Activity,
			tob.ActivityDate,
			tob.CreditDate,
			tob.IsWaiver
		FROM
			#NewHire mem
		JOIN
			#WaivedActivity tob
			ON	(mem.MemberID = tob.MemberID)
		WHERE
			tob.Activity = 'Tobacco' AND
			tob.CreditDate < @inEndDate
			
		UNION

		-- PHA Waiver
		SELECT
			mem.MemberID,
			pha.Activity,
			pha.ActivityDate,
			pha.CreditDate,
			pha.IsWaiver
		FROM
			#NewHire mem
		JOIN
			#WaivedActivity pha
			ON	(mem.MemberID = pha.MemberID)
		WHERE
			pha.Activity = 'PHA' AND
			pha.CreditDate < @inEndDate

		UNION
		
		-- Coaching
		SELECT
			mem.MemberID,
			cch.Activity,
			cch.ActivityDate,
			cch.CreditDate,
			cch.IsWaiver
		FROM
			#NewHire mem
		JOIN
			#WaivedActivity cch
			ON	(mem.MemberID = cch.MemberID)
		WHERE
			cch.Activity = 'Coaching' AND
			cch.CreditDate < @inEndDate 

		UNION

		-- Tier1 Waiver
		SELECT
			mem.MemberID,
			t1.Activity,
			t1.ActivityDate,
			t1.CreditDate,
			t1.IsWaiver
		FROM
			#NewHire mem
		JOIN
			#WaivedActivity t1
			ON	(mem.MemberID = t1.MemberID)
		WHERE
			t1.Activity LIKE '%Tier1%' AND
			t1.ConnectedCreditMonth IS NOT NULL AND
			t1.ConnectedCreditMonth = DATEADD(mm,2,@inBeginMonth) AND
			t1.CreditDate < @inEndDate
		
		UNION

		-- Tier2 Waiver
		SELECT
			mem.MemberID,
			t2.Activity,
			t2.ActivityDate,
			t2.CreditDate,
			t2.IsWaiver
		FROM
			#NewHire mem
		JOIN
			#WaivedActivity t2
			ON	(mem.MemberID = t2.MemberID)
		WHERE
			t2.Activity LIKE '%Tier2%' AND
			t2.ConnectedCreditMonth IS NOT NULL AND
			t2.ConnectedCreditMonth = DATEADD(mm,2,@inBeginMonth) AND
			t2.CreditDate < @inEndDate
		) data
	

	-- FINAL
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
		CASE WHEN CoachingCompletedDate != '' AND TobaccoCompletedDate = '' THEN 1 ELSE 0 END AS [CoachingFlag],
		CASE WHEN TobaccoCompletedDate = '' THEN Coaching_IsWaiver ELSE 0 END AS [Coaching_IsWaiver],
		CASE WHEN TobaccoCompletedDate = '' THEN CoachingCompletedDate ELSE '' END AS [CoachingCompletedDate],
		CASE WHEN TobaccoCompletedDate = '' THEN CoachingCreditDate ELSE '' END AS [CoachingCreditDate],
		PHA_BIO_Percent,
		Tobacco_Coaching_Percent,
		TierOne_Percent,
		TierTwo_Percent,
		PHA_BIO_Percent + Tobacco_Coaching_Percent + TierOne_Percent + TierTwo_Percent AS [Total_Percent],
		GracePeriodEndDate
	FROM
		(
		SELECT
			mem.GroupName,
			mem.FirstName,
			mem.LastName,
			mem.Relationship,
			ISNULL(mem.Suffix,'') AS [Suffix],
			ISNULL(mem.EEID,'') AS [EEID],
			CONVERT(VARCHAR(10),mem.EffectiveDate,101) AS [EffectiveDate],
			ISNULL(CONVERT(VARCHAR(10),pha.ActivityDate,101),'') AS [PHACompletedDate],
			ISNULL(CONVERT(VARCHAR(10),pha.CreditDate,101),'') AS [PHACreditDate],
			ISNULL(CONVERT(VARCHAR(10),bio.ActivityDate,101),'') AS [BiometricsCompletedDate],
			ISNULL(CONVERT(VARCHAR(10),bio.CreditDate,101),'') AS [BiometricsCreditDate],
			ISNULL(CONVERT(VARCHAR(10),cch.ActivityDate,101),'') AS [CoachingCompletedDate],
			ISNULL(CONVERT(VARCHAR(10),cch.CreditDate,101),'') AS [CoachingCreditDate],
			ISNULL(CONVERT(VARCHAR(10),tob.ActivityDate,101),'') AS [TobaccoCompletedDate],
			ISNULL(CONVERT(VARCHAR(10),tob.CreditDate,101),'') AS [TobaccoCreditDate],
			CASE
				WHEN pha.MemberID IS NOT NULL AND bio.MemberID IS NOT NULL THEN 10 
				ELSE 0
			END AS [PHA_BIO_Percent],
			CASE
				WHEN tob.MemberID IS NOT NULL OR cch.MemberID IS NOT NULL THEN 10 
				ELSE 0 
			END AS [Tobacco_Coaching_Percent],
			CASE
				WHEN trone.MemberID IS NOT NULL OR trtwo.MemberID IS NOT NULL THEN 10
				ELSE 0 
			END AS [TierOne_Percent],
			CASE
				WHEN trtwo.MemberID IS NOT NULL THEN 10
				ELSE 0 
			END AS [TierTwo_Percent],
			CASE WHEN pha.IsWaiver = 1 THEN 1 ELSE 0 END AS [PHA_IsWaiver],
			CASE WHEN bio.IsWaiver = 1 THEN 1 ELSE 0 END AS [Biometrics_IsWaiver],
			CASE WHEN tob.IsWaiver = 1 THEN 1 ELSE 0 END AS [Tobacco_IsWaiver],
			CASE WHEN cch.IsWaiver = 1 THEN 1 ELSE 0 END AS [Coaching_IsWaiver],
			CASE WHEN trone.IsWaiver = 1 THEN 1 ELSE 0 END AS [TierOne_IsWaiver],
			CASE WHEN trtwo.IsWaiver = 1 THEN 1 ELSE 0 END AS [TierTwo_IsWaiver],
			CASE WHEN DATEADD(dd,60,mem.EffectiveDate) >= DATEADD(mm,1,@inBeginMonth) THEN 1 ELSE 0 END AS [GracePeriod_IsActive],
			CONVERT(VARCHAR(10),DATEADD(dd,90,mem.EffectiveDate),101) AS [GracePeriodEndDate]
		FROM
			#NewHire mem
		LEFT JOIN
			#Activity pha
			ON	(mem.MemberID = pha.MemberID)
			AND	(pha.Activity = 'PHA')
			AND	(pha.ActivitySeq = 1)
		LEFT JOIN
			#Activity bio
			ON	(mem.MemberID = bio.MemberID)
			AND	(bio.Activity = 'Bio')
			AND	(bio.ActivitySeq = 1)
		LEFT JOIN
			#Activity tob
			ON	(mem.MemberID = tob.MemberID)
			AND	(tob.Activity = 'Tobacco')
			AND	(tob.ActivitySeq = 1)
		LEFT JOIN
			#Activity cch
			ON	(mem.MemberID = cch.MemberID)
			AND	(cch.Activity = 'Coaching')
			AND	(cch.ActivitySeq = 1)
		LEFT JOIN
			#Activity trone
			ON	(mem.MemberID = trone.MemberID)
			AND	(trone.Activity LIKE '%Tier1%')
			AND	(trone.ActivitySeq = 1)
		LEFT JOIN
			#Activity trtwo
			ON	(mem.MemberID = trtwo.MemberID)
			AND	(trtwo.Activity LIKE '%Tier2%')
			AND	(trtwo.ActivitySeq = 1)
		) final
	ORDER BY
		EEID,
		Relationship
	

	-- CLEAN UP
	IF OBJECT_ID ('tempDb.dbo.#NewHire') IS NOT NULL
	BEGIN
		DROP TABLE #NewHire
	END

	IF OBJECT_ID('tempDb.dbo.#WaivedActivity') IS NOT NULL
	BEGIN
		DROP TABLE #WaivedActivity
	END

	IF OBJECT_ID('tempDb.dbo.#Activity') IS NOT NULL
	BEGIN
		DROP TABLE #Activity
	END



END
GO
