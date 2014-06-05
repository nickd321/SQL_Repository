SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-06-05
-- Description:	ACEC Incentives Participation Summary Report
--
-- Notes:
--
--
--
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [acec].[proc_Incentives_ParticipationSummary] 

AS
BEGIN

	SET NOCOUNT ON;
	
-- DECLARES
	DECLARE 
	@loc_BeginJulDate DATETIME,
	@loc_BeginJanDate DATETIME,
	@loc_End DATETIME

-- SETS
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
	IF OBJECT_ID('tempdb.dbo.#Member') IS NOT NULL BEGIN DROP TABLE #Member END
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL BEGIN DROP TABLE #Incentive END
	IF OBJECT_ID('tempdb.dbo.#Eligible') IS NOT NULL BEGIN DROP TABLE #Eligible END
	IF OBJECT_ID('tempdb.dbo.#MetIncentive') IS NOT NULL BEGIN DROP TABLE #MetIncentive END

-- GET MEMBER DATA
	SELECT
		grp.GroupName,
		mem.GroupID,
		mem.MemberID,
		mem.RelationshipID,
		cs.CS1,
		CASE WHEN cs.CS1 IN (1,4) THEN 1
			 WHEN cs.CS1 IN (2,5) THEN 2
			 WHEN cs.CS1 IN (3,6) THEN 3
			 WHEN cs.CS1 IN (7,8) THEN 4
			 ELSE NULL
			 END AS IncentiveOption,
		CASE WHEN cs.CS1 IN (1,2,3,7) THEN 1
			 WHEN cs.CS1 IN (4,5,6,8) THEN 2
			 ELSE NULL END AS CS1_IncentiveStart_INT,
		CASE WHEN cs.CS1 IN (1,2,3,7) THEN @loc_BeginJulDate
			 WHEN cs.CS1 IN (4,5,6,8) THEN @loc_BeginJanDate
			 ELSE NULL END AS CS1_IncentiveStart_DATE
	INTO
		#Member
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.HealthPlanID = 175)
		AND	(mem.RelationshipID IN (6,1))
	LEFT JOIN
		(
		SELECT
			MemberID,
			CS1,
			SourceAddDate,
			AddDate,
			ArchiveDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AddDate DESC) AS AddDateRevSeq
		FROM
			(
			SELECT
				MemberID,
				CS1,
				SourceAddDate,
				AddDate,
				NULL AS ArchiveDate
			FROM
				DA_Production.prod.CSFields
			WHERE
				HealthPlanID = 175
			
			UNION ALL
			
			SELECT
				MemberID,
				CS1,
				SourceAddDate,
				AddDate,
				ArchiveDate
			FROM
				DA_Production.archive.CSFields
			WHERE
				HealthPlanID = 175
			) sub
		WHERE
			AddDate < DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)
		) cs
		ON	(mem.MemberID = cs.MemberID)
		AND	(cs.AddDateRevSeq = 1)

