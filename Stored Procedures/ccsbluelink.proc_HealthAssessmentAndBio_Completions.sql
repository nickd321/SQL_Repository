SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-09-19
-- Description:	PHA and Completions Report for CCS Blue Link
--
-- Notes		Default begin date is set to the beginning of the year
--				and will reset every February.  The biometrics screenings
--				will be evaluated by the SourceAddDate to account for lagging data.
--
-- =============================================
CREATE PROCEDURE [ccsbluelink].[proc_HealthAssessmentAndBio_Completions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

-- DECLARES
	DECLARE @HealthPlanID INT 

-- SETS
	SET @HealthPlanID = 171
	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(yy,DATEDIFF(yy,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0)),0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)) -- WEEKLY RUN

-- PHA DATASET
SELECT
	grp.HealthPlanName,
	grp.GroupName,
	grp.GroupNumber,
	ISNULL(mem.EligMemberID,'') AS EligMemberID,
	ISNULL(mem.EligMemberSuffix,'') AS EligMemberSuffix,
	mem.FirstName,
	mem.LastName,
	ISNULL(addr.Address1,'') AS Address1,
	ISNULL(addr.Address2,'') AS Address2,
	ISNULL(addr.City,'') AS City,
	ISNULL(addr.[State],'') AS [State],
	ISNULL(addr.ZipCode,'') AS ZipCode,
	ISNULL(CONVERT(VARCHAR(10),ha.AssessmentCompleteDate,101),'') AS PHACompleteDate
FROM
	DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
JOIN
	DA_Production.prod.Member mem WITH (NOLOCK)
	ON	(grp.GroupID = mem.GroupID)
	AND	(mem.HealthPlanID = @HealthPlanID)
LEFT JOIN
	DA_Production.prod.[Address] addr WITH (NOLOCK)
	ON	(mem.MemberID = addr.MemberID)
	AND	(addr.AddressTypeID = 6)
JOIN
	DA_Production.prod.HealthAssessment ha WITH (NOLOCK)
	ON	(mem.MemberID = ha.MemberID)
	AND	(ha.IsComplete = 1)
	AND	(ha.IsPrimarySurvey = 1)
	AND	(ha.AssessmentCompleteDate >= @inBeginDate)
	AND	(ha.AssessmentCompleteDate < @inEndDate)
ORDER BY
	grp.HealthPlanName,
	grp.GroupName,
	mem.LastName,
	mem.FirstName

-- BIOMETRICS SCREENINGS DATASET	
SELECT
	grp.HealthPlanName,
	grp.GroupName,
	grp.GroupNumber,
	ISNULL(mem.EligMemberID,'') AS EligMemberID,
	ISNULL(mem.EligMemberSuffix,'') AS EligMemberSuffix,
	mem.FirstName,
	mem.LastName,
	ISNULL(addr.Address1,'') AS Address1,
	ISNULL(addr.Address2,'') AS Address2,
	ISNULL(addr.City,'') AS City,
	ISNULL(addr.[State],'') AS [State],
	ISNULL(addr.ZipCode,'') AS ZipCode,
	ISNULL(CONVERT(VARCHAR(10),scr.ScreeningDate,101),'') AS BiometricsScreeningCompleteDate
FROM
	DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
JOIN
	DA_Production.prod.Member mem WITH (NOLOCK)
	ON	(grp.GroupID = mem.GroupID)
	AND	(mem.HealthPlanID = @HealthPlanID)
LEFT JOIN
	DA_Production.prod.[Address] addr WITH (NOLOCK)
	ON	(mem.MemberID = addr.MemberID)
	AND	(addr.AddressTypeID = 6)
JOIN
	DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
	ON	(mem.MemberID = scr.MemberID)
	AND	(scr.SourceAddDate >= @inBeginDate)
	AND	(scr.SourceAddDate < @inEndDate)
ORDER BY
	grp.HealthPlanName,
	grp.GroupName,
	mem.LastName,
	mem.FirstName

END
GO
