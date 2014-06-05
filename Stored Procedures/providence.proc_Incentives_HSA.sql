SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-12-17
-- Description:	Providence Incentives Data for HSA
--
-- Notes:
--
-- Updates:		WilliamPe 20131226
--				Modified code to support new @inReportType parameter passed to grab the base data	
-- 
--				WilliamPe 20131231
--				Added logic to exclude primary and spouses where the CS1 values do not match
--
--				WilliamPe 20140107
--				Deleted EligMemberID's in WHERE clause in the DA_Reports.providence.EarnedIncentiveReportLog INSERT
--
--				WilliamPe 20140108
--				Added ReportedTo = 'Providence_HSA' to Final Results Query
--
--				WilliamPe 20140205
--				Took out code that was deleting mismatched CS1 values between primary and spouse.
--				This logic should have been placed in the [providence].[proc_Incentives_BaseData] proc.	
--
--				WilliamPe 20140206
--				Modified Family Met max logic.
--
--				WilliamPe 20140325
--				Updated Member Met max and Member Earned Additional logic.
--
-- =============================================

CREATE PROCEDURE [providence].[proc_Incentives_HSA] 
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	--DECLARE @inEndDate DATETIME
	-- SETS
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(wk,DATEDIFF(wk,0,GETDATE()),2)) -- Wednesday of current week

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#BaseData') IS NOT NULL
	BEGIN
		DROP TABLE #BaseData
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#EarnedIncentive') IS NOT NULL
	BEGIN
		DROP TABLE #EarnedIncentive
	END

	IF OBJECT_ID('tempdb.dbo.#LastBenefitCoverageTier') IS NOT NULL
	BEGIN
		DROP TABLE #LastBenefitCoverageTier
	END

	-- BASE DATA TEMP
	CREATE TABLE #BaseData
	(
		MemberID INT,
		SubscriberMemberID INT,
		RelationshipID INT,
		EligMemberID VARCHAR(30),
		EligMemberSuffix CHAR(2),
		EligMemberID_Suffix VARCHAR(50),
		SubscriberFirstName VARCHAR(80),
		SubscriberMiddleInitial VARCHAR(10),
		SubscriberLastName VARCHAR(80),
		CS1 VARCHAR(100),
		CS3 VARCHAR(100),
		CS4 VARCHAR(100),
		CS6 VARCHAR(100),
		CS8 VARCHAR(100),
		CS9 VARCHAR(100),
		CS10 VARCHAR(100),
		CS1_INT INT,
		IsCurrentlyEligble BIT,
		EffectiveDate DATETIME,
		TerminationDate DATETIME,
		ClientIncentivePlanID INT,
		ActivityItemID INT,
		Activity VARCHAR(1000),
		ConformedActivity VARCHAR(100),
		ActivityDate DATETIME,
		ActivityValue INT,
		ActivityCreditDate DATETIME
	)
	INSERT INTO #BaseData
	EXEC [providence].[proc_Incentives_BaseData] 'HSA', 1

	SELECT
		*
	INTO
		#Incentive
	FROM
		(
		SELECT
			MemberID,
			SubscriberMEmberID,
			RelationshipID,
			EligMemberID,
			EligMemberSuffix,
			EligMemberID_Suffix,
			SubscriberFirstName,
			SubscriberMiddleInitial,
			SubscriberLastName,
			CS1,
			CS3,
			CS6,
			CS8,
			CS9,
			CS10,
			CS1_INT,
			ClientIncentivePlanID,
			ActivityItemID,
			Activity,
			ConformedActivity,
			ActivityDate,
			ActivityValue,
			ActivityCreditDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID, ConformedActivity ORDER BY ActivityDate, ActivityCreditDate) AS [ActivitySeq],
			CASE WHEN ConformedActivity = 'Coaching' THEN ROW_NUMBER() OVER (PARTITION BY MemberID, ConformedActivity ORDER BY ActivityCreditDate) ELSE 0 END AS [CoachingSeq] 
		FROM
			#BaseData
		) data
	WHERE
		(ActivitySeq = 1 AND CoachingSeq = 0) OR
		CoachingSeq = 4

	SELECT
		*,
		CASE IncentiveCoverageTier WHEN 1 THEN 350 WHEN 2 THEN 700 WHEN 3 THEN 1400 END [MemberTotal]
	INTO
		#EarnedIncentive
	FROM
		(
		SELECT
			bio.MemberID,
			bio.EligMemberID,
			bio.EligMemberSuffix,
			bio.EligMemberID_Suffix,
			bio.SubscriberFirstName,
			bio.SubscriberMiddleInitial,
			bio.SubscriberLastName,
			bio.CS1,
			bio.CS3,
			bio.CS6,
			bio.CS8,
			bio.CS9,
			bio.CS10,
			bio.CS1_INT,
			CASE
				bio.CS3 -- OUTCOMES (ALASKA)
				WHEN 1 THEN
					CASE bio.CS1_INT
						WHEN 3 THEN
							CASE
								WHEN outc.ActivityCreditDate IS NOT NULL THEN 3
								WHEN outc.ActivityCreditDate IS NULL AND cch.ActivityCreditDate IS NOT NULL THEN 3
								WHEN outc.ActivityCreditDate IS NULL AND sotf.ActivityCreditDate IS NOT NULL THEN 3
								ELSE 2
							END
						ELSE
							CASE
								WHEN outc.ActivityCreditDate IS NOT NULL THEN 2
								WHEN outc.ActivityCreditDate IS NULL AND cch.ActivityCreditDate IS NOT NULL THEN 2
								WHEN outc.ActivityCreditDate IS NULL AND sotf.ActivityCreditDate IS NOT NULL THEN 2
								ELSE 1 
							END
					END
				WHEN 2 THEN -- PARTICIPATION (NON-ALASKA)
					CASE bio.CS1_INT
						WHEN 3 THEN 3
						ELSE 2
					END -- NEW HIRE PARTICIPATION (ALAKSA)
				WHEN 3 THEN
					CASE bio.CS1_INT
						WHEN 3 THEN 3
						ELSE 2
					END -- NEW HIRE PARTICIPATION (NON-ALASKA)
				WHEN 4 THEN
					CASE bio.CS1_INT
						WHEN 3 THEN 3
						ELSE 2
					END
			END AS [IncentiveCoverageTier],
			CASE bio.CS3
				WHEN 1 -- OUTCOMES (ALASKA)
					THEN
						dbo.func_MAX_DATETIME(bio.ActivityCreditDate,dbo.func_MAX_DATETIME(outc.ActivityCreditDate,dbo.func_MAX_DATETIME(cch.ActivityCreditDate,sotf.ActivityCreditDate)))
				WHEN 2 -- PARTICIPATION (NON-ALASKA)
					THEN
						bio.ActivityCreditDate
				WHEN 3 -- NEW HIRE PARTICIPATION (ALAKSA)
					THEN
						bio.ActivityCreditDate
				WHEN 4 -- NEW HIRE PARTICIPATION (NON-ALASKA)
					THEN 
						bio.ActivityCreditDate	
			END AS EarnedDate
		FROM
			#Incentive bio
		LEFT JOIN
			(
			SELECT
				MemberID,
				ActivityDate,
				ActivityCreditDate,
				Activity,
				ConformedActivity,
				ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ActivityCreditDate) AS 'OutcomesSeq'
			FROM
				#Incentive
			WHERE
				ConformedActivity IN ('BP','Tobacco','Cholesterol','BMI') 
			) outc
			ON	(bio.MemberID = outc.MemberID)
			AND	(outc.OutcomesSeq = 4)
		LEFT JOIN
			#Incentive cch
			ON	(bio.MemberID = cch.MemberID)
			AND	(cch.ConformedActivity = 'Coaching')
		LEFT JOIN
			#Incentive sotf
			ON	(bio.MemberID = sotf.MemberID)
			AND	(sotf.ConformedActivity = 'SoTF')
		WHERE
			bio.ConformedActivity = 'BIO'
		) data
	WHERE
		EarnedDate < @inEndDate
	ORDER BY
		EligMemberID_Suffix

	-- DELETE DATA IF ALREADY RAN TODAY
	DELETE DA_Reports.providence.EarnedIncentiveReportLog
	WHERE
		DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
		DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE()) AND
		ReportedTo = 'Providence_HSA'
	
	-- DETERMINE LAST REPORTED BENEFIT COVERAGE TIER
	SELECT
		MemberID,
		CS1_INT,
		DateReported,
		ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY DateReported DESC) AS RevCS1Seq
	INTO
		#LastBenefitCoverageTier
	FROM
		DA_Reports.providence.EarnedIncentiveReportLog
		
	
	-- INSERT TO REPORT LOG
	INSERT INTO DA_Reports.providence.EarnedIncentiveReportLog
	SELECT
		einc.MemberID,
		einc.EligMemberID, 
		einc.EligMemberSuffix,
		einc.EligMemberID_Suffix,
		einc.CS1,
		einc.CS3,
		einc.CS6,
		einc.CS8,
		einc.CS9,
		einc.CS10,
		einc.CS1_INT,
		ISNULL((einc.IncentiveCoverageTier - ABS(einc.IncentiveCoverageTier - earn.[IncentiveCoverageTier_Hist_Sum])),einc.IncentiveCoverageTier) AS IncentiveCoverageTier,
		NULL AS PremiumLifestyleCreditCode,
		GETDATE() AS DateReported,
		'Providence_HSA' AS ReportedTo,
		@inEndDate AS ReportEndDate,
		GETDATE() AS AddedDate,
		'UserStoredProcedure' AS AddedBy,
		NULL AS ModifiedBy,
		NULL AS Notes,
		0 AS Deleted
	FROM
		#EarnedIncentive einc
	LEFT JOIN
		(
		SELECT
			cur.MemberID,
			cur.EligMemberID,
			cur.CS1_INT,
			cur.MemberTotal AS 'MemberTotal_Cur',
			memhist.MemberTotal AS 'MemberTotal_Hist',
			cur.IncentiveCoverageTier AS 'IncentiveCoverageTier_Cur',
			memhist.IncentiveCoverageTier AS 'IncentiveCoverageTier_Hist_Sum',
			CASE
				WHEN cur.CS1_INT = 1 AND (700 - memhist.MemberTotal) <= 0 THEN 1
				WHEN cur.CS1_INT = 2 AND (700 - memhist.MemberTotal) <= 0 THEN 1
				WHEN cur.CS1_INT = 3 AND (1400 - memhist.MemberTotal) <= 0 THEN 1
				ELSE 0
			END AS 'IndividualMetMax',
			CASE
				WHEN (cur.MemberTotal - memhist.MemberTotal) > 0 THEN 1
				ELSE 0
			END AS 'EarnedAdditional'
		FROM
			#EarnedIncentive cur
		JOIN
			(
			SELECT
				MemberID,
				SUM(CASE IncentiveCoverageTier WHEN 1 THEN 350 WHEN 2 THEN 700 WHEN 3 THEN 1400 END) AS 'MemberTotal',
				SUM(IncentiveCoverageTier) AS 'IncentiveCoverageTier'
			FROM
				DA_Reports.providence.EarnedIncentiveReportLog
			WHERE
				Deleted = 0
			GROUP BY
				MemberID
			) memhist
			ON	(cur.MemberID = memhist.MemberID)
		) earn
		ON	(earn.MemberID = einc.MemberID)
	LEFT JOIN
		(
		SELECT
			cur.EligMemberID,
			cur.CS1_INT,
			famhist.FamilyTotal,
			CASE
				WHEN cur.CS1_INT = 1 AND (700 - famhist.FamilyTotal) <= 0 THEN 1 
				WHEN cur.CS1_INT = 2 AND (1400 - famhist.FamilyTotal) <= 0 THEN 1
				WHEN cur.CS1_INT = 3 AND (1400 - famhist.FamilyTotal) <= 0 THEN 1 
				ELSE 0 
			END AS 'FamilyMetMax'
		FROM
			#EarnedIncentive cur
		JOIN
			(
			SELECT
				EligMemberID,
				SUM(CASE IncentiveCoverageTier WHEN 1 THEN 350 WHEN 2 THEN 700 WHEN 3 THEN 1400 END) AS 'FamilyTotal'
			FROM
				DA_Reports.providence.EarnedIncentiveReportLog
			WHERE
				Deleted = 0
			GROUP BY
				EligMemberID
			) famhist
			ON	(cur.EligMemberID = famhist.EligMemberID)
		GROUP BY
			cur.EligMemberID,
			cur.CS1_INT,
			famhist.FamilyTotal
		) famearn
		ON	(einc.EligMemberID= famearn.EligMemberID)
	WHERE
		(
		(earn.MemberID IS NULL) OR
		(earn.IndividualMetMax = 0 AND earn.EarnedAdditional = 1) 
		) 
		AND
		(
		 (famearn.EligMemberID IS NULL) OR
		 (famearn.FamilyMetMax = 0)
		)  

	-- RESULTS
	SELECT
		einc.EligMemberID AS [ContractID],
		einc.EligMemberID_Suffix AS [MemberID],
		earn.IncentiveCoverageTier,
		einc.CS6 AS [ProductType],
		einc.SubscriberFirstName,
		einc.SubscriberMiddleInitial,
		einc.SubscriberLastName,
		CASE WHEN ben.CS1_INT IS NULL THEN CONVERT(VARCHAR(8),einc.EarnedDate,112)
			 WHEN ben.CS1_INT IS NOT NULL AND (ben.CS1_INT < einc.CS1_INT) THEN CONVERT(VARCHAR(8),GETDATE(),112)
			 ELSE CONVERT(VARCHAR(8),einc.EarnedDate,112) END AS EarnedDate,
		einc.CS1 AS BenefitCoverageTier, 
		einc.CS8 AS EmployeeID,
		CONVERT(VARCHAR(10),GETDATE(),112) AS FileDate
	FROM
		#EarnedIncentive einc
	JOIN
		DA_Reports.providence.EarnedIncentiveReportLog earn
		ON	(einc.MemberID = earn.MemberID)
		AND	(DATEDIFF(dd,0,earn.DateReported) = DATEDIFF(dd,0,GETDATE()))
		AND	(DATEDIFF(dd,0,earn.AddedDate) = DATEDIFF(dd,0,GETDATE()))
		AND	(earn.ReportedTo = 'Providence_HSA')
	LEFT JOIN
		#LastBenefitCoverageTier ben
		ON	(einc.MemberID = ben.MemberID)
		AND	(ben.RevCS1Seq = 1)

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#BaseData') IS NOT NULL
	BEGIN
		DROP TABLE #BaseData
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#EarnedIncentive') IS NOT NULL
	BEGIN
		DROP TABLE #EarnedIncentive
	END

	IF OBJECT_ID('tempdb.dbo.#LastBenefitCoverageTier') IS NOT NULL
	BEGIN
		DROP TABLE #LastBenefitCoverageTier
	END

END
GO
