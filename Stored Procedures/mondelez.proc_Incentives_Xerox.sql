SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 1/27/2014
-- Description:	This procedure is the incentive data feed
--				for Mondelez International.
--
-- Update:		
-- =============================================

CREATE PROCEDURE [mondelez].[proc_Incentives_Xerox]

AS
	BEGIN

	SET NOCOUNT ON;


	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END


	SELECT
		*
	INTO #Incentive
	FROM
		(
		--Header Record
		  SELECT
		 'H' +
		  '00000' +
		  (SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',30,'HRIncentive')) +
		  CONVERT(CHAR(8),GETDATE(),112) +
		 (SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',30,'Mondelez International')) +
		  SPACE(26) AS [Records]
	
	
	UNION ALL
	


		--Detail Records
	
	SELECT ISNULL(mem.AltID1,'') +
		  ',' +
		  'OTHERBENEFITSEARNED' +
		  ',' +
		  CAST(SUM(
			 CASE 
				WHEN aetna.MemberID IS NOT NULL AND csf.CS4 = 'AETNA'
				THEN aetna.ActivityValue
				When kaiser.MemberID IS NOT NULL AND csf.CS4 = 'KAISER'
				THEN kaiser.ActivityValue
				WHEN waived.MemberID IS NOT NULL AND csf.CS4 = 'WAIVED'
				THEN waived.ActivityValue
				ELSE 0 
			 END) AS VARCHAR)
	
	FROM
		DA_Production.prod.HealthPlanGroup grp
	JOIN
		DA_Production.prod.Member mem
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 204296)
	JOIN
		DA_Production.prod.CSFields csf
		ON	(csf.MemberID = mem.MemberID)
	LEFT JOIN
		Healthyroads.dbo.IC_MemberActivityItem aetna
		ON	(aetna.MemberID = mem.MemberID)
		AND	(aetna.Deleted = 0)
		AND	(aetna.ClientIncentivePlanID = 1264)
		AND (aetna.ActivityItemID IN (
									6555, --(PHA and Bio Screening)
									6558, --(Coaching Session)
									6560, --(Worksite Challenge)
									6561, --(In-Touch Nurse Care Program)
									6563, --(Annual Physical)
									6564 --(Well-Woman Exam)
									)
			)

	LEFT JOIN
		Healthyroads.dbo.IC_MemberActivityItem kaiser
		ON	(kaiser.MemberID = mem.MemberID)
		AND	(kaiser.Deleted = 0)
		AND	(kaiser.ClientIncentivePlanID = 1266)
		AND (kaiser.ActivityItemID IN (
									6566, --(PHA and Bio Screening)
									6569, --(Coaching Session)
									6571 --(Worksite Health Challenge)
									)
			)
	LEFT JOIN
		Healthyroads.dbo.IC_MemberActivityItem waived
		ON	(waived.MemberID = mem.MemberID)
		AND	(waived.Deleted = 0)
		AND	(waived.ClientIncentivePlanID = 1268)
		AND (waived.ActivityItemID IN (
									6573, --(Coaching Session)
									6575 --(Worksite Health Challenge)
									)
			)

	WHERE
		csf.CS4 IN ('AETNA','KAISER','WAIVED')
	GROUP BY
		ISNULL(mem.AltID1,'')
	
	HAVING
		SUM(
			CASE 
				WHEN aetna.MemberID IS NOT NULL AND csf.CS4 = 'AETNA'
				THEN aetna.ActivityValue
				When kaiser.MemberID IS NOT NULL AND csf.CS4 = 'KAISER'
				THEN kaiser.ActivityValue
				WHEN waived.MemberID IS NOT NULL AND csf.CS4 = 'WAIVED'
				THEN waived.ActivityValue
				ELSE 0 
			 END) > 0
								
		) inc

	DECLARE @RecordCount INT
	SET @RecordCount = (
						SELECT COUNT(*)-1 FROM #Incentive --The header record is subtracted from the detail count
						)	

	SELECT
		*
	FROM
		#Incentive
	
	UNION ALL
		--Trailer Records
		SELECT
		  'T'+
		  '000000000' +
		  CAST(RIGHT('000000000'+CONVERT(VARCHAR,@RecordCount),10) as VARCHAR(10)) +
		  '0000000000' +
		  '0000000000' +
		  '0000000000' +
		  SPACE(1926)
ORDER BY 1
	
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

END
GO
