SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
--
-- Author:		Nick Domokos
-- Create date: 2014-03-13
-- Description:	Gander Mountain PHA Completion Report
--
-- =============================================

CREATE PROCEDURE [gandermountain].[proc_HealthAssessment_Completions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(yy, DATEDIFF(yy,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0)), 0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))
	
	SELECT
		grp.GroupName,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS [Birthdate],
		ISNULL(mem.SubscriberSSN,'') AS [SSN],
		ISNULL(addr.Address1,'') AS [Address],
		ISNULL(addr.City,'') AS [City],
		ISNULL(addr.[State],'') AS [State],
		ISNULL(addr.ZipCode,'') AS [ZipCode],
		CONVERT(VARCHAR(10),pha.AssessmentCompleteDate,101) AS [PHACompletedDate]
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(grp.GroupID IN (141795,141796,141797))
	LEFT JOIN
		DA_Production.prod.[Address] addr WITH (NOLOCK)
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)
	JOIN
		DA_Production.prod.HealthAssessment pha WITH (NOLOCK)
		ON	(mem.MemberID = pha.MemberID)
		AND	(pha.IsComplete = 1)
		AND	(pha.IsPrimarySurvey = 1)
		AND	(pha.AssessmentCompleteDate >= @inBeginDate)
		AND	(pha.AssessmentCompleteDate < @inEndDate)
		
END
GO
