SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-05-15
-- Description:	Outbound biometric data feed to Anthem BCBS on behalf of AMF Bowling Worldwide
--
-- Notes:		Verified biometric data elements we should report for this client through HOL (Alicia Durante). 
--				Monthly report. Cumulative.
--
-- =============================================
CREATE PROCEDURE [amf].[proc_BiometricsFeed] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;
	
	SET @inBeginDate = ISNULL(@inBeginDate, DATEADD(yy,DATEDIFF(yy,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0)),0))
	SET @inEndDate = ISNULL(@inEndDate, DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))
	
	SELECT
		grp.GroupName AS CompanyName,
		ISNULL(scr.Location,'') AS BiometricsEventLocation,
		scr.IsPregnant,
		scr.IsFasting,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS DOB,
		CONVERT(VARCHAR(10),scr.ScreeningDate,101) AS BiometricsEventDate,
		mem.EligMemberID AS EligMemberID,
		mem.EligMemberSuffix AS EligMemberSuffix,
		mem.FirstName AS FirstName,
		mem.LastName AS LastName,
		ISNULL(mem.Gender,'') AS Gender,
		ISNULL(CAST(val.HeightInches AS VARCHAR(25)),'') AS HeightInches,
		ISNULL(CAST(val.WeightLbs AS VARCHAR(25)),'') AS WeightLbs,
		ISNULL(CAST(val.BMI AS VARCHAR(25)),'') AS BMI,
		ISNULL(CAST(val.Systolic AS VARCHAR(25)),'') AS Systolic,
		ISNULL(CAST(val.Diastolic AS VARCHAR(25)),'') AS Diastolic,
		ISNULL(CAST(val.Cholesterol AS VARCHAR(25)),'') AS Cholesterol,
		ISNULL(CAST(val.HDLCholesterolRatio AS VARCHAR(25)),'') AS HDLCholesterolRatio,
		ISNULL(CAST(val.Triglycerides AS VARCHAR(25)),'') AS Triglycerides,
		ISNULL(CAST(val.HDL AS VARCHAR(25)),'') AS HDL,
		ISNULL(CAST(val.LDL AS VARCHAR(25)),'') AS LDL,
		ISNULL(CAST(val.Glucose AS VARCHAR(25)),'') AS Glucose
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 181006)
	JOIN
		DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
		ON	(mem.MemberID = scr.MemberID)
		AND	(scr.ScreeningDate >= @inBeginDate)
		AND	(scr.ScreeningDate < @inEndDate)
	JOIN
		DA_Production.prod.BiometricsScreeningResults val WITH (NOLOCK)
		ON	(scr.MemberScreeningID = val.MemberScreeningID)


END
GO
