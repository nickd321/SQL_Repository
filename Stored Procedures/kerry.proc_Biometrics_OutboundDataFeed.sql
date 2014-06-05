SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 2014-02-13
-- Description:	Outbound biometric data feed to Anthem on behalf of Kerry Ingredients and Flavors.
--
--
-- =============================================
CREATE PROCEDURE [kerry].[proc_Biometrics_OutboundDataFeed]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	
	
	SET NOCOUNT ON;
	--Declare @inBeginDate DATETIME, @inEndDate DATETIME

	SET @inBeginDate = ISNULL(@inBeginDate, '1/1/2014')
	SET @inEndDate = ISNULL(@inEndDate, DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))
	
	SELECT
		REPLACE(grp.GroupName,',','') AS CompanyName,
		mem.EligMemberID AS EligMemberID,
		mem.EligMemberSuffix AS EligMemberSuffix,
		mem.FirstName AS FirstName,
		mem.LastName AS LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS DOB,
		mem.Relationship AS Relationship,
		mem.Gender AS Gender,
		mem.SubscriberSSN AS SSN,
		scr.Location AS BiometricsEventLocation,
		CONVERT(VARCHAR(10),scr.ScreeningDate,101) AS BiometricsScreeningDate,
		CONVERT(VARCHAR(10),scr.SourceAddDate,101) AS BiometricsLoadDate,
		scr.IsPregnant AS IsPregnant,
		scr.IsFasting AS IsFasting,
		val.HeightInches AS HeightInches,
		val.WeightLbs AS WeightLbs,
		val.BMI,
		val.WaistCircumference AS WaistCircumference,
		val.Systolic AS Systolic,
		val.Diastolic AS Diastolic,
		val.Cholesterol AS Cholesterol,
		val.HDLCholesterolRatio AS HDLCholesterolRatio,
		val.Triglycerides AS Triglycerides,
		val.HDL AS HDL,
		val.LDL AS LDL,
		val.Glucose AS Glucose,
		val.Hemoglobin AS Hemoglobin,
		val.Cotinine AS CotinineValue,
		val.CotinineFlag AS CotinineFlag,
		val.SmokeFlag AS SmokeFlag
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 172754)
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
