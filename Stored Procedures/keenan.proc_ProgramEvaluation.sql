SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2014-03-20
-- Description:	Standard procedure to provide Keenan and Associates
--				information about a particular group. 
--				They use the data to evaluate the population. Keenan is a brokerage and consulting firm
-- 
-- Notes:		This report passes Biometrics Screening, PHA Condition Risk Measures, and
--				Utilization/Participation data
--
-- =============================================
CREATE PROCEDURE [keenan].[proc_ProgramEvaluation] 
		@inGroupID VARCHAR(250),
		@inBeginDate DATETIME,
		@inEndDate DATETIME,
		@inSSN INT = 0
AS
BEGIN

	SET NOCOUNT ON;

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END
	
	IF OBJECT_ID('tempdb.dbo.#HealthAssessmentMetric') IS NOT NULL
	BEGIN
		DROP TABLE #HealthAssessmentMetric
	END
	
	
	IF @inSSN NOT IN (1,0)
	BEGIN
		RAISERROR 
			(
				N'@inSSN value should either be 1 = TRUE or 0 = FALSE', -- Message text.
				10, -- Severity,
				1  -- State,
			)
	END
	
	IF @inSSN IN (1,0)
	BEGIN
		-- BASE DATA
		SELECT
			mem.MemberID,
			REPLACE(grp.GroupName,',','') AS [GroupName],
			grp.GroupNumber AS [GroupNumber],
			mem.EligMemberID AS [EligMemberID],
			mem.EligMemberSuffix AS [EligMemberSuffix],
			mem.FirstName AS [FirstName],
			mem.MiddleInitial AS [MiddleInitial],
			mem.LastName AS [LastName],
			CONVERT(VARCHAR(10),mem.Birthdate,101) AS [DOB],
			mem.Gender AS Gender_Elig,
			CONVERT(VARCHAR(10),@inBeginDate,101) AS [StartDate],
			CONVERT(VARCHAR(10),DATEADD(dd,-1,@inEndDate),101) AS [EndDate],
			mem.AltID1,
			CASE WHEN @inSSN = 0 THEN NULL ELSE mem.SubscriberSSN END AS [SSN],
			cs.CS1
		INTO
			#Base
		FROM
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(grp.GroupID = mem.GroupID)
			AND	(mem.GroupID IN (SELECT * FROM [DA_Reports].[dbo].[SPLIT](@inGroupID,',')))
		LEFT JOIN
			DA_Production.prod.CSFields cs WITH (NOLOCK)
			ON	(mem.MemberID = cs.MemberID)
		
		-- BIOMETRICS DATA
		SELECT
			mem.GroupName,
			mem.GroupNumber,
			mem.EligMemberID,
			mem.EligMemberSuffix,
			mem.FirstName,
			mem.MiddleInitial,
			mem.LastName,
			mem.DOB,
			mem.Gender_Elig,
			mem.StartDate,
			mem.EndDate,
			mem.AltID1,
			mem.SSN,
			mem.CS1,
			CONVERT(VARCHAR(10),scr.ScreeningDate,101) AS [BiometricsScreeningDate],
			CASE
				WHEN val.Systolic > 159 OR val.Diastolic > 99 THEN '160/100 or Higher - May Indicate Stage 2 Hypertension'
				WHEN val.Systolic BETWEEN 140 AND 159 OR val.Diastolic BETWEEN 90 AND 99 THEN '140/90-159/99 - May Indicate Stage 1 Hypertension'
				WHEN val.Systolic BETWEEN 120 AND 139 OR val.Diastolic BETWEEN 80 AND 89 THEN '120/80-139/89 - Prehypertension'
				WHEN val.Systolic < 120 OR val.Diastolic < 80 THEN '119/79 or Below - Normal'
			END AS [BloodPressureCategory],
			CASE
				WHEN val.Systolic >= 140 OR val.Diastolic >= 90 THEN 1
				WHEN val.Systolic < 140 OR val.Diastolic < 90 THEN 0
			END AS [BloodPressure_HighRisk],
			val.BMI AS [BMI],
			CASE
				WHEN val.BMI < 18.5 THEN 'Underweight (<18.5)'
				WHEN val.BMI >= 18.5 AND [BMI] < 25.0 THEN 'Normal Weight (18.5-24.9)'
				WHEN val.BMI >= 25.0 AND [BMI] < 30.0 THEN 'Overweight (25.0-29.9)'
				WHEN val.BMI >= 30.0 AND [BMI] < 35.0 THEN 'Class I Obese (>=30)'
				WHEN val.BMI >= 35.0 AND [BMI] < 40.0 THEN 'Class II Obesity (>=35)'
				WHEN val.BMI >= 40.0 THEN 'Class III Obesity (>=40)'
			END AS [BMICategory],
			CASE
				WHEN val.BMI < 30.0 THEN 0
				WHEN val.BMI >= 30.0 THEN 1
			END AS [BMI_HighRisk],
			CASE
				WHEN val.Cholesterol <= 199 THEN '199 or Below - Desirable'
				WHEN val.Cholesterol BETWEEN 200 AND 239 THEN '200-239 - Borderline High'
				WHEN val.Cholesterol >= 240 THEN '240 or Higher - High'
			END AS [CholesterolCategory],
			CASE
				WHEN val.Cholesterol >= 240 THEN 1
				WHEN val.Cholesterol < 240 THEN 0
			END AS [Cholesterol_HighRisk],
			CAST(val.CotinineFlag AS INT) AS [Cotinine_HighRisk],
			CASE
				WHEN scr.IsFasting = 1 AND val.Glucose <= 69 THEN '69 or Below - May be too low'
				WHEN scr.IsFasting = 1 AND val.Glucose BETWEEN 70 AND 99 THEN '70-99 - Normal'
				WHEN scr.IsFasting = 1 AND val.Glucose BETWEEN 100 AND 125 THEN '100-125 - Borderline'
				WHEN scr.IsFasting = 1 AND val.Glucose BETWEEN 126 AND 249 THEN '126-249 - May indicate diabetes'
				WHEN scr.IsFasting = 1 AND val.Glucose >= 250 THEN '250 or Higher - May indicate diabetes'
			END AS [FastingGlucoseCategory],
			CASE
				WHEN scr.IsFasting = 1 AND val.Glucose < 126 THEN 0
				WHEN scr.IsFasting = 1 AND val.Glucose >= 126 THEN 1
			END AS [FastingGlucose_HighRisk],
			CASE
				WHEN scr.IsFasting = 0 AND val.Glucose <= 69 THEN '69 or Below - May be too low'
				WHEN scr.IsFasting = 0 AND val.Glucose BETWEEN 70 AND 139 THEN '70-139 - Normal'
				WHEN scr.IsFasting = 0 AND val.Glucose BETWEEN 140 AND 199 THEN '140-199 - Borderline'
				WHEN scr.IsFasting = 0 AND val.Glucose >= 200 THEN '200 or Higher - May indicate diabetes'
			END AS [RandomGlucoseCategory],
			val.Hemoglobin,
			CASE
				WHEN val.HDL < 40 THEN 'Low (<40)'
				WHEN val.HDL >= 40 AND val.HDL < 60 THEN 'Okay (40-59)'
				WHEN val.HDL >= 60 THEN 'May Protect the Heart (>=60)'
			END AS [HDL_Category],
			CASE
				WHEN val.HDL < 40 THEN 1
				WHEN val.HDL >= 40 THEN 0
			END AS [HDL_HighRisk],
			CASE
				WHEN val.HDLCholesterolRatio > 5 THEN 1
				WHEN val.HDLCholesterolRatio <= 5 THEN 0
			END AS [HDLCholesterolRatio_HighRisk],
			CASE
				WHEN val.LDL < 100 THEN 'Optimal (<100)'
				WHEN val.LDL >= 100 AND val.LDL < 130 THEN 'Near Optimal (100-129)'
				WHEN val.LDL >= 130 AND val.LDL < 160 THEN 'Borderline High (130-159)'
				WHEN val.LDL >= 160 AND val.LDL < 190 THEN 'High (160-189)'
				WHEN val.LDL > 190 THEN 'Very High (>=190)'
			END AS [LDL_Category],
			CASE
				WHEN val.LDL < 160 THEN 1
				WHEN val.LDL >= 160 THEN 0
			END AS [LDL_HighRisk],
			CASE
				WHEN val.Triglycerides <= 149 THEN 'Normal (<150)'
				WHEN val.Triglycerides BETWEEN 150 AND 199 THEN 'Borderline High (150-199)'
				WHEN val.Triglycerides BETWEEN 200 AND 499 THEN 'High (200-499)'
				WHEN val.Triglycerides >= 500 THEN 'Very High (>=500)'
			END AS [TriglyceridesCategory],
			CASE
				WHEN val.Triglycerides >= 200 THEN 1
				WHEN val.Triglycerides < 200 THEN 0
			END AS [Triglycerides_HighRisk],
			CASE
				WHEN LEFT(mem.Gender_Elig,1) = 'M' AND val.WaistCircumference >= 40 THEN 1
				WHEN LEFT(mem.Gender_Elig,1) = 'F' AND val.WaistCircumference >= 35 THEN 1
				WHEN LEFT(mem.Gender_Elig,1) IN ('F','M') AND val.WaistCircumference IS NOT NULL THEN 0
			END AS [WaistCircumference_HighRisk]
		FROM
			#Base mem
		JOIN
			DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
			ON	(mem.MemberID = scr.MemberID)
			AND	(scr.ScreeningDate >= @inBeginDate)
			AND	(scr.ScreeningDate < @inEndDate)
		JOIN
			DA_Production.prod.BiometricsScreeningResults val WITH (NOLOCK)
			ON	(scr.MemberScreeningID = val.MemberScreeningID)
		ORDER BY
			mem.GroupName,
			mem.LastName, 
			mem.FirstName, 
			scr.ScreeningDate
			
		-- PHA DATA
		SELECT
			MemberID,
			MemberAssessmentID,
			GroupName,
			GroupNumber,
			EligMemberID,
			EligMemberSuffix,
			FirstName,
			MiddleInitial,
			LastName,
			DOB,
			Gender_Elig,
			StartDate,
			EndDate,
			AltID1,
			SSN,
			CS1,
			CONVERT(VARCHAR(10),AssessmentCompleteDate,101) AS AssessmentCompleteDate,
			AbsenteeDays,
			CASE
				WHEN LittleInterest = 1 AND FeltDown = 1 THEN 1
				WHEN LittleInterest IS NOT NULL OR FeltDown IS NOT NULL THEN 0
			END AS DepressionIndicator,
			CASE
				WHEN CAST(REPLACE(LEFT(Diet_GrainServings,1),'N',0) AS INT) <= 1 THEN 1
				WHEN CAST(REPLACE(LEFT(Diet_FruitServings,1),'N',0) AS INT) + CAST(REPLACE(LEFT(Diet_VegServings,1),'N',0) AS INT) <= 1 THEN 1
				WHEN CAST(REPLACE(LEFT(Diet_GrainServings,1),'N',0) AS INT) > 1 THEN 0
				WHEN CAST(REPLACE(LEFT(Diet_FruitServings,1),'N',0) AS INT) + CAST(REPLACE(LEFT(Diet_VegServings,1),'N',0) AS INT) > 1 THEN 0
			END AS Diet_HighRisk,
			Diet_FastFoodFrequency,
			Diet_FruitServings,
			Diet_GrainServings,
			Diet_VegServings,
			CASE
				WHEN (SELECT Result FROM DA_Production.dbo.func_TryCastFloat(Exercise_Moderate_Minutes)) < 11.0 OR (SELECT Result FROM DA_Production.dbo.func_TryCastFloat(Exercise_Vigorous_Minutes)) < 1.0 THEN 1
				WHEN Exercise_Moderate_Minutes IS NULL AND Exercise_Vigorous_Minutes IS NULL THEN 1
				ELSE 0
			END AS Activity_HighRisk,
			(SELECT Result FROM DA_Production.dbo.func_TryCastFloat(Exercise_Moderate_Minutes)) AS Exercise_Moderate_Minutes,
			(SELECT Result FROM DA_Production.dbo.func_TryCastFloat(Exercise_Vigorous_Minutes)) AS Exercise_Vigorous_Minutes,
			SelfRatedHealth,
			SelfRatedHealth_YearAgo,
			StressLevel_Health,
			CASE
				WHEN StressLevel_Health >= 8 OR StressLevel_Home >= 8 OR StressLevel_Work >= 8 THEN 1
				WHEN StressLevel_Health IS NOT NULL OR StressLevel_Home IS NOT NULL OR StressLevel_Work IS NOT NULL THEN 0
			END AS Stress_HighRisk,
			CASE
				WHEN StressLevel_Health >= 8 THEN 1
				WHEN StressLevel_Health <= 7 THEN 0
			END AS StressLevel_Health_HighRisk,
			StressLevel_Home,
			CASE
				WHEN StressLevel_Home >= 8 THEN 1
				WHEN StressLevel_Home <= 7 THEN 0
			END AS StressLevel_Home_HighRisk,
			StressLevel_Work,
			CASE
				WHEN StressLevel_Work >= 8 THEN 1
				WHEN StressLevel_Work <= 7 THEN 0
			END AS StressLevel_Work_HighRisk,
			StressManage_Health,
			StressManage_Home,
			StressManage_Work,
			(SELECT Result FROM DA_Production.dbo.func_TryCastInt(Tobacco_Use)) AS Tobacco_HighRisk
		INTO
			#HealthAssessmentMetric
		FROM
			(
			SELECT
				mem.MemberID,
				mem.GroupName,
				mem.GroupNumber,
				mem.EligMemberID,
				mem.EligMemberSuffix,
				mem.FirstName,
				mem.MiddleInitial,
				mem.LastName,
				mem.DOB,
				mem.Gender_Elig,
				mem.StartDate,
				mem.EndDate,
				mem.AltID1,
				mem.SSN,
				mem.CS1,
				ha.AssessmentCompleteDate,
				ha.MemberAssessmentID,
				hamr.Measure,
				hamr.Response
			FROM
				#Base mem
			JOIN
				DA_Production.prod.HealthAssessment ha WITH (NOLOCK)
				ON	(mem.MemberID = ha.MemberID)
				AND	(ha.IsComplete = 1)
				AND	(ha.AssessmentCompleteDate >= @inBeginDate)
				AND	(ha.AssessmentCompleteDate < @inEndDate)
				AND	(ha.SurveyID IN (1,22))
			JOIN
				DA_Production.prod.HealthAssessment_MeasureResponse hamr
				ON	(ha.MemberAssessmentID = hamr.MemberAssessmentID)
			WHERE
				hamr.MeasureID IN
				(
				2,3,4,7,8,9,14,16,21,23,25,26,27,29,30,31,32,33,34,35,36,37,38,39,40,41,43,44,45,46,
				47,48,50,51,52,53,54,55,56,57,58,59,61,67,68,69,70,72,73,74,75,76,77,78,79,80,81,82,
				85,86,87,90,91,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,111,112,116,
				117,118,119,120,121,122,124,125,126,127,128,129,130,136,138,139,140,141,145,147,148,
				149,151,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,
				286,287,288,289,290,291,292,293,294,295,296,297,298,303,304,305,306,307,310,311,312
				)
			) data
		PIVOT
			(
			MAX(Response) FOR Measure IN	(
												AbsenteeDays,
												LittleInterest,
												FeltDown,
												Diet_FastFoodFrequency,
												Diet_FruitServings,
												Diet_GrainServings,
												Diet_VegServings,
												Diet_Resources,
												Diet_StageOfChange,
												Exercise_Moderate_Minutes,
												Exercise_Vigorous_Minutes,
												SelfRatedHealth,
												SelfRatedHealth_YearAgo,
												StressLevel_Health,
												StressLevel_Home,
												StressLevel_Work,
												StressManage_Health,
												StressManage_Home,
												StressManage_Work,
												Tobacco_Use
											)
			) pvt
		ORDER BY
			GroupName,
			LastName,
			FirstName,
			AssessmentCompleteDate

		SELECT
			GroupName,
			GroupNumber,
			EligMemberID,
			EligMemberSuffix,
			FirstName,
			MiddleInitial,
			LastName,
			DOB,
			Gender_Elig,
			StartDate,
			EndDate,
			AltID1,
			SSN,
			CS1,
			AssessmentCompleteDate,
			AbsenteeDays,
			DepressionIndicator,
			CASE
				WHEN ds.Score_Presenteeism BETWEEN 6 AND 18 THEN 1
				WHEN ds.Score_Presenteeism BETWEEN 19 AND 30 THEN 0
			END AS [LowPresenteeism],
			Diet_HighRisk,
			Diet_FastFoodFrequency,
			Diet_FruitServings,
			Diet_GrainServings,
			Diet_VegServings,
			Activity_HighRisk,
			Exercise_Moderate_Minutes,
			CASE
				WHEN Exercise_Moderate_Minutes >= 1 AND Exercise_Moderate_Minutes < 11 THEN '1-10 min'
				WHEN Exercise_Moderate_Minutes >= 11 AND Exercise_Moderate_Minutes < 20 THEN '11-20 min'
				WHEN Exercise_Moderate_Minutes >= 21 AND Exercise_Moderate_Minutes < 30 THEN '21-30 min'
				WHEN Exercise_Moderate_Minutes >= 30 THEN '>30 min'
			END AS [Exercise_Moderate_Minutes_Category],
			Exercise_Vigorous_Minutes,
			CASE
				WHEN Exercise_Vigorous_Minutes >= 1 AND Exercise_Vigorous_Minutes < 11 THEN '1-10 min'
				WHEN Exercise_Vigorous_Minutes >= 11 AND Exercise_Vigorous_Minutes < 20 THEN '11-20 min'
				WHEN Exercise_Vigorous_Minutes >= 21 AND Exercise_Vigorous_Minutes < 30 THEN '21-30 min'
				WHEN Exercise_Vigorous_Minutes >= 30 THEN '>30 min'
			END AS [Exercise_Vigorous_Minutes_Category],
			SelfRatedHealth,
			SelfRatedHealth_YearAgo,
			StressLevel_Health,
			Stress_HighRisk,
			StressLevel_Health_HighRisk,
			StressLevel_Home,
			StressLevel_Home_HighRisk,
			StressLevel_Work,
			StressLevel_Work_HighRisk,
			StressManage_Health,
			StressManage_Home,
			StressManage_Work,
			Tobacco_HighRisk
		FROM
			#HealthAssessmentMetric	ham
		LEFT JOIN
			(
			SELECT
				MemberID,
				MemberAssessmentID,
				[Sleep] AS Score_Sleep,
				[Diet] AS Score_Diet,
				[Activity] AS Score_Activity,
				[Tobacco Use] AS Score_Tobacco,
				[Presenteeism] AS Score_Presenteeism,
				[TotalScore] AS Score_Total,
				[Stress Management] AS Score_Stress,
				[Preventive Health] AS Score_PreventiveHealth
			FROM
				(
				SELECT
					ds.MemberID,
					ds.MemberAssessmentID,
					ds.Domain,
					ds.Score
				FROM
					DA_Production.prod.HealthAssessment_DomainScore ds
				JOIN
					#HealthAssessmentMetric ham
					ON	(ds.MemberAssessmentID = ham.MemberAssessmentID)
				) data	
				PIVOT
				(
				MAX(Score) FOR Domain IN (
										[Sleep],
										[Diet],
										[Activity],
										[Tobacco Use],
										[Presenteeism],
										[TotalScore],
										[Stress Management],
										[Preventive Health]
										)
				) pvt
			) ds
			ON	(ham.MemberAssessmentID = ds.MemberAssessmentID)
		
		-- PARTICIPATION DATA		
		SELECT
			mem.GroupName,
			mem.GroupNumber,
			mem.EligMemberID,
			mem.EligMemberSuffix,
			mem.FirstName,
			mem.MiddleInitial,
			mem.LastName,
			mem.DOB,
			mem.Gender_Elig,
			mem.StartDate,
			mem.EndDate,
			mem.AltID1,
			mem.SSN,
			mem.CS1,
			act.Activity,
			act.ActivityDetail,
			CONVERT(VARCHAR(10),act.ActivityDate,101) AS [ActivityDate]
		FROM
			#Base mem
		JOIN
			(
				SELECT
					ha.MemberID,
					'Personal Health Assessment' AS Activity,
					NULL AS ActivityDetail,
					ha.AssessmentCompleteDate AS ActivityDate
				FROM
					DA_Production.prod.HealthAssessment ha WITH (NOLOCK)
				JOIN
					#Base mem
					ON	(ha.MemberID = mem.MemberID)
				WHERE
					ha.IsComplete = 1 AND
					ha.SurveyID IN (1,22) AND
					ha.AssessmentCompleteDate >= @inBeginDate AND
					ha.AssessmentCompleteDate < @inEndDate
				
				UNION ALL
				
				SELECT
					bio.MemberID,
					'Biometrics Screening' AS Activity,
					NULL AS ActivityDetail,
					bio.ScreeningDate AS ActivityDate
				FROM
					DA_Production.prod.BiometricsScreening bio WITH (NOLOCK)
				JOIN
					#Base mem
					ON	(bio.MemberID = mem.MemberID)
				WHERE
					bio.ScreeningDate >= @inBeginDate AND
					bio.ScreeningDate < @inEndDate			
				
				UNION ALL
				
				SELECT
					chlg.MemberID,
					'Challenge' AS Activity,
					ISNULL(chlg.ChallengeName,chlg.DefaultChallengeName) AS ActivityDetail,
					chlg.CompletionDate AS ActivityDate
				FROM
					DA_Production.prod.Challenge chlg WITH (NOLOCK)
				JOIN
					#Base mem
					ON	(chlg.MemberID = mem.MemberID)
				WHERE
					chlg.CompletionDate >= @inBeginDate AND
					chlg.CompletionDate < @inEndDate
					
				UNION ALL
				
				SELECT
					pln.MemberID,
					'Exercise Planner Created' AS Activity,
					pln.ExerciseProgramType AS ActivityDetail,
					pln.SourceAddDate AS ActivityDate
				FROM
					DA_Production.prod.Planner pln WITH (NOLOCK)
				JOIN
					#Base mem
					ON	(pln.MemberID = mem.MemberID)
				WHERE
					pln.SourceAddDate >= @inBeginDate AND
					pln.SourceAddDate < @inEndDate
				
				UNION ALL
				
				SELECT		
					mem.MemberID,
					'Nutrition Planner Created' AS Activity,
					typ.MealPlanType AS ActivityDetail,
					usr.AddDate AS ActivityDate
				FROM
					#Base mem
				JOIN
					Healthyroads.dbo.NutritionUserMealPlans usr WITH (NOLOCK)
					ON	(mem.MemberID = usr.MemberID)
					AND	(usr.Deleted = 0)
				JOIN
					Healthyroads.dbo.NutritionMealPlans pln WITH (NOLOCK)
					ON	(usr.OriginalMealPlanID = pln.MealPlanID)
				JOIN
					Healthyroads.dbo.NutritionMealPlanTypes typ WITH (nolock)
					ON	(pln.MealPlanTypeID = typ.MealPlanTypeID)
				WHERE
					usr.AddDate >= @inBeginDate AND
					usr.AddDate < @inEndDate
					
				UNION ALL
				
				SELECT
					trk.MemberID,
					'Tracker' AS Activity,
					trk.TrackerName AS ActivityDetail,
					trk.ValueDate AS ActivityDate
				FROM
					DA_Production.prod.Tracker trk WITH (NOLOCK)
				JOIN
					#Base mem
					ON	(trk.MemberID = mem.MemberID)
				WHERE
					trk.ValueDate >= @inBeginDate AND
					trk.ValueDate < @inEndDate AND
					trk.TrackerDataSourceID IN (1,2,8,32,128,256,512)
				GROUP BY
					trk.MemberID,
					trk.TrackerName,
					trk.ValueDate
				
				UNION ALL
				
				SELECT
					comp.MemberID,
					'Competition' AS Activity,
					comp.CompetitionName AS ActivityDetail,
					comp.RegisterDate AS ActivityDate
				FROM
					DA_Production.prod.Competition comp WITH (NOLOCK)
				JOIN
					#Base mem
					ON	(comp.MemberID = mem.MemberID)
				WHERE
					comp.RegisterDate >= @inBeginDate AND
					comp.RegisterDate < @inEndDate		
				
				UNION ALL			
				
				SELECT
					aml.MemberID,
					'Connected!' AS Activity,
					CASE aml.ActivityType WHEN 'Actiped' THEN 'Device' ELSE aml.ActivityType END AS ActivityDetail,
					aml.ActivityDate
				FROM
					DA_Production.prod.ActivityMonitorLog aml WITH (NOLOCK)
				JOIN
					#Base mem
					ON	(aml.MemberID = mem.MemberID)
				WHERE
					aml.ActivityDate >= @inBeginDate AND
					aml.ActivityDate < @inEndDate
				
				UNION ALL
				
				SELECT
					web.MemberID,
					'Web Class' AS Activity,
					web.CourseNameID AS ActivityDetail,
					web.CourseCompleteDate AS ActivityDate
				FROM
					DA_Production.prod.WebClass web WITH (NOLOCK)
				JOIN
					#Base mem
					ON	(web.MemberID = mem.MemberID)
				WHERE
					web.CourseCompleteDate >= @inBeginDate AND
					web.CourseCompleteDate < @inEndDate
				GROUP BY
					web.MemberID,
					web.CourseNameID,
					web.CourseCompleteDate
					
				UNION ALL
				
				SELECT
					appt.MemberID,
					'Telephone Coaching' AS Activity,
					enr.ProgramName AS ActivityDetail,
					CONVERT(VARCHAR(10),appt.AppointmentBeginDate,101) AS ActivityDate
				FROM
					DA_Production.prod.Appointment appt WITH (NOLOCK)
				JOIN
					#Base mem
					ON	(appt.MemberID = mem.MemberID)
				LEFT JOIN
					DA_Production.prod.ProgramEnrollment enr WITH (NOLOCK)
					ON	(appt.MemberID = enr.MemberID)
					AND	(appt.AppointmentBeginDate >= enr.EnrollmentDate)
					AND	(appt.AppointmentBeginDate < ISNULL(enr.TerminationDate,'2999-12-31'))
				WHERE
					appt.AppointmentStatusID = 4 AND
					appt.AppointmentBeginDate >= @inBeginDate AND
					appt.AppointmentBeginDate < @inEndDate
					
			) act
			ON	(mem.MemberID = act.MemberID)
		ORDER BY
			mem.GroupName,
			mem.LastName,
			mem.FirstName,
			act.Activity,
			act.ActivityDetail,
			act.ActivityDate								
	
	END							

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END
	
	IF OBJECT_ID('tempdb.dbo.#HealthAssessmentMetric') IS NOT NULL
	BEGIN
		DROP TABLE #HealthAssessmentMetric
	END
			

END
GO
