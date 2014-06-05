SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-11-25
-- Description:	Adams Outdoor Advertising 
--
-- Notes: AOA is part of the Health Plan CCS BlueLink
-- =============================================

CREATE PROCEDURE [aoa].[proc_Incentives] 

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

	-- BASE POPULATION
	SELECT
		mem.MemberID,
		grp.GroupName,
		ISNULL(mem.EligMemberID,'') AS UniqueID,
		ISNULL(mem.EligMemberID,'') AS EligMemberID,
		ISNULL(mem.EligMemberSuffix,'') AS EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS DOB,
		ISNULL(mem.EmailAddress,'') AS EmailAddress,
		ISNULL(addr.City,'') AS City,
		ISNULL(addr.[State],'') AS [State],
		NULLIF(RTRIM(LTRIM(CS5)),'') AS HireType,
		CASE
			WHEN NULLIF(RTRIM(LTRIM(CS5)),'') = 'NH'
			THEN 1090 -- NEW HIRE
			ELSE 1020 -- CURRENT
		END AS ClientIncentivePlanID
	INTO
		#Base
	FROM	
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 184454)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	LEFT JOIN
		DA_Production.prod.[Address] addr WITH (NOLOCK)
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)
	WHERE
		FirstName NOT LIKE 'Client%'

	SELECT
		b.*,
		inc.ActivityItemID,
		CASE 
			WHEN inc.ActivityItemID IN (5018,5296) THEN 'PHA'
			WHEN inc.ActivityItemID IN (5019,5297) THEN 'Bio'
			WHEN inc.ActivityItemID IN (5020,5298) THEN 'Coach'
			WHEN inc.ActivityItemID IN (5137,5301) THEN 'Cholesterol'
			WHEN inc.ActivityItemID IN (5024,5302) THEN 'BP'
			WHEN inc.ActivityItemID IN (5027,5305) THEN 'BMI'
			WHEN inc.ActivityItemID IN (5028,5307,5294,5308) THEN 'Tobacco'
			WHEN inc.ActivityItemID IN (5029,5309) THEN 'Cardio'
			WHEN inc.ActivityItemID IN (5030,5310) THEN 'Strength'
			WHEN inc.ActivityItemID IN (5031,5311) THEN 'Meal'
			WHEN inc.ActivityItemID IN (5032,5312) THEN 'OnlineCoach'
		END AS Activity,
		inc.ActivityDate,
		inc.ActivityValue,
		inc.AddDate
	INTO
		#Incentive
	FROM
		#Base b
	JOIN
		Healthyroads.dbo.IC_MemberActivityItem inc WITH (NOLOCK)
		ON	(b.MemberID = inc.MemberID)
		AND	(b.ClientIncentivePlanID = inc.ClientIncentivePlanID)
		AND	(inc.Deleted = 0)
	WHERE
		inc.ActivityItemID IN
		(
			5018, -- PHA (Current)
			5296, -- PHA (NH)
			5019, -- Bio (Current)
			5297, -- Bio (NH)
			5020, -- Coach (Current)
			5298, -- Coach (NH)
			5137, -- Cholesterol (Current)
			5301, -- Cholesterol (NH)
			5024, -- BP (Current)
			5302, -- BP (NH)
			5027, -- BMI (Current)
			5305, -- BMI (NH)
			5028, -- Cotinine (Current)
			5307, -- Cotinine (NH)
			5294, -- TobaccoUse (Current)
			5308, -- TobaccoUse (NH)
			5029, -- Cardio (Current)
			5309, -- Cardio (NH)
			5030, -- Strength (Current)
			5310, -- Strength (NH)
			5031, -- Meal (Current)
			5311, -- Meal (NH)
			5032, -- OnlineCoach (Current)
			5312  -- OnlineCoach (NH)
		)


	-- RESULTS
	SELECT
	
		inc.GroupName,
		inc.UniqueID,
		inc.EligMemberID,
		inc.EligMemberSuffix,
		inc.FirstName,
		inc.LastName,
		inc.DOB,
		inc.EmailAddress,
		inc.City,
		inc.[State],
		ISNULL(inc.HireType,'') AS HireType,
		ISNULL(CONVERT(VARCHAR(10),pha.CompletedDate,101),'') AS PHACompletionDate,
		ISNULL(CONVERT(VARCHAR(10),bio.CompletedDate,101),'') AS BiometricsScreeningCompletionDate,
		CASE
			WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL
			THEN 'Y'
			ELSE ''
		END AS PHAandBiometricsScreeningCompletionFlag,
		CASE
			WHEN outc.OutcomesCount = 4 OR phn.CompletedDate IS NOT NULL
			THEN 'Y'
			ELSE ''
		END AS MetFourOutcomes_OR_OneCoachingCall,
		CASE
			WHEN (ISNULL(outc.OutcomesCount,0) + ISNULL(act.ActivitiesCount,0)) > 4
			THEN 4
			ELSE (ISNULL(outc.OutcomesCount,0) + ISNULL(act.ActivitiesCount,0))
		END AS DeductibleCredit
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
			Activity = 'Bio'
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
			Activity = 'Coach'
		GROUP BY
			MemberID
		) phn
		ON	(inc.MemberID = phn.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			COUNT(Activity) AS 'OutcomesCount'
		FROM
			#Incentive
		WHERE
			Activity IN ('Cholesterol','BP','BMI','Tobacco')
		GROUP BY
			MemberID
		) outc
		ON	(inc.MemberID = outc.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			COUNT(Activity) AS 'ActivitiesCount'
		FROM
			#Incentive
		WHERE
			Activity IN ('Cardio','Strength','Meal','OnlineCoach')
		GROUP BY
			MemberID
		) act
		ON	(inc.MemberID = act.MemberID)
	GROUP BY
		inc.GroupName,
		inc.UniqueID,
		inc.EligMemberID,
		inc.EligMemberSuffix,
		inc.FirstName,
		inc.LastName,
		inc.DOB,
		inc.EmailAddress,
		inc.City,
		inc.[State],
		ISNULL(inc.HireType,''),
		CONVERT(VARCHAR(10),pha.CompletedDate,101),
		CONVERT(VARCHAR(10),bio.CompletedDate,101),
		CASE
			WHEN pha.CompletedDate IS NOT NULL AND bio.CompletedDate IS NOT NULL
			THEN 'Y'
			ELSE ''
		END,
		CASE
			WHEN outc.OutcomesCount = 4 OR phn.CompletedDate IS NOT NULL
			THEN 'Y'
			ELSE ''
		END,
		CASE
			WHEN (ISNULL(outc.OutcomesCount,0) + ISNULL(act.ActivitiesCount,0)) > 4
			THEN 4
			ELSE (ISNULL(outc.OutcomesCount,0) + ISNULL(act.ActivitiesCount,0))
		END
	ORDER BY
		ISNULL(inc.HireType,''),
		inc.FirstName,
		inc.LastName


		

-- CLEAN UP
IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
BEGIN
	DROP TABLE #Base
END

END
GO
