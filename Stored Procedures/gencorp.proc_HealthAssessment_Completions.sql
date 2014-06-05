SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 2/7/2014
-- Description:	Yearly Gencorp Health Assessment Completions
-- =============================================
CREATE PROCEDURE [gencorp].[proc_HealthAssessment_Completions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	-- FOR TESTING
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

	-- SETS
	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(yy,DATEDIFF(yy,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),-1)),0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

	SELECT
		hpg.GroupName,
		ISNULL(mem.AltID1,'') AS [EmployeeUniqueID],
		mem.FirstName,
		mem.LastName,
		CONVERT(DATE,mem.Birthdate) AS [Birthdate],
		ISNULL(addr.City,'') AS [City],
		ISNULL(addr.[State],'') AS [State],
		ISNULL(csf.CS1,'') AS [Location],
		CONVERT(DATE,pha.AssessmentBeginDate) AS [PHACompletionDate]	
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem
		ON	hpg.GroupID = mem.GroupID
		AND hpg.GroupID = 188815
	JOIN
		(
		SELECT
			MemberID,
			AssessmentBeginDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AssessmentBeginDate) AS PhaSeq
		FROM
			DA_Production.prod.HealthAssessment
		WHERE
			IsComplete = 1
			AND IsPrimarySurvey = 1
			AND	AssessmentBeginDate >= @inBeginDate
			AND	AssessmentBeginDate < @inEndDate
		) pha
		ON	mem.MemberID = pha.MemberID
	LEFT JOIN
		DA_Production.prod.[Address] addr
		ON	mem.MemberID = addr.MemberID
		AND	addr.AddressTypeID = 6
	LEFT JOIN
		DA_Production.prod.CSFields csf
		ON	mem.MemberID = csf.MemberID

	WHERE
		pha.PhaSeq = 1
	ORDER BY mem.AltID1

END
GO
