SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Domokos/William Perez
-- Create date: 4/10/2014
-- Description:	Southern States Quarterly Gift Card Redemptions Report

-- Notes:		Custom Reward Redemptions Report 
--				
--				Please note that we refrained from using the ClientIncentivePlanID in the 
--				DA_Production.prod.IncentiveRedemption table since it is deriving the link
--				by checking if the request date is within a certain incentive plan period
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [southernstates].[proc_Incentives_RewardRedemptions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

	--Testing: DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

	-- DECLARES
	
	-- SETS
	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(qq,DATEDIFF(qq,0,GETDATE())-1,0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(qq,DATEDIFF(qq,0,GETDATE()),0))
	
	-- CLEAN UP
	IF OBJECT_ID('tempDb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END
	
	IF OBJECT_ID('tempDb.dbo.#Reward') IS NOT NULL
	BEGIN
		DROP TABLE #Reward
	END
	
	IF OBJECT_ID('tempDb.dbo.#Redemption') IS NOT NULL
	BEGIN
		DROP TABLE #Redemption
	END
	
	-- BASE
	SELECT
		mem.MemberID,
		mem.AltID1,
		hpg.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		mem.RelationshipID,
		mem.Relationship,
		elig.EffectiveDate,
		elig.TerminationDate,
		CASE WHEN ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) THEN 1 ELSE 0 END AS [IsCurrentlyEligible]
	INTO
		#Base
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem 
		ON	(hpg.GroupID = mem.GroupID)
		AND	(mem.GroupID = 185798)
	JOIN
		(
		SELECT
			MemberID,
			EffectiveDate,
			TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.Eligibility
		WHERE
			GroupID = 185798
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)
	WHERE
		mem.RelationshipID IN (6,1)

	-- REWARD
	SELECT 
		mem.MemberID,
		mem.AltID1,
		mem.EligMemberID,
		mem.RelationshipID,
		rew.MemberRewardID,
		rew.DateCreated AS [RewardDate],
		rew.RewardValue,
		rew.PayoutPoint,
		rew.RewardDescription,
		rew.AddDate AS [SourceAddDate]
	INTO
		#Reward
	FROM
		#Base mem
	JOIN
		Healthyroads.dbo.IC_MemberReward rew
		ON	(mem.MemberID = rew.MemberID)
		AND	(rew.Deleted = 0)
	WHERE
		rew.DateCreated >= @inBeginDate AND
		rew.DateCreated < @inEndDate
	
	
	-- REDEMPTION
	SELECT
		mem.MemberID,
		mem.AltID1,
		mem.EligMemberID,
		mem.RelationshipID,
		red.MemberRedeemedID,
		red.DateCreated AS [RequestDate],
		red.SentDate, -- PLEASE NOT CHECKS ARE TRACKED IF THEY WERE 'ACTUALLY' SENT BY A DIFFERENT PROCESS IN IHIS; THIS DATE IS REALLY A PROCESS DATE
		red.RedeemedStatusID,
		stat.[Description] AS [RedeemedStatusName],
		red.RewardTypeID,
		typ.[Description] AS [RewardTypeName],
		red.Quantity,
		red.RedeemedAmount,
		red.AddDate AS [SourceAddDate]
	INTO
		#Redemption
	FROM
		#Base mem
	JOIN
		Healthyroads.dbo.IC_MemberRedeemed red
		ON	(mem.MemberID = red.MemberID)
		AND	(red.Deleted = 0)
	JOIN
		Healthyroads.dbo.IC_RedeemedStatus stat
		ON	(red.RedeemedStatusID = stat.RedeemedStatusID)
		AND	(stat.Deleted = 0)
	JOIN
		Healthyroads.dbo.IC_RewardType typ
		ON	(red.RewardTypeID = typ.RewardTypeID)
		AND	(typ.Deleted = 0)
	WHERE
		red.DateCreated >= @inBeginDate AND
		red.DateCreated < @inEndDate
	
	-- RESULTS
	SELECT
		prmem.GroupName,
		prmem.FirstName AS [EE_FirstName],
		prmem.LastName AS [EE_LastName],
		prmem.AltID1 AS [UniqueID],
		prmem.Relationship,
		prmem.EligMemberSuffix AS [Suffix],
		ISNULL(CAST(sps.MemberID AS VARCHAR(30)),'') AS [SP_HRDSMemberID],
		ISNULL(sps.FirstName,'') AS [SP_FirstName],
		ISNULL(sps.LastName,'') AS [SP_LastName],
		ISNULL(ee.EE_Earned,0) AS [EE_Earned],
		ISNULL(ee.EE_Redeemed,0) AS [EE_Redeemed],
		ISNULL(sper.SP_Earned,0) AS [SP_Earned],
		ISNULL(sper.SP_Redeemed,0) AS [SP_Redeemed],
		ISNULL(EE_Earned,0) + ISNULL(sper.SP_Earned,0) AS [Total_Earned],
		ISNULL(EE_Redeemed,0) + ISNULL(sper.SP_Redeemed,0) AS [Total_Redeemed]
	FROM
		#Base mem
	JOIN
		#Base prmem
		ON	(mem.EligMemberID = prmem.EligMemberID)
		AND	(prmem.RelationshipID = 6)
	LEFT JOIN
		#Base sps
		ON	(mem.EligMemberID = sps.EligMemberID)
		AND	(sps.RelationshipID = 1)
	LEFT JOIN
		(
		SELECT
			EligMemberID,
			MemberID,
			[EE_Earned],
			[EE_Redeemed]
		FROM
			(
			SELECT
				EligMemberID,
				MemberID,
				'EE_Earned' AS Measure,
				SUM(RewardValue) AS MeasureValue
			FROM
				#Reward
			WHERE
				RelationshipID = 6
			GROUP BY
				EligMemberID,
				MemberID
			UNION ALL
			SELECT
				EligMemberID,
				MemberID,
				'EE_Redeemed' AS Measure,
				SUM(RedeemedAmount * Quantity) AS Measurevalue
			FROM
				#Redemption
			WHERE
				RelationshipID = 6
			GROUP BY
				EligMemberID,
				MemberID
			) inc
		PIVOT
			(
			MAX(MeasureValue) FOR Measure IN ([EE_Earned],[EE_Redeemed])
			) pvt
		) ee
		ON	(prmem.MemberID = ee.MemberID)
	LEFT JOIN
		(
		SELECT
			EligMemberID,
			MemberID,
			[SP_Earned],
			[SP_Redeemed]
		FROM
			(
			SELECT
				EligMemberID,
				MemberID,
				'SP_Earned' AS Measure,
				SUM(RewardValue) AS MeasureValue
			FROM
				#Reward
			WHERE
				RelationshipID = 1
			GROUP BY
				EligMemberID,
				MemberID
			UNION ALL
			SELECT
				EligMemberID,
				MemberID,
				'SP_Redeemed' AS Measure,
				SUM(RedeemedAmount * Quantity) AS Measurevalue
			FROM
				#Redemption
			WHERE
				RelationshipID = 1
			GROUP BY
				EligMemberID,
				MemberID
			) inc
		PIVOT
			(
			MAX(MeasureValue) FOR Measure IN ([SP_Earned],[SP_Redeemed])
			) pvt
		) sper
		ON	(sper.MemberID = sps.MemberID)
	WHERE
		ee.MemberID IS NOT NULL OR
		sper.MemberID IS NOT NULL
	GROUP BY
		prmem.GroupName,
		prmem.FirstName,
		prmem.LastName,
		prmem.AltID1,
		prmem.EligMemberID,
		prmem.Relationship,
		prmem.EligMemberSuffix,
		ISNULL(CAST(sps.MemberID AS VARCHAR(30)),''),
		ISNULL(sps.FirstName,''),
		ISNULL(sps.LastName,''),
		ISNULL(ee.EE_Earned,0),
		ISNULL(ee.EE_Redeemed,0),
		ISNULL(sper.SP_Earned,0),
		ISNULL(sper.SP_Redeemed,0),
		ISNULL(EE_Earned,0) + ISNULL(sper.SP_Earned,0),
		ISNULL(EE_Redeemed,0) + ISNULL(sper.SP_Redeemed,0)
	ORDER BY
		prmem.EligMemberID
		
	

END
GO
