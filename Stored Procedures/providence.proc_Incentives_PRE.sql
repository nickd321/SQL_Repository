SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-12-17
-- Description:	Providence Incentives Data for Premium Credit
--
-- Notes:
--
-- Updates:		WilliamPe 20131230
--				Modified code to support new @inReportType parameter passed to grab the base data	
--
--				WilliamPe 20140108
--				Added ReportedTo = 'Providence_PRE' to final results query
-- =============================================

CREATE PROCEDURE [providence].[proc_Incentives_PRE] 
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

	IF OBJECT_ID('tempdb.dbo.#FinalIncentiveTable') IS NOT NULL
	BEGIN
		DROP TABLE #FinalIncentiveTable
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
		IsCurrentlyEligible BIT,
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
	EXEC [providence].[proc_Incentives_BaseData] 'PRE', 1
		

	-- INCENTIVE TEMP TABLE
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
			CS8 AS [EmployeeID],
			CS9,
			CS10 AS [PlanCode],
			CS1_INT,
			ClientIncentivePlanID,
			ActivityItemID,
			Activity,
			ConformedActivity,
			ActivityDate,
			ActivityValue,
			ActivityCreditDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID, ConformedActivity ORDER BY ActivityDate, ActivityCreditDate) AS [ActivitySeq]
		FROM
			#BaseData
		WHERE
			CS3 IN ('2','4')  AND
			ConformedActivity = 'BIO'
		) data
	WHERE
		ActivitySeq = 1 
	
	-- FINAL INCENTIVE TEMP
	SELECT
		'C' AS [EmpFc],
		55 AS [EmpCompany],
		EmployeeID AS [EmpEmployee],
		1 AS [PepPosLevel],
		CONVERT(VARCHAR(10),GETDATE(),101) AS [PepEffectDate],
		CASE
			WHEN EE_EarnedDate IS NOT NULL AND SP_EarnedDate IS NULL THEN 1--EE Only
			WHEN EE_EarnedDate IS NULL AND SP_EarnedDate IS NOT NULL THEN 3 --SP/ABR Only
			WHEN EE_EarnedDate IS NOT NULL AND SP_EarnedDate IS NOT NULL THEN 5 --Both
		END AS [PemLifestyleCr],
		CONVERT(VARCHAR(10),MaxEarnedDate,112) AS [MaxEarnedDate]
	INTO
		#FinalIncentiveTable
	FROM
		(
			SELECT
				EmployeeID,
				PlanCode,
				EE_EarnedDate,
				SP_EarnedDate,
				dbo.func_MAX_DATETIME(EE_EarnedDate,SP_EarnedDate) AS MaxEarnedDate
			FROM
				(	
					SELECT
						'EE_EarnedDate' AS 'MeasureName',
						 EmployeeID,
						 PlanCode,
						 ActivityCreditDate AS 'MeasureValue'
					FROM
						#Incentive
					WHERE
						RelationshipID = 6
				
					UNION ALL
				
					SELECT
						'SP_EarnedDate' AS 'MeasureName',
						 EmployeeID,
						 PlanCode,
						 ActivityCreditDate AS 'MeasureValue'
					FROM
						#Incentive
					WHERE
						RelationshipID IN (1,2)
				) subset
				PIVOT 
				(
					MAX(MeasureValue) FOR MeasureName IN ([EE_EarnedDate],
														  [SP_EarnedDate])
				) pvt
		) data
	WHERE
		MaxEarnedDate < @inEndDate
	

	-- DELETE DATA IF ALREADY RAN TODAY
	DELETE DA_Reports.providence.EarnedIncentiveReportLog
	WHERE
		DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
		DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE()) AND
		ReportedTo = 'Providence_PRE'
	
	
	-- INSERT TO REPORT LOG
	INSERT INTO DA_Reports.providence.EarnedIncentiveReportLog
	SELECT
		inc.MemberID,
		inc.EligMemberID,
		inc.EligMemberSuffix,
		inc.EligMemberID_Suffix,
		inc.CS1,
		inc.CS3,
		inc.CS6,
		inc.EmployeeID, -- CS8
		inc.CS9,
		inc.PlanCode, -- CS10,
		inc.CS1_INT,
		NULL AS [IncentiveCoverageTier],
		final.PemLifestyleCr AS [PremiumLifestyleCreditCode],
		GETDATE() AS [DateReported],
		'Providence_PRE' AS [ReportedTo],
		@inEndDate AS [ReportEndDate],
		GETDATE() AS [AddedDate],
		'UserStoredProcedure' AS [AddedBy],
		NULL AS [ModifiedBy],
		NULL AS [Notes],
		0 AS Deleted
	FROM
		#Incentive inc
	LEFT JOIN
		DA_Reports.providence.EarnedIncentiveReportLog prov
		ON	(inc.MemberID = prov.MemberID)
		AND	(prov.Deleted = 0)
	JOIN
		#FinalIncentiveTable final
		ON	(final.EmpEmployee = inc.EmployeeID)
	WHERE
		prov.MemberID IS NULL OR
		(prov.MemberID IS NULL AND 
		 prov.PremiumLifestyleCreditCode < final.PemLifestyleCr AND
		 final.PemLifestyleCr = 5)

	-- RESULTS
	SELECT
		final.EmpFc,
		final.EmpCompany,
		final.EmpEmployee,
		final.PepPosLevel,
		final.PepEffectDate,
		final.PemLifeStyleCr,
		final.MaxEarnedDate
	FROM
		#FinalIncentiveTable final
	JOIN
		(
		SELECT
			inc.EmployeeID
		FROM
			#Incentive inc
		JOIN
			DA_Reports.providence.EarnedIncentiveReportLog prov
			ON	(inc.MemberID = prov.MemberID)
			AND	(DATEDIFF(dd,0,prov.DateReported) = DATEDIFF(dd,0,GETDATE()))
			AND	(DATEDIFF(dd,0,prov.AddedDate) = DATEDIFF(dd,0,GETDATE()))
			AND	(prov.ReportedTo = 'Providence_PRE')
		) prov
		ON	(final.EmpEmployee = prov.EmployeeID)
	GROUP BY
		final.EmpFc,
		final.EmpCompany,
		final.EmpEmployee,
		final.PepPosLevel,
		final.PepEffectDate,
		final.PemLifeStyleCr,
		final.MaxEarnedDate

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#BaseData') IS NOT NULL
	BEGIN
		DROP TABLE #BaseData
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#FinalIncentiveTable') IS NOT NULL
	BEGIN
		DROP TABLE #FinalIncentiveTable
	END

END
GO
