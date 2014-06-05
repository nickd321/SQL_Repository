SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:			William Perez
-- Create date:		2014-02-10
-- Client:			Envision Healthcare, AMR and EmCare (Formerly EMSC)
--
-- Description:		EVHC Incentive Report
--
-- Notes:				
-- =============================================

CREATE PROCEDURE [evhc].[proc_Incentives] 

AS
BEGIN


SET NOCOUNT ON;

/*============================================ CLEAN UP ==============================================*/


	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL 
	BEGIN
		DROP TABLE #Base
	END
	
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL 
	BEGIN
		DROP TABLE #Incentive
	END
	
/*=========================================== BASE TEMP ==============================================*/

	SELECT
	    mem.MemberID,
		grp.GroupName,
		mem.EligMemberID,
		mem.AltID1 AS [EmployeeID],
		rel.RelationshipDescription AS [Relationship],
		mem.FirstName,
		mem.LastName,
		mem.CS2 AS [UnionIndicator],
		mem.CS1 AS [BenefitGroupCode],
		mem.CS4 AS [HealthPlan],
		mem.CS5 AS [HealthPlanTier],
		CASE WHEN ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) THEN 1 ELSE 0 END AS [IsCurrentlyEligible],
		CASE WHEN sps.MemberID IS NOT NULL THEN 1 ELSE 0 END AS [HasSpouse],
		CASE WHEN mem.RelationshipID IN (1,2) THEN 1 ELSE 0 END AS [IsSpouse],
		elig.EffectiveDate,
		elig.TerminationDate
	INTO
		#Base
	FROM
		Benefits.dbo.[Group] grp WITH (NOLOCK)
	JOIN
		Benefits.dbo.Member mem WITH (NOLOCK)
		ON	(mem.GroupID = grp.GroupID)
		AND	(mem.GroupID = 194355)
		AND (mem.CS4 NOT IN ('APPO200','APPO300','APPO500'))
		AND	(mem.CS3 = 'Y') -- Incentive Option
		AND (mem.Deleted = 0)
	JOIN
		Benefits.dbo.Relationship rel WITH (NOLOCK)
		ON	(mem.RelationshipID = rel.RelationshipID)
	LEFT JOIN
		Benefits.dbo.Member sps WITH (NOLOCK)
		ON	(mem.EligMemberID = sps.EligMemberID)
		AND	(mem.GroupID = sps.GroupID)
		AND	(sps.RelationshipID IN (1,2))
		AND	(sps.CS4 NOT IN ('APPO200','APPO300','APPO500'))
		AND	(sps.CS3 = 'Y')
		AND	(sps.Deleted = 0)
	JOIN
		(
		SELECT
			mem.MemberID,
			elig.EffectiveDate,
			elig.TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY mem.MemberID ORDER BY ISNULL(elig.TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			Benefits.dbo.Member mem WITH (NOLOCK)
		JOIN
			Benefits.dbo.MemberEnrollment elig WITH (NOLOCK)
			ON	(mem.MemberID = elig.MemberiD)
			AND	(elig.Deleted = 0)
		WHERE
			mem.Deleted = 0 AND
			mem.GroupID = 194355
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)

/*==================================== INCENTIVE ACTIVITY TEMP =======================================*/

	SELECT
		b.MemberID,
		b.GroupName,
		b.EligMemberID,
		b.EmployeeID,
		b.Relationship,
		b.FirstName,
		b.LastName,
		b.UnionIndicator,
		b.BenefitGroupCode,
		b.HealthPlan,
		b.HealthPlanTier,
		CASE WHEN b.Relationship = 'Primary' 
					AND b.HealthPlanTier IN ('E1','FM') 
					AND (ISNULL(sps.IsCurrentlyEligible,0) = 0 OR ISNULL(sps.HealthPlanTier,'') NOT IN ('E1','FM')) THEN 'N' 
		     WHEN b.Relationship = 'Primary' 
					AND b.HealthPlanTier IN ('E1','FM') 
					AND sps.EligMemberID IS NOT NULL 
					AND sps.IsCurrentlyEligible = 1 
					AND sps.HealthPlanTier IN ('E1','FM') THEN 'Y'
			 ELSE '' END AS [E1FM_HasEligibleSpouse],
		b.IsCurrentlyEligible,
		b.HasSpouse,
		b.IsSpouse,
		b.EffectiveDate,
		b.TerminationDate,
		act.ActivityItemID,
		act.ActivityDate,
		act.AddDate AS [CreditDate],
		CASE WHEN b.Relationship = 'Primary' AND b.HealthPlanTier IN ('E1','FM') THEN sps.FirstName END AS [SpouseFirstName],
		CASE WHEN b.Relationship = 'Primary' AND b.HealthPlanTier IN ('E1','FM') THEN sps.LastName END AS [SpouseLastName],
		CASE WHEN b.Relationship = 'Primary' AND b.HealthPlanTier IN ('E1','FM') THEN sps.HealthPlanTier END AS [SpouseHealthPlanTier],
		CASE WHEN b.Relationship = 'Primary' AND b.HealthPlanTier IN ('E1','FM') THEN sps.EffectiveDate END AS [SpouseEffectiveDate],
		CASE WHEN b.Relationship = 'Primary' AND b.HealthPlanTier IN ('E1','FM') THEN sps.TerminationDate END AS [SpouseTermDate],
		ROW_NUMBER() OVER (PARTITION BY b.MemberID ORDER BY act.ActivityDate, act.AddDate) AS [ActivitySeq]
	INTO
		#Incentive
	FROM
		#Base b
	JOIN
        Healthyroads.dbo.IC_MemberActivityItem act WITH (NOLOCK)
		ON	(b.MemberID = act.MemberID)
		AND	(act.ClientIncentivePlanID = 1124)
		AND	(act.ActivityItemID = 5593)
		AND	(act.Deleted = 0)
	LEFT JOIN
		#Base sps
		ON	(b.EligMemberID = sps.EligMemberID)
		AND	(sps.IsSpouse = 1)
	ORDER BY
		b.EligMemberID


/*======================================== FINAL QUERY ==============================================*/	

	SELECT
		GroupName,
		EligMemberID,
		EmployeeID,
		Relationship,
		FirstName,
		LastName,
		UnionIndicator,
		BenefitGroupCode,
		HealthPlan,
		HealthPlanTier,
		E1FM_HasEligibleSpouse,
		CONVERT(VARCHAR(10),ActivityDate,101) AS [EarnedDate],
		CONVERT(VARCHAR(10),CreditDate,101) AS [PostDate],
		ISNULL(SpouseFirstName,'') AS [SpouseFirstName],
		ISNULL(SpouseLastName,'') AS [SpouseLastName],
		ISNULL(SpouseHealthPlanTier,'') AS [SpouseHealthPlanTier],
		ISNULL(CONVERT(VARCHAR(10),SpouseEffectiveDate,101),'') AS [SpouseEffectiveDate],
		ISNULL(CONVERT(VARCHAR(10),SpouseTermDate,101),'') AS [SpouseTermDate]
	FROM
		#Incentive
	WHERE
		ActivitySeq = 1
	ORDER BY
		EligMemberID,
		Relationship

/*============================================ CLEAN UP ==============================================*/


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
