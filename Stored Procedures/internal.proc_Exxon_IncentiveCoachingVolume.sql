SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [internal].[proc_Exxon_IncentiveCoachingVolume]

	@AsOfMonth INT = NULL,
	@AsOfDay INT = NULL

AS BEGIN

	SET @AsOfMonth = DATEPART(mm,GETDATE())
	SET @AsOfDay = DATEPART(dd,GETDATE())

	DECLARE @AsOfDate_2013 DATETIME = DATEADD(mm,(2013 - 1900) * 12 + @AsOfMonth - 1, @AsOfDay - 1)
	DECLARE @AsOfDate_2012 DATETIME = DATEADD(yy,-1,@AsOfDate_2013)

	--2013
	SELECT
		asmt.MemberID,
		strat.MemberStratificationName AS Stratification,
		CONVERT(VARCHAR,MIN(enr.EnrollmentDate),101) AS EnrollmentDate,
		ISNULL(CONVERT(VARCHAR,NULLIF(MAX(ISNULL(enr.TerminationDate,'12/31/2999')),'12/31/2999'),101),'') AS TerminationDate,
		sess.CompletedSessions,
		sess.PendingSessions,
		cch.CoachName AS Coach
	FROM
		DA_Production.prod.HealthAssessment asmt
	JOIN
		DA_Production.prod.ProgramEnrollment enr
		ON	(asmt.MemberID = enr.MemberID)
		AND	(enr.EnrollmentDate >= '1/1/2013')
		AND	(enr.EnrollmentDate < '9/30/2013')
	JOIN
		DA_Production.prod.Stratification strat
		ON	(asmt.MemberID = strat.MemberID)
		AND	(DATEDIFF(dd,asmt.AssessmentCompleteDate,strat.StratificationDate) BETWEEN 0 AND 2)
		AND	(strat.StratificationSourceID = 6)
	JOIN
		(
		SELECT
			MemberID,
			COUNT(CASE WHEN AppointmentBeginDate <= @AsOfDate_2013 THEN AppointmentID END) AS CompletedSessions,
			COUNT(CASE WHEN AppointmentBeginDate > @AsOfDate_2013 THEN AppointmentID END) AS PendingSessions
		FROM
			DA_Production.prod.Appointment
		WHERE
			AppointmentStatusID IN (1,4) AND
			AppointmentBeginDate >= '1/1/2013'
		GROUP BY
			MemberID
		) sess
		ON	(asmt.MemberID = sess.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			CoachName,
			ROW_NUMBER() OVER(PARTITION BY MemberID ORDER BY AppointmentBeginDate DESC) AS Sequence
		FROM
			DA_Production.prod.Appointment
		WHERE
			AppointmentStatusID IN (1,4) AND
			AppointmentBeginDate >= '1/1/2013'
		) cch
		ON	(asmt.MemberID = cch.MemberID)
		AND	(cch.Sequence = 1)
	WHERE
		asmt.GroupID = 37231 AND
		asmt.IsPrimarySurvey = 1 AND
		asmt.AssessmentCompleteDate >= '1/1/2013' AND
		asmt.AssessmentCompleteDate < @AsOfDate_2013
	GROUP BY
		asmt.MemberID,
		strat.MemberStratificationName,
		sess.CompletedSessions,
		sess.PendingSessions,
		cch.CoachName

	--- 2012
	SELECT
		asmt.MemberID,
		strat.MemberStratificationName AS Stratification,
		CONVERT(VARCHAR,MIN(enr.EnrollmentDate),101) AS EnrollmentDate,
		ISNULL(CONVERT(VARCHAR,NULLIF(MAX(ISNULL(enr.TerminationDate,'12/31/2999')),'12/31/2999'),101),'') AS TerminationDate,
		sess.CompletedSessions,
		sess.PendingSessions,
		cch.CoachName AS Coach
	FROM
		DA_Production.prod.HealthAssessment asmt
	JOIN
		DA_Production.prod.ProgramEnrollment enr
		ON	(asmt.MemberID = enr.MemberID)
		AND	(enr.EnrollmentDate >= '1/1/2012')
		AND	(enr.EnrollmentDate < '9/30/2012')
	JOIN
		DA_Production.prod.Stratification strat
		ON	(asmt.MemberID = strat.MemberID)
		AND	(DATEDIFF(dd,asmt.AssessmentCompleteDate,strat.StratificationDate) BETWEEN 0 AND 2)
		AND	(strat.StratificationSourceID = 6)
	JOIN
		(
		SELECT
			MemberID,
			COUNT(CASE WHEN AppointmentBeginDate <= @AsOfDate_2012 THEN AppointmentID END) AS CompletedSessions,
			COUNT(CASE WHEN AppointmentBeginDate > @AsOfDate_2012 THEN AppointmentID END) AS PendingSessions
		FROM
			DA_Production.prod.Appointment
		WHERE
			AppointmentStatusID IN (1,4) AND
			AppointmentBeginDate >= '1/1/2012'
		GROUP BY
			MemberID
		) sess
		ON	(asmt.MemberID = sess.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			CoachName,
			ROW_NUMBER() OVER(PARTITION BY MemberID ORDER BY AppointmentBeginDate DESC) AS Sequence
		FROM
			DA_Production.prod.Appointment
		WHERE
			AppointmentStatusID IN (1,4) AND
			AppointmentBeginDate >= '1/1/2012'
		) cch
		ON	(asmt.MemberID = cch.MemberID)
		AND	(cch.Sequence = 1)
	WHERE
		asmt.GroupID = 37231 AND
		asmt.IsPrimarySurvey = 1 AND
		asmt.AssessmentCompleteDate >= '1/1/2012' AND
		asmt.AssessmentCompleteDate < @AsOfDate_2012
	GROUP BY
		asmt.MemberID,
		strat.MemberStratificationName,
		sess.CompletedSessions,
		sess.PendingSessions,
		cch.CoachName
	
END
GO
