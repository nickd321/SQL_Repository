
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-06-05
-- Description:	ACEC Incentives Report
--
-- Notes: 
--
--
--
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [acec].[proc_Incentives] 
--Testing
AS
BEGIN

	SET NOCOUNT ON;
	
-- DECLARES
	DECLARE 
	@loc_BeginJulDate DATETIME,
	@loc_BeginJanDate DATETIME,
	@loc_End DATETIME

-- SETS
	-- THIS LOGIC IS CONSIDERING REPORTING PERIODS
	-- THE MONTH AFTER THE INCENTIVE PLAN ENDS IS THE LAST REPORTING MONTH. THEN, THE BEGIN DATES WILL RESET
	SET @loc_BeginJulDate = (CASE WHEN MONTH(GETDATE()) >= 8 
												  THEN '7' + '/' + '1' + '/' + CAST(YEAR(GETDATE()) AS CHAR(4)) 
												  ELSE '7' + '/' + '1' + '/' + CAST(YEAR(GETDATE()) - 1 AS CHAR(4)) END
							   )
	SET @loc_BeginJanDate = (CASE WHEN MONTH(GETDATE()) = 1 
												  THEN DATEADD(yy,DATEDIFF(yy,0,GETDATE())-1,0) 
												  ELSE DATEADD(yy,DATEDIFF(yy,0,GETDATE()),0) END
							   )

	SET @loc_End = DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)
	                           

-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#CSFields') IS NOT NULL BEGIN DROP TABLE #CSFields END
	IF OBJECT_ID('tempdb.dbo.#IncentiveGroups') IS NOT NULL BEGIN DROP TABLE #IncentiveGroups END
	IF OBJECT_ID('tempdb.dbo.#IncentivePlanID') IS NOT NULL BEGIN DROP TABLE #IncentivePlanID END
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL BEGIN DROP TABLE #Incentive END


-- GET GROUPS WITH INCENTIVE BENEFIT
	SELECT
		grp.GroupID,
		grp.GroupName
	INTO
		#IncentiveGroups
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.GroupBenefit ben WITH (NOLOCK)
		ON	(grp.GroupID = ben.GroupID)
		AND	(ben.BenefitDescription LIKE '%Incentives%')
		AND (ISNULL(ben.TerminationDate,'2999-12-31') >= DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))
	WHERE
		grp.HealthPlanID = 175
	GROUP BY
		grp.GroupName,
		grp.GroupID	



-- GET CURRENT CS FIELDS
	SELECT
		*
	INTO
		#CSFields
	FROM
		(
			SELECT
				MemberID,
				CS1,
				CS2,
				SourceAddDate,
				AddDate,
				ArchiveDate,
				ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AddDate DESC) AS AddDateRevSeq
			FROM
				(
				SELECT
					csp.MemberID,
					csp.CS1,
					csp.CS2,
					csp.SourceAddDate,
					csp.AddDate,
					NULL AS ArchiveDate
				FROM
					#IncentiveGroups grp
				JOIN
					DA_Production.prod.CSFields csp WITH (NOLOCK)
					ON	(grp.GroupID = csp.GroupID)
				
				UNION ALL
				
				SELECT
					csa.MemberID,
					csa.CS1,
					csa.CS2,
					csa.SourceAddDate,
					csa.AddDate,
					csa.ArchiveDate
				FROM
					#IncentiveGroups grp
				JOIN
					DA_Production.archive.CSFields csa WITH (NOLOCK)
					ON	(grp.GroupID = csa.GroupID)
				) cs
			WHERE
				AddDate < DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)
		) data
	WHERE
		AddDateRevSeq = 1
	
	-- GET INCENTIVE PLAN IDs
	SELECT
		pln.ClientIncentivePlanID
	INTO
		#IncentivePlanID
	FROM
		#IncentiveGroups grp
	JOIN
		DA_Production.prod.GroupIncentivePlan pln WITH (NOLOCK)
		ON	(grp.GroupID = pln.GroupID)
	WHERE
		pln.IncentiveBeginDate IN (@loc_BeginJulDate, @loc_BeginJanDate)
	GROUP BY
		pln.ClientIncentivePlanID

