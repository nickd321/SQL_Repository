SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 4/14/2014
-- Description:	PepsiCo Members with missing biometric data

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [pepsico].[proc_Biometrics_MissingMeasures]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

--For Testing: DECLARE @inBeginDate DATETIME, @inEndDate DATETIME
	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(wk,DATEDIFF(wk,0,GETDATE())-1,0)) --Defaults to Previous Monday
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(wk,DATEDIFF(wk,0,GETDATE()),0)) --Defaults to current Monday

	SELECT
		hpg.GroupName,
		mem.FirstName,
		mem.LastName,
		mem.EligMemberID AS [GPID],
		addr.Address1,
		addr.Address2,
		addr.City,
		addr.[State],
		addr.ZipCode
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem
		ON	(hpg.GroupID = mem.GroupID)
		AND	(hpg.GroupID = 206772)
	JOIN
		DA_Production.prod.BiometricsScreening bio
		ON	(bio.MemberID = mem.MemberID)
		AND	(bio.IsPregnant = 0)
		AND	(bio.SourceAddDate >= @inBeginDate)
		AND	(bio.SourceAddDate < @inEndDate)
	LEFT JOIN
		DA_Production.prod.[Address] addr
		ON	(addr.MemberID = mem.MemberID)
		AND	(addr.AddressTypeID = 6)
	LEFT JOIN
		DA_Production.prod.BiometricsScreeningResults outc
		ON	(bio.MemberScreeningID = outc.MemberScreeningID)
	WHERE
		outc.HeightInches IS NULL OR
		outc.WeightLbs IS NULL OR
		outc.BMI IS NULL OR
		outc.Cholesterol IS NULL OR
		outc.Glucose IS NULL OR
		outc.Systolic IS NULL OR
		outc.Diastolic IS NULL

END
GO
