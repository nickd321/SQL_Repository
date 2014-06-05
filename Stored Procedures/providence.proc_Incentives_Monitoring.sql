SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-12-17
-- Description:	Providence Incentives Data Monitoring
--
-- Notes:		
--
-- Updates:		
-- =============================================	


CREATE PROCEDURE [providence].[proc_Incentives_Monitoring]

AS
BEGIN

	SET NOCOUNT ON;
	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#ActivityData') IS NOT NULL
	BEGIN
		DROP TABLE #ActivityData
	END

	IF OBJECT_ID('tempdb.dbo.#Flat') IS NOT NULL
	BEGIN
		DROP TABLE #Flat
	END

	-- BASE TEMP
	CREATE TABLE #Base
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
		TerminationDate DATETIME
	)
	INSERT INTO #Base
	EXEC [providence].[proc_Incentives_BaseData] 'All', 3

	-- INCENTIVE TEMP
	CREATE TABLE #Incentive
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
	INSERT INTO #Incentive
	EXEC [providence].[proc_Incentives_BaseData] 'All', 2
	
	SELECT
		PHPID,
		Suffix,
		EmployeeID,
		ProcessLevel,
		PlanCode,
		IncentivePlan,
		OutcomesBased,
		RelationshipID,
		Activity,
		COUNT(Activity) AS ActivityCount
	INTO
		#ActivityData
	FROM
		(
		SELECT
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
			ROW_NUMBER() OVER (PARTITION BY MemberID, ConformedActivity  ORDER BY ActivityDate, ActivityCreditDate) AS ActivitySeq,
			CASE WHEN ConformedActivity = 'Coaching' THEN ROW_NUMBER() OVER (PARTITION BY MemberID, ConformedActivity ORDER BY ActivityCreditDate) ELSE 0 END AS CoachingSeq 
		FROM
			#Incentive 
		) data
	WHERE
		(ActivitySeq = 1 AND CoachingSeq = 0) OR
		(CoachingSeq >= 1)
	GROUP BY
		PHPID,
		Suffix,
		EmployeeID,
		ProcessLevel,
		PlanCode,
		IncentivePlan,
		OutcomesBased,
		RelationshipID,
		Activity

	UNION ALL

	SELECT
		mem.EligMemberID AS PHPID,
		mem.EligMemberSuffix AS Suffix,
		mem.CS8 AS EmployeeID,
		mem.CS4 AS ProcessLevel,
		mem.CS6 AS PlanCode,
		mem.CS3 AS IncentivePlan,
		CASE WHEN mem.CS3 = 1 THEN 1 ELSE 0 END AS OutcomesBased,
		mem.RelationshipID,
		'ScheduledAppointment' AS Activity,
		COUNT(app.AppointmentID) AS ActivityCount
	FROM
		#Base mem
	JOIN
		DA_Production.prod.Appointment app 
		ON	(mem.MemberID = app.MemberID)
		AND	(app.AppointmentStatusID = 1)
		AND	(app.AppointmentBeginDate > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))
	GROUP BY
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.CS8,
		mem.CS4,
		mem.CS6,
		mem.CS3,
		CASE WHEN mem.CS3 = 1 THEN 1 ELSE 0 END,
		mem.RelationshipID

	-- INCENTIVE PLAN 1
	SELECT
		IncentivePlan,
		CASE
			WHEN RelationshipID = 6 THEN 'Primary'
			ELSE 'Spouse'
		END AS Relationship,
		ISNULL(SUM([BIO]),0) AS 'Bio',
		COUNT(CASE WHEN [Outcomes] >= 4 THEN PHPID END) AS 'Outcomes',
		COUNT(CASE WHEN [SoTF] = 1 OR [Coaching] >= 4 THEN PHPID END) AS 'Alternatives',
		ISNULL(SUM([SoTF]),0) AS 'SoTF',
		COUNT(CASE WHEN [Coaching] >= 4 THEN PHPID END) AS 'Coach4',
		COUNT(CASE WHEN [Coaching] = 3 THEN PHPID END) AS 'Coach3',
		COUNT(CASE WHEN [Coaching] = 2 THEN PHPID END) AS 'Coach2',
		COUNT(CASE WHEN [Coaching] = 1 THEN PHPID END) AS 'Coach1',
		COUNT(CASE WHEN [ScheduledAppointment] >= 1 THEN PHPID END) AS 'Appt',
		COUNT(CASE WHEN [BIO] = 1
						AND ([Outcomes] >= 4 OR [SoTF] = 1 OR [Coaching] >= 4)
				   THEN PHPID END) AS 'Bio_OutcOrAlt',
		COUNT(CASE WHEN [BIO] = 1 AND [Outcomes] >= 4 THEN PHPID END) AS 'Bio_Outc',
		COUNT(CASE WHEN [BIO] = 1
						AND	ISNULL([Outcomes],0) < 4
						AND	([SoTF] = 1 OR [Coaching] >= 4)
				   THEN PHPID END) AS 'Bio_OutcNotMet_Alt',
		COUNT(CASE WHEN [BIO] = 1
						AND	ISNULL([Outcomes],0) < 4
						AND	[SoTF] = 1
				   THEN PHPID END) AS 'Bio_OutcNotMet_SoTF',
		COUNT(CASE WHEN [BIO] = 1
						AND	ISNULL([Outcomes],0) < 4
						AND	[Coaching] >= 4
				   THEN PHPID END) AS 'Bio_OutcNotMet_Coach4',
		COUNT(CASE WHEN [BIO] = 1
						AND ISNULL([Outcomes],0) < 4 
						AND ISNULL([SoTF],0) = 0
						AND [Coaching] = 3 
				   THEN PHPID END) AS 'Bio_OutcOrAltNotMet_Coach3',
		COUNT(CASE WHEN [BIO] = 1
						AND	ISNULL([Outcomes],0) < 4
						AND ISNULL([SoTF],0) = 0 
						AND [Coaching] = 2
				   THEN PHPID END) AS 'Bio_OutcOrAltNotMet_Coach2',
		COUNT(CASE WHEN [BIO] = 1
						AND ISNULL([Outcomes],0) < 4 
						AND ISNULL([SoTF],0) = 0 
						AND [Coaching] = 1
				   THEN PHPID END) AS 'Bio_OutcOrAltNotMet_Coach1',
	    COUNT(CASE WHEN [BIO] = 1
						AND ISNULL([Outcomes],0) < 4 
						AND ISNULL([SoTF],0) = 0 
						AND [Coaching] = 3 
						AND [ScheduledAppointment] >= 1
				   THEN PHPID END) AS 'Bio_OutcOrAltNotMet_Coach3_Appt',
		COUNT(CASE WHEN [BIO] = 1
						AND ISNULL([Outcomes],0) < 4 
						AND ISNULL([SoTF],0) = 0 
						AND [Coaching] = 2 
						AND [ScheduledAppointment] >= 1
				   THEN PHPID END) AS 'Bio_OutcOrAltNotMet_Coach2_Appt',
		COUNT(CASE WHEN [BIO] = 1
						AND ISNULL([Outcomes],0) < 4 
						AND ISNULL([SoTF],0) = 0 
						AND [Coaching] = 1
						AND [ScheduledAppointment] >= 1
				   THEN PHPID END) AS 'Bio_OutcOrAltNotMet_Coach1_Appt',
		COUNT(CASE WHEN [BIO] = 1
						AND ISNULL([Outcomes],0) < 4
						AND	ISNULL([SoTF],0) = 0
						AND ISNULL([Coaching],0) = 0
						AND	[ScheduledAppointment] >= 1
				   THEN PHPID END) AS 'Bio_OutcOrAltNotMet_Coach0_Appt'
	INTO
		#Flat
	FROM
		#ActivityData
	PIVOT
		(
		MAX(ActivityCount) FOR Activity IN ([BIO],[Outcomes],[SoTF],[Coaching],[ScheduledAppointment])
		) pvt
	WHERE
		IncentivePlan = 1
	GROUP BY
		IncentivePlan,
		CASE
			WHEN RelationshipID = 6 THEN 'Primary'
			ELSE 'Spouse'
		END
	ORDER BY
		1,2		

	SELECT
		IncentivePlan,
		Measure,
		[Primary],
		Spouse
	FROM
		(
		SELECT
			IncentivePlan,
			'Bio' AS Measure,
			SUM(CASE WHEN RelationshipID = 6 THEN ActivityCount END) AS [Primary],
			SUM(CASE WHEN RelationshipID !=6 THEN ActivityCount END) AS Spouse,
			'01' AS DisplayOrder
		FROM
			#ActivityData
		WHERE
			Activity = 'BIO' AND
			IncentivePlan != 1
		GROUP BY
			IncentivePlan

		UNION ALL 

		SELECT
			IncentivePlan,
			Measure,
			[Primary],
			Spouse,
			CASE
				WHEN Measure = 'Bio' THEN '00'
				WHEN Measure = 'Outcomes' THEN '01'
				WHEN Measure = 'Alternatives' THEN '02'
				WHEN Measure = 'SoTF' THEN '03'
				WHEN Measure = 'Coach4' THEN '04'
				WHEN Measure = 'Coach3' THEN '05'
				WHEN Measure = 'Coach2' THEN '06'
				WHEN Measure = 'Coach1' THEN '07'
				WHEN Measure = 'Appt' THEN '08'
				WHEN Measure = 'Bio_OutcOrAlt' THEN '09'
				WHEN Measure = 'Bio_Outc' THEN '10'
				WHEN Measure = 'Bio_OutcNotMet_Alt' THEN '11'
				WHEN Measure = 'Bio_OutcNotMet_SoTF' THEN '12'
				WHEN Measure = 'Bio_OutcNotMet_Coach4' THEN '13'
				WHEN Measure = 'Bio_OutcOrAltNotMet_Coach3' THEN '14'
				WHEN Measure = 'Bio_OutcOrAltNotMet_Coach2' THEN '15'
				WHEN Measure = 'Bio_OutcOrAltNotMet_Coach1' THEN '16'
				WHEN Measure = 'Bio_OutcOrAltNotMet_Coach3_Appt' THEN '17'
				WHEN Measure = 'Bio_OutcOrAltNotMet_Coach2_Appt' THEN '18'
				WHEN Measure = 'Bio_OutcOrAltNotMet_Coach1_Appt' THEN '19'
				WHEN Measure = 'Bio_OutcOrAltNotMet_Coach0_Appt' THEN '20'
			END AS DisplayOrder
		FROM
			(
				SELECT
					IncentivePlan,
					Relationship,
					Measure,
					MeasureValue
				FROM
					#Flat
					UNPIVOT
					(
					MeasureValue
						FOR Measure IN 
								([Bio],[Outcomes],[Alternatives],[SoTF],[Coach4],[Coach3],[Coach2],[Coach1],
								 [Appt],[Bio_OutcOrAlt],[Bio_Outc],[Bio_OutcNotMet_Alt],[Bio_OutcNotMet_SoTF],
								 [Bio_OutcNotMet_Coach4],[Bio_OutcOrAltNotMet_Coach3],[Bio_OutcOrAltNotMet_Coach2],
								 [Bio_OutcOrAltNotMet_Coach1],[Bio_OutcOrAltNotMet_Coach3_Appt],[Bio_OutcOrAltNotMet_Coach2_Appt],
								 [Bio_OutcOrAltNotMet_Coach1_Appt],[Bio_OutcOrAltNotMet_Coach0_Appt])
					) unpvt
			) data
			PIVOT
			(
			MAX(MeasureValue) FOR Relationship IN ([Primary],[Spouse])
			) pvt
	
		) data
	ORDER BY
		IncentivePlan,
		DisplayOrder

END
GO
