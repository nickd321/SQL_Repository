SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 1/8/2014
-- Description:	This procedure acts as the source for the
--				PepsiCo Wellness Participation SSRS report.
--
-- Update:		NickD 2014-10-13: After some QA with Will, 
--				the SQL has been greatly simplified
--				
--				NickD 2014-10-17: Added a number of left join
--				in-line views to get easy filters for the SSRS
--				component of the report.
-- =============================================

CREATE PROCEDURE [pepsico].[proc_Participation]

AS
	BEGIN

	SET NOCOUNT ON;

		IF OBJECT_ID('tempdb.dbo.#Eligible') IS NOT NULL
	BEGIN
		DROP TABLE #Eligible
	END

	IF OBJECT_ID('tempdb.dbo.#IncentiveActivity') IS NOT NULL
	BEGIN
		DROP TABLE #IncentiveActivity
	END

	IF OBJECT_ID('tempdb.dbo.#EligActivityDenorm') IS NOT NULL
	BEGIN
		DROP TABLE #EligActivityDenorm
	END

	SELECT
		'1/1/2014' AS BeginDate,
		CONVERT(DATE, GETDATE() - 1) AS EndDate,
		mem.GroupID,
		mem.MemberID,
		mem.RelationshipID,
		CASE
			WHEN mem.RelationshipID = 6
			THEN 'EE'
			ELSE 'Spouse'
		END AS [Relationship],
		ISNULL(csf.CS14, '') AS [CS2], -- Division
		ISNULL(csf.CS15, '') AS [CS1], -- LocationName
		ISNULL(csf.CS16, '') AS [CS3], -- LocationCode
		eli.EffectiveDate,
		eli.TerminationDate
	INTO
		#Eligible
	FROM
		[DA_Production].[prod].[Eligibility] eli 
	JOIN
		[DA_Production].[prod].[Member] mem 
		ON	(eli.MemberID = mem.MemberID) 
	JOIN
		(
		SELECT
			MemberID,
			EffectiveDate,
			TerminationDate, 
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate, '2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.Eligibility WITH (NOLOCK)
		WHERE
			GroupID = 206772
		) elig
		ON	(mem.MemberID = elig.MemberID) 
		AND (elig.RevTermSeq = 1) 
		AND (ISNULL(elig.TerminationDate, '2999-12-31') > DATEADD(dd, DATEDIFF(dd, 0, GETDATE()), 0)) 
	LEFT JOIN
		[DA_Production].[prod].[CSFields] csf 
		ON	(csf.MemberID = mem.MemberID)
	WHERE
		ISNULL(csf.CS21, '') NOT IN ('LTD', 'X')
		AND ISNULL(csf.CS5, '') = 'Y' 

	SELECT
		pln.GroupID,
		mai.MemberID,
		pln.ClientIncentivePlanID,
		pln.PlanStart,
		pln.PlanEnd,
		act.ActivityItemCode,
		act.ActivityItemID,
		act.ActivityID,
		act.ActivityDescription,
		act.AI_Name,
		act.AI_Instruction,
		act.AI_Start,
		act.AI_End,
		mai.ActivityDate,
		mai.ActivityValue,
		mai.AddDate
	INTO
		#IncentiveActivity
	FROM
		DA_Reports.incentives.[Plan] pln
	JOIN
		DA_Reports.incentives.[PlanActivity] act
		ON	(pln.ClientIncentivePlanID = act.ClientIncentivePlanID)
		AND	(act.Expired = 0)
	JOIN
		Incentive.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
		ON	(act.ClientIncentivePlanID = mai.ClientIncentivePlanID)
		AND	(act.ActivityItemID = mai.ActivityItemID)
		AND	(mai.Deleted = 0)
	JOIN
		#Eligible elig
		ON	(mai.MemberID = elig.MemberID)
	WHERE
		pln.Expired = 0 AND
		pln.GroupID = 206772 AND
		act.ActivityItemCode IN ('PRIMARYPHA','BIOMETRICSCREENING','BIOMETRICOUTCOMES','LIFESTYLECOACHINGSESSIONS','01020201')

	SELECT
		'1/1/2014' AS BeginDate,
		CONVERT(DATE, GETDATE() - 1) AS EndDate,
		elig.GroupID,
		elig.MemberID,
		elig.RelationshipID,
		elig.Relationship,
		elig.CS2,
		CASE WHEN lessfifty.EmployeeCount IS NOT NULL THEN 'Locations with < 50 Employees' ELSE (CASE WHEN elig.CS1 = '' THEN 'No Description - ' + elig.CS3 ELSE elig.CS1 END) END AS [CS1],
		CASE WHEN lessfifty.EmployeeCount IS NOT NULL THEN 'Locations with < 50 Employees' ELSE elig.CS3 END AS [CS3],
		1 AS [Eligible],
		ISNULL(act.PRIMARYPHA,0) AS [PHANumberYes],
		ISNULL(act.BIOMETRICSCREENING,0) AS [BioNumberYes],
		CASE WHEN ISNULL(act.BIOMETRICOUTCOMES,0) < 1 AND ISNULL(act.BIOMETRICSCREENING,0) = 1 THEN 1 ELSE 0 END AS [DidNotMeetBiometric],
		ISNULL(act.LIFESTYLECOACHINGSESSIONS,0) AS [CompletedCoaching],
		ISNULL(act.[01020201],0) AS [ApptNumberYes],
		CASE WHEN lessfifty.EmployeeCount IS NOT NULL THEN 1 ELSE 0 END AS [LessThan50],
		CASE WHEN greateqfifty.EmployeeCount IS NOT NULL THEN 1 ELSE 0 END AS [GreaterThanEqualTo50]
	INTO
		#EligActivityDenorm
	FROM
		#Eligible elig
	LEFT JOIN
		(
		SELECT
			MemberID,
			ISNULL([PRIMARYPHA],0) AS [PRIMARYPHA],
			ISNULL([BIOMETRICSCREENING],0) AS [BIOMETRICSCREENING],
			ISNULL([BIOMETRICOUTCOMES],0) AS [BIOMETRICOUTCOMES],
			ISNULL([LIFESTYLECOACHINGSESSIONS],0) AS [LIFESTYLECOACHINGSESSIONS],
			MIN(ISNULL([01020201],0)) AS [01020201]
			
		FROM
			(
			SELECT
				MemberID,
				ActivityItemCode AS [Measure],
				1 AS [MeasureValue]
			FROM
				#IncentiveActivity
			) inc
		PIVOT
			(
			MIN(MeasureValue) FOR Measure IN ([PRIMARYPHA],[BIOMETRICSCREENING],[BIOMETRICOUTCOMES],[LIFESTYLECOACHINGSESSIONS],[01020201])
			) pvt
			GROUP BY 
			MemberID,
			ISNULL([PRIMARYPHA],0),
			ISNULL([BIOMETRICSCREENING],0),
			ISNULL([BIOMETRICOUTCOMES],0),
			ISNULL([LIFESTYLECOACHINGSESSIONS],0)
		) act
		ON	(elig.MemberID = act.MemberID)
		
	LEFT JOIN
		(
		SELECT
			'LessThan50' AS MeasureName,
			CS3,
			CS2,
			COUNT(MemberID) AS EmployeeCount
		FROM
			#Eligible
		WHERE
			Relationship = 'EE'
		GROUP BY
			CS3,
			CS2
		HAVING
			COUNT(MemberID) < 50
		) lessfifty
		ON	(elig.CS2 = lessfifty.CS2)
		AND	(elig.CS3 = lessfifty.CS3)
	LEFT JOIN
		(
		SELECT
			'GreaterThanEqualTo50' AS MeasureName,
			CS3,
			CS2,
			COUNT(MemberID) AS EmployeeCount
		FROM
			#Eligible
		WHERE
			Relationship = 'EE'
		GROUP BY
			CS3,
			CS2
		HAVING COUNT(MemberID) >= 50
		) greateqfifty
		ON	(elig.CS2 = greateqfifty.CS2)
		AND	(elig.CS3 = greateqfifty.CS3)

	SELECT
		norm.*,
		locperc.PRIMARYPHA AS [PHAPercentage],
		divperc.PRIMARYPHA AS [divPHAPercentage],
		CASE WHEN lesstwohundred.EmployeeCount IS NOT NULL THEN 'LessThan200' ELSE norm.CS3 END AS [LessThan200],
		CASE WHEN greatertwohundred.EmployeeCount IS NOT NULL THEN 'GreaterThanEqualTo200' ELSE norm.CS3 END AS [GreaterThanEqualTo200],
		CASE WHEN lesstwohundredloc.EmployeeCount IS NOT NULL THEN 'LessThan200' ELSE norm.CS3 END AS [LessThan200loc],
		CASE WHEN greatertwohundredloc.EmployeeCount IS NOT NULL THEN 'GreaterThanEqualTo200' ELSE norm.CS3 END AS [GreaterThanEqualTo200loc]
		
	FROM
		#EligActivityDenorm norm
	LEFT JOIN --This inline view calculates a percentage that is simpler to display in SSRS
		(
		SELECT
			CS1,
			CS3,
			Relationship,
			CONVERT(float,COUNT(ActivityItemCode))/CONVERT(float,COUNT(Eligible)) AS PRIMARYPHA
		FROM
			#EligActivityDenorm a
		LEFT JOIN
			#IncentiveActivity b
			ON	(a.MemberID = b.MemberID)
			AND (ActivityItemCode = 'PRIMARYPHA')
		GROUP BY
			CS1,
			CS3,
			Relationship
		) locperc
		ON	norm.CS1 = locperc.CS1
		AND	norm.CS3 = locperc.CS3
		AND norm.Relationship = locperc.Relationship
		
	LEFT JOIN --This inline view calculates a percentage that is simpler to display in SSRS
		(
		SELECT
			CS1,
			CS3,
			CS2,
			Relationship,
			CONVERT(float,COUNT(ActivityItemCode))/CONVERT(float,COUNT(Eligible)) AS PRIMARYPHA
		FROM
			#EligActivityDenorm a
		LEFT JOIN
			#IncentiveActivity b
			ON	(a.MemberID = b.MemberID)
			AND (ActivityItemCode = 'PRIMARYPHA')
		GROUP BY
			CS1,
			CS3,
			CS2,
			Relationship
		) divperc
		ON	norm.CS1 = divperc.CS1
		AND	norm.CS3 = divperc.CS3
		AND norm.CS2 = divperc.CS2
		AND norm.Relationship = divperc.Relationship
		
	LEFT JOIN
		(
		SELECT
			'LessThan200' AS MeasureName,
			CS3,
			CS2,
			COUNT(MemberID) AS EmployeeCount
		FROM
			#Eligible
		WHERE
			Relationship = 'EE'
		GROUP BY
			CS3,
			CS2
		HAVING 
			COUNT(MemberID) >= 50
			AND COUNT(MemberID) < 200
		) lesstwohundred
		ON	(norm.CS2 = lesstwohundred.CS2)
		AND	(norm.CS3 = lesstwohundred.CS3)
	
	LEFT JOIN
		(
		SELECT
			'GreaterThanEqualTo200' AS MeasureName,
			CS3,
			CS2,
			COUNT(MemberID) AS EmployeeCount
		FROM
			#Eligible
		WHERE
			Relationship = 'EE'
		GROUP BY
			CS3,
			CS2
		HAVING COUNT(MemberID) >= 200
		) greatertwohundred
		ON	(norm.CS2 =  greatertwohundred.CS2)
		AND	(norm.CS3 =  greatertwohundred.CS3)
		
	LEFT JOIN
		(
		SELECT
			'LessThan200' AS MeasureName,
			CS3,
			COUNT(MemberID) AS EmployeeCount
		FROM
			#Eligible
		WHERE
			Relationship = 'EE'
		GROUP BY
			CS3
		HAVING 
			COUNT(MemberID) >= 50
			AND COUNT(MemberID) < 200
		) lesstwohundredloc
		ON	(norm.CS3 = lesstwohundredloc.CS3)
	
	LEFT JOIN
		(
		SELECT
			'GreaterThanEqualTo200' AS MeasureName,
			CS3,
			COUNT(MemberID) AS EmployeeCount
		FROM
			#Eligible
		WHERE
			Relationship = 'EE'
		GROUP BY
			CS3
		HAVING COUNT(MemberID) >= 200
		) greatertwohundredloc
		ON	(norm.CS3 =  greatertwohundredloc.CS3)
			



END
GO
