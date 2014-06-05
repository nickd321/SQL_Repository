SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 3/21/2014
-- Description:	Owens Illinois PHA Participation Report

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [owensillinois].[proc_HealthAssessment_Completions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;
SET @inBeginDate = ISNULL(@inBeginDate,'2/1/2014')
SET @inEndDate = ISNULL(@inEndDate,'5/1/2014')

SELECT
	hpg.GroupName,
	mem.EligMemberID,
	mem.EligMemberSuffix,
	mem.FirstName,
	ISNULL(mem.MiddleInitial,'') AS [MiddleInitial],
	mem.LastName,
	ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS [Birthdate],
	ISNULL(addr.Address1,'') AS [Address1],
	ISNULL(addr.Address2,'') AS [Address2],
	ISNULL(addr.City,'') AS [City],
	ISNULL(addr.State,'') AS [State],
	ISNULL(addr.ZipCode,'') AS [ZipCode],
	CONVERT(VARCHAR(10),pha.CompletedDate,101) AS [PHACompletedDate]
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = hpg.GroupID)
	AND	(hpg.GroupID = 204116)
JOIN
	(
	SELECT
		MemberID,
		MIN(AssessmentCompleteDate) AS [CompletedDate]
	FROM
		DA_Production.prod.HealthAssessment
	WHERE
		AssessmentCompleteDate >= @inBeginDate
		AND	AssessmentCompleteDate < @inEndDate
		AND	IsComplete = 1
		AND	IsPrimarySurvey = 1
	GROUP BY
		MemberID
	) pha
	ON	(mem.MemberID = pha.MemberID)
LEFT JOIN
	DA_Production.prod.Address addr
	ON	(addr.MemberID = mem.MemberID)
	AND	(addr.AddressTypeID = 6)

END
GO
