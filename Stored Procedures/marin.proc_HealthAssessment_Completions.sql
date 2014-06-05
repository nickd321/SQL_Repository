SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-10-31
-- Description:	Marin Healthcare District (Marin General Hospital) PHA Completions Report
--
-- Notes: Changed default date parameters to account for the change to bi-weekly runs.
-- =============================================

CREATE PROCEDURE [marin].[proc_HealthAssessment_Completions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	
	SET NOCOUNT ON;

	-- FOR TESTING
	-- DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(yy,DATEDIFF(yy,0,DATEADD(dd,DATEDIFF(dd,0,GETDATE())-14,0)),0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))
	
	SELECT
		grp.GroupName,
		ISNULL(mem.EligMemberID,'') AS EligMemberID,
		ISNULL(mem.EligMemberSuffix,'') AS EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS [Birthdate],
		ISNULL(mem.EmailAddress,'') AS [EmailAddress],
		ISNULL(mem.AltID1,'') AS [EmployeeID],
		CONVERT(VARCHAR(10),ha.AssessmentCompleteDate,101) AS [PHACompletedDate]
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 131380)
	JOIN
		DA_Production.prod.HealthAssessment ha WITH (NOLOCK)
		ON	(mem.MemberID = ha.MemberID)
		AND	(ha.IsPrimarySurvey = 1)
		AND	(ha.IsComplete = 1)
		AND	(ha.AssessmentCompleteDate >= @inBeginDate)
		AND	(ha.AssessmentCompleteDate < @inEndDate)

END
GO