-- GET INCENTIVE DATA
	SELECT
		mem.MemberID,
		mem.GroupID,
		grp.GroupName,
		mem.EligMemberID,
		mem.FirstName,
		mem.LastName,
		mem.EligMemberSuffix,
		mem.Relationship,
		cs.CS1,
		CASE WHEN cs.CS1 IN (1,4) THEN 1
			 WHEN cs.CS1 IN (2,5) THEN 2
			 WHEN cs.CS1 IN (3,6) THEN 3
			 WHEN cs.CS1 IN (7,8) THEN 4
			 ELSE NULL
			 END AS IncentiveOption, 
		cs.CS2 AS MedicalCoverage,
		CASE WHEN elig.MemberID IS NOT NULL THEN 'Y' ELSE '' END AS IsCurrentlyEligible,
		CASE WHEN cs.CS1 IN (1,2,3,7) THEN 1
			 WHEN cs.CS1 IN (4,5,6,8) THEN 2
			 ELSE NULL END AS CS1_IncentiveStart_INT,
		CASE WHEN cs.CS1 IN (1,2,3,7) THEN @loc_BeginJulDate
			 WHEN cs.CS1 IN (4,5,6,8) THEN @loc_BeginJanDate
			 ELSE NULL END AS CS1_IncentiveStart_DATE, -- REFRAINED FROM USING THE EFFECTIVE DATE FROM THE INCENTIVE TABLE SINCE IT SEEMS THAT NOT ALL THE RECORDS 
			                                           -- UNDER A MEMBER REFLECT A CONSISTENT INCENTIVE EFFECTIVE DATE.  
		inc.IncentiveEffectiveDate,
		inc.IncentiveExpiresDate,
		CASE WHEN MONTH(inc.IncentiveEffectiveDate) = 7 THEN 1
			 WHEN MONTH(inc.IncentiveEffectiveDate) = 1 THEN 2
			 ELSE NULL END AS INC_IncentiveStart_INT, 
		inc.FK_ClientIncentivePlanID,		
		inc.ActivityDate,
		CASE inc.ActivityDescription
			WHEN 'Personal Health Assessment (Primary)' THEN 'PHA'
			WHEN 'Biometrics Screening' THEN 'Bio'
			WHEN 'Phone-Based Coaching Session' THEN 'Phone'
			WHEN 'E-Coaching Course' THEN 'E-Coaching'
			WHEN 'Worksite Health Challenge' THEN 'Challenge'
			WHEN 'Cardio Planner' THEN 'Cardio'
			WHEN 'Strength Planner' THEN 'Strength'
			WHEN 'Meal/Nutrition Planner' THEN 'Meal'
			WHEN 'Incentives Questionnaire' THEN 'Questionnaire'
			ELSE inc.ActivityDescription
			END AS ActivityDescription,
		inc.PointsValue,
		inc.RecordEffectiveBeginDate
	INTO
		#Incentive
	FROM
		#IncentiveGroups grp
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.RelationshipID IN (6,1))
	LEFT JOIN
		(
		SELECT
			MemberID,
			EffectiveDate,
			TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.Eligibility elig WITH (NOLOCK)
		JOIN
			#IncentiveGroups grp
			ON	(elig.GroupID = grp.GroupID)
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)
		AND	(ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))
	LEFT JOIN
		#CSFields cs
		ON	(mem.MemberID = cs.MemberID)
		AND	(cs.AddDateRevSeq = 1)
	JOIN
		(
		SELECT
			act.*
		FROM
			#IncentivePlanID pln
		JOIN
			[ASH-HRLReports].HrlDw.dbo.vwMemberIncentiveActivity_WithHistory act WITH (NOLOCK)
			ON	(pln.ClientIncentivePlanID = act.FK_ClientIncentivePlanID)
		WHERE
			act.RecordEffectiveEndDate IS NULL AND
			act.ActivityDate < @loc_End
		) inc
		ON	(mem.MemberID = inc.MemberID)

-- DELETE 

	DELETE #Incentive
	WHERE
		CS1_IncentiveStart_INT != INC_IncentiveStart_INT AND
		ActivityDate < CS1_IncentiveStart_DATE
		
	