-- GET INCENTIVE DATA
	SELECT
		inc.GroupID,
		inc.MemberID,
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
			END AS ActivityDescription,
		inc.PointsValue,
		inc.RecordEffectiveBeginDate,
		inc.FK_ClientIncentivePlanID,
		inc.IncentiveEffectiveDate,
		inc.IncentiveExpiresDate,
		mem.RelationshipID,
		mem.IncentiveOption,
		mem.CS1_IncentiveStart_INT,
		mem.CS1_IncentiveStart_DATE,
		CASE WHEN MONTH(inc.IncentiveEffectiveDate) = 7 THEN 1
			 WHEN MONTH(inc.IncentiveEffectiveDate) = 1 THEN 2
			 ELSE NULL END AS INC_IncentiveStart_INT
	INTO
		#Incentive
	FROM
		[ASH-HRLReports].HrlDw.dbo.vwMemberIncentiveActivity_WithHistory inc WITH (NOLOCK)
	JOIN
		(
		SELECT
			pln.ClientIncentivePlanID
		FROM
			(
			-- GET GROUPS WITH INCENTIVE PLAN BENEFIT
			SELECT
				grp.GroupName,
				grp.GroupID
			FROM
				DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
			JOIN
				DA_Production.prod.GroupBenefit ben WITH (NOLOCK)
				ON	(grp.GroupID = ben.GroupID)
				AND	(ISNULL(ben.TerminationDate,'2999-12-31') >= DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))
				AND	(ben.BenefitDescription LIKE '%Incentives%')
			WHERE
				grp.HealthPlanID = 175
			GROUP BY
				grp.GroupName,
				grp.GroupID	
			) grp
		JOIN
			DA_Production.prod.GroupIncentivePlan pln WITH (NOLOCK)
			ON	(grp.GroupID = pln.GroupID)
			AND	(pln.IncentiveBeginDate IN (@loc_BeginJulDate, @loc_BeginJanDate))
		GROUP BY
			pln.ClientIncentivePlanID
		) pln
		ON	(inc.FK_ClientIncentivePlanID = pln.ClientIncentivePlanID)
	JOIN
		#Member mem
		ON	(inc.MemberID = mem.MemberID)
	WHERE
		inc.RecordEffectiveEndDate IS NULL AND
		inc.ActivityDate < @loc_End
		
-- DELETE 

	DELETE #Incentive
	WHERE
		CS1_IncentiveStart_INT != INC_IncentiveStart_INT AND
		ActivityDate < CS1_IncentiveStart_DATE

-- GET ELIGIBLE MEMBERS AND WHETHER THEY HAVE HRDS ACCOUNT
	SELECT
		mem.GroupName,
		mem.GroupID,
		mem.CS1_IncentiveStart_DATE,
		mem.MemberID,
		mem.RelationshipID,
		mem.CS1,
		mem.IncentiveOption,
		enr.EffectiveDate,
		enr.TerminationDate,
		hrds.FirstAccountCreateDate
	INTO 
		#Eligible
	FROM
		#Member mem
	JOIN
		(
		SELECT
			MemberID,
			EffectiveDate,
			TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.Eligibility WITH (NOLOCK)
		WHERE
			HealthPlanID = 175 AND
			ISNULL(TerminationDate,'2999-12-31') >= DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)
		) enr
		ON	(mem.MemberID = enr.MemberID)
		AND	(enr.RevTermSeq = 1)
	LEFT JOIN
		(
		SELECT
			web.MemberID,
			MIN(web.FirstAccountCreateDate) AS FirstAccountCreateDate
		FROM
			[ASH-HRLReports].HrlDw.dbo.vwMemberFirstWebAccounts web WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(web.MemberID = mem.MemberID)
			AND	(mem.HealthPlanID = 175)
		WHERE
			web.FirstAccountApplicationName = 'Healthyroads' AND
			web.FirstAccountCreateDate < DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)
		GROUP BY
			web.MemberID
		) hrds
		ON	(mem.MemberID = hrds.MemberID)



