SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-03-27
-- Description:	Standard Challenge Completion Report
--
-- Updates:		WilliamPe 20130716
--				Changed order of columns for the qa report.				
--
-- =============================================
CREATE PROCEDURE [standard].[proc_Challenges_Completions]
	@inClientChallengeID INT,
	@inCompletedRule BIT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	SET @inCompletedRule = ISNULL(@inCompletedRule,1)

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
			CONVERT(CHAR(10),chlg.ChallengeBeginDate,101) AS [ChallengeBeginDate],
			CONVERT(CHAR(10),chlg.ChallengeEndDate,101) AS [ChallengeEndDate],
			ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName) AS [ChallengeName],
			CONVERT(CHAR(10),chlg.EnrollmentDate,101) AS [EnrollmentDate],
			ISNULL(CONVERT(CHAR(10),chlg.CompletionDate,101),'') AS [CompletionDate]
		FROM
			DA_Production.prod.Challenge chlg WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(chlg.MemberID = mem.MemberID)
			AND	(chlg.ClientChallengeID = @inClientChallengeID)
		JOIN
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
			ON	(mem.GroupID = grp.GroupID)
		LEFT JOIN
			DA_Production.prod.[Address] addr WITH (NOLOCK)
			ON	(mem.MemberID = addr.MemberID)
			AND	(addr.AddressTypeID = 6)
		WHERE
			chlg.CompletionDate IS NOT NULL
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
			CONVERT(CHAR(10),chlg.ChallengeBeginDate,101) AS [ChallengeBeginDate],
			CONVERT(CHAR(10),chlg.ChallengeEndDate,101) AS [ChallengeEndDate],
			ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName) AS [ChallengeName],
			CONVERT(CHAR(10),chlg.EnrollmentDate,101) AS [EnrollmentDate],
			ISNULL(CONVERT(CHAR(10),chlg.WithdrawDate,101),'') AS [WithdrawDate],	
			ISNULL(CONVERT(CHAR(10),chlg.CompletionDate,101),'') AS [CompletionDate]
		FROM
			DA_Production.prod.Challenge chlg WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(chlg.MemberID = mem.MemberID)
			AND	(chlg.ClientChallengeID = @inClientChallengeID)
		JOIN
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
			ON	(mem.GroupID = grp.GroupID)
		LEFT JOIN
			DA_Production.prod.[Address] addr WITH (NOLOCK)
			ON	(mem.MemberID = addr.MemberID)
			AND	(addr.AddressTypeID = 6)
	END	

END
GO
