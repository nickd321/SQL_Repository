SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [survey].[proc_TelephoneCoaching]

	@LogRecipients BIT = 0,
	@EventDate DATETIME = NULL

AS BEGIN

	SET @EventDate = ISNULL(@EventDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

	DECLARE @BatchID INT

	IF OBJECT_ID('TempDB.dbo.#FinalDataSet') IS NOT NULL BEGIN
		DROP TABLE #FinalDataSet
	END
	

	--Prepare final data set
	SELECT
		4 AS SurveyID,
		mem.MemberID,
		mem.FirstName,
		mem.LastName,
		mem.EmailAddress,
		CONVERT(VARCHAR,GETDATE(),101) AS SurveyDate,
		ISNULL(hist.SurveyCount,0) + 1 AS SurveySequence,
		appt.FirstAppointmentDate,
		coach.CoachUserID
	INTO
		#FinalDataSet
	FROM
		DA_Production.prod.Member mem
	JOIN
		DA_Production.prod.Eligibility elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.IsTermed = 0)
	JOIN
		(
		SELECT
			MemberID,
			MIN(AppointmentEndDate) AS FirstAppointmentDate
		FROM
			DA_Production.prod.Appointment
		WHERE
			AppointmentStatusID = 4 AND
			DATEDIFF(mm,AppointmentEndDate,@EventDate) BETWEEN 0 AND 12
		GROUP BY
			MemberID
		HAVING
			COUNT(AppointmentID) >= 2
		) appt
		ON	(mem.MemberID = appt.MemberID)
		AND	(DATEDIFF(dd,appt.FirstAppointmentDate,@EventDate) >= 100)
	JOIN
		(
		SELECT
			MemberID,
			CoachUserID,
			CAST(CASE ROW_NUMBER() OVER(PARTITION BY MemberID ORDER BY AppointmentEndDate DESC) WHEN 1 THEN 1 ELSE 0 END AS BIT) AS MostRecentAppt
		FROM
			DA_Production.prod.Appointment
		WHERE
			AppointmentStatusID = 4
		) coach
		ON	(mem.MemberID = coach.MemberID)
		AND	(coach.MostRecentAppt = 1)
	LEFT JOIN
		(
		SELECT
			MemberID,
			COUNT(SurveyMemberID) AS SurveyCount,
			MAX(EventDate) AS LatestEventDate
		FROM
			DA_Evaluation.survey.SurveyMember
		WHERE
			SurveyID = 4 AND
			EventTypeID IN (1,2,3) AND
			Deleted = 0
		GROUP BY
			MemberID
		) hist
		ON	(mem.MemberID = hist.MemberID)
	LEFT JOIN
		DA_Evaluation.survey.SurveyExemption srvyex
		ON	(srvyex.ReferenceID =
				CASE srvyex.ExemptionTypeID
					WHEN 1 THEN mem.HealthPlanID
					WHEN 2 THEN mem.GroupID
					WHEN 3 THEN mem.MemberID
				END
			)
		AND	srvyex.SurveyID = 4
		AND	srvyex.Deleted = 0
	WHERE
		mem.EmailAddress LIKE '%@%.%' AND
		DATEDIFF(mm,ISNULL(hist.LatestEventDate,'1/1/1900'),@EventDate) > 12 AND
		srvyex.SurveyExemptionID IS NULL

	
	--If indicated to log, insert into SurveyMember table
	IF @LogRecipients = 1 BEGIN

		SELECT
			@BatchID = MAX(BatchID) + 1
		FROM
			DA_Evaluation.survey.SurveyMember

		SET @BatchID = ISNULL(@BatchID,1)

		INSERT INTO DA_Evaluation.survey.SurveyMember
		SELECT
			SurveyID,
			MemberID,
			@BatchID AS BatchID,
			@EventDate AS EventDate,
			1 AS EventTypeID,
			GETDATE() AS AddDate,
			0 AS Deleted
		FROM
			#FinalDataSet
		
	END

	--Return final result
	SELECT
		fds.EmailAddress,
		fds.FirstName,
		fds.LastName,
		sr.SurveyMemberID AS CustomData
	FROM
		#FinalDataSet fds
	LEFT JOIN
		DA_Evaluation.survey.SurveyMember sr
		ON	(fds.MemberID = sr.MemberID)
		AND	(fds.SurveyID = sr.SurveyID)
		AND	(sr.BatchID = @BatchID)
		AND	(sr.EventTypeID = 1)
	WHERE
		(@LogRecipients = 1 AND sr.SurveyMemberID IS NOT NULL) OR
		(@LogRecipients = 0)

	--Clean up

	IF OBJECT_ID('TempDB.dbo.#FinalDataSet') IS NOT NULL BEGIN
		DROP TABLE #FinalDataSet
	END


END
GO
