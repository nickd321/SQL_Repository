SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		William Perez
-- Create date: 2014-02-06
-- Description:	Kaydon Incentives Report
--
-- Notes:
--
-- Updates:
-- =============================================

CREATE PROCEDURE [kaydon].[proc_Incentives] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL,
	@inReport INT = 1
AS
BEGIN

	SET NOCOUNT ON;

	IF @inReport <= 0 OR @inReport > 2
	BEGIN
	RAISERROR (N'Please pass integers 1 or 2 for the @inReport parameter. Parameters are @inBeginDate DATETIME, @inEndDate DATETIME, @inReport INT', -- Message text.
			   10, -- Severity,
			   1  -- State,
			   )
	END

	-- FOR TESTING
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME, @inReport INT

/*=========================================DECLARE VARIABLES =========================================*/

	DECLARE @RecordCount INT

/*=========================================== SET VARIABLES ==========================================*/


	-- END DATE DEFAULTS TO THE 20th OF THE CURRENT MONTH (DELIVERY DATE)
	SET @inBeginDate = ISNULL(@inBeginDate,'2013-09-01') 
	SET @inEndDate = ISNULL(@inEndDate, DATEADD(dd,19,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0)))


/*================================================== CLEAN UP ==================================================*/

	IF OBJECT_ID('tempdb.dbo.#Qualified') IS NOT NULL
	BEGIN
		DROP TABLE #Qualified
	END

	IF OBJECT_ID('tempdb.dbo.#Member') IS NOT NULL
	BEGIN
		DROP TABLE #Member
	END

/*=================================================== MEMBER ===================================================*/
	SELECT
		mem.MemberID,
		mem.GroupID,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		mem.AltID1,
		cs.CS10
	INTO
		#Member
	FROM
		DA_Production.prod.Member mem WITH (NOLOCK)
	JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	WHERE
		mem.GroupID = 191949 AND
		cs.CS10 IS NOT NULL

/*=============================================== QUALIFIED DATE ===============================================*/

	SELECT
		mem.MemberID,
		mem.AltID1 AS [ParticipantID],
		mem.CS10 AS [MemberPlanBeginDate],
		CASE
			bio.Negative
				WHEN 1 THEN 'LEVEL2'
				WHEN 0 THEN
						CASE WHEN sess.AppointmentBeginDate IS NOT NULL THEN 'LEVEL2' ELSE 'LEVEL1' END
		END AS IncentiveLevel,
		CASE
			bio.Negative
				WHEN 1 THEN
						dbo.func_MAX_DATETIME(pha.AssessmentCompleteDate, bio.SourceAddDate)
				WHEN 0 THEN
						dbo.func_MAX_DATETIME(sess.AppointmentBeginDate,dbo.func_MAX_DATETIME(pha.AssessmentCompleteDate, bio.SourceAddDate))
		END AS QualifiedDate
	INTO
		#Qualified
	FROM
		#Member mem
	-- PHA DATA	
	JOIN
		(
		SELECT
			mem.MemberID,
			pha.AssessmentCompleteDate,
			ROW_NUMBER() OVER (PARTITION BY mem.MemberID ORDER BY pha.AssessmentCompleteDate) AS PHASeq
		FROM
			#Member mem
		JOIN
			DA_Production.prod.HealthAssessment pha WITH (NOLOCK)
			ON	(mem.MemberID = pha.MemberID)
		WHERE
			pha.IsPrimarySurvey = 1 AND
			pha.IsComplete = 1 AND
			pha.AssessmentCompleteDate >= '2013-09-01' AND -- InitialBeginDate
			pha.AssessmentCompleteDate < CASE
											ISDATE(mem.CS10) 
												WHEN 1 THEN 
															CASE
																WHEN DATEADD(dd,30,CAST(mem.CS10 AS DATETIME)) >= '2013-10-04'
																THEN DATEADD(dd,30,CAST(mem.CS10 AS DATETIME)) 
																ELSE '2013-10-04'
															END
												ELSE '2013-10-04' 
										 END
		) pha
		ON	(mem.MemberID = pha.MemberID)
		AND	(pha.PHASeq = 1)
	-- BIO DATA	                            
	JOIN
		(
			SELECT
				mem.MemberID,
				scr.SourceAddDate,
				scr.ScreeningDate,
				CASE WHEN res.SmokeFlag = 0 OR res.CotinineFlag = 0 THEN 1 ELSE 0 END AS Negative,
				ROW_NUMBER() OVER (PARTITION BY scr.MemberID, CASE WHEN res.SmokeFlag = 0 OR res.CotinineFlag = 0 THEN 1 ELSE 0 END ORDER BY scr.SourceAddDate) AS ScreenSeq,
				RANK() OVER (PARTITION BY scr.MemberID ORDER BY CASE WHEN res.SmokeFlag = 0 OR res.CotinineFlag = 0 THEN 1 ELSE 0 END DESC) AS ScreenTypeSeq
			FROM
				#Member mem
			JOIN
				DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
				ON	(mem.MemberID = scr.MemberID)
			JOIN
				DA_Production.prod.BiometricsScreeningResults res WITH (NOLOCK)
				ON	(scr.MemberScreeningID = res.MemberScreeningID)
			WHERE
				scr.ScreeningDate >= '2013-06-01' AND
				scr.ScreeningDate < CASE
										ISDATE(mem.CS10)
											WHEN 1 THEN
														CASE
															WHEN DATEADD(dd,30,CAST(mem.CS10 AS DATETIME)) >= '2013-09-24'
															THEN DATEADD(dd,30,CAST(mem.CS10 AS DATETIME)) 
															ELSE '2013-09-24'
														END 
											ELSE '2013-09-24'
									END
		) bio
		ON	(mem.MemberID = bio.MemberID)
		AND	(bio.ScreenSeq = 1)
		AND	(bio.ScreenTypeSeq = 1)
	-- COACHING DATA
	LEFT JOIN
		(
			SELECT
				MemberID,
				AppointmentBeginDate,
				ROW_NUMBER() OVER(PARTITION BY MemberID ORDER BY AppointmentBeginDate) AS SessSeq
			FROM
				DA_Production.prod.Appointment WITH (NOLOCK)
			WHERE
				AppointmentStatusID = 4 AND
				AppointmentBeginDate >= '2013-09-01'
		) sess
		ON	(mem.MemberID = sess.MemberID)
		AND	(sess.SessSeq = 4)
		AND	(bio.Negative = 0)

	-- SET RECORD COUNT
	SELECT 
		@RecordCount = COUNT(MemberID)
	FROM
		#Qualified
	WHERE
		QualifiedDate >= @inBeginDate AND QualifiedDate < @inEndDate	

