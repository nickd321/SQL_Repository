SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [selfservice].[proc_Assessments]

AS BEGIN

	IF OBJECT_ID('selfservice.Assessments') IS NOT NULL BEGIN
		DROP TABLE selfservice.Assessments
	END

	SELECT
		CASE clnt.TypeID
			WHEN 1 THEN 'Direct'
			ELSE 'Health Plan'
		END AS ClientType,
		clnt.ClientName AS Client,
		CASE
			WHEN clnt.IsRider = 1 THEN clnt.PlanSponsorName
			ELSE
				CASE WHEN clnt.TypeID != 1 THEN '[Core Groups]' ELSE '' END
		END AS PlanSponsor,
		mem.FirstName,
		mem.LastName,
		REPLACE(mem.EligMemberID + '-' + mem.EligMemberSuffix,' ','') AS EligMemberID,
		mem.Relationship,
		mem.Birthdate,
		ISNULL(mem.EmailAddress,'') AS Email,
		ISNULL(addr.Address1 + ' ' + addr.Address2,'') AS [Address],
		ISNULL(addr.City,'') AS City,
		ISNULL(addr.[State],'') AS [State],
		ISNULL(addr.ZipCode,'') AS ZipCode,
		elig.IsTermed,
		mem.AltID1,
		mem.AltID2,
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
		data.AssessmentType,
		data.AssessmentDate
	INTO
		selfservice.Assessments
	FROM
		DA_Production.prod.Client clnt
	JOIN
		DA_Production.prod.Member mem
		ON	(clnt.GroupID = mem.GroupID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			ROW_NUMBER() OVER(PARTITION BY MemberID ORDER BY EffectiveDate DESC) AS Sequence,
			IsTermed
		FROM
			DA_Production.prod.Eligibility
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.Sequence = 1)
	LEFT JOIN
		DA_Production.prod.[Address] addr
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)
	LEFT JOIN
		DA_Production.prod.CSFields cs
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		(
		SELECT
			MemberID,
			CASE
				WHEN SurveyID IN (1,22) THEN 'Initial PHA'
				WHEN SurveyID = 18 THEN 'Mini PHA'
				ELSE SurveyName
			END AS AssessmentType,
			AssessmentCompleteDate AS AssessmentDate
		FROM
			DA_Production.prod.HealthAssessment
		WHERE
			IsComplete = 1 AND
			(SurveyID IN (1,2,18,22))
		UNION
		SELECT
			MemberID,
			'Biometrics Screening' AS AssessmentType,
			ScreeningDate AS AssessmentDate
		FROM
			DA_Production.prod.BiometricsScreening
		) data
		ON	(mem.MemberID = data.MemberID)

	--Innocuous Output, so that this may be used within the report automation process
	SELECT 1 AS [Output]

END
GO
