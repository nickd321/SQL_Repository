SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-02-13
-- Description:	True Value Tobacco Attestation Answer Count
--
-- Notes:		Rollup by Relationship.  Show total count that answered attestation.
--				Show total that answered yes and total that answered no. 
--				Of the population that answered no, show the members that are enrolled
--				in coaching and the number of sessions. The grain of the coaching dataset
--				will show the member and their respective program(s) during the incentive period
--
-- =============================================

CREATE PROCEDURE [truevalue].[proc_Incentives_TobaccoAttestation]

AS
BEGIN


	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb.dbo.#Answer') IS NOT NULL 
	BEGIN
		DROP TABLE #Answer
	END

	IF OBJECT_ID('tempdb.dbo.#Coaching') IS NOT NULL 
	BEGIN
		DROP TABLE #Coaching
	END

	SELECT
		mem.MemberID,
		mem.Relationship,
		UPPER(LEFT(ans.Answer,1)) + SUBSTRING(ans.Answer,2,LEN(ans.Answer)) AS Answer,
		ans.AddDate,
		ans.ModifiedDate
	INTO
		#Answer
	FROM
		DA_Production.prod.Member mem WITH (NOLOCK)
	JOIN
		Healthyroads.dbo.IC_MemberSingleQuestionAnswer ans WITH (NOLOCK)
		ON	(mem.MemberID = ans.MemberID)
		AND	(ans.SingleQuestionID = 135)
		AND	(ans.Deleted = 0)
	JOIN
		Healthyroads.dbo.IC_SingleQuestion ques WITH (NOLOCK)
		ON	(ans.SingleQuestionID = ques.SingleQuestionID)
		AND	(ques.Deleted = 0)
	WHERE
		mem.GroupID = 202586

	SELECT
		ans.MemberID,
		ans.Relationship,
		ans.Answer,
		enr.ProgramName,
		stat.IsTermed,
		COUNT(appt.AppointmentID) AS NumberSessions
	INTO
		#Coaching
	FROM
		#Answer ans
	JOIN
		DA_Production.prod.ProgramEnrollment enr WITH (NOLOCK)
		ON	(ans.MemberID = enr.MemberID)
		AND	(ISNULL(enr.TerminationDate,'2999-12-31') > '2013-09-01')
	JOIN -- GET MOST RECENT ENROLLMENT STATUS (IsTermed) FOR EACH PROGRAM
		(
		SELECT
			enr.MemberID,
			enr.ProgramID,
			enr.IsTermed,
			enr.EnrollmentDate,
			enr.TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY enr.MemberID, enr.ProgramID ORDER BY ISNULL(enr.TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.ProgramEnrollment enr WITH (NOLOCK)
		JOIN
			#Answer ans
			ON	(enr.MemberID = ans.MemberiD)
			AND	(ans.Answer = 'No')
		WHERE
			ISNULL(enr.TerminationDate,'2999-12-31') > '2013-09-01'
		) stat
		ON	(enr.MemberID = stat.MemberID)
		AND	(enr.ProgramID = stat.ProgramID)
		AND	(stat.RevTermSeq = 1)
	LEFT JOIN
		DA_Production.prod.Appointment appt WITH (NOLOCK)
		ON	(enr.MemberID = appt.MemberID)
		AND	(appt.AppointmentStatusID = 4)
		AND	(appt.AppointmentBeginDate >= '2013-09-01')
		AND (appt.AppointmentBeginDate BETWEEN enr.EnrollmentDate AND ISNULL(enr.TerminationDate,'2999-12-31'))
		AND	(appt.AppointmentBeginDate < '2014-04-01')
	WHERE
		ans.Answer = 'No'
	GROUP BY
		ans.MemberID,
		ans.Relationship,
		ans.Answer,
		enr.ProgramName,
		stat.IsTermed
	
	SELECT
		*
	FROM
		(
		SELECT
			Relationship,
			Answer,
			COUNT(MemberID) AS Value
		FROM
			#Answer
		GROUP BY
			Relationship,
			Answer
		UNION ALL
		SELECT
			Relationship,
			'Total' AS Answer,
			COUNT(MemberID) AS Value
		FROM
			#Answer
		GROUP BY
			Relationship
		UNION ALL
		SELECT
			'Total' AS Relationship,
			Answer,
			COUNT(MemberID) AS Value
		FROM
			#Answer
		GROUP BY
			Answer
		UNION ALL
		SELECT
			'Total' AS Relationship,
			'Total' AS Answer,
			COUNT(MemberID) AS Value
		FROM
			#Answer
		) data
		PIVOT
		(
		MAX(Value) FOR Answer IN ([Yes],[No],[Total])
		) pvt

	SELECT
		DENSE_RANK() OVER (ORDER BY MemberID) AS Member,
		ProgramName AS CoachingProgram,
		Relationship,
		Answer,
		CASE WHEN IsTermed = 0 THEN 'Active' ELSE 'TermedEnrollment' END AS EnrollmentStatus,
		NumberSessions
	FROM
		#Coaching

	IF OBJECT_ID('tempdb.dbo.#Answer') IS NOT NULL 
	BEGIN
		DROP TABLE #Answer
	END

	IF OBJECT_ID('tempdb.dbo.#Coaching') IS NOT NULL 
	BEGIN
		DROP TABLE #Coaching
	END

END
GO
