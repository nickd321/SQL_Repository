SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-07-22
-- Description:	Sequa Tobacco File to Alere
-- =============================================
CREATE PROCEDURE [sequa].[proc_HealthAssessment_TobaccoUsers] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(qq,DATEDIFF(qq,0,GETDATE())-1,0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(qq,DATEDIFF(qq,0,GETDATE()),0))

	SELECT
		mem.FirstName,
		mem.LastName,
		ISNULL(mem.MiddleInitial,'') AS MiddleInitial,
		ISNULL(COALESCE(mem.AlternatePhone,mem.HomePhone,mem.WorkPhone,mem.CellPhone),'') AS Phone,
		ISNULL(mem.EmailAddress,'') AS Email,
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS Birthdate,
		ISNULL(addr.Address1,'') AS Address1,
		ISNULL(addr.Address2,'') AS Address2,
		ISNULL(addr.City,'') AS City,
		ISNULL(addr.[State],'') AS [State],
		ISNULL(addr.Zipcode,'') AS ZipCode
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID IN (136436,150675))
	LEFT JOIN
		DA_Production.prod.[Address] addr WITH (NOLOCK)
		ON	(addr.MemberID = mem.MemberID)
		AND	(addr.AddressTypeID = 6)
	JOIN
		DA_Production.prod.HealthAssessment pha WITH (NOLOCK)
		ON	(mem.MemberID = pha.MemberID)
		AND	(pha.AssessmentCompleteDate >= @inBeginDate)
		AND (pha.AssessmentCompleteDate < @inEndDate)
		AND	(pha.IsPrimarySurvey = 1)
		AND	(pha.IsComplete = 1)
	JOIN
		DA_Production.prod.HealthAssessment_MeasureResponse resp WITH (NOLOCK)
		ON	(pha.MemberAssessmentID = resp.MemberAssessmentID)
		AND	(resp.MeasureID = 149) -- Tobacco_Use
		AND	(resp.Response = 1) -- Yes
	GROUP BY
		mem.FirstName,
		mem.LastName,
		ISNULL(mem.MiddleInitial,''),
		ISNULL(COALESCE(mem.AlternatePhone,mem.HomePhone,mem.WorkPhone,mem.CellPhone),''),
		ISNULL(mem.EmailAddress,''),
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),''),
		ISNULL(addr.Address1,''),
		ISNULL(addr.Address2,''),
		ISNULL(addr.City,''),
		ISNULL(addr.[State],''),
		ISNULL(addr.Zipcode,'')		

END
GO
