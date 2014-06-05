SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-11-01
-- Description: Harley Davidson Incentives Report (ClassCode)
--
-- Notes:		This report is a custom report that outputs specific codes 
--				provided by Harley in order to pass to WageWorks (vendor).
--				
--				Each year this report is run you will have to revisit the DOH dates and
--				if anything about the activity and points mapping has changed.
--
-- Updates:		WilliamPe 20131104
--				Modified to include all eligible members regardless if they did any activities in the previous 
--				year's plan
-- =============================================

CREATE PROCEDURE [harley].[proc_Incentives_ClassCode]

AS
BEGIN

	SET NOCOUNT ON;

/*============================================ CLEAN UP ==============================================*/

	IF OBJECT_ID('tempdb.dbo.#Eligible') IS NOT NULL 
	BEGIN
		DROP TABLE #Eligible
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL 
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#Results') IS NOT NULL 
	BEGIN
		DROP TABLE #Results
	END
	
/*=========================================== ELIGIBLE ===============================================*/

	SELECT
	    mem.MemberID,
	    mem.RelationshipID,
		mem.EligMemberID AS 'ID',
		mem.SubscriberSSN AS 'SSN',
		mem.FirstName AS 'FirstName',
		mem.LastName AS 'LastName',
	    cs.CS1 AS 'LocationCode',
		cs.CS2 AS 'EmploymentStatus',
		CASE WHEN ISDATE(cs.CS3) = 1 THEN CAST(cs.CS3 AS DATETIME) ELSE NULL END AS 'DateofHire',
		elig.EffectiveDate,
		elig.TerminationDate
	INTO
		#Eligible
	FROM
	    DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 118977)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		(
		SELECT
			MemberID,
			EffectiveDate,
			TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.Eligibility WITH (NOLOCK)
		WHERE
			GroupID = 118977
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)
		AND	(ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))


/*==================================== INCENTIVE ACTIVITY TEMP =======================================*/

	SELECT
	    mem.MemberID,
	    mem.RelationshipID,
		prmem.ID,
		prmem.SSN,
		prmem.FirstName,
		prmem.LastName,
	    prmem.LocationCode,
		prmem.EmploymentStatus,
		prmem.DateofHire,
		CASE WHEN sps.MemberID IS NOT NULL THEN 1 ELSE 0 END AS 'HasEligibleSpouse',
		CASE mem.RelationshipID WHEN 1 THEN 1 ELSE 0 END AS 'IsSpouse',
		inc.PointsValue AS 'Points',
		inc.ActivityDescription AS 'Activity',
		inc.ActivityDate AS 'ActivityDate',
		inc.RecordEffectiveBeginDate AS 'RecordReceivedDate'
	INTO
		#Incentive
	FROM
	    #Eligible mem
	JOIN
		#Eligible prmem WITH (NOLOCK)
		ON	(mem.ID = prmem.ID)
		AND	(prmem.RelationshipID = 6)
	LEFT JOIN
		#Eligible sps WITH (NOLOCK)
		ON	(mem.ID = sps.ID)
		AND	(sps.RelationshipID = 1)
	LEFT JOIN
        [ASH-HRLReports].HrlDw.dbo.vwMemberIncentiveActivity_WithHistory inc WITH (NOLOCK)
		ON	(inc.MemberID = mem.MemberID) 
		AND	(inc.FK_ClientIncentivePlanID = 705)
		AND	(inc.RecordEffectiveEndDate IS NULL)