/*================================================ FINAL RESULTS ===============================================*/
	IF @inReport = 1 
	BEGIN

		SELECT
			  RecordType,
			  CreationDate,
			  ClientCode,
			  VendorName,
			  RecordCount,
			  FieldSpacer1,
			  FieldSpacer2
		FROM
			(
			 SELECT
					'H' AS RecordType,
					CONVERT(VARCHAR(10),GETDATE(),120) AS CreationDate,
					'KAYDON' AS ClientCode,
					'Healthyroads' AS VendorName,
					CONVERT(VARCHAR(4),@RecordCount) AS RecordCount,
					'' AS FieldSpacer1,
					'' AS FieldSpacer2,
					0 AS SortPosition

			  UNION

			  SELECT
					'D',
					ParticipantID,
					'', -- SSN Placeholder
					'MEDICAL', -- BenefitsAreaID
					CASE WHEN QualifiedDate < '2014-01-01' THEN '2014-01-01' ELSE CONVERT(VARCHAR(10),QualifiedDate,120) END, --EffectiveStartDate
					'2014-12-31', --EffectiveEndDate
					IncentiveLevel,
					2
			  FROM
					#Qualified
			  WHERE
					QualifiedDate >= @inBeginDate AND QualifiedDate < @inEndDate
					     
			  UNION

			  SELECT
					'T',
					'KAYDON',
					CONVERT(VARCHAR(4), @RecordCount),
					CONVERT(VARCHAR(10), GETDATE(),120),
					'',
					'',
					'',
					3
					
			  ) final
		ORDER BY
			SortPosition	

	END
	
	IF @inReport = 2
	BEGIN
	
		  SELECT
				'D' AS RecordType,
				ParticipantID,
				'' AS SSN_Placeholder, -- 
				'MEDICAL' AS BenefitsAreaID,
				CASE WHEN QualifiedDate < '2014-01-01' THEN '2014-01-01' ELSE CONVERT(VARCHAR(10),QualifiedDate,120) END AS EffectiveStartDate,
				'2014-12-31' AS EffectiveEndDate,
				IncentiveLevel,
				MemberPlanBeginDate,
				MemberID AS HRDS_ID,
				CONVERT(VARCHAR(10),QualifiedDate,120) AS QualifiedDate
		  FROM
				#Qualified
		  WHERE
				QualifiedDate >= @inBeginDate AND QualifiedDate < @inEndDate
				
	END	
/*================================================== CLEAN UP ==================================================*/

	IF OBJECT_ID('tempdb.dbo.#Qualified') IS NOT NULL
	BEGIN
		DROP TABLE #Qualified
	END

END

GO
