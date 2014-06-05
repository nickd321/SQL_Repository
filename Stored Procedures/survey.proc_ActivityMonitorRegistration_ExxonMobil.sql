SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [survey].[proc_ActivityMonitorRegistration_ExxonMobil]

	@LogRecipients BIT = 0,
	@BeginDate DATETIME = NULL,
	@EndDate DATETIME = NULL,
	@EventDate DATETIME = NULL

AS BEGIN

	SET @BeginDate = ISNULL(@BeginDate,'10/1/2012')
	SET @EndDate = ISNULL(@EndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))
	SET @EventDate = ISNULL(@EventDate,DATEADD(mm,-1,@EndDate))

	DECLARE @BatchID INT

	IF OBJECT_ID('TempDB.dbo.#MemberActivity') IS NOT NULL BEGIN
		DROP TABLE #MemberActivity
	END

	IF OBJECT_ID('TempDB.dbo.#FinalDataSet') IS NOT NULL BEGIN
		DROP TABLE #FinalDataSet
	END

	--Get monitor registration
	SELECT
		MemberID,
		MIN(RegistrationDate) AS LastActivityDate
	INTO
		#MemberActivity
	FROM
		DA_Production.prod.MonitorDevice
	WHERE
		GroupID = 37231 AND
		DATEDIFF(dd,RegistrationDate,@EndDate) BETWEEN 45 AND 366 AND
		RegistrationDate >= @BeginDate AND
		RegistrationDate < @EndDate
	GROUP BY
		MemberID


	--Prepare final data set
	SELECT
		mem.EmailAddress,
		mem.FirstName,
		mem.LastName,
		mem.MemberID,
		5 AS SurveyID
	INTO
		#FinalDataSet
	FROM
		DA_Production.prod.Member mem
	JOIN
		#MemberActivity mon
		ON	(mem.MemberID = mon.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			MAX(AddDate) AS LastSentDate
		FROM
			DA_Evaluation.survey.SurveyMember
		WHERE
			SurveyID = 5 AND
			EventTypeID IN (1,2,3) AND
			Deleted = 0
		GROUP BY
			MemberID
		) hist
		ON	(mem.MemberID = hist.MemberID)
	WHERE
		mem.EmailAddress IS NOT NULL AND
		PATINDEX('%@%.%',mem.EmailAddress) > 0 AND
		DATEDIFF(mm,ISNULL(hist.LastSentDate,'1/1/1900'),mon.LastActivityDate) > 12

	
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


		--If the number of members to survey is greater than 10,000;
		--we need to take a random sample and limit to 10,000
		IF @@ROWCOUNT > 10000 BEGIN
		
		UPDATE tgt
		SET tgt.EventTypeID = 2
		FROM
			DA_Evaluation.survey.SurveyMember tgt
		JOIN
			(
			SELECT
				SurveyMemberID,
				ROW_NUMBER() OVER(PARTITION BY BatchID ORDER BY NEWID()) AS Seq
			FROM
				DA_Evaluation.survey.SurveyMember
			WHERE
				BatchID = @BatchID
			) rnd
			ON	(tgt.SurveyMemberID = rnd.SurveyMemberID)
			AND	(rnd.Seq > 10000)
		END

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
	IF OBJECT_ID('TempDB.dbo.#MemberActivity') IS NOT NULL BEGIN
		DROP TABLE #MemberActivity
	END

	IF OBJECT_ID('TempDB.dbo.#FinalDataSet') IS NOT NULL BEGIN
		DROP TABLE #FinalDataSet
	END


END
GO
