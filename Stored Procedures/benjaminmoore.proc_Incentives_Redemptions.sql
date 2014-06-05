SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Domokos
-- Create date: 5/13/2014
-- Description:	Benjamin Moore Gift Card Redemptions Report

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

CREATE PROCEDURE [benjaminmoore].[proc_Incentives_Redemptions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

	--Testing: DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

	-- DECLARES
	
	-- SETS
	SET @inBeginDate = ISNULL(@inBeginDate,'2014-01-01')
	SET @inEndDate = ISNULL(@inEndDate,'2015-02-01')
	
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
		mem.Relationship
	INTO
		#Base
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem 
		ON	(hpg.GroupID = mem.GroupID)
		AND	(mem.GroupID = 195330)

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
		ISNULL(mem.LastName,'') AS [LastName], 
		ISNULL(mem.FirstName,'') AS [FirstName], 
		ISNULL(mem.AltID1,'') AS [EmployeeID],
		ISNULL(mem.EligMemberSuffix,'') AS [EligMemberSuffix],
		ISNULL(csf.CS1,'') AS [CS1],
		ISNULL(CONVERT(CHAR(10),red.RequestDate,101),'') AS [RedeemedDate],
		ISNULL(CASE WHEN CONVERT(VARCHAR(10),red.RedeemedAmount) = '0.00' THEN '' ELSE CONVERT(VARCHAR(10),red.RedeemedAmount) END,'') AS [AmountRedeemed],
		ISNULL(red.RewardTypeName,'') AS [RewardType]
	FROM
		#Base mem
	JOIN
		#Redemption red
		ON	(red.MemberID = mem.MemberID)
	LEFT JOIN
		DA_Production.prod.CSFields csf
		ON	(csf.MemberID = mem.MemberID)
	GROUP BY
		mem.MemberID,
		ISNULL(mem.LastName,''), 
		ISNULL(mem.FirstName,''), 
		ISNULL(mem.AltID1,''),
		ISNULL(mem.EligMemberSuffix,''),
		ISNULL(csf.CS1,''),
		ISNULL(CONVERT(CHAR(10),red.RequestDate,101),''),
		ISNULL(CASE WHEN CONVERT(VARCHAR(10),red.RedeemedAmount) = '0.00' THEN '' ELSE CONVERT(VARCHAR(10),red.RedeemedAmount) END,''),
		ISNULL(red.RewardTypeName,'')

ORDER BY 1,2
	

END
GO