/*============================================ RESULTS ===============================================*/

	SELECT
		inc.ID,
		inc.SSN,
		inc.FirstName,
		inc.LastName,
		inc.LocationCode,
		inc.EmploymentStatus,
		inc.DateofHire,
		inc.HasEligibleSpouse,
		act.PHA_EE,
		act.BIO_EE,
		act.PHA_SP,
		act.BIO_SP,
		pts.PTS_EE,
		pts.PTS_SP,
		CASE WHEN act.PHA_EE IS NULL OR act.BIO_EE IS NULL THEN NULL ELSE pts.PTS_EE END AS EVAL_PTS_EE,
		CASE WHEN act.PHA_SP IS NULL OR act.BIO_SP IS NULL THEN NULL ELSE pts.PTS_SP END AS EVAL_PTS_SP,
		0 AS PTS_CLASSCODE_EE,
		0 AS PTS_CLASSCODE_SP,
		CASE WHEN act.PHA_EE IS NOT NULL AND act.BIO_EE IS NOT NULL THEN 1 ELSE 0 END AS PHABIO_EE,
		CASE WHEN act.PHA_SP IS NOT NULL AND act.BIO_SP IS NOT NULL THEN 1 ELSE 0 END AS PHABIO_SP	
	INTO
		#Results
	FROM
		#Incentive inc
	LEFT JOIN
		(
			SELECT
				ID,
				PHA_EE,
				PHA_SP,
				BIO_EE,
				BIO_SP
			FROM
				(
				SELECT
					ID,
					'PHA_EE' AS MeasureName,
					ActivityDate AS Measure
				FROM
					#Incentive
				WHERE
					Activity = 'Health Assessment' AND
					IsSpouse = 0
				
				UNION

				SELECT
					ID,
					'PHA_SP' AS MeasureName,
					ActivityDate   AS Measure
				FROM
					#Incentive
				WHERE
					Activity = 'Health Assessment' AND
					IsSpouse = 1
				
				UNION
				
				SELECT
					ID,
					'BIO_EE' AS MeasureName,
					ActivityDate AS Measure
				FROM
					#Incentive
				WHERE
					Activity = 'Biometrics Screening' AND
					IsSpouse = 0
				
				UNION

				SELECT
					ID,
					'BIO_SP' AS MeasureName,
					ActivityDate AS Measure
				FROM
					#Incentive
				WHERE
					Activity = 'Biometrics Screening' AND
					IsSpouse = 1	
			   ) subset
				PIVOT 
			   (
				MAX(Measure) FOR MeasureName IN ([PHA_EE],[PHA_SP],[BIO_EE],[BIO_SP])
			   ) pvt
		) act
		ON	(inc.ID = act.ID)
	LEFT JOIN
		(
			SELECT
				ID,
				PTS_EE,
				PTS_SP
			FROM
				(
				SELECT
					ID,
					'PTS_EE' AS MeasureName,
					SUM(Points) AS Measure
				FROM
					#Incentive
				WHERE
					IsSpouse = 0 AND
					Activity NOT IN ('Biometrics Screening','Health Assessment') AND
					Points != 0
				GROUP BY
					ID
				
				UNION

				SELECT
					ID,
					'PTS_SP' AS MeasureName,
					SUM(Points) AS Measure
				FROM
					#Incentive
				WHERE
					IsSpouse = 1 AND
					Activity NOT IN ('Biometrics Screening','Health Assessment') AND
					Points != 0
				GROUP BY
					ID
			   ) subset
				PIVOT 
			   (
				MAX(Measure) FOR MeasureName IN ([PTS_EE],[PTS_SP])
			   ) pvt
		) pts
		ON	(pts.ID = inc.ID)
	GROUP BY
		inc.ID,
		inc.SSN,
		inc.FirstName,
		inc.LastName,
		inc.LocationCode,
		inc.EmploymentStatus,
		inc.DateofHire,
		inc.HasEligibleSpouse,
		act.PHA_EE,
		act.BIO_EE,
		act.PHA_SP,
		act.BIO_SP,
		pts.PTS_EE,
		pts.PTS_SP,
		CASE WHEN act.PHA_EE IS NULL OR act.BIO_EE IS NULL THEN NULL ELSE pts.PTS_EE END,
		CASE WHEN act.PHA_SP IS NULL OR act.BIO_SP IS NULL THEN NULL ELSE pts.PTS_SP END,
		CASE WHEN act.PHA_EE IS NOT NULL AND act.BIO_EE IS NOT NULL THEN 1 ELSE 0 END,
		CASE WHEN act.PHA_SP IS NOT NULL AND act.BIO_SP IS NOT NULL THEN 1 ELSE 0 END	

	
	UPDATE r
		SET r.PTS_CLASSCODE_EE = codeEE.PointsClassCode
	FROM
		#Results r
	JOIN
		(
		SELECT
			r.ID,
			r.PTS_EE,
			r.EVAL_PTS_EE,
			trans.PointsClassCode,
			trans.MinPointsValue,
			trans.MaxPointsValue
		FROM
			#Results r
		CROSS JOIN
			DA_Reports.harley.PointsTranslation trans WITH (NOLOCK)
		WHERE
			r.EVAL_PTS_EE BETWEEN trans.MinPointsValue AND trans.MaxPointsValue
		) codeEE
		ON	(r.ID = codeEE.ID)

	UPDATE r
		SET r.PTS_CLASSCODE_SP = codeSP.PointsClassCode
	FROM
		#Results r
	JOIN
		(
		SELECT
			r.ID,
			r.PTS_SP,
			r.EVAL_PTS_SP,
			trans.PointsClassCode,
			trans.MinPointsValue,
			trans.MaxPointsValue
		FROM
			#Results r
		CROSS JOIN
			DA_Reports.harley.PointsTranslation trans WITH (NOLOCK)
		WHERE
			r.EVAL_PTS_SP BETWEEN trans.MinPointsValue AND trans.MaxPointsValue
		) codeSP
		ON	(r.ID = codeSP.ID)

