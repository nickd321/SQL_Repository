SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-12-30
-- Description:	Providence Incentives Activity
--
-- Notes:
--
-- Updates:		
-- =============================================

CREATE PROCEDURE [providence].[proc_Incentives_Activity] 

AS
BEGIN

	SET NOCOUNT ON;

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#BaseData') IS NOT NULL
	BEGIN
		DROP TABLE #BaseData
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('TempDB.dbo.#IncentiveDataFlat') IS NOT NULL
	BEGIN
		DROP TABLE #IncentiveDataFlat
	END

	-- BASE DATA TEMP
	CREATE TABLE #BaseData
	(
		MemberID INT,
		RelationshipID INT,
		EligMemberID VARCHAR(30),
		EligMemberSuffix CHAR(2),
		EligMemberID_Suffix VARCHAR(50),
		FirstName VARCHAR(80),
		MiddleInitial VARCHAR(10),
		LastName VARCHAR(80),
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
	EXEC [providence].[proc_Incentives_BaseData] 'All', 2

	-- INCENTIVE DATA TEMP
	SELECT
		*
	INTO 
		#Incentive
	FROM
		(
		SELECT
			MemberID,
			EligMemberID AS PHPID,
			EligMemberSuffix AS Suffix,
			CS8 AS EmployeeID,
			CS4 AS ProcessLevel,
			CS6 AS PlanCode,
			CS3 AS IncentivePlan,
			CASE WHEN CS3 = 1 THEN 1 ELSE 0 END AS OutcomesBased,
			RelationshipID,
			CASE
				WHEN ConformedActivity = 'BMI' THEN 'Outcomes'
				WHEN ConformedActivity = 'Cholesterol' THEN 'Outcomes'
				WHEN ConformedActivity = 'BP' THEN 'Outcomes'
				WHEN ConformedActivity = 'Tobacco' THEN 'Outcomes'
				ELSE ConformedActivity
			END AS Activity,
			ActivityDate,
			ActivityCreditDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID, ConformedActivity ORDER BY ActivityDate, ActivityCreditDate) AS ActivitySeq,
			CASE WHEN ConformedActivity = 'Coaching' THEN ROW_NUMBER() OVER (PARTITION BY MemberID, ConformedActivity ORDER BY ActivityCreditDate) ELSE 0 END AS CoachingSeq
		FROM
			#BaseData
		) data
	WHERE
		(ActivitySeq = 1 AND CoachingSeq = 0) OR
		(CoachingSeq = 4)

	-- INCENTIVE DATA FLAT TEMP
	SELECT DISTINCT
		inc.PHPID,
		inc.Suffix,
		inc.EmployeeID,
		inc.ProcessLevel,
		inc.PlanCode,
		inc.IncentivePlan,
		inc.OutcomesBased,
		inc.RelationshipID,
		CASE inc.OutcomesBased
			WHEN 1 THEN outcalt.ActivityDate
			ELSE NULL
		END AS OutcomesOrAlternative_ActivityDate,
		CASE inc.OutcomesBased
			WHEN 1 THEN outcalt.ActivityCreditDate
			ELSE NULL
		END AS OutcomesOrAlternative_ActivityCreditDate,
		bio.ActivityDate AS BioActivityDate,
		bio.ActivityCreditDate AS BioActivityCreditDate,
		CASE 
			WHEN inc.OutcomesBased = 0 AND inc.PlanCode IN ('HSA','HRA')
			THEN
				CASE
					WHEN bio.ActivityDate IS NOT NULL THEN 1
					ELSE 0
				END
			WHEN inc.OutcomesBased = 1 AND inc.PlanCode IN ('HSA','HRA') 
			THEN
				CASE
					-- ALASKA POP MAY EARN PARTIAL INCENTIVE, BUT EVALUATING IF MET FULL INCENTIVE
					WHEN inc.IncentivePlan = 1 AND bio.ActivityDate IS NOT NULL AND outcalt.ActivityDate IS NOT NULL THEN 1
					ELSE 0
				END
			WHEN inc.PlanCode = 'PRE'
			THEN
				CASE
					WHEN bio.ActivityDate IS NOT NULL THEN 1
					ELSE 0
				END		
		END AS MetIncentive
	INTO
		#IncentiveDataFlat
	FROM
		#Incentive inc
	LEFT JOIN
		#Incentive bio
		ON	(inc.MemberID = bio.MemberID)
		AND	(bio.Activity = 'BIO')
	LEFT JOIN
		(
		SELECT
			MemberID,
			'OutcomesOrAlternatives' AS Activity,
			ActivityDate,
			ActivityCreditDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ActivityDate) AS RowSeq
		FROM
			(
				SELECT
					MemberID,
					Activity,
					ActivityDate,
					ActivityCreditDate
				FROM
					#Incentive
				WHERE
					Activity = 'Coaching'
			UNION
				SELECT
					MemberID,
					Activity,
					ActivityDate,
					ActivityCreditDate
				FROM
					#Incentive
				WHERE
					Activity = 'SoTF'
			UNION
				SELECT
					MemberID,
					Activity,
					ActivityDate,
					ActivityCreditDate
				FROM
					(
					SELECT
						MemberID,
						Activity,
						ActivityDate,
						ActivityCreditDate,
						ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ActivityDate) AS 'OutcomesSeq'
					FROM
						#Incentive
					WHERE
						Activity = 'Outcomes'
					) outc
				WHERE
					OutcomesSeq = 4
			) data
		) outcalt
		ON	(inc.MemberID = outcalt.MemberID)
		AND	(outcalt.RowSeq = 1)
	WHERE
		bio.ActivityDate IS NOT NULL OR
		outcalt.ActivityDate IS NOT NULL


	-- RESULTS
	SELECT
		inc.PHPID,
		inc.Suffix,
		inc.EmployeeID,
		'BiometricsScreening' AS Activity,
		CONVERT(VARCHAR(10),inc.BioActivityDate,101) AS ActivityDate,
		CONVERT(VARCHAR(10),inc.BioActivityCreditDate,101) AS ActivityPostDate,
		ISNULL(CAST(lcc.LifestyleCreditCode AS VARCHAR(1)),'') AS LifestyleCreditCode,
		inc.ProcessLevel,
		inc.IncentivePlan
	FROM
		#IncentiveDataFlat inc
	LEFT JOIN
		(
		SELECT
			PHPID,
			CASE PlanCode
				WHEN 'PRE' THEN
					CASE SUM(MetIncentive)
						WHEN 2 THEN 5
						WHEN 1 THEN
							CASE MAX(RelationshipID)
								WHEN 6 THEN 1
								ELSE 3
							END
						ELSE NULL
					END
				ELSE NULL
			END AS LifestyleCreditCode
		FROM
			#IncentiveDataFlat
		GROUP BY
			PHPID,
			PlanCode
		) lcc
		ON	(inc.PHPID = lcc.PHPID)
	WHERE
		inc.BioActivityDate IS NOT NULL

	UNION

	SELECT
		inc.PHPID,
		inc.Suffix,
		inc.EmployeeID,
		'OutcomesOrAlternative' AS Activity,
		CONVERT(VARCHAR(10),inc.OutcomesOrAlternative_ActivityDate,101) AS ActivityDate,
		CONVERT(VARCHAR(10),inc.OutcomesOrAlternative_ActivityCreditDate,101) AS ActivityPostDate,
		'' AS LifestyleCreditCode,
		inc.ProcessLevel,
		inc.IncentivePlan
	FROM
		#IncentiveDataFlat inc
	WHERE
		inc.IncentivePlan = 1 AND 
		inc.PlanCode IN ('HSA','HRA') AND
		inc.OutcomesOrAlternative_ActivityDate IS NOT NULL
	ORDER BY
		inc.PHPID,
		inc.Suffix,
		Activity

	

END
GO