-- DETERMINE MEMBERS THAT MET INCENTIVE

	-- INCENTIVE PLAN 1
	SELECT
		inc.GroupID,
		inc.MemberID,
		inc.IncentiveOption,
		inc.CS1_IncentiveStart_DATE,
		CASE WHEN pha.MemberID IS NOT NULL THEN 1 ELSE 0 END AS PHA,
		NULL AS Bio,
		NULL AS Coaching,
		NULL AS [30PointsEarned],
		NULL AS [50PointsEarned],
		CASE WHEN pha.MemberID IS NOT NULL THEN 1 ELSE 0 END AS MetIncentive
	INTO 
		#MetIncentive
	FROM
		#Incentive inc
	LEFT JOIN
		(
		SELECT
			MemberID
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'PHA'
		) pha
		ON	(inc.MemberID = pha.MemberID)
	WHERE
		inc.IncentiveOption = 1
	GROUP BY
		inc.GroupID,
		inc.MemberID,
		inc.IncentiveOption,
		inc.CS1_IncentiveStart_DATE,
		CASE WHEN pha.MemberID IS NOT NULL THEN 1 ELSE 0 END

	UNION ALL

	-- INCENTIVE PLAN 2
	SELECT
		inc.GroupID,
		inc.MemberID,
		inc.IncentiveOption,
		inc.CS1_IncentiveStart_DATE,
		CASE WHEN pha.MemberID IS NOT NULL THEN 1 ELSE 0 END AS PHA,
		CASE WHEN bio.MemberID IS NOT NULL THEN 1 ELSE 0 END AS Bio,
		CASE WHEN cch.MemberID IS NOT NULL THEN 1 ELSE 0 END AS Coaching,
		NULL AS [30PointsEarned],
		NULL AS [50PointsEarned],
		CASE WHEN pha.MemberID IS NOT NULL AND bio.MemberID IS NOT NULL AND cch.MemberID IS NOT NULL THEN 1 ELSE 0 END AS MetIncentive
	FROM
		#Incentive inc
	LEFT JOIN
		(
		SELECT
			MemberID
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'PHA'
		) pha
		ON	(inc.MemberID = pha.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'Bio'
		) bio
		ON	(inc.MemberID = bio.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID
		FROM
			#Incentive
		WHERE
			ActivityDescription IN ('Phone','E-Coaching')
		) cch
		ON	(inc.MemberID = cch.MemberID)
	WHERE
		inc.IncentiveOption = 2
	GROUP BY
		inc.GroupID,
		inc.MemberID,
		inc.IncentiveOption,
		inc.CS1_IncentiveStart_DATE,
		CASE WHEN pha.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN bio.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN cch.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN pha.MemberID IS NOT NULL AND bio.MemberID IS NOT NULL AND cch.MemberID IS NOT NULL THEN 1 ELSE 0 END
		
	UNION ALL

	-- INCENTIVE PLAN 3
	SELECT
		inc.GroupID,
		inc.MemberID,
		inc.IncentiveOption,
		inc.CS1_IncentiveStart_DATE,
		CASE WHEN pha.MemberID IS NOT NULL THEN 1 ELSE 0 END AS PHA,
		CASE WHEN bio.MemberID IS NOT NULL THEN 1 ELSE 0 END AS Bio,
		NULL AS Coaching,
		CASE WHEN pts.MemberID IS NOT NULL THEN 1 ELSE 0 END AS [30PointsEarned],
		NULL AS [50PointsEarned],
		CASE WHEN pha.MemberID IS NOT NULL AND bio.MemberID IS NOT NULL AND pts.MemberID IS NOT NULL THEN 1 ELSE 0 END AS MetIncentive
	FROM
		#Incentive inc
	LEFT JOIN
		(
		SELECT
			MemberID
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'PHA'
		) pha
		ON	(inc.MemberID = pha.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'Bio'
		) bio
		ON	(inc.MemberID = bio.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			SUM(PointsValue) AS PointsEarned
		FROM
			#Incentive
		GROUP BY
			MemberID
		HAVING
			SUM(PointsValue) >= 30
		) pts
		ON	(inc.MemberID = pts.MemberID)
	WHERE
		inc.IncentiveOption = 3
	GROUP BY
		inc.GroupID,
		inc.MemberID,
		inc.IncentiveOption,
		inc.CS1_IncentiveStart_DATE,
		CASE WHEN pha.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN bio.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN pts.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN pha.MemberID IS NOT NULL AND bio.MemberID IS NOT NULL AND pts.MemberID IS NOT NULL THEN 1 ELSE 0 END

	UNION ALL

	-- INCENTIVE PLAN 4
	SELECT
		inc.GroupID,
		inc.MemberID,
		inc.IncentiveOption,
		inc.CS1_IncentiveStart_DATE,
		CASE WHEN pha.MemberID IS NOT NULL THEN 1 ELSE 0 END AS PHA,
		CASE WHEN bio.MemberID IS NOT NULL THEN 1 ELSE 0 END AS Bio,
		NULL AS Coaching,
		NULL AS [30PointsEarned],
		CASE WHEN pts.MemberID IS NOT NULL THEN 1 ELSE 0 END AS [50PointsEarned],
		CASE WHEN pha.MemberID IS NOT NULL AND bio.MemberID IS NOT NULL AND pts.MemberID IS NOT NULL THEN 1 ELSE 0 END AS MetIncentive
	FROM
		#Incentive inc
	LEFT JOIN
		(
		SELECT
			MemberID
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'PHA'
		) pha
		ON	(inc.MemberID = pha.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID
		FROM
			#Incentive
		WHERE
			ActivityDescription = 'Bio'
		) bio
		ON	(inc.MemberID = bio.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			SUM(PointsValue) AS PointsEarned
		FROM
			#Incentive
		GROUP BY
			MemberID
		HAVING
			SUM(PointsValue) >= 50
		) pts
		ON	(inc.MemberID = pts.MemberID)
	WHERE
		inc.IncentiveOption = 4
	GROUP BY
		inc.GroupID,
		inc.MemberID,
		inc.IncentiveOption,
		inc.CS1_IncentiveStart_DATE,
		CASE WHEN pha.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN bio.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN pts.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN pha.MemberID IS NOT NULL AND bio.MemberID IS NOT NULL AND pts.MemberID IS NOT NULL THEN 1 ELSE 0 END



