SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 4/30/2014
-- Description:	Telligen Lfestyle and Health Coaching Aggregate Participation

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [telligen].[proc_Coaching_AggregateParticipation]

AS
BEGIN
	SET NOCOUNT ON;
	
IF OBJECT_ID('tempdb.dbo.#HealthCoaching') IS NOT NULL
BEGIN
	DROP TABLE #HealthCoaching
END

SELECT
	mem.MemberID,
	app.ProgramName,
	CASE WHEN app.AppointmentTypeID = 26 OR app.ProgramName = 'Post Bariatric Surgery' THEN 1 ELSE 0 END AS [NurseCall],
	CASE WHEN app.AppointmentTypeID != 26 AND app.ProgramName != 'Post Bariatric Surgery' THEN 1 ELSE 0 END AS [NonNurseCall]
INTO
	#HealthCoaching
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = hpg.GroupID)
	AND	(hpg.GroupID = 202842)
JOIN
	DA_Production.prod.ProgramEnrollment pge
	ON	(pge.MemberID = mem.MemberID)
JOIN
		(
		SELECT
			app.MemberID,
			prg.ProgramID,
			prg.ProgramName,
			prg.EnrollmentDate,
			prg.TerminationDate,
			app.AppointmentBeginDate,
			app.AppointmentTypeID,
			app.AppointmentTypeName,
			ROW_NUMBER() OVER (PARTITION BY app.MemberID ORDER BY app.AppointmentBeginDate) AS TobCoachSeq
		FROM
			DA_Production.prod.ProgramEnrollment prg WITH (NOLOCK)
		JOIN
			DA_Production.prod.Appointment app WITH (NOLOCK)
			ON	(prg.MemberID = app.MemberID)
			AND (app.AppointmentStatusID = 4) -- Call Completed
			AND (app.AppointmentBeginDate >= '10/1/2013')
		WHERE
			prg.GroupID = 202842 AND
			app.AppointmentBeginDate >= prg.EnrollmentDate AND
			app.AppointmentBeginDate < ISNULL(prg.TerminationDate,'2999-12-31')
		) app
		ON	(mem.MemberID = app.MemberID)



SELECT
	ProgramName,
	SUM(NurseCall) AS [HC_CallCount],
	SUM(NonNurseCall) AS [LC_CallCount],
	COUNT(DISTINCT CASE WHEN NurseCall = 1 THEN MemberID END) AS [HC_DistintMemberCount],
	COUNT(DISTINCT CASE WHEN NonNurseCall = 1 THEN MemberID END) AS [LC_DistinctMemberCount],
	COUNT(DISTINCT MemberID) AS [DistinctMemberCount]
FROM
	#HealthCoaching
GROUP BY
	ProgramName
	
UNION ALL

SELECT
	'Overall Population',
	SUM(NurseCall) AS [HC_CallCount],
	SUM(NonNurseCall) AS [LC_CallCount],
	COUNT(DISTINCT CASE WHEN NurseCall = 1 THEN MemberID END) AS [HC_DistintMemberCount],
	COUNT(DISTINCT CASE WHEN NonNurseCall = 1 THEN MemberID END) AS [LC_DistinctMemberCount],
	COUNT(DISTINCT MemberID) AS [DistinctMemberCount]
FROM
	#HealthCoaching


	
SELECT
	'1000' + CAST(DENSE_RANK() OVER (ORDER BY MemberID) AS VARCHAR(10)) AS [DeIdentifiedMemberID],
	ProgramName,
	SUM(NurseCall) AS HC_CallCount,
	SUM(NonNurseCall) AS LC_CallCount
FROM
	#HealthCoaching
GROUP BY
	MemberID,
	ProgramName


IF OBJECT_ID('tempdb.dbo.#HealthCoaching') IS NOT NULL
BEGIN
	DROP TABLE #HealthCoaching
END

END
GO
