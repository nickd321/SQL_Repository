SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-09-30
-- Description:	Experian PHA and Bio Completions Report
--
-- Notes:		This report is being used by Experian to administer a premium reduction
--				Since they wanted the data prior to the incentive plan going live 1/1/2014,
--				the report is pulling from the source tables and not the incentive system.
--				As a result, I had to apply the pha and bio date restriction in the reporting layer.
--				If the incentive plan changes regarding the pha and bio rules, this report will need to change
--				as well.
--
--				Rules:
--				Current Employee (CS1 = 'N')
--				Must complete PHA from 8/1/2013 through 8/31/2014
--				Must complete Bio from 1/1/2013 through 12/31/2013
--
--				New Hire (CS1 = 'Y')
--				Must complete PHA from 8/1/2013 through 8/31/2014
--
--				The frequency of this report is weekly. We will be sending a full file each time to Experian.
--				They requested I note the records where the qualified date is within the previous week.  I am 
--				defining previous week as being 1 week prior to the report run date.
--
-- Updates:		WilliamPe 20140101
--				Changed code to reference dbo.func_TRIM rather than the CLR dbo.TRIM function.
--
-- =============================================
CREATE PROCEDURE [experian].[proc_HealthAssessmentAndBio_Completions]
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	
	-- DECLARES
	DECLARE
		@GroupID INT,
		@PHABegin DATETIME,
		@PHAEnd DATETIME,
		@BioBegin DATETIME,
		@BioEnd DATETIME

	-- SETS
	SET @GroupID = 200846
	SET @PHABegin = '2013-08-01'
	SET @PHAEnd = '2014-09-01' -- Exclusive
	SET @BioBegin = '2013-01-01'
	SET @BioEnd = '2014-01-01' -- Exclusive

	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))

	-- RESULTS
	SELECT
		GroupName,
		EligMemberID,
		EligMemberSuffix,
		FirstName,
		LastName,
		EmployeeID,
		LocationCode,
		NewHire,
		CONVERT(VARCHAR(10),PHACompletedDate,101) AS PHACompletedDate,
		ISNULL(CONVERT(VARCHAR(10),BiometricsScreeningCompletedDate,101),'') AS BiometricsScreeningCompletedDate,
		ISNULL(CONVERT(VARCHAR(10),BiometricsScreeningLoadDate,101),'') AS BiometricsScreeningLoadDate,
		CONVERT(VARCHAR(10),QualifiedDate,101) AS QualifiedDate,
		CASE
			WHEN QualifiedDate >= DATEADD(dd,DATEDIFF(dd,0,@inEndDate),-7) AND QualifiedDate < @inEndDate 
			THEN 'Y'
			ELSE ''
		END AS QualifiedPreviousWeek
	FROM
		(
			SELECT
				grp.GroupName,
				mem.EligMemberID,
				mem.EligMemberSuffix,
				mem.FirstName,
				mem.LastName,
				mem.AltID1 AS [EmployeeID],
				cs.CS2 AS [LocationCode],
				cs.CS1 AS [NewHire],
				ha.AssessmentCompleteDate AS [PHACompletedDate],
				scr.ScreeningDate AS [BiometricsScreeningCompletedDate],
				scr.LoadDate AS [BiometricsScreeningLoadDate],
				CASE
					WHEN dbo.func_TRIM(cs.CS1) != 'Y' THEN dbo.func_MAX_DATETIME(scr.LoadDate,ha.AssessmentCompleteDate)
					WHEN dbo.func_TRIM(cs.CS1) = 'Y' THEN ha.AssessmentCompleteDate 
					ELSE NULL 
				END AS [QualifiedDate]    
			FROM
				DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
			JOIN
				DA_Production.prod.Member mem WITH (NOLOCK)
				ON	(grp.GroupID = mem.GroupID)
				AND	(mem.GroupID = @GroupID)
			LEFT JOIN
				DA_Production.prod.CSFields cs WITH (NOLOCK)
				ON	(mem.MemberID = cs.MemberID)
			LEFT JOIN
				(
				SELECT
					MemberID,
					AssessmentCompleteDate,
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AssessmentCompleteDate) AS CompleteDateSeq
				FROM
					DA_Production.prod.HealthAssessment WITH (NOLOCK)
				WHERE
					GroupID = @GroupID AND
					IsComplete = 1 AND
					IsPrimarySurvey = 1 AND
					AssessmentCompleteDate >= @PHABegin AND
					AssessmentCompleteDate < @PHAEnd
				) ha
				ON	(mem.MemberID = ha.MemberID)
				AND	(CompleteDateSeq = 1)
			LEFT JOIN
				(
				SELECT
					MemberID,
					ScreeningDate,
					SourceAddDate AS LoadDate,
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY SourceAddDate) AS LoadDateSeq
				FROM
					DA_Production.prod.BiometricsScreening WITH (NOLOCK)
				WHERE
					GroupID = @GroupID AND
					ScreeningDate >= @BioBegin AND
					ScreeningDate < @BioEnd
				) scr
				ON	(mem.MemberID = scr.MemberID)
				AND	(LoadDateSeq = 1)
			WHERE
				(dbo.func_TRIM(cs.CS1) != 'Y' AND ha.MemberID IS NOT NULL AND scr.MemberID IS NOT NULL) OR
				(dbo.func_TRIM(cs.CS1) = 'Y' AND ha.MemberID IS NOT NULL)
		) data
	WHERE
		QualifiedDate < @inEndDate
	ORDER BY
		CAST(QualifiedDate AS DATETIME) DESC

END
GO
