SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [magellan].[proc_Lowes_HealthAssessmentData]

	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL

AS BEGIN

	DECLARE @BeginDate DATETIME = ISNULL(@inBeginDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
	DECLARE @EndDate DATETIME = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

	IF OBJECT_ID('TempDB.dbo.#BaseQuestionData') IS NOT NULL BEGIN
		DROP TABLE #BaseQuestionData
	END

	--Base Question Data
	SELECT
		mem.MemberID,
		ISNULL(mem.AltID1,'') AS UniqueID,
		ma.MemberAssessmentId AS AssessmentID,
		ma.AssessmentCompleteDate AS AssessmentDate,
		CHECKSUM(dbo.REGEX_REPLACE(ISNULL(pq.DisplayText + ' - ','') + q.DisplayText,'<(/)*([a-z])>','') + ISNULL(' - ' + ac.DisplayText,'')) AS QuestionKey,
		dbo.REGEX_REPLACE(ISNULL(pq.DisplayText + ' - ','') + q.DisplayText,'<(/)*([a-z])>','') + ISNULL(' - ' + ac.DisplayText,'') AS Question,
		CASE
			WHEN a.DisplayText LIKE '%{[0-9]}%' THEN 0
			ELSE CHECKSUM(a.DisplayText)
		END AS AnswerKey,
		CASE
			WHEN a.DisplayText LIKE '%{[0-9]}%' THEN mr.AnswerText
			ELSE a.DisplayText
		END AS Answer
	INTO
		#BaseQuestionData
	FROM
		DA_Production.prod.Member mem
	JOIN
		DA_Production.prod.HealthAssessment ma
		ON	(mem.MemberID = ma.MemberID)
		AND	(ma.SurveyId = 22)
	JOIN
		HRAQuiz.dbo.srvy_MemberResponse mr
		ON	(ma.MemberAssessmentId = mr.MemberAssessmentId)
		AND	(mr.QuestionId NOT IN (1163)) --Exclude non-questions
		AND	(mr.Deleted = 0)
	JOIN
		HRAQuiz.dbo.srvy_Question q
		ON	(mr.QuestionId = q.QuestionId)
		AND	(q.Deleted = 0)
	JOIN
		HRAQuiz.dbo.srvy_Answer a
		ON	(mr.AnswerId = a.AnswerId)
		AND	(a.Deleted = 0)
	LEFT JOIN
		HRAQuiz.dbo.srvy_Question pq
		ON	(q.ParentQuestionId = pq.QuestionId)
		AND	(pq.Deleted = 0)
	LEFT JOIN
		HRAQuiz.dbo.srvy_Answer ac
		ON	(mr.QuestionId = 1165)
		AND	(ac.QuestionId = 1039)
		AND	(SUBSTRING(mr.AnswerText,1,CHARINDEX('.',mr.AnswerText)) = 'A' + CAST(ac.AnswerId AS VARCHAR) + '.')
		AND	(ac.Deleted = 0)
	WHERE
		mem.GroupID = 150645 AND
		ma.AssessmentCompleteDate >= @BeginDate AND
		ma.AssessmentCompleteDate < @EndDate



	/*** RESULT SET ***/

	--Header Record
	SELECT
		'HR' AS RecordType,
		'Lowe''s Companies, Inc.' AS Col2, --CompanyName
		CAST(COUNT(DISTINCT AssessmentID) AS VARCHAR) AS Col3, --PHACompletedCount
		CONVERT(VARCHAR(10),@BeginDate,121) AS Col4, --PeriodBeginDate
		CONVERT(VARCHAR(10),DATEADD(dd,-1,@EndDate),121) AS Col5, --PeriodEndDate
		'' AS Col6,
		'' AS Col7,
		'' AS Col8,
		'' AS Col9,
		'' AS Col10,
		'' AS Col11,
		'' AS Col12,
		'' AS Col13,
		'' AS Col14,
		'' AS Col15,
		'' AS Col16,
		'' AS Col17,
		'' AS Col18,
		'' AS Col19
	FROM
		#BaseQuestionData

	UNION ALL

	--Participant Record
	SELECT
		'PR' AS RecordType,
		bqd.UniqueID,
		ISNULL(mem.SubscriberSSN,'') AS SubSSN,
		ISNULL(LEFT(mem.Gender,1),'') AS Gender,
		CONVERT(VARCHAR(10),mem.Birthdate,121) AS DoB,
		mem.Relationship,
		mem.FirstName,
		ISNULL(mem.MiddleInitial,'') AS MiddleInitial,
		mem.LastName,
		ISNULL(addr.Address1,'') AS Address1,
		ISNULL(addr.Address2,'') AS Address2,
		ISNULL(addr.City,'') AS City,
		ISNULL(addr.[State],'') AS [State],
		ISNULL(addr.ZipCode,'') AS Zip,
		ISNULL(mem.HomePhone,'') AS Phone,
		ISNULL(mem.EmailAddress,'') AS Email,
		'' AS Col17,
		'' AS Col18,
		'' AS Col19
	FROM
		DA_Production.prod.Member mem
	JOIN
		(
		SELECT
			UniqueID,
			MemberID
		FROM
			#BaseQuestionData
		GROUP BY
			UniqueID,
			MemberID
		) bqd
		ON	(mem.MemberID = bqd.MemberID)
	LEFT JOIN
		DA_Production.prod.[Address] addr
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)

	UNION ALL

	--Assessment Record
	SELECT
		'AR' AS RecordType,
		bio.UniqueID,
		bio.AssessmentID,
		CONVERT(VARCHAR(10),bio.AssessmentDate,121) AS AssessmentDate,
		CAST(bio.Height_FT AS VARCHAR) AS [Height_FT],
		bio.Height_IN,
		bio.Weight_LBS,
		bio.Waist_IN,
		bio.BloodPressure,
		bio.TotalCholesterol,
		bio.FastingGlucose,
		CAST(dom.RiskScore_Activity AS VARCHAR),
		CAST(dom.RiskScore_Diet AS VARCHAR),
		CAST(dom.RiskScore_TobaccoUse AS VARCHAR),
		CAST(dom.RiskScore_PreventiveHealth AS VARCHAR),
		CAST(dom.RiskScore_StressManagement AS VARCHAR),
		CAST(dom.RiskScore_Sleep AS VARCHAR),
		CAST(dom.RiskScore_Presenteeism AS VARCHAR),
		CAST(dom.LifestyleScore AS VARCHAR)
	FROM
		(
		SELECT
			UniqueID,
			AssessmentID,
			AssessmentDate,
			[Height - Feet (ft)] AS Height_FT,
			[Height - Inches (in)] AS Height_IN,
			[What is your current weight? (lbs)] AS Weight_LBS,
			ISNULL([What is your waist measurement?  - waist in whole inches],'') AS Waist_IN,
			[What is your current blood pressure?] AS BloodPressure,
			[What is your current blood cholesterol level?] AS TotalCholesterol,
			[What was your most recent FASTING blood sugar level?] AS FastingGlucose
		FROM
			#BaseQuestionData data
		PIVOT
			(
			MAX(Answer) FOR Question IN	(
										[Height - Feet (ft)],
										[Height - Inches (in)],
										[What is your current weight? (lbs)],
										[What is your waist measurement?  - waist in whole inches],
										[What is your current blood pressure?],
										[What is your current blood cholesterol level?],
										[What was your most recent FASTING blood sugar level?]
										)
			) pvt
		) bio
	LEFT JOIN
		(
		SELECT
			AssessmentID,
			[Activity] AS RiskScore_Activity,
			[Diet] AS RiskScore_Diet,
			[Tobacco Use] AS RiskScore_TobaccoUse,
			[Preventive Health] AS RiskScore_PreventiveHealth,
			[Stress Management] AS RiskScore_StressManagement,
			[Sleep] AS RiskScore_Sleep,
			[Presenteeism] AS RiskScore_Presenteeism,
			[TotalScore] AS LifestyleScore
		FROM
			(
			SELECT
				MemberAssessmentID AS AssessmentID,
				Domain,
				Score
			FROM
				DA_Production.prod.HealthAssessment_DomainScore
			WHERE
				GroupID = 150645
			) data
		PIVOT
			(
			MAX(Score) FOR Domain IN	(
										[Activity],
										[Diet],
										[Tobacco Use],
										[Preventive Health],
										[Stress Management],
										[Sleep],
										[Presenteeism],
										[TotalScore]
										)
			) pvt
		) dom
		ON	(bio.AssessmentID = dom.AssessmentID)

	UNION ALL

	--Question Answer Record
	SELECT
		'QA' AS RecordType,
		CAST(UniqueID AS VARCHAR(1000)) AS [UniqueID],
		CAST(AssessmentID AS VARCHAR(1000)) AS [UniqueID],
		CAST(QuestionKey AS VARCHAR(1000)) AS [QuestionKey],
		CAST(Question AS VARCHAR(1000)) AS [Question],
		CAST(AnswerKey AS VARCHAR(1000)) AS [AnswerKey],
		CAST(Answer AS VARCHAR(1000)) AS [Answer],
		'' AS Col8,
		'' AS Col9,
		'' AS Col10,
		'' AS Col11,
		'' AS Col12,
		'' AS Col13,
		'' AS Col14,
		'' AS Col15,
		'' AS Col16,
		'' AS Col17,
		'' AS Col18,
		'' AS Col19
	FROM
		#BaseQuestionData

END
GO
