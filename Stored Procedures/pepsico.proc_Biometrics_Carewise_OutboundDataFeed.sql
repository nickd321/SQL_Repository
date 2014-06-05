SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- ===========================================================
-- Author:			Nick Domokos
-- Create date:		12/31/2013
-- Description:		Pepsico Biometric Outbound Data Feed (Carewise)

-- Notes:			The population we will be providing to Carewise 
--					will be filtered by a particular CSField value in CS11.
--					
--					This is a weekly non-cumulative report that checks to see data
--					added within the previous week. The actual screening must take place
--					on or after 2013-07-01.
--
--					Please not the Header records are FIXED WIDTH and the Detail records
--					are TAB DELIMITED ( CHAR(9) )
--
-- Updates:			NickD_20140116
--					CS11 logic was added to exclude Carewise ineligible population
--
-- ===========================================================

CREATE PROCEDURE [pepsico].[proc_Biometrics_Carewise_OutboundDataFeed] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	-- FOR TESTING
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

	-- SETS
	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),-7))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))

/*---------------------------------------------- HEADER ----------------------------------------------*/

	-- HEADER RECORDS ARE CODED AS FIXED WIDTH
	SELECT 
		(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',6,'1015')) +
		(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',4,'SHPS')) +
		(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',8,CONVERT(VARCHAR(8),GETDATE(),112) )) +
		SPACE(2) +
		(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_LEFT('0',6,COUNT(scr.MemberScreeningID))) +
		SPACE(124)
	FROM
		DA_Production.prod.Member mem WITH (NOLOCK)
	JOIN
		DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
		ON	(mem.MemberID = scr.MemberID)
		AND	(scr.GroupID = 206772)
	JOIN
		DA_Production.prod.BiometricsScreeningResults res WITH (NOLOCK)
		ON	(scr.MemberScreeningID = res.MemberScreeningID)
	JOIN
		DA_Production.prod.CSFields csf
		ON	(mem.MemberID = csf.MemberID)
		AND	(csf.CS11 = 'Y')
	
	WHERE
		scr.SourceAddDate >= @inBeginDate AND
		scr.SourceAddDate < @inEndDate AND
		scr.ScreeningDate >= '2013-07-01'
		
		

/*---------------------------------------------- DETAIL ----------------------------------------------*/	

	UNION ALL

	-- DETAIL RECORDS ARE CODED AS TAB DELIMITED
	SELECT
		'' + CHAR(9) +
		'' + CHAR(9) +
		CAST(scr.MemberScreeningID AS VARCHAR) + CHAR(9) +
		'' + CHAR(9) +
		'1017' + CHAR(9) +
		'PepsiCo' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		ISNULL(mem.EligMemberID,'') + CHAR(9) +
		'0000000000' + CHAR(9) +
		'' + CHAR(9) +
		CASE WHEN mem.Relationship = 'Primary' THEN 'E'
			 WHEN mem.Relationship = 'Spouse' THEN 'SC'
			 END + CHAR(9) + --Code to convert table values to the desired output
		'' + CHAR(9) +
		'Y' + CHAR(9) +
		'N' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		CAST(CASE WHEN SmokeFlag = 0 THEN 'N' WHEN SmokeFlag = 1 THEN 'Y' ELSE '' END AS VARCHAR) + CHAR(9) +  -- SMOKE FLAG?
		mem.LastName + CHAR(9) +
		mem.FirstName + CHAR(9) +
		'10221 Wateridge Circle' + CHAR(9) +
		'' + CHAR(9) +
		'San Diego' + CHAR(9) +
		'CA' + CHAR(9) +
		'92121' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		mem.Gender + CHAR(9) +
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') + CHAR(9) +
		ISNULL(CAST(res.HeightInches AS VARCHAR),'') + CHAR(9) +
		ISNULL(CAST(res.WeightLbs AS VARCHAR),'') + CHAR(9) +
		'' + CHAR(9) +
		ISNULL(CAST(res.WaistCircumference AS VARCHAR),'') + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +	
		'' + CHAR(9) +
		ISNULL(CAST(res.Systolic AS VARCHAR),'') + CHAR(9) +
		ISNULL(CAST(res.Diastolic AS VARCHAR),'') + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		ISNULL(CAST(CAST(res.BMI AS DEC(18,1)) AS VARCHAR),'') + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		CONVERT(VARCHAR(10),scr.ScreeningDate,101) + CHAR(9) +
		CONVERT(VARCHAR(10),scr.ScreeningDate,101) + CHAR(9) +
		CONVERT(VARCHAR(10),scr.ScreeningDate,101) + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		ISNULL(CASE WHEN scr.FileSource IN ('Quest','Manual') THEN 'V' WHEN FileSource = 'Standard' THEN 'F' END,'') + CHAR(9) + -- Standard = 'Summit'; Manual = 'Physican Form'
		ISNULL(CASE WHEN scr.FileSource IN ('Quest','Manual') THEN 'IO' WHEN FileSource = 'Standard' THEN 'WS' END,'') + CHAR(9) + -- Standard = 'Summit'; Manual = 'Physican Form'
		ISNULL(CAST(res.Glucose AS VARCHAR),'') + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		ISNULL(CAST(res.Triglycerides AS VARCHAR),'') + CHAR(9) +
		ISNULL(CAST(res.Cholesterol AS VARCHAR),'') + CHAR(9) +
		ISNULL(CAST(res.HDL AS VARCHAR),'') + CHAR(9) +
		ISNULL(CAST(res.LDL AS VARCHAR),'') + CHAR(9) +
		CAST(CASE res.CotinineFlag WHEN 1 THEN 'POS' WHEN 0 THEN 'NEG' ELSE '' END AS VARCHAR) + CHAR(9) +
		'' + CHAR(9) +
		ISNULL(CAST(res.HDLCholesterolRatio AS VARCHAR),'') + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		ISNULL(CAST(CAST(res.Hemoglobin AS DEC(18,1)) AS VARCHAR),'') + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		'' + CHAR(9) +
		''
	FROM
		DA_Production.prod.Member mem WITH (NOLOCK)
	JOIN
		DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
		ON	(mem.MemberID = scr.MemberID)
		AND	(scr.GroupID = 206772)
	JOIN
		DA_Production.prod.BiometricsScreeningResults res WITH (NOLOCK)
		ON	(scr.MemberScreeningID = res.MemberScreeningID)
	JOIN
		DA_Production.prod.CSFields csf
		ON	(mem.MemberID = csf.MemberID)
		AND	(csf.CS11 = 'Y')
	WHERE
		scr.SourceAddDate >= @inBeginDate AND
		scr.SourceAddDate < @inEndDate AND
		scr.ScreeningDate >= '2013-07-01'
END
GO
