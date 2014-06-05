SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-12-13
-- Description:	Lockton Biometrics Outbound Data Feed
--	
-- Notes:		This sproc will be used to pass data to Lockton (broker) on behalf of its clients
--				Deliver file as pipe '|' delimited text file
--
--				The difference between this feed and the standard biometrics sproc is that
--				this feed does not include the contininevalue measure.
--
--
-- =============================================

CREATE PROCEDURE [lockton].[proc_Biometrics_OutboundDataFeed]
	@inGroupID INT,
	@inBeginDate DATETIME,
	@inEndDate DATETIME
AS
BEGIN

	SET NOCOUNT ON;

	SELECT
		REPLACE(grp.GroupName,',','') AS CompanyName,
		mem.EligMemberID AS EligMemberID,
		mem.EligMemberSuffix AS EligMemberSuffix,
		mem.FirstName AS FirstName,
		mem.LastName AS LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS DOB,
		mem.Relationship AS Relationship,
		mem.Gender AS Gender,
		mem.AltID1,
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
		val.CotinineFlag AS CotinineFlag,
		val.SmokeFlag AS SmokeFlag
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = @inGroupID)
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