/*======================================== DOH LESS THAN  ============================================*/

	SELECT 
		r.ID,
		r.SSN,
		r.FirstName,
		r.LastName,
		r.LocationCode,
		r.EmploymentStatus,
		CONVERT(VARCHAR(10),r.DateofHire,101) AS DateofHire,
		r.HasEligibleSpouse,
		ISNULL(CONVERT(VARCHAR(10),r.PHA_EE,101),'') AS PHA_EE,
		ISNULL(CONVERT(VARCHAR(10),r.BIO_EE,101),'') AS BIO_EE,
		r.PHABIO_EE,
		ISNULL(CONVERT(VARCHAR(10),r.PHA_SP,101),'') AS PHA_SP,
		ISNULL(CONVERT(VARCHAR(10),r.BIO_SP,101),'') AS BIO_SP,
		r.PHABIO_SP,
		ISNULL(CAST(r.PTS_EE AS VARCHAR(4)),'') AS PTS_EE,
		ISNULL(CAST(r.PTS_SP AS VARCHAR(4)),'') AS PTS_SP,
		class.ClassCode AS Class
	FROM
		#Results r
	JOIN
		(
		SELECT
			r.ID,
			map.ClassCode
		FROM
			#Results r
		JOIN
			DA_Reports.harley.PointsMapping map WITH (NOLOCK)
			ON	(r.PTS_CLASSCODE_EE = map.EmployeeClassCode)
			AND	(r.PTS_CLASSCODE_SP = map.SpouseClassCode)
		) class
		ON	(r.ID = class.ID)	
	WHERE
		r.DateofHire < '2012-12-02'
	
/*===================================== DOH GREATER THAN EQUAL  ======================================*/

	SELECT 
		r.ID,
		r.SSN,
		r.FirstName,
		r.LastName,
		r.LocationCode,
		r.EmploymentStatus,
		CONVERT(VARCHAR(10),r.DateofHire,101) AS DateofHire,
		r.HasEligibleSpouse,
		ISNULL(CONVERT(VARCHAR(10),r.PHA_EE,101),'') AS PHA_EE,
		ISNULL(CONVERT(VARCHAR(10),r.BIO_EE,101),'') AS BIO_EE,
		r.PHABIO_EE,
		ISNULL(CONVERT(VARCHAR(10),r.PHA_SP,101),'') AS PHA_SP,
		ISNULL(CONVERT(VARCHAR(10),r.BIO_SP,101),'') AS BIO_SP,
		r.PHABIO_SP,
		ISNULL(CAST(r.PTS_EE AS VARCHAR(4)),'') AS PTS_EE,
		ISNULL(CAST(r.PTS_SP AS VARCHAR(4)),'') AS PTS_SP,
		class.ClassCode AS Class
	FROM
		#Results r
	JOIN
		(
		SELECT
			r.ID,
			map.ClassCode
		FROM
			#Results r
		JOIN
			DA_Reports.harley.ActivityMapping map WITH (NOLOCK)
			ON	(r.PHABIO_EE = map.EmployeePHABio)
			AND	(r.PHABIO_SP = map.SpousePHABio)
		) class
		ON	(r.ID = class.ID)			
	WHERE
		r.DateofHire >= '2012-12-02'


/*============================================ CLEAN UP ==============================================*/

	IF OBJECT_ID('tempdb.dbo.#Eligible') IS NOT NULL 
	BEGIN
		DROP TABLE #Eligible
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL 
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#Results') IS NOT NULL 
	BEGIN
		DROP TABLE #Results
	END
	
END
GO