-- SUMMARY 7/1
	SELECT
		inc.GroupName,
		inc.EligMemberID,
		inc.FirstName,
		inc.LastName,
		inc.EligMemberSuffix,
		inc.Relationship,
		inc.IncentiveOption,
		inc.MedicalCoverage,
		inc.IsCurrentlyEligible,
		CONVERT(VARCHAR(10),inc.CS1_IncentiveStart_DATE,101) AS IncentiveEffectiveDate,
		ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),'') AS PHACompletedDate,
		ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),'') AS BiometricsCompletedDate,
		ISNULL(CONVERT(VARCHAR(10),cch.CompletedDate,101),'') AS CoachingCompletedDate,
		pts.TotalPoints,
		CASE 
			WHEN inc.IncentiveOption = 1 AND pha.CompletedDate IS NOT NULL THEN 'Y'
		    WHEN inc.IncentiveOption = 2 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND cch.CompletedDate IS NOT NULL THEN 'Y'
		    WHEN inc.IncentiveOption = 3 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND pts.TotalPoints >= 30 THEN 'Y'
		    WHEN inc.IncentiveOption = 4 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND pts.TotalPoints >= 50 THEN 'Y' 
		    ELSE ''
		END AS MetIncentive  
	FROM
		#Incentive inc
	LEFT JOIN
		(
		SELECT
			MemberID, MIN(ActivityDate) AS 'CompletedDate'
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'PHA'
		GROUP BY
			MemberID
		) pha
		ON	(inc.MemberID = pha.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			MIN(ActivityDate) AS 'CompletedDate'
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'Bio'
		GROUP BY
			MemberID
		) bio
		ON	(inc.MemberID = bio.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			MIN(ActivityDate) AS 'CompletedDate'
		FROM
			#Incentive
		WHERE
			ActivityDescription IN ('E-Coaching','Phone')
		GROUP BY
			MemberID
		) cch
		ON	(inc.MemberID = cch.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			SUM(PointsValue) AS 'TotalPoints'
		FROM
			#Incentive
		GROUP BY
			MemberID
		) pts
		ON	(inc.MemberID = pts.MemberID)
	WHERE
		inc.CS1_IncentiveStart_INT = 1 AND
		(
		 pha.CompletedDate IS NOT NULL OR
		 bio.CompletedDate IS NOT NULL OR
		 cch.CompletedDate IS NOT NULL
		)
	GROUP BY
		inc.GroupName,
		inc.EligMemberID,
		inc.FirstName,
		inc.LastName,
		inc.EligMemberSuffix,
		inc.Relationship,
		inc.IncentiveOption,
		inc.MedicalCoverage,
		inc.IsCurrentlyEligible,
		CONVERT(VARCHAR(10),inc.CS1_IncentiveStart_DATE,101),
		ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),cch.CompletedDate,101),''),
		pts.TotalPoints,
		CASE 
			WHEN inc.IncentiveOption = 1 AND pha.CompletedDate IS NOT NULL THEN 'Y'
		    WHEN inc.IncentiveOption = 2 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND cch.CompletedDate IS NOT NULL THEN 'Y'
		    WHEN inc.IncentiveOption = 3 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND pts.TotalPoints >= 30 THEN 'Y'
		    WHEN inc.IncentiveOption = 4 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND pts.TotalPoints >= 50 THEN 'Y' 
		    ELSE ''
		END
	
-- DETAILS 7/1
	SELECT
		GroupName,
		EligMemberID,
		FirstName,
		LastName,
		EligMemberSuffix,
		Relationship,
		IncentiveOption,
		MedicalCoverage,
		IsCurrentlyEligible,
		CONVERT(VARCHAR(10),CS1_IncentiveStart_DATE,101) AS IncentiveEffectiveDate,
		ActivityDescription,
		CONVERT(VARCHAR(10),ActivityDate,101) AS ActivityDate,
		PointsValue AS Points
	FROM
		#Incentive
	WHERE
		CS1_IncentiveStart_INT = 1	
	ORDER BY
		GroupName,
		EligMemberID,
		LastName,
		FirstName,
		ActivityDate

