SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-24
-- Description: PepsiCo Tobacco Coaching Calls Report
--
-- Notes:		Report goes to Aon Hewitt
--
-- Updates:		WilliamPe 20140126
--				Changed pad left to pad right in final result set for the EligMemberID
--
--				WilliamPe 20140221
--				Hardcoded five records that were missed due to source system bug.
--				This code will be updated removing the memberid's after the 2/24/2014 run
--
--				AdrienneB 20140226
--				Removed 2 of the hardcoded records (23222764,23174983) since they were reported on the 2/24 report.
--				The other 3 records (23093774,23138487,23145809) will need to be removed after they are sent on the 3/3 run.  
--				These 3 records were corrected by Slavisa after the 2/24 run so they will be picked up on 3/3.
--
--				AdrienneB 20140310
--				Removed 1 more of the hardcoded records (23138487) since it was sent on the 3/3 file.  The remaining 2 records
--				will be sent on today's file and then removed afterwards.
--			    After the file was sent I only removed 1 of the 2 remaining records since the other has not yet been corrected in the system.
--				I removed (23145809) but (23093774) needs to stay until it is corrected and sent.
--
--				AdrienneB20140317
--				Removed the last hardcoded record (23093774) since it was sent on the 3/17 file. 
--
--				AdrienneB 20140424
--				Hardcoded 1 record (23195343) that was missed due to source system bug.  See WO 3798
--				This code will be updated removing the memberid after the 4/28/2014 run.
--
--				AdrienneB 20140429
--				Removed the hardcoded record (23195343) since it was sent on the 4/28 file.
--
--				NickD 20140523
--				Restructureded the base data to incorporate new rules from WO 3816, which is then
--				pivoted to create the criteria to enforce those rules.
-- =============================================


