SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [survey].[proc_HealthyroadsUtilization]

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

	--Get web activity
	SELECT
		MemberID,
		MAX(SourceAddDate) AS LastActivityDate
	INTO
		#MemberActivity
	FROM
		(
		SELECT
			MemberID,
			SourceAddDate
		FROM
			DA_Production.prod.WebClass
		UNION
		SELECT
			MemberID,
			SourceAddDate
		FROM
			DA_Production.prod.HealthAssessment
		UNION
		SELECT
			MemberID,
			SourceAddDate
		FROM
			DA_Production.prod.Planner
		UNION
		SELECT
			MemberID,
			SourceAddDate
		FROM
			DA_Production.prod.Tracker
		) web
	WHERE
		DATEDIFF(dd,web.SourceAddDate,@EndDate) BETWEEN 90 AND 366 AND
		web.SourceAddDate >= @BeginDate AND
		web.SourceAddDate < @EndDate
	GROUP BY
		MemberID


	--Prepare final data set
	SELECT
		mem.EmailAddress,
		mem.FirstName,
		mem.LastName,
		mem.MemberID,
		1 AS SurveyID
	INTO
		#FinalDataSet
	FROM
		DA_Production.prod.Member mem
	JOIN
		#MemberActivity web
		ON	(mem.MemberID = web.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			MAX(AddDate) AS LastSentDate
		FROM
			DA_Evaluation.survey.SurveyMember
		WHERE
			SurveyID = 1 AND
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
		AND	srvyex.SurveyID = 1
		AND	srvyex.Deleted = 0
	WHERE
		mem.EmailAddress IS NOT NULL AND
		PATINDEX('%@%.%',mem.EmailAddress) > 0 AND
		DATEDIFF(mm,ISNULL(hist.LastSentDate,'1/1/1900'),web.LastActivityDate) > 12 AND
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
