SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [selfservice].[proc_Challenges]

AS BEGIN

	IF OBJECT_ID('selfservice.Challenges') IS NOT NULL BEGIN
		DROP TABLE selfservice.Challenges
	END

	SELECT
		clnt.[Type] AS ClientType,
		clnt.ClientName AS Client,
		clnt.PlanSponsorName AS PlanSponsor,
		mem.LastName,
		mem.FirstName,
		mem.Relationship,
		mem.EligMemberID + '-' + mem.EligMemberSuffix AS EligMemberID,
		cs.CS1,
		cs.CS2,
		cs.CS3,
		cs.CS4,
		cs.CS5,
		cs.CS6,
		cs.CS7,
		cs.CS8,
		cs.CS9,
		cs.CS10,
		cs.CS11,
		cs.CS12,
		cs.CS13,
		cs.CS14,
		cs.CS15,
		cs.CS16,
		cs.CS17,
		cs.CS18,
		cs.CS19,
		cs.CS20,
		cs.CS21,
		cs.CS22,
		cs.CS23,
		cs.CS24,
		mem.AltID1,
		mem.AltID2,
		mem.EmailAddress AS Email,
		CONVERT(VARCHAR,mem.Birthdate,101) AS DOB,
		ISNULL(addr.Address1,'') + ' ' + ISNULL(addr.Address2,'') AS [Address],
		ISNULL(addr.City,'') AS City,
		ISNULL(addr.[State],'') AS [State],
		CASE WHEN elig.MemberID IS NOT NULL THEN 1 ELSE 0 END AS IsCurrentlyEligible,
		REPLACE(ISNULL(chl.ChallengeName,chl.DefaultChallengeName),'&','and') AS ChallengeName,
		ISNULL(CONVERT(VARCHAR,chl.ChallengeBeginDate,101),'') AS ChallengeBeginDate,
		ISNULL(CONVERT(VARCHAR,chl.EnrollmentDate,101),'') AS RegistrationDate,
		ISNULL(CONVERT(VARCHAR,chl.CompletionDate,101),'') AS CompletionDate,
		CASE WHEN chl.CompletionDate IS NOT NULL THEN 1 ELSE 0 END AS ChallengeCompleted
	INTO
		DA_Reports.selfservice.Challenges
	FROM
		DA_Production.prod.Client clnt
	JOIN
		DA_Production.prod.Member mem
		ON	(clnt.GroupID = mem.GroupID)
	JOIN
		DA_Production.prod.Challenge chl
		ON	(mem.MemberID = chl.MemberID)
	LEFT JOIN
		DA_Production.prod.CSFields cs
		ON	(mem.MemberID = cs.MemberID)
	LEFT JOIN
		DA_Production.prod.Eligibility elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.IsTermed = 0)
	LEFT JOIN
		DA_Production.prod.[Address] addr
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)

	--Innocuous Output, so that this may be used within the report automation process
	SELECT 1 AS [Output]

END
GO
