SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-10-03 
-- Description:	Tyco Daily PHA Completions File
--
-- Notes:		This report is only for Tyco Fire and Security
--				Includes all of the population whether they are currently eligible or not.
--				
-- Updates:		WilliamPe 20131011
--				Per Adrienne and Robyn, filter on relationship id IN (1,2,6)
--
--				WilliamPe 2013115
--				Current HealthAssessment table does not have RecordReceivedDate.  The latter is relevant for incentives.
--				Slavisa's team uses this date to determine if pha fell within required timeframe.  For this scenario,
--				we are mimicking this business logic.  I added new #HealthAssessment temp table to handle this small subset.
--
--				WilliamPe 20131126
--				Adding incentive waiver PHA Completions (WO3030). Per the request of Xerox, the incentives file they receive
--				on Wednesdays should no longer pass PHA completions.  So, in order to ensure we send them all PHAs we are adding
--				PHA activity completions from the waiver process as well. I added the activititemid and clientincentivplanid's
--				or the 2013 and 2014 incentive years for the waiver activities.
--
-- =============================================

CREATE PROCEDURE [tyco].[proc_HealthAssessment_Completions] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	-- FOR TESTING
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

/*============================================= DECLARES =============================================*/

	DECLARE
		@loc_GlobalBegin DATETIME, -- 2012
		@loc_PHAReset DATETIME,
		@loc_GlobalEnd DATETIME -- 2014

/*=========================================== SET VARIABLES ==========================================*/

	SET @loc_GlobalBegin  = '2012-10-01'
	SET @loc_PHAReset = '2013-10-01'
	SET @loc_GlobalEnd = '2014-10-01' --Exclusive

	-- THERE IS SOME ISSUE IN THIS PROCEDURE WITH USING OPTIONAL PARAMETERS
	-- DECLARED LOCAL PARAMETERS BELOW AND SET THEM TO THE PARAMETER PASSED OR A DEFAULT DATE
	DECLARE @loc_BeginDate DATETIME, @loc_EndDate DATETIME
	
	SET @loc_BeginDate = ISNULL(@inBeginDate,@loc_PHAReset)
	SET @loc_EndDate = ISNULL(@inEndDate,GETDATE())