-- SUMMARY 1/1
	SELECT
		inc.GroupName,
		inc.EligMemberID,
		inc.FirstName,
		inc.LastName,
		inc.EligMemberSuffix,
		inc.Relationship,
		inc.IncentiveOption,
		inc.MedicalCoverage,
		inc.IsCurrentlyEligible,
		CONVERT(VARCHAR(10),inc.CS1_IncentiveStart_DATE,101) AS IncentiveEffectiveDate,
		ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),'') AS PHACompletedDate,
		ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),'') AS BiometricsCompletedDate,
		ISNULL(CONVERT(VARCHAR(10),cch.CompletedDate,101),'') AS CoachingCompletedDate,
		pts.TotalPoints,
		CASE 
			WHEN inc.IncentiveOption = 1 AND pha.CompletedDate IS NOT NULL THEN 'Y'
		    WHEN inc.IncentiveOption = 2 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND cch.CompletedDate IS NOT NULL THEN 'Y'
		    WHEN inc.IncentiveOption = 3 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND pts.TotalPoints >= 30 THEN 'Y'
		    WHEN inc.IncentiveOption = 4 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND pts.TotalPoints >= 50 THEN 'Y' 
		    ELSE ''
		END AS MetIncentive  
	FROM
		#Incentive inc
	LEFT JOIN
		(
		SELECT
			MemberID, MIN(ActivityDate) AS 'CompletedDate'
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'PHA'
		GROUP BY
			MemberID
		) pha
		ON	(inc.MemberID = pha.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			MIN(ActivityDate) AS 'CompletedDate'
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'Bio'
		GROUP BY
			MemberID
		) bio
		ON	(inc.MemberID = bio.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			MIN(ActivityDate) AS 'CompletedDate'
		FROM
			#Incentive
		WHERE
			ActivityDescription IN ('E-Coaching','Phone')
		GROUP BY
			MemberID
		) cch
		ON	(inc.MemberID = cch.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			SUM(PointsValue) AS 'TotalPoints'
		FROM
			#Incentive
		GROUP BY
			MemberID
		) pts
		ON	(inc.MemberID = pts.MemberID)
	WHERE
		inc.CS1_IncentiveStart_INT = 2 AND
		(
		 pha.CompletedDate IS NOT NULL OR
		 bio.CompletedDate IS NOT NULL OR
		 cch.CompletedDate IS NOT NULL
		)
	GROUP BY
		inc.GroupName,
		inc.EligMemberID,
		inc.FirstName,
		inc.LastName,
		inc.EligMemberSuffix,
		inc.Relationship,
		inc.IncentiveOption,
		inc.MedicalCoverage,
		inc.IsCurrentlyEligible,
		CONVERT(VARCHAR(10),inc.CS1_IncentiveStart_DATE,101),
		ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),cch.CompletedDate,101),''),
		pts.TotalPoints,
		CASE 
			WHEN inc.IncentiveOption = 1 AND pha.CompletedDate IS NOT NULL THEN 'Y'
		    WHEN inc.IncentiveOption = 2 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND cch.CompletedDate IS NOT NULL THEN 'Y'
		    WHEN inc.IncentiveOption = 3 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND pts.TotalPoints >= 30 THEN 'Y'
		    WHEN inc.IncentiveOption = 4 AND pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL AND pts.TotalPoints >= 50 THEN 'Y' 
		    ELSE ''
		END
	
-- DETAILS 1/1
	SELECT
		GroupName,
		EligMemberID,
		FirstName,
		LastName,
		EligMemberSuffix,
		Relationship,
		IncentiveOption,
		MedicalCoverage,
		IsCurrentlyEligible,
		CONVERT(VARCHAR(10),CS1_IncentiveStart_DATE,101) AS IncentiveEffectiveDate,
		ActivityDescription,
		CONVERT(VARCHAR(10),ActivityDate,101) AS ActivityDate,
		PointsValue AS Points
	FROM
		#Incentive
	WHERE
		CS1_IncentiveStart_INT = 2	
	ORDER BY
		GroupName,
		EligMemberID,
		LastName,
		FirstName,
		ActivityDate
		
-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#CSFields') IS NOT NULL BEGIN DROP TABLE #CSFields END
	IF OBJECT_ID('tempdb.dbo.#IncentiveGroups') IS NOT NULL BEGIN DROP TABLE #IncentiveGroups END
	IF OBJECT_ID('tempdb.dbo.#IncentivePlanID') IS NOT NULL BEGIN DROP TABLE #IncentivePlanID END
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL BEGIN DROP TABLE #Incentive END

END
GO
