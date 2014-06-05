SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 5/1/2014
-- Description:	Incentives for Nexans

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [nexans].[proc_Nexans_Incentives]
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

--Testing: DECLARE @inEndDate DATETIME
-- DECLARES
DECLARE 
	@GroupID INT

-- SETS
SET @GroupID = 195496
SET @inEndDate = ISNULL(@inEndDate,DATEADD(ms,-3,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)))

-- CLEAN UP
IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
BEGIN
	DROP TABLE #Incentive
END

IF OBJECT_ID('tempdb.dbo.#CoachEnroll') IS NOT NULL
BEGIN
	DROP TABLE #CoachEnroll
END

-- INCENTIVE ACTIVITY TEMP
SELECT
	mem.MemberID,
	REPLACE(grp.GroupName,',','') AS [GroupName],
	grp.GroupNumber,
	ISNULL(mem.EligMemberID,'') AS [EligMemberID],
	ISNULL(mem.EligMemberSuffix,'') AS [EligMemberSuffix],
	mem.FirstName,
	ISNULL(mem.MiddleInitial,'') AS [MiddleInitial],
	mem.LastName,
	ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS [Birthdate],
	rel.RelationshipDescription AS [Relationship],
	ISNULL(addr.Address1,'') AS [Address1],
	ISNULL(addr.Address2,'') AS [Address2],
	ISNULL(addr.City,'') AS [City],
	ISNULL(addr.[State],'') AS [State],
	ISNULL(addr.ZipCode,'') AS [ZipCode],
	ISNULL(mem.HomePhone,'') AS [HomePhone],
	ISNULL(mem.WorkPhone,'') AS [WorkPhone],
	ISNULL(mem.CellPhone,'') AS [CellPhone],
	ISNULL(mem.AlternatePhone,'') AS [AlternatePhone],
	ISNULL(mem.Email,'') AS [Email],
	ISNULL(mem.SSOID,'') AS [SSOID],
	ISNULL(mem.SSN,'') AS [SSN],
	ISNULL(mem.CS1,'') AS [CS1],
	ISNULL(mem.CS2,'') AS [CS2],
	ISNULL(mem.CS3,'') AS [CS3],
	ISNULL(mem.CS4,'') AS [CS4],
	ISNULL(mem.CS5,'') AS [CS5],
	ISNULL(mem.CS6,'') AS [CS6],
	ISNULL(mem.CS7,'') AS [CS7],
	ISNULL(mem.CS8,'') AS [CS8],
	ISNULL(mem.CS9,'') AS [CS9],
	ISNULL(mem.CS10,'') AS [CS10],
	ISNULL(mem.CS11,'') AS [CS11],
	ISNULL(mem.CS12,'') AS [CS12],
	ISNULL(mem.AltID1,'') AS [AltID1],
	ISNULL(mem.AltID2,'') AS [AltID2],
	inc.ActivityValue,
	CASE inc.ActivityItemID 
		WHEN 7054 THEN 'PHA'
		WHEN 7055 THEN 'BIO'
		WHEN 7056 THEN 'Coach'
		WHEN 7058 THEN 'TobaccoFree'
	END AS [Activity],
	inc.ActivityDate,
	inc.AddDate
INTO
	#Incentive
FROM
	Benefits.dbo.[Group] grp WITH (NOLOCK)
JOIN
	Benefits.dbo.Member mem WITH (NOLOCK)
	ON	(grp.GroupID = mem.GroupID)
	AND	(mem.Deleted = 0)
	AND	(grp.GroupID =@GroupID)
JOIN
	Benefits.dbo.Relationship rel WITH (NOLOCK)
	ON	(mem.RelationshipID = rel.RelationshipID)
LEFT JOIN
	Benefits.dbo.MemberAddress addr WITH (NOLOCK)
	ON	(mem.MemberID = addr.MemberID)
	AND	(addr.AddressTypeID = 6)
	AND	(addr.Deleted = 0)
JOIN
	Healthyroads.dbo.IC_MemberActivityItem inc WITH (NOLOCK)
	ON	(mem.MemberID = inc.MemberID)
	AND	(inc.Deleted = 0)
	AND (inc.ClientIncentivePlanID = 1333)
	AND	(inc.ActivityItemID IN (7054,7055,7058,7056))
	AND	(inc.ActivityDate < @inEndDate)

-- SUMMARY
SELECT
	inc.GroupName,
	inc.AltID1 AS [EEID],
	inc.FirstName,
	inc.LastName,
	inc.CS2 AS [Location],
	ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),'') AS [PHACompletedDate],
	ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),'') AS [BiometricScreeningCompletedDate],
	CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN 'Y' ELSE '' END AS [PHAandBiometricScreeningCompletedFlag],
	CASE WHEN tobyes.CompletedDate IS NOT NULL OR (fourcch.CompletedDate IS NOT NULL AND tobno.CompletedDate IS NOT NULL) THEN 'Y' ELSE '' END AS [TobaccoFree-Yes_OR_TobaccoFree-No-FourCalls]
FROM
	#Incentive inc
LEFT JOIN
	(
	SELECT
		MemberID,
		MIN(ActivityDate) AS 'CompletedDate'
	FROM
		#Incentive
	WHERE
		Activity = 'PHA'
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
		Activity = 'BIO'
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
		Activity = 'TobaccoFree' AND
		ActivityValue = 1 -- YES
	GROUP BY
		MemberID
	) tobyes
	ON	(inc.MemberID = tobyes.MemberID)
LEFT JOIN
	(
	SELECT
		MemberID,
		MIN(ActivityDate) AS 'CompletedDate'
	FROM
		#Incentive
	WHERE
		Activity = 'TobaccoFree' AND
		ActivityValue = 0 -- No
	GROUP BY
		MemberID
	) tobno
	ON	(inc.MemberID = tobno.MemberID)
LEFT JOIN
	(
	SELECT
		MemberID,
		MIN(ActivityDate) AS 'CompletedDate'
	FROM
		#Incentive
	WHERE
		Activity = 'Coach'
	GROUP BY
		MemberID
	) fourcch
	ON	(inc.MemberID = fourcch.MemberID)
WHERE
	(pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL)
	OR
	(tobyes.CompletedDate IS NOT NULL OR 
	(tobno.CompletedDate IS NOT NULL AND
	fourcch.CompletedDate IS NOT NULL))
GROUP BY
	inc.GroupName,
	inc.AltID1,
	inc.FirstName,
	inc.LastName,
	inc.CS2,
	ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),''),
	ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),''),
	CASE WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL THEN 'Y' ELSE '' END,
	CASE WHEN tobyes.CompletedDate IS NOT NULL OR (fourcch.CompletedDate IS NOT NULL AND tobno.CompletedDate IS NOT NULL) THEN 'Y' ELSE '' END
ORDER BY
	inc.FirstName,
	inc.LastName


-- CLEAN UP
IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
BEGIN
	DROP TABLE #Incentive
END

IF OBJECT_ID('tempdb.dbo.#CoachEnroll') IS NOT NULL
BEGIN
	DROP TABLE #CoachEnroll
END

END
GO
