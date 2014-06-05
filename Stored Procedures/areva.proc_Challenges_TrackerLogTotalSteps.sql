SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 20130812
-- Description:	Areva Step Challenge Report using the Tracker log (self-reported steps)
--
-- Notes:		This report should only be used for step challenges that do NOT use a connected device
--
--				Currently, the client wants to see members who at least registered
--
-- =============================================
CREATE PROCEDURE [areva].[proc_Challenges_TrackerLogTotalSteps]
	@inClientChallengeID INT = NULL,
	@inCompletedRule BIT = NULL
	
AS
BEGIN
	SET NOCOUNT ON;
	
	-- DECLARES
	DECLARE @StepType VARCHAR(100)
	
	-- SETS
	SET @inClientChallengeID = (
								SELECT
									ClientChallengeID
								FROM
									DA_Production.prod.Challenge
								WHERE
									GroupID = 191545 AND
									(ClientChallengeID = @inClientChallengeID OR
									(DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) >= ChallengeBeginDate AND
									 DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) <= DATEADD(dd,14,ChallengeEndDate)))
								GROUP BY
									ClientChallengeID
								)
								
	SET @inCompletedRule = ISNULL(@inCompletedRule,1)
	SET @StepType = (
					 SELECT
						ActipedStepTypeID
					 FROM
						 HRMS.dbo.Threshold WITH (NOLOCK)
					 WHERE
						 ClientChallengeID = @inClientChallengeID AND
						 ActipedStepTypeID IS NOT NULL AND
						 Deleted = 0
					 GROUP BY
						ActipedStepTypeID
					)

	-- CLEAN UP
	IF OBJECT_ID('tempDB.dbo.#ChallengeSteps') IS NOT NULL
	BEGIN
		DROP TABLE #ChallengeSteps
	END

	IF @StepType IS NOT NULL
	BEGIN
		RAISERROR 
			(
				N'This challenge is not a step challenge that uses the challenge step log.', -- Message text.
				10, -- Severity,
				1  -- State,
			)
	END

	IF @StepType IS NULL
	BEGIN
	
		SELECT
			chlg.MemberID,
			SUM(CAST(trk.Value AS INT)) AS TotalSteps
		INTO
			#ChallengeSteps
		FROM
			[DA_Production].[prod].[Challenge] chlg WITH (NOLOCK)
		JOIN
			[DA_Production].[prod].[Tracker] trk WITH (NOLOCK)
			ON	(chlg.MemberID = trk.MemberID)
			AND	(trk.TrackerDataSourceID = 32)
			AND	(trk.TrackerID = 27)
		WHERE
			chlg.ClientChallengeID = @inClientChallengeID AND
			(DATEADD(dd,DATEDIFF(dd,0,trk.ValueDate),0) BETWEEN chlg.ChallengeBeginDate AND chlg.ChallengeEndDate) AND
			(DATEADD(dd,DATEDIFF(dd,0,trk.SourceAddDate),0) BETWEEN chlg.ChallengeBeginDate AND DATEADD(wk,2,chlg.ChallengeEndDate))
		GROUP BY
			chlg.MemberID
		
		-- COMPLETED ONLY
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
				ISNULL(cs.CS1,'') AS [Location],
				ISNULL(cs.CS2,'') AS [LocationName],
				ISNULL(cs.CS3,'') AS [DistributionLocation],
				CONVERT(CHAR(10),chlg.ChallengeBeginDate,101) AS [ChallengeBeginDate],
				CONVERT(CHAR(10),chlg.ChallengeEndDate,101) AS [ChallengeEndDate],
				ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName) AS [ChallengeName],
				CONVERT(CHAR(10),chlg.EnrollmentDate,101) AS [EnrollmentDate],
				ISNULL(CONVERT(CHAR(10),chlg.CompletionDate,101),'') AS [CompletionDate],
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
				DA_Production.prod.CSFields cs WITH (NOLOCK)
				ON	(mem.MemberID = cs.memberID)
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
				ISNULL(cs.CS1,''),
				ISNULL(cs.CS2,''),
				ISNULL(cs.CS3,''),
				CONVERT(CHAR(10),chlg.ChallengeBeginDate,101),
				CONVERT(CHAR(10),chlg.ChallengeEndDate,101),
				ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName),
				CONVERT(CHAR(10),chlg.EnrollmentDate,101),
				ISNULL(CONVERT(CHAR(10),chlg.CompletionDate,101),'')
		END

		-- REGISTERED RULE
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
				ISNULL(cs.CS1,'') AS [Location],
				ISNULL(cs.CS2,'') AS [LocationName],
				ISNULL(cs.CS3,'') AS [DistributionLocation],
				CONVERT(CHAR(10),chlg.ChallengeBeginDate,101) AS [ChallengeBeginDate],
				CONVERT(CHAR(10),chlg.ChallengeEndDate,101) AS [ChallengeEndDate],
				ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName) AS [ChallengeName],
				CONVERT(CHAR(10),chlg.EnrollmentDate,101) AS [EnrollmentDate],
				ISNULL(CONVERT(CHAR(10),chlg.WithdrawDate,101),'') AS [WithdrawDate],
				ISNULL(CONVERT(CHAR(10),chlg.CompletionDate,101),'') AS [CompletionDate],
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
				DA_Production.prod.CSFields cs WITH (NOLOCK)
				ON	(mem.MemberID = cs.memberID)
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
				ISNULL(cs.CS1,''),
				ISNULL(cs.CS2,''),
				ISNULL(cs.CS3,''),
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