/*=============================== TEST THAT DATES PASSED ARE WITHIN RANGE ============================*/

	-- IF NOT WITHIN RANGE STOP AND THROW ERROR
	IF (@loc_BeginDate < @loc_GlobalBegin) OR
	   (@loc_BeginDate >= @loc_GlobalEnd) 
	BEGIN
		RAISERROR 
			(
				N'@inBeginDate parameter must be greater than or equal to ''2012-10-01'' and less then ''2014-10-01''', -- Message text.
				10, -- Severity,
				1  -- State,
			)
	END

	-- IF WITHIN RANGE CONTINUE
	IF (@loc_BeginDate >= @loc_GlobalBegin) AND
	   (@loc_BeginDate < @loc_GlobalEnd)

	BEGIN

		/*============================================ CLEAN UP ==============================================*/

		IF OBJECT_ID('TempDB.dbo.#HealthAssessment') IS NOT NULL BEGIN
			DROP TABLE #HealthAssessment
		END

		IF OBJECT_ID('TempDB.dbo.#TycoPHAs') IS NOT NULL BEGIN
			DROP TABLE #TycoPHAs
		END

		/*==================================== DATA QUERY (INTO TEMP) =======================================*/
		

		SELECT
			*,
			CASE
				WHEN AssessmentCompleteDate >= @loc_GlobalBegin AND AssessmentCompleteDate < @loc_PHAReset THEN '2013'
				WHEN AssessmentCompleteDate >= @loc_PHAReset AND AssessmentCompleteDate < @loc_GlobalEnd THEN '2014'
			END AS IncentiveYear
		INTO
			#HealthAssessment
		FROM
			(
			SELECT
				mem.HealthPlanID,
				mem.GroupID,
				mem.MemberID,
				srvymem.SurveyMemberID,
				memasmnt.MemberAssessmentID,
				memasmnt.StartedDateTime AS AssessmentBeginDate,
				-- ReceivedDateTime column will be populated only for paper PHAs according to Slavisa
				ISNULL(memasmnt.ReceivedDateTime,memasmnt.CompletedDateTime) AS AssessmentCompleteDate,
				srvy.SurveyID,
				srvy.[Name] AS SurveyName,
				entsrc.MemberAssessmentEntrySourceID AS EntrySourceID,
				entsrc.MemberAssessmentEntrySourceName AS EntrySourceName,
				entmthd.MemberAssessmentEntryMethodID AS EntryMethodID,
				entmthd.MemberAssessmentEntryMethodName AS EntryMethodName,
				CAST(CASE WHEN memasmnt.CompletedDateTime IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS IsComplete,
				CASE WHEN srvy.SurveyID IN (1,18,22) THEN 1 ELSE 0 END AS IsPrimarySurvey,
				memasmnt.AddDate AS SourceAddDate,
				0 AS IsWaiver
			FROM
				DA_Production.prod.Member mem WITH (NOLOCK) 
			JOIN
				HRAQuiz.dbo.srvy_SurveyMember srvymem WITH (NOLOCK)
				ON	(mem.MemberID = srvymem.BenefitsMemberID)
				AND	(srvymem.Deleted = 0)
			JOIN
				HRAQuiz.dbo.srvy_MemberAssessment memasmnt WITH (NOLOCK)
				ON	(srvymem.SurveyMemberID = memasmnt.SurveyMemberID)
				AND	(memasmnt.Deleted = 0)
			JOIN
				HRAQuiz.dbo.srvy_Survey srvy WITH (NOLOCK)
				ON	(memasmnt.SurveyID = srvy.SurveyID)
			JOIN
				HRAQuiz.dbo.srvy_StratificationLevel stratlvl WITH (NOLOCK)
				ON	(memasmnt.StratificationLevelID = stratlvl.StratificationLevelID)
			JOIN
				HRAQuiz.dbo.srvy_MemberAssessmentEntryMethod entmthd WITH (NOLOCK)
				ON	(memasmnt.MemberAssessmentEntryMethodID = entmthd.MemberAssessmentEntryMethodID)
			JOIN
				HRAQuiz.dbo.srvy_MemberAssessmentEntrySource entsrc WITH (NOLOCK)
				ON	(memasmnt.MemberAssessmentEntrySourceID = entsrc.MemberAssessmentEntrySourceID)
			WHERE
				mem.GroupID = 193629
		
			UNION ALL
		
			-- INCENTIVE PHA COMPLETION WAIVERS (2014)
			SELECT
				mem.HealthPlanID,
				mem.GroupID,
				mem.MemberID,
				mai.ActivityItemID AS SurveyMemberID, -- ActivityItemID
				mai.MemberActivityItemID AS MemberAssessmentID, -- MemberActivityItemID
				mai.ActivityDate AS AssessmentBeginDate,
				mai.ActivityDate AS AssessmentCompleteDate,
				-123456 AS SurveyID,
				'PHA Waiver' AS SurveyName,
				-123456 AS EntrySourceID,
				'Healthyroads' AS EntrySourceName,
				-123456 AS EntryMethodID,
				'Incentive Waiver Process' AS EntryMethodName,
				1 AS IsComplete,
				0 IsPrimarySurvey,
				mai.AddDate AS SourceAddDate,
				mai.IsWaiver			
			FROM
				DA_Production.prod.Member mem WITH (NOLOCK)
			JOIN
				Healthyroads.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
				ON	(mem.MemberID = mai.MemberID)
				AND	(mai.ClientIncentivePlanID IN (733,1076,1082,1084))
				AND	(mai.ActivityItemID IN (3210,5222,5250))
				AND	(mai.Deleted = 0)
			WHERE
				mem.GroupID = 193629 AND
				mai.IsWaiver = 1
			) data
		WHERE
			(IsPrimarySurvey = 1 OR IsWaiver = 1) AND
			IsComplete = 1 AND
			AssessmentCompleteDate >= @loc_GlobalBegin AND
			AssessmentCompleteDate < @loc_GlobalEnd AND
			AssessmentCompleteDate >= @loc_BeginDate AND
			AssessmentCompleteDate < @loc_EndDate
		

		SELECT
			mem.MemberID,
			CASE mem.RelationshipID
				WHEN 6 THEN mem.AltID2
				ELSE RIGHT(mem.AltID2,4) + REPLACE(CONVERT(CHAR(10),mem.BirthDate,101),'/','')
			END AS UniqueID,
			CASE mem.RelationshipID
				WHEN 6 THEN ''
				ELSE mem.AltID2
			END AS RelatedID,
			mem.RelationshipID,
			ha.IncentiveYear,
			REPLACE(REPLACE(REPLACE(CONVERT(CHAR(19),ha.AssessmentCompleteDate,120),'-',''),':',''),' ','') AS PHACompletionDate
		INTO
			#TycoPHAs
		FROM
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(grp.GroupID = mem.GroupID)
			AND	(mem.GroupID = 193629)
			AND	(mem.AltID2 IS NOT NULL)
			AND	(mem.RelationshipID IN (1,2,6)) -- PRIMARY, SPOUSE OR DOMESTIC PARTNER
		JOIN
			(
			SELECT
				MemberID,
				SurveyID,
				SurveyName,
				IncentiveYear,
				AssessmentCompleteDate,
				ROW_NUMBER() OVER (PARTITION BY MemberID, IncentiveYear ORDER BY AssessmentCompleteDate) AS RowSeq
			FROM
				#HealthAssessment ha WITH (NOLOCK)
			) ha
			ON	(mem.MemberID = ha.MemberID)
			AND	(ha.RowSeq = 1)

		/*==================================== RETURN QUERY =======================================*/

		SELECT
			Data
		FROM
			(
			SELECT
				REPLACE(CONVERT(VARCHAR(10),@loc_EndDate,101),'/','') AS Data, 
				1 AS RowOrder

			UNION ALL

			SELECT --PHA
				CAST(UniqueID AS VARCHAR(20)) + ',' +
				CAST(RelatedID AS VARCHAR(20)) + ',' +
				'PHA' + IncentiveYear + ',' +
				'Personal Health Assessment' + ',,' +
				CAST(PHACompletionDate AS VARCHAR(20)) AS Data,
				2 AS RowOrder
			FROM
				#TycoPHAs

			UNION ALL

			SELECT
				CAST(
					COUNT(UniqueID) -- NUMBER OF RECORDS
					AS VARCHAR(20)
				) AS Data,
				3 AS RowOrder
			FROM
				#TycoPHAs
			) data
		ORDER BY
			RowOrder
	
		/*============================================ CLEAN UP ==============================================*/

		IF OBJECT_ID('TempDB.dbo.#HealthAssessment') IS NOT NULL BEGIN
			DROP TABLE #HealthAssessment
		END

		IF OBJECT_ID('TempDB.dbo.#TycoPHAs') IS NOT NULL BEGIN
			DROP TABLE #TycoPHAs
		END

	END

END
GO
