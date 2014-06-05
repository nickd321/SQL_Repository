SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [internal].[proc_QAC_ECROutcomes]

AS BEGIN

IF OBJECT_ID('DA_Evaluation.qac.ECROutcomes') IS NOT NULL BEGIN
	DROP TABLE DA_Evaluation.qac.ECROutcomes
END

IF OBJECT_ID('TempDB.dbo.#Normalized') IS NOT NULL BEGIN
	DROP TABLE #Normalized
END

	SELECT
		HealthPlanID,
		GroupID,
		MemberID,
		StartDate,
		Measure,
		CAST(NULLIF(Value,'~') AS FLOAT) AS Value,
		ROW_NUMBER() OVER(PARTITION BY MemberID, YEAR(StartDate), Measure ORDER BY StartDate) AS Seq,
		ROW_NUMBER() OVER(PARTITION BY MemberID, YEAR(StartDate), Measure ORDER BY StartDate DESC) AS InvSeq,
		CASE WHEN RANK() OVER(PARTITION BY MemberID ORDER BY YEAR(StartDate)) = 1 THEN 1 ELSE 0 END AS NewParticipant
	INTO
		#Normalized
	FROM
		(
		SELECT
			HealthPlanID,
			GroupID,
			MemberID,
			StartDate,
			ISNULL(CAST(TobaccoUse AS VARCHAR),'~') AS TobaccoUse,
			ISNULL(CAST(WeightPounds AS VARCHAR),'~') AS WeightPounds,
			ISNULL(CAST(BMI AS VARCHAR),'~') AS BMI,
			CAST(CASE
				WHEN ActivityRisk = 'Low' THEN '1'
				WHEN ActivityRisk IS NOT NULL THEN '0'
				ELSE '~'
			END AS VARCHAR) AS TargetedExercise,
			CAST(CASE
				WHEN ISNULL(WorkStress,7) >= 7 AND HealthStress >= 7 AND HomeStress >= 7 THEN '1'
				WHEN ISNULL(WorkStress,7) < 7 AND HealthStress < 7 AND HomeStress < 7 THEN '0'
				ELSE '~'
			END AS VARCHAR) AS TargetedStress,
			CAST(CASE
				WHEN LEFT(FruitServings,1) IN ('1','2','3','4','5') AND
					LEFT(VegetableServings,1) IN ('1','2','3','4','5') AND
					LEFT(GrainServings,1) IN ('1','2','3','4','5') THEN '1'
				WHEN (FruitServings + VegetableServings + GrainServings) IS NULL THEN '~'
				ELSE '0'
			END AS VARCHAR) AS TargetedDiet
		FROM
			DA_Production.prod.ECRCaseSession
		) data
	UNPIVOT
		(
		Value FOR Measure IN (TobaccoUse,WeightPounds,BMI,TargetedExercise,TargetedStress,TargetedDiet)
		) unpvt


	SELECT
		t1.HealthPlanID,
		t1.GroupID,
		t1.MemberID,
		YEAR(t1.StartDate) AS CalendarYear,
		t1.Measure,
		t1.StartDate AS T1_Date,
		t2.StartDate AS T2_Date,
		t1.Value AS T1_Value,
		t2.Value AS T2_Value,
		t1.NewParticipant,
		t1.InvSeq AS SessionCount,
		prg1.ProgramName AS T1_Program,
		prg2.ProgramName AS T2_Program
	INTO
		DA_Evaluation.qac.ECROutcomes
	FROM
		#Normalized t1
	JOIN
		#Normalized t2
		ON	(t1.MemberID = t2.MemberID)
		AND	(t1.Measure = t2.Measure)
		AND	(YEAR(t1.StartDate) = YEAR(t2.StartDate))
		AND	(t2.InvSeq = CASE WHEN t2.Value IS NULL THEN 2 ELSE 1 END)
		AND	(t2.Seq > 1)
	LEFT JOIN
		DA_Production.prod.ProgramEnrollment prg1
		ON	(t1.MemberID = prg1.MemberID)
		AND	(t1.StartDate BETWEEN prg1.EnrollmentDate AND ISNULL(prg1.TerminationDate,'12/31/2999'))
	LEFT JOIN
		DA_Production.prod.ProgramEnrollment prg2
		ON	(t2.MemberID = prg2.MemberID)
		AND	(t2.StartDate BETWEEN prg2.EnrollmentDate AND ISNULL(prg2.TerminationDate,'12/31/2999'))
	WHERE
		t1.Seq = 1 AND
		t1.Value IS NOT NULL AND
		t2.Value IS NOT NULL


	--Return an innocuous result
	SELECT 1 AS Result
	
END
GO
