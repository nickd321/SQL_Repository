SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-11-26
-- Description:	The Geo Group PHA Completions Report
--
-- Updates:		WilliamPe 20131126
--				Should only include initial PHA according to PM
--
-- =============================================

CREATE PROCEDURE [geogroup].[proc_HealthAssessment_Completions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL

AS
BEGIN
	SET NOCOUNT ON;

	SET @inBeginDate = ISNULL(@inBeginDate,'2013-11-01')
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))


	SELECT
		grp.GroupName AS Client,
		mem.FirstName,
		mem.LastName,
		ISNULL(mem.AltID1,'') AS [GEO EEID],
		ISNULL(mem.EligMemberID,'') AS EligMemberID,
		ISNULL(mem.EligMemberSuffix,'') AS Suffix,
		CASE
			WHEN elig.MemberID IS NOT NULL
			THEN 'Y'
			ELSE ''
		END AS [Member is Currently Eligible],
		ISNULL(mem.EmailAddress,'') AS Email,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS Birthdate,
		ISNULL(addr.City,'') AS City,
		ISNULL(addr.[State],'') AS [State],
		ISNULL(addr.Address1 + ' ' + addr.Address2,'') AS [Address],
		CONVERT(VARCHAR(10),ha.AssessmentCompleteDate,101) AS AssessmentDate,
		'Initial PHA' AS AssessmentType
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID IN (181334,181961))
	LEFT JOIN
		DA_Production.prod.[Address] addr WITH (NOLOCK)
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)
	JOIN
		DA_Production.prod.HealthAssessment ha WITH (NOLOCK)
		ON	(mem.MemberID = ha.MemberID)
		AND	(ha.SurveyID IN (1,22))
		AND (ha.IsComplete = 1)
		AND	(ha.AssessmentCompleteDate >= @inBeginDate)
		AND	(ha.AssessmentCompleteDate < @inEndDate)
	LEFT JOIN
		DA_Production.prod.Eligibility elig WITH (NOLOCK)
		ON	(mem.MemberID = elig.MemberID)
		AND	(ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))
	ORDER BY
		mem.FirstName,
		mem.LastName

END
GO