-- RESULTS

	SELECT
		elig.GroupName,
		elig.IncentiveOption,
		CONVERT(VARCHAR(10),elig.CS1_IncentiveStart_DATE,101) AS IncentiveEffectiveDate,
		COUNT(elig.MemberID ) AS TotalNumElig_EESP,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL AND elig.RelationshipID = 6 THEN 1 ELSE 0 END) AS TotalRegistered_EE,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL AND elig.RelationshipID = 1 THEN 1 ELSE 0 END) AS TotalRegistered_SP,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL THEN 1 ELSE 0 END) AS TotalRegistered_EESP,
		100.0 * SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL THEN 1 ELSE 0 END) / COUNT(elig.MemberID) AS RegistrationPercentage,
		ISNULL(SUM(met.PHA),0) AS TotalPHA,
		ISNULL(SUM(met.MetIncentive),0) AS TotalMetIncentive
	FROM
		#Eligible elig
	LEFT JOIN
		#MetIncentive met
		ON	(elig.MemberID = met.MemberID)
	WHERE
		elig.IncentiveOption = 1
	GROUP BY
		elig.GroupName,
		elig.IncentiveOption,
		CONVERT(VARCHAR(10),elig.CS1_IncentiveStart_DATE,101)
	ORDER BY
		1, 3


	SELECT
		elig.GroupName,
		elig.IncentiveOption,
		CONVERT(VARCHAR(10),elig.CS1_IncentiveStart_DATE,101) AS IncentiveEffectiveDate,
		COUNT(elig.MemberID ) AS TotalNumElig_EESP,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL AND elig.RelationshipID = 6 THEN 1 ELSE 0 END) AS TotalRegistered_EE,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL AND elig.RelationshipID = 1 THEN 1 ELSE 0 END) AS TotalRegistered_SP,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL THEN 1 ELSE 0 END) AS TotalRegistered_EESP,
		100.0 * SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL THEN 1 ELSE 0 END) / COUNT(elig.MemberID) AS RegistrationPercentage,
		ISNULL(SUM(met.PHA),0) AS TotalPHA,
		ISNULL(SUM(met.Bio),0) AS TotalBio,
		ISNULL(SUM(met.Coaching),0) AS TotalCoaching,
		ISNULL(SUM(met.MetIncentive),0) AS TotalMetIncentive
	FROM
		#Eligible elig
	LEFT JOIN
		#MetIncentive met
		ON	(elig.MemberID = met.MemberID)
	WHERE
		elig.IncentiveOption = 2
	GROUP BY
		elig.GroupName,
		elig.IncentiveOption,
		CONVERT(VARCHAR(10),elig.CS1_IncentiveStart_DATE,101)
	ORDER BY
		1, 3


	SELECT
		elig.GroupName,
		elig.IncentiveOption,
		CONVERT(VARCHAR(10),elig.CS1_IncentiveStart_DATE,101) AS IncentiveEffectiveDate,
		COUNT(elig.MemberID ) AS TotalNumElig_EESP,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL AND elig.RelationshipID = 6 THEN 1 ELSE 0 END) AS TotalRegistered_EE,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL AND elig.RelationshipID = 1 THEN 1 ELSE 0 END) AS TotalRegistered_SP,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL THEN 1 ELSE 0 END) AS TotalRegistered_EESP,
		100.0 * SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL THEN 1 ELSE 0 END) / COUNT(elig.MemberID) AS RegistrationPercentage,
		ISNULL(SUM(met.PHA),0) AS TotalPHA,
		ISNULL(SUM(met.Bio),0) AS TotalBio,
		ISNULL(SUM(met.[30PointsEarned]),0) AS TotalMet30Points,
		ISNULL(SUM(met.MetIncentive),0) AS TotalMetIncentive
	FROM
		#Eligible elig
	LEFT JOIN
		#MetIncentive met
		ON	(elig.MemberID = met.MemberID)
	WHERE
		elig.IncentiveOption = 3
	GROUP BY
		elig.GroupName,
		elig.IncentiveOption,
		CONVERT(VARCHAR(10),elig.CS1_IncentiveStart_DATE,101)
	ORDER BY
		1, 3

	SELECT
		elig.GroupName,
		elig.IncentiveOption,
		CONVERT(VARCHAR(10),elig.CS1_IncentiveStart_DATE,101) AS IncentiveEffectiveDate,
		COUNT(elig.MemberID ) AS TotalNumElig_EESP,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL AND elig.RelationshipID = 6 THEN 1 ELSE 0 END) AS TotalRegistered_EE,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL AND elig.RelationshipID = 1 THEN 1 ELSE 0 END) AS TotalRegistered_SP,
		SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL THEN 1 ELSE 0 END) AS TotalRegistered_EESP,
		100.0 * SUM(CASE WHEN elig.FirstAccountCreateDate IS NOT NULL THEN 1 ELSE 0 END) / COUNT(elig.MemberID) AS RegistrationPercentage,
		ISNULL(SUM(met.PHA),0) AS TotalPHA,
		ISNULL(SUM(met.Bio),0) AS TotalBio,
		ISNULL(SUM(met.[50PointsEarned]),0) AS Total50MetPoints,
		ISNULL(SUM(met.MetIncentive),0) AS TotalMetIncentive
	FROM
		#Eligible elig
	LEFT JOIN
		#MetIncentive met
		ON	(elig.MemberID = met.MemberID)
	WHERE
		elig.IncentiveOption = 4
	GROUP BY
		elig.GroupName,
		elig.IncentiveOption,
		CONVERT(VARCHAR(10),elig.CS1_IncentiveStart_DATE,101)
	ORDER BY
		1, 3


-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Member') IS NOT NULL BEGIN DROP TABLE #Member END
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL BEGIN DROP TABLE #Incentive END
	IF OBJECT_ID('tempdb.dbo.#Eligible') IS NOT NULL BEGIN DROP TABLE #Eligible END
	IF OBJECT_ID('tempdb.dbo.#MetIncentive') IS NOT NULL BEGIN DROP TABLE #MetIncentive END

END
GO
