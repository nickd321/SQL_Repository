SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 4/21/2014
-- Description:	Alere TC Recurring Monthly Tobacco Report for Lowe's

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [magellan].[proc_Lowes_Alere_TobaccoFile]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;
	
--Testing: DECLARE @inBeginDate DATETIME, @inEndDate DATETIME
SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

SELECT distinct
	mem.EligMemberID AS SalesID,
	mem.EligMemberSuffix AS Suffix,
	mem.FirstName,
	mem.LastName,
	CONVERT(VARCHAR(10),mem.Birthdate,101) AS DOB,
	ISNULL(addr.Address1,'') AS Address1,
	ISNULL(addr.Address2,'') AS Address2,
	ISNULL(addr.City,'') AS City,
	ISNULL(addr.[State],'') AS [State],
	ISNULL(addr.ZipCode,'') AS ZipCode,
	ISNULL(COALESCE(mem.AlternatePhone,mem.HomePhone,mem.WorkPhone,mem.CellPhone),'') AS Phone,
	ISNULL(mem.EmailAddress,'') AS Email,
	ISNULL(cs.CS2,'') AS Location,
	ISNULL(cs.CS3,'') AS Accolade
FROM
	DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
JOIN
	DA_Production.prod.Member mem WITH (NOLOCK)
	ON	(grp.GroupID = mem.GroupID)
	AND	(mem.GroupID = 150645)
	AND (mem.EligMemberID is not null)
LEFT JOIN
	DA_Production.prod.CSFields cs WITH (NOLOCK)
	ON	(mem.MemberID = cs.MemberID)
LEFT JOIN
	(
		SELECT
			addr.MemberID,
			addr.Address1,
			addr.Address2,
			addr.City,
			addr.[State],
			addr.ZipCode
		FROM
			DA_Production.prod.[Address] addr WITH (NOLOCK)
		JOIN
			(
			SELECT
				MemberID,
				AddressTypeID,
				ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY SUM(CASE WHEN Address1 IS NOT NULL THEN 1 ELSE 0 END + 
																	  CASE WHEN Address2 IS NOT NULL THEN 1 ELSE 0 END +
																	  CASE WHEN City IS NOT NULL THEN 1 ELSE 0 END +
																	  CASE WHEN [State] IS NOT NULL THEN 1 ELSE 0 END +
																	  CASE WHEN ZipCode IS NOT NULL THEN 1 ELSE 0 END) DESC, 
																  CASE WHEN AddressTypeID = 6 THEN 0 ELSE AddressTypeID END ASC) AS AddressSeq
			FROM
				DA_Production.prod.[Address] WITH (NOLOCK)
			WHERE
				GroupID = 150645
			GROUP BY
				MemberID,
				AddressTypeID
			) seq
			ON	(addr.MemberID = seq.MemberID)
			AND	(addr.AddressTypeID = seq.AddressTypeID)
			AND	(seq.AddressSeq = 1)
	) addr
	ON	(mem.MemberID = addr.MemberID)
JOIN
	DA_Production.prod.HealthAssessment pha WITH (NOLOCK)
	ON	(mem.MemberID = pha.MemberID)
	AND	(pha.IsComplete = 1)
	AND	(pha.IsPrimarySurvey = 1)
	AND	(pha.AssessmentCompleteDate >= @inBeginDate)
	AND	(pha.AssessmentCompleteDate < @inEndDate)
JOIN
	DA_Production.prod.HealthAssessment_MeasureResponse resp WITH (NOLOCK)
	ON	(pha.MemberAssessmentID = resp.MemberAssessmentID)
	AND	(resp.MeasureID = 149)
	AND	(resp.Response = 1)
ORDER BY 2

END
GO
