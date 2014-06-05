SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-03-27
-- Description:	Standard Step Challenge Completion Report 
--
-- Notes:		This report should only be used for challenges that use an activity monitor (pebble, actiped, etc)
--
-- =============================================
CREATE PROCEDURE [standard].[proc_Challenges_ActivityMonitorTotalSteps]-- 769
	@inClientChallengeID INT,
	@inCompletedRule BIT = NULL
	
AS
BEGIN
	SET NOCOUNT ON;

	
	-- DECLARES
	DECLARE @StepType VARCHAR(100)
	
	-- SETS
	SET @inCompletedRule = ISNULL(@inCompletedRule,1)
	SET @StepType = (
					 SELECT
						 CASE ActipedStepTypeName
							 WHEN 'All Activity' THEN 'All'
							 WHEN 'Actiped Activity Only' THEN 'Actiped'
							 WHEN 'Actiped Activity and Activity that is Self-Reported' THEN 'Actiped,Manual'
							 WHEN 'Actiped Activity and Activity that has been Reclassified' THEN 'Actiped,Reclassified'
						 END
					 FROM
						 HRMS.dbo.Threshold thr WITH (NOLOCK)
					 JOIN
						 HRMS.dbo.ActipedStepType stptyp WITH (NOLOCK)
						 ON	 (thr.ActipedStepTypeID = stptyp.ActipedStepTypeID)
						 AND (stptyp.Deleted = 0)
					 WHERE
						 thr.ClientChallengeID = @inClientChallengeID AND
						 thr.Deleted = 0	
					)
	
	-- CLEAN UP
	IF OBJECT_ID('tempDB.dbo.#ChallengeSteps') IS NOT NULL
	BEGIN
		DROP TABLE #ChallengeSteps
	END

	IF @StepType IS NULL
	BEGIN
		RAISERROR 
			(
				N'This challenge is not a step challenge that uses a Connected device.', -- Message text.
				10, -- Severity,
				1  -- State,
			)
	END

	IF @StepType IS NOT NULL
	BEGIN
	
		SELECT
			chlg.MemberID,
			CASE WHEN stp.ActivityType = 'Actiped' THEN SUM(stp.TotalSteps) END AS DeviceSteps,
			CASE WHEN stp.ActivityType = 'Manual' THEN SUM(stp.TotalSteps) END AS ManualSteps,
			CASE WHEN stp.ActivityType = 'Reclassified' THEN SUM(stp.TotalSteps) END AS ReclassifiedSteps,
			SUM(stp.TotalSteps) AS TotalSteps
		INTO
			#ChallengeSteps
		FROM
			[DA_Production].[prod].[ActivityMonitorLog] stp WITH (NOLOCK)		
		JOIN
			[DA_Production].[prod].[Challenge] chlg WITH (NOLOCK)
			ON	(stp.MemberID = chlg.MemberID)
			AND (chlg.ClientChallengeID = @inClientChallengeID)
		WHERE
			(@StepType = 'All' OR stp.ActivityType IN (SELECT * FROM [DA_Reports].[dbo].[SPLIT] (@StepType,','))) AND
			(DATEADD(dd,DATEDIFF(dd,0,stp.ActivityDate),0) BETWEEN chlg.ChallengeBeginDate AND chlg.ChallengeEndDate) AND
			(DATEADD(dd,DATEDIFF(dd,0,stp.SourceAddDate),0) BETWEEN chlg.ChallengeBeginDate AND DATEADD(wk,2,chlg.ChallengeEndDate))
		GROUP BY
			chlg.MemberID,
			stp.ActivityType

		IF @inCompletedRule = 1
		BEGIN
			SELECT
				grp.GroupName,
				ISNULL(mem.EligMemberID,'') AS [EligMemberID],
				ISNULL(mem.EligMemberSuffix,'') AS [EligMemberSuffix],
				mem.FirstName,
				mem.LastName,
				ISNULL(mem.EmailAddress,'') AS [Email],
				ISNULL(CONVERT(CHAR(10),mem.Birthdate,101),'') AS [Birthdate],
				ISNULL(addr.City,'') AS [City],
				ISNULL(addr.[State],'') AS [State],
				ISNULL(mem.AltID1,'') AS [AltID1],
				CONVERT(CHAR(10),chlg.ChallengeBeginDate,101) AS [ChallengeBeginDate],
				CONVERT(CHAR(10),chlg.ChallengeEndDate,101) AS [ChallengeEndDate],
				ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName) AS [ChallengeName],
				CONVERT(CHAR(10),chlg.EnrollmentDate,101) AS [EnrollmentDate],
				ISNULL(CONVERT(CHAR(10),chlg.CompletionDate,101),'') AS [CompletionDate],
				REPLACE(@StepType,'Actiped','Device') AS StepsAllowed,
				--ISNULL(SUM(stp.DeviceSteps),'') AS DeviceSteps,
				--ISNULL(SUM(stp.ManualSteps),'') AS ManualSteps,
				--ISNULL(SUM(stp.ReclassifiedSteps),'') AS ReclassifiedSteps,
				ISNULL(SUM(stp.TotalSteps),'') AS TotalSteps
			FROM
				DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
			JOIN
				DA_Production.prod.Member mem WITH (NOLOCK)
				ON	(grp.GroupID = mem.GroupID)
			JOIN
				DA_Production.prod.Challenge chlg WITH (NOLOCK)
				ON	(mem.MemberID = chlg.MemberID)
				AND	(chlg.ClientChallengeID = @inClientChallengeID)
			LEFT JOIN
				DA_Production.prod.[Address] addr WITH (NOLOCK)
				ON	(mem.MemberID = addr.MemberID)
				AND	(addr.AddressTypeID = 6)
			LEFT JOIN
				#ChallengeSteps stp
				ON	(mem.MemberID = stp.MemberID)
			WHERE
				chlg.CompletionDate IS NOT NULL
			GROUP BY
				grp.GroupName,
				ISNULL(mem.EligMemberID,''),
				ISNULL(mem.EligMemberSuffix,''),
				mem.FirstName,
				mem.LastName,
				ISNULL(mem.EmailAddress,''),
				ISNULL(CONVERT(CHAR(10),mem.Birthdate,101),''),
				ISNULL(addr.City,''),
				ISNULL(addr.[State],''),
				ISNULL(mem.AltID1,''),
				CONVERT(CHAR(10),chlg.ChallengeBeginDate,101),
				CONVERT(CHAR(10),chlg.ChallengeEndDate,101),
				ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName),
				CONVERT(CHAR(10),chlg.EnrollmentDate,101),
				ISNULL(CONVERT(CHAR(10),chlg.CompletionDate,101),'')
		END

		-- USE FOR QA
		IF @inCompletedRule = 0
		BEGIN
			SELECT
				grp.GroupName,
				ISNULL(mem.EligMemberID,'') AS [EligMemberID],
				ISNULL(mem.EligMemberSuffix,'') AS [EligMemberSuffix],
				mem.FirstName,
				mem.LastName,
				ISNULL(mem.EmailAddress,'') AS [Email],
				ISNULL(CONVERT(CHAR(10),mem.Birthdate,101),'') AS [Birthdate],
				ISNULL(addr.City,'') AS [City],
				ISNULL(addr.[State],'') AS [State],
				ISNULL(mem.AltID1,'') AS [AltID1],
				CONVERT(CHAR(10),chlg.ChallengeBeginDate,101) AS [ChallengeBeginDate],
				CONVERT(CHAR(10),chlg.ChallengeEndDate,101) AS [ChallengeEndDate],
				ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName) AS [ChallengeName],
				CONVERT(CHAR(10),chlg.EnrollmentDate,101) AS [EnrollmentDate],
				ISNULL(CONVERT(CHAR(10),chlg.WithdrawDate,101),'') AS [WithdrawDate],
				ISNULL(CONVERT(CHAR(10),chlg.CompletionDate,101),'') AS [CompletionDate],
				REPLACE(@StepType,'Actiped','Device') AS StepsAllowed,
				--ISNULL(SUM(stp.DeviceSteps),'') AS DeviceSteps,
				--ISNULL(SUM(stp.ManualSteps),'') AS ManualSteps,
				--ISNULL(SUM(stp.ReclassifiedSteps),'') AS ReclassifiedSteps,
				ISNULL(SUM(stp.TotalSteps),'') AS TotalSteps
			FROM
				DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
			JOIN
				DA_Production.prod.Member mem WITH (NOLOCK)
				ON	(grp.GroupID = mem.GroupID)
			JOIN
				DA_Production.prod.Challenge chlg WITH (NOLOCK)
				ON	(mem.MemberID = chlg.MemberID)
				AND	(chlg.ClientChallengeID = @inClientChallengeID)
			LEFT JOIN
				DA_Production.prod.[Address] addr WITH (NOLOCK)
				ON	(mem.MemberID = addr.MemberID)
				AND	(addr.AddressTypeID = 6)
			LEFT JOIN
				#ChallengeSteps stp
				ON	(mem.MemberID = stp.MemberID)
			GROUP BY
				grp.GroupName,
				ISNULL(mem.EligMemberID,''),
				ISNULL(mem.EligMemberSuffix,''),
				mem.FirstName,
				mem.LastName,
				ISNULL(mem.EmailAddress,''),
				ISNULL(CONVERT(CHAR(10),mem.Birthdate,101),''),
				ISNULL(addr.City,''),
				ISNULL(addr.[State],''),
				ISNULL(mem.AltID1,''),
				CONVERT(CHAR(10),chlg.ChallengeBeginDate,101),
				CONVERT(CHAR(10),chlg.ChallengeEndDate,101),
				ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName),
				CONVERT(CHAR(10),chlg.EnrollmentDate,101),
				ISNULL(CONVERT(CHAR(10),chlg.WithdrawDate,101),''),
				ISNULL(CONVERT(CHAR(10),chlg.CompletionDate,101),'')
		END	
		
	END

	-- CLEAN UP
	IF OBJECT_ID('tempDB.dbo.#ChallengeSteps') IS NOT NULL
	BEGIN
		DROP TABLE #ChallengeSteps
	END



END
GO
