SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 2014-01-06
-- Description:	Pulls PHA and Biometric activity for Callaway Members 
--
-- Notes:		This report will display only those members that have 
--				an eligible effective date greater than or equal to 11/01/2013.
--				Analytics is defining this population as newly benefited members,
--				and not as 'New Hires'.  Callaway is not passing us any indicators
--				that would allow us to determine a hire date or status
--				
-- Updates:
--
-- =============================================

CREATE PROCEDURE [callawaygolf].[proc_HealthAssessmentAndBio_Completions_NewBenefitEligible]

AS
BEGIN
	SET NOCOUNT ON;

	-- DECLARES: Execute from here down to end of WHERE clause to see output without creating procedure 
	DECLARE 
		@GroupID INT,
		@EffectiveBeginDate DATETIME

	-- SETS
	SET @GroupID = 191546
	SET @EffectiveBeginDate = '2013-11-01'


	SELECT
		hpg.GroupName,
		mem.EligMemberID,
		mem.FirstName,
		ISNULL(mem.MiddleInitial,'') AS [MiddleInitial],
		mem.LastName,
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,121),'')  AS [Birthdate],
		mem.Relationship,
		ISNULL(addr.City,'') AS [City],
		ISNULL(addr.[State],'') AS [State],
		CONVERT(VARCHAR(10),eli.EffectiveDate,121) AS [EffectiveDateOfBenefit],
		ISNULL(CONVERT(VARCHAR(10),pha.AssessmentBeginDate,121),'') AS [PHACompletedDate],
		ISNULL(CONVERT(VARCHAR(10),bio.ScreeningDate,121),'') AS [BiometricScreeningCompletedDate],
		CASE 
			WHEN pha.AssessmentBeginDate IS NOT NULL AND 
				 bio.ScreeningDate IS NOT NULL 
			THEN 'Y' 
			ELSE '' 
		END AS [PHAandBiometricScreeningCompletedFlag]
	
	FROM 
		[DA_Production].[prod].[HealthPlanGroup] hpg
	JOIN
		[DA_Production].[prod].[Member] mem
		ON   hpg.GroupID = mem.GroupID
		AND  hpg.GroupID = @GroupID
	LEFT JOIN
		[DA_Production].[prod].[Address] addr
		ON	 mem.MemberID = addr.MemberID
		AND	 addr.AddressTypeID = 6
	JOIN
		(
		SELECT
			MemberID,
			EffectiveDate,
			TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			[DA_Production].[prod].[Eligibility] 
		WHERE
			GroupID = @GroupID AND
			EffectiveDate >= @EffectiveBeginDate
		) eli
		ON	eli.MemberID = mem.MemberID
		AND eli.RevTermSeq = 1

	LEFT JOIN
		(
		SELECT
			MemberID,
			AssessmentBeginDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AssessmentBeginDate) AS [PHASeq]
		FROM	
			[DA_Production].[prod].[HealthAssessment]
		WHERE
			GroupID = @GroupID AND
			AssessmentBeginDate >= @EffectiveBeginDate
	   ) pha
		ON	mem.MemberID = pha.MemberID
		AND pha.PHASeq = 1
	LEFT JOIN
		(
		SELECT
			MemberID,
			ScreeningDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ScreeningDate) as [BioSeq]
		 FROM	
			[DA_Production].[prod].[BiometricsScreening]
		WHERE
			GroupID = @GroupID AND
			ScreeningDate >= @EffectiveBeginDate
		 ) bio
		ON	mem.MemberID = bio.MemberID
		AND bio.BioSeq = 1
	WHERE 
		pha.AssessmentBeginDate IS NOT NULL
		OR bio.ScreeningDate IS NOT NULL

END
GO
