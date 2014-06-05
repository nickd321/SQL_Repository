SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-12-30
-- Description:	Providence Incentives Activity Two
--
-- Notes:		Report to be used for customer service to 
--				field questions.  Excludes Alaska populations
--				Only include Biometric Completion Activity
--
-- Updates:		
-- =============================================

CREATE PROCEDURE [providence].[proc_Incentives_ActivityTwo] 

AS
BEGIN

	SET NOCOUNT ON;

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#BaseData') IS NOT NULL
	BEGIN
		DROP TABLE #BaseData
	END

	-- BASE DATA TEMP
	CREATE TABLE #BaseData
	(
		MemberID INT,
		RelationshipID INT,
		EligMemberID VARCHAR(30),
		EligMemberSuffix CHAR(2),
		EligMemberID_Suffix VARCHAR(50),
		FirstName VARCHAR(80),
		MiddleInitial VARCHAR(10),
		LastName VARCHAR(80),
		CS1 VARCHAR(100),
		CS3 VARCHAR(100),
		CS4 VARCHAR(100),
		CS6 VARCHAR(100),
		CS8 VARCHAR(100),
		CS9 VARCHAR(100),
		CS10 VARCHAR(100),
		CS1_INT INT,
		IsCurrentlyEligible BIT,
		EffectiveDate DATETIME,
		TerminationDate DATETIME,
		ClientIncentivePlanID INT,
		ActivityItemID INT,
		Activity VARCHAR(1000),
		ConformedActivity VARCHAR(100),
		ActivityDate DATETIME,
		ActivityValue INT,
		ActivityCreditDate DATETIME
	)
	INSERT INTO #BaseData
	EXEC [providence].[proc_Incentives_BaseData] 'All', 2

	SELECT
		PHPID,
		Suffix,
		EmployeeID,
		'x' AS IncentiveComplete
	FROM
		(
		SELECT
			EligMemberID AS PHPID,
			EligMemberSuffix AS Suffix,
			CS8 AS EmployeeID,
			CS4 AS ProcessLevel,
			CS6 AS PlanCode,
			CS3 AS IncentivePlan,
			RelationshipID,
			ConformedActivity AS Activity,
			ActivityDate,
			ActivityCreditDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ActivityDate, ActivityCreditDate) AS BioSeq
		FROM
			#BaseData
		WHERE
			ConformedActivity = 'BIO' AND
			CS3 IN ('2','4')
		) bio
	WHERE
		BioSeq = 1


	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#BaseData') IS NOT NULL
	BEGIN
		DROP TABLE #BaseData
	END

END
GO