CREATE PROCEDURE [pepsico].[proc_Coaching_Tobacco] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;
	
	-- FOR TESTING
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

	-- SETS
	SET @inBeginDate = ISNULL(@inBeginDate, DATEADD(dd,DATEDIFF(dd,0,GETDATE()),-7))
	SET @inEndDate = ISNULL(@inEndDate, DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#PvtBase') IS NOT NULL
	BEGIN
		DROP TABLE #PvtBase
	END
	
	IF OBJECT_ID('tempdb.dbo.#TobaccoCoaching') IS NOT NULL
	BEGIN
		DROP TABLE #TobaccoCoaching
	END

	-- Base Tobacco Data for Rule Pivot and Final Output
	SELECT
		EligMemberID,
		EESP_Indicator,
		AppointmentBeginDate AS [AppointmentBeginDate],
		RuleBucket AS [Measure],
		MAX(CoachSeq) AS [MeasureValue]
	INTO
		#PvtBase
	FROM
		(
		SELECT
			mem.MemberID,
			mem.EligMemberID,
			mem.EligMemberSuffix,
			mem.FirstName,
			mem.LastName,
			CASE mem.RelationshipID 
				WHEN 6 THEN 'E'
				WHEN 1 THEN 'S'
				WHEN 2 THEN 'S'
			END AS [EESP_Indicator],
			enr.ProgramID,
			enr.ProgramName,
			enr.EnrollmentDate,
			enr.TerminationDate,
			app.AppointmentStatusID,
			app.AppointmentStatusName,
			MAX(app.AppointmentBeginDate) OVER (PARTITION BY mem.MemberID) AS [AppointmentBeginDate],
			CASE
				WHEN app.AppointmentBeginDate >= '1/1/2014' AND app.AppointmentBeginDate < '5/1/2014'
				THEN 'Rule1'
				WHEN app.AppointmentBeginDate >= '5/1/2014' AND app.AppointmentBeginDate < '12/1/2014'
				THEN 'Rule2'
				ELSE ''
			END AS [RuleBucket],
			ROW_NUMBER() OVER (PARTITION BY mem.MemberID, CASE
				WHEN app.AppointmentBeginDate >= '1/1/2014' AND app.AppointmentBeginDate < '5/1/2014'
				THEN 'Rule1'
				WHEN app.AppointmentBeginDate >= '5/1/2014' AND app.AppointmentBeginDate < '12/1/2014'
				THEN 'Rule2'
				ELSE ''
			END ORDER BY app.AppointmentBeginDate) AS CoachSeq
		FROM
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(grp.GroupID = mem.GroupID)
			AND	(mem.GroupID = 206772)
		JOIN
			DA_Production.prod.ProgramEnrollment enr WITH (NOLOCK)
			ON	(mem.MemberID = enr.MemberID)
			AND	(enr.ProgramID = 1)
		JOIN
			DA_Production.prod.Appointment app WITH (NOLOCK)
			ON	(mem.MemberID = app.MemberID)
			AND	(app.AppointmentStatusID = 4)
			AND	(app.AppointmentBeginDate BETWEEN enr.EnrollmentDate AND ISNULL(enr.TerminationDate,'2999-12-31'))
		WHERE
			mem.RelationshipID IN (1,2,6) AND
			app.AppointmentBeginDate >= '2014-01-01' AND
			app.AppointmentBeginDate < '2015-01-01'
		) data
	GROUP BY
		EligMemberID,
		EESP_Indicator,
		AppointmentBeginDate,
		RuleBucket

	--Rule Pivot to Determine records to include in output
	SELECT
		EligMemberID,
		EESP_Indicator,
		AppointmentBeginDate,
		Rule1,
		Rule2
	INTO
		#TobaccoCoaching
	FROM
		(
		SELECT
			EligMemberID,
			EESP_Indicator,
			AppointmentBeginDate,
			Measure,
			MeasureValue
		FROM
			#PvtBase
		) act
		PIVOT
		(
		MAX(MeasureValue) FOR Measure IN ([Rule1],[Rule2])
		) pvt
	WHERE
		(AppointmentBeginDate >= @inBeginDate) AND
		(AppointmentBeginDate < @inEndDate) AND
		((Rule1 < 4 AND Rule1 > 0 AND Rule1 + Rule2 >= 4) OR
		(Rule2 = 4))
	

	DECLARE
		@RecordCount INT,
		@ReportDate DATETIME
	SET
		@RecordCount = (
						SELECT
							COUNT(EligMemberID)
						FROM
							#TobaccoCoaching
						)
	SET @ReportDate = GETDATE()

	SELECT
		[H1],
		[H2],
		[H3],
		[H4],
		[H5],
		[H6]
	FROM
		(
		SELECT
			'0' AS [H1],
			SPACE(1) AS [H2],
			'PepsiCo Tobacco Cessation' AS [H3],
			SPACE(1) AS [H4],
			CONVERT(CHAR(8),@ReportDate,112) AS [H5],
			CONVERT(CHAR(8),@ReportDate,108) AS [H6],
			1 AS [Sequence]

		UNION ALL

		SELECT
			'1' AS [D1],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',20,EligMemberID)) AS [D2],
			EESP_Indicator AS [D3],
			'Y' AS [D4],
			CONVERT(CHAR(8),AppointmentBeginDate,112) AS [D5],
			'' AS [D6],
			2 AS [Sequence]
		FROM
			#TobaccoCoaching
	
		UNION ALL

		SELECT
			'9' AS [T1],
			SPACE(1) AS [T2],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_LEFT('0',9,@RecordCount)) AS [T3],
			'' AS [T4],
			'' AS [T5],
			'' AS [T6],
			3 AS [Sequence]
		) data
	ORDER BY
		Sequence

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#PvtBase') IS NOT NULL
	BEGIN
		DROP TABLE #PvtBase
	END
	
	IF OBJECT_ID('tempdb.dbo.#TobaccoCoaching') IS NOT NULL
	BEGIN
		DROP TABLE #TobaccoCoaching
	END
END


GO
