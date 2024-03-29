SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Adrienne Bellomo
-- Create date: 20140207
-- Description:	Avmed Health Assessment Data
--
-- Notes:		Modified from Optima-Sentara Health Assessment Data stored proc but made several changes
--				Removed some fields per client request
--				Changed Condition fields from 3-digit format to BIT
--				Added mr.MeasureID of 3 (it was missing from Optima stored proc)
--				Limiting to SurveyID = 22 until additional logic can be added
--
-- Updates:		
--				Need to add logic to put the 2 surveys (SurveyID 1 & 22) on the same scale for Confidence fields
--				It appears SurveyID 1 is on a 100-point scale and SurveyID 22 is on a 10-pt scale for the confidence fiels (Diet, Exercise, Tobacco)				
--
-- =============================================


CREATE PROCEDURE [avmed].[proc_HealthAssessmentData]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

/*======================================================= SETS ======================================================*/	

	
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

-- CLEAN UP
IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
BEGIN
	DROP TABLE #Base
END

	SELECT DISTINCT
		'D' as RecordType,
		mem.EligMemberID,
		CAST(mem.EligMemberSuffix as varchar(10)) as EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR,mem.Birthdate,101) AS DOB,
		mem.Relationship,
		CAST(ha.MemberAssessmentID as varchar) as MemberAssessmentID,
		CONVERT(VARCHAR,ha.AssessmentCompleteDate,101) AS AssessmentCompleteDate,
		isnull(ha.AbsenteeDays,0) as AbsenteeDays,
		isnull(ha.Alcohol_Current,0) as Alcohol_Current,
		isnull(ha.Alcohol_Days5Plus,0) as Alcohol_Days5Plus,
		isnull(ha.Alcohol_Frequency,0) as Alcohol_Frequency,
		isnull(ha.Alcohol_MaxDrinks,0) as Alcohol_MaxDrinks,
		isnull(ha.Alcohol_Remorse,0) as Alcohol_Remorse,
		ha.BloodPressure,
		ha.Cholesterol,
		left(isnull(ha.Condition_Allergies,0),1) as Condition_Allergies,
		left(isnull(ha.Condition_Arthritis,0),1) as Condition_Arthritis,
		left(isnull(ha.Condition_Asthma,0),1) as Condition_Asthma,
		left(isnull(ha.Condition_BackNeck,0),1) as Condition_BackNeck,
		left(isnull(ha.Condition_Cancer,0),1) as Condition_Cancer,
		left(isnull(ha.Condition_ChronicPain,0),1) as Condition_ChronicPain,
		left(isnull(ha.Condition_COPD,0),1) as Condition_COPD,
		left(isnull(ha.Condition_Depression,0),1) as Condition_Depression,
		left(isnull(ha.Condition_Diabetes,0),1) as Condition_Diabetes,
		left(isnull(ha.Condition_GallbladderDisease,0),1) as Condition_GallbladderDisease,
		left(isnull(ha.Condition_HeartCirculatory,0),1) as Condition_HeartCirculatory,
		left(isnull(ha.Condition_Hyperlipidemia,0),1) as Condition_Hyperlipidemia,
		left(isnull(ha.Condition_Hypertension,0),1) as Condition_Hypertension,
		left(isnull(ha.Condition_MetabolicSyndrome,0),1) as Condition_MetabolicSyndrome,
		left(isnull(ha.Condition_Migraine,0),1) as Condition_Migraine,
		left(isnull(ha.Condition_Neurologic,0),1) as Condition_Neurologic,
		left(isnull(ha.Condition_Obesity,0),1) as Condition_Obesity,
		left(isnull(ha.Condition_Osteoporosis,0),1) as Condition_Osteoporosis,
		left(isnull(ha.Condition_SleepApnea,0),1) as Condition_SleepApnea,
		left(isnull(ha.Condition_StomachBowel,0),1) as Condition_StomachBowel,
		left(isnull(ha.Condition_Stroke,0),1) as Condition_Stroke,
		ha.CurrentHealthProblem,
		ha.Diet_BestMethod,
		ha.Diet_ConfidenceBoredom,
		ha.Diet_ConfidenceHolidays,
		ha.Diet_ConfidenceRestaurant,
		ha.Diet_ConfidenceUpset,
		ha.Diet_FastFoodFrequency,
		ha.Diet_FruitServings,
		ha.Diet_GrainServings,
		ha.Diet_Resources,
		ha.Diet_StageOfChange,
		ha.Diet_VegServings,
		ha.Education,
		ha.EmploymentDuration,
		ha.Exercise_AdvisedToIncrease,
		ha.Exercise_BestMethod,
		ha.Exercise_ConfidenceDiscomfort,
		ha.Exercise_ConfidenceHaveTime,
		ha.Exercise_ConfidenceMissGoals,
		ha.Exercise_ConfidenceTired,
		ha.Exercise_Moderate,
		ha.Exercise_Moderate_Minutes,
		ha.Exercise_Resources,
		ha.Exercise_StageOfChange,
		ha.Exercise_Vigorous,
		ha.Exercise_Vigorous_Minutes,
		ha.FastingGlucose,
		ha.FeltDown,
		ha.Goals,
		ha.Hearing_Devices,
		ha.Hearing_Impairment,
		ha.Height_Inches,
		ha.Helmet,
		ha.Immunization_ChickenPox,
		ha.Immunization_Flu,
		ha.Immunization_HepA,
		ha.Immunization_HepB,
		ha.Immunization_Measles,
		ha.Immunization_Meningococcal,
		ha.Immunization_Tetanus,
		ha.Immunization_Zoster,
		ha.Income,
		ha.JobCategory,
		ha.LittleInterest,
		ha.MaritalStatus,
		ha.PainFrequency,
		ha.PainLevel,
		ha.PreferredLanguage,
		ha.PregnancyStatus,
		ha.Presenteeism_Distracted,
		ha.Presenteeism_Energetic,
		ha.Presenteeism_Focus,
		ha.Presenteeism_Hopeless,
		ha.Presenteeism_Stress,
		ha.Presenteeism_Tasks,
		ha.Preventive_Aspirin,
		ha.Preventive_BloodPressure,
		ha.Preventive_Chlamydia,
		ha.Preventive_Cholesterol,
		ha.Preventive_Colonoscopy,
		ha.Preventive_Mammo,
		ha.Preventive_Pap,
		ha.Preventive_Stool,
		ha.ReadingAid,
		ha.RecreationalDrugUse,
		ha.SeatBelt,
		ha.SelfRatedHealth,
		ha.SelfRatedHealth_YearAgo,
		ha.Sleep_Hours,
		ha.Sleep_WakeupFeeling,
		ha.Stress_StageOfChange,
		ha.StressLevel_Health,
		ha.StressLevel_Home,
		ha.StressLevel_Work,
		ha.StressManage_Health,
		ha.StressManage_Home,
		ha.StressManage_Work,
		ha.Tobacco_BestMethod,
		ha.Tobacco_ConfidenceMorning,
		ha.Tobacco_ConfidenceSocializing,
		ha.Tobacco_ConfidenceTV,
		ha.Tobacco_ConfidenceUpset,
		ha.Tobacco_Resources,
		ha.Tobacco_StageOfChange,
		ha.Tobacco_Use,
		ha.Utilization_ERVisits,
		ha.Utilization_InpatientAdmissions,
		ha.Utilization_PhysicianVisits,
		ha.VisionImpairment,
		ha.WaistCircumference,
		ha.Weight_BestMethod,
		ha.Weight_CarryExcess,
		ha.Weight_ConfidenceGeneral,
		ha.Weight_Pounds,
		ha.Weight_Resources,
		ha.Weight_SelfPerceivedLoss,
		ha.Weight_StageOfChange,
		ha.WorkCulture_Control,
		ha.WorkCulture_Demands,
		ha.WorkCulture_Relationships,
		ha.WorkCulture_Reward,
		ha.WorkCulture_Role,
		ha.WorkCulture_Support,
		CAST(har.Activity_HighRisk AS VARCHAR) AS [Activity_HighRisk],
		CAST(har.Tobacco_HighRisk AS VARCHAR) AS [Tobacco_HighRisk],
		CAST(har.BMI_HighRisk AS VARCHAR) AS [BMI_HighRisk],
		CAST(har.DepressionIndicator AS VARCHAR) AS [DepressionIndicator]
	INTO
		#Base
	FROM
		DA_Production.prod.HealthPlanGroup grp
	JOIN
		DA_Production.prod.Member mem
		ON	(grp.GroupID = mem.GroupID)
	LEFT JOIN
		DA_Production.prod.[Address] addr
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)
	JOIN
		(
		SELECT
			MemberID,
			MemberAssessmentID,
			AssessmentCompleteDate,
			AbsenteeDays,
			Alcohol_Current,
			Alcohol_Days5Plus,
			Alcohol_Frequency,
			Alcohol_MaxDrinks,
			Alcohol_Remorse,
			BloodPressure,
			Cholesterol,
			Condition_Allergies,
			Condition_Arthritis,
			Condition_Asthma,
			Condition_BackNeck,
			Condition_Cancer,
			Condition_ChronicPain,
			Condition_COPD,
			Condition_Depression,
			Condition_Diabetes,
			Condition_GallbladderDisease,
			Condition_HeartCirculatory,
			Condition_Hyperlipidemia,
			Condition_Hypertension,
			Condition_MetabolicSyndrome,
			Condition_Migraine,
			Condition_Neurologic,
			Condition_Obesity,
			Condition_Osteoporosis,
			Condition_SleepApnea,
			Condition_StomachBowel,
			Condition_Stroke,
			CurrentHealthProblem,
			Diet_BestMethod,
			Diet_ConfidenceBoredom,
			Diet_ConfidenceHolidays,
			Diet_ConfidenceRestaurant,
			Diet_ConfidenceUpset,
			Diet_FastFoodFrequency,
			Diet_FruitServings,
			Diet_GrainServings,
			Diet_Resources,
			Diet_StageOfChange,
			Diet_VegServings,
			Education,
			EmploymentDuration,
			Exercise_AdvisedToIncrease,
			Exercise_BestMethod,
			Exercise_ConfidenceDiscomfort,
			Exercise_ConfidenceHaveTime,
			Exercise_ConfidenceMissGoals,
			Exercise_ConfidenceTired,
			Exercise_Moderate,
			Exercise_Moderate_Minutes,
			Exercise_Resources,
			Exercise_StageOfChange,
			Exercise_Vigorous,
			Exercise_Vigorous_Minutes,
			FastingGlucose,
			FeltDown,
			Goals,
			Hearing_Devices,
			Hearing_Impairment,
			Height_Inches,
			Helmet,
			Immunization_ChickenPox,
			Immunization_Flu,
			Immunization_HepA,
			Immunization_HepB,
			Immunization_Measles,
			Immunization_Meningococcal,
			Immunization_Tetanus,
			Immunization_Zoster,
			Income,
			JobCategory,
			LittleInterest,
			MaritalStatus,
			PainFrequency,
			PainLevel,
			PreferredLanguage,
			PregnancyStatus,
			Presenteeism_Distracted,
			Presenteeism_Energetic,
			Presenteeism_Focus,
			Presenteeism_Hopeless,
			Presenteeism_Stress,
			Presenteeism_Tasks,
			Preventive_Aspirin,
			Preventive_BloodPressure,
			Preventive_Chlamydia,
			Preventive_Cholesterol,
			Preventive_Colonoscopy,
			Preventive_Mammo,
			Preventive_Pap,
			Preventive_Stool,
			ReadingAid,
			RecreationalDrugUse,
			SeatBelt,
			SelfRatedHealth,
			SelfRatedHealth_YearAgo,
			Sleep_Hours,
			Sleep_WakeupFeeling,
			Stress_StageOfChange,
			StressLevel_Health,
			StressLevel_Home,
			StressLevel_Work,
			StressManage_Health,
			StressManage_Home,
			StressManage_Work,
			Tobacco_BestMethod,
			Tobacco_ConfidenceMorning,
			Tobacco_ConfidenceSocializing,
			Tobacco_ConfidenceTV,
			Tobacco_ConfidenceUpset,
			Tobacco_Resources,
			Tobacco_StageOfChange,
			Tobacco_Use,
			Utilization_ERVisits,
			Utilization_InpatientAdmissions,
			Utilization_PhysicianVisits,
			VisionImpairment,
			WaistCircumference,
			Weight_BestMethod,
			Weight_CarryExcess,
			Weight_ConfidenceGeneral,
			Weight_Pounds,
			Weight_Resources,
			Weight_SelfPerceivedLoss,
			Weight_StageOfChange,
			WorkCulture_Control,
			WorkCulture_Demands,
			WorkCulture_Relationships,
			WorkCulture_Reward,
			WorkCulture_Role,
			WorkCulture_Support
		FROM
			(
			SELECT
				ha.MemberID,
				ha.MemberAssessmentID,
				ha.AssessmentCompleteDate,
				mr.Measure,
				mr.Response
			FROM
				DA_Production.prod.HealthAssessment ha
			JOIN
				DA_Production.prod.HealthAssessment_MeasureResponse mr
				ON	(ha.MemberAssessmentID = mr.MemberAssessmentID)
				AND	(mr.MeasureID IN
						(
						2,3,4,7,8,9,14,16,21,23,25,26,27,29,30,31,32,33,34,35,36,37,38,39,40,41,43,44,45,46,
						47,48,50,51,52,53,54,55,56,57,58,59,61,67,68,69,70,72,73,74,75,76,77,78,79,80,81,82,
						85,86,87,90,91,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,111,112,116,
						117,118,119,120,121,122,124,125,126,127,128,129,130,136,138,139,140,141,145,147,148,
						149,151,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,
						286,287,288,289,290,291,292,293,294,295,296,297,298,303,304,305,306,307,310,311,312
						)
					)
			WHERE
				ha.HealthPlanID = 70 AND
				ha.SurveyID IN (22) AND --Removed SurveyID 1 until scale logic is added
				ha.AssessmentCompleteDate >= @inBeginDate AND
				ha.AssessmentCompleteDate < @inEndDate
			) data
		PIVOT
			(
			MAX(Response) FOR Measure IN	(
										[AbsenteeDays],
										[Alcohol_Current],
										[Alcohol_Days5Plus],
										[Alcohol_Frequency],
										[Alcohol_MaxDrinks],
										[Alcohol_Remorse],
										[BloodPressure],
										[Cholesterol],
										[Condition_Allergies],
										[Condition_Arthritis],
										[Condition_Asthma],
										[Condition_BackNeck],
										[Condition_Cancer],
										[Condition_ChronicPain],
										[Condition_COPD],
										[Condition_Depression],
										[Condition_Diabetes],
										[Condition_GallbladderDisease],
										[Condition_HeartCirculatory],
										[Condition_Hyperlipidemia],
										[Condition_Hypertension],
										[Condition_MetabolicSyndrome],
										[Condition_Migraine],
										[Condition_Neurologic],
										[Condition_Obesity],
										[Condition_Osteoporosis],
										[Condition_SleepApnea],
										[Condition_StomachBowel],
										[Condition_Stroke],
										[CurrentHealthProblem],
										[Diet_BestMethod],
										[Diet_ConfidenceBoredom],
										[Diet_ConfidenceHolidays],
										[Diet_ConfidenceRestaurant],
										[Diet_ConfidenceUpset],
										[Diet_FastFoodFrequency],
										[Diet_FruitServings],
										[Diet_GrainServings],
										[Diet_Resources],
										[Diet_StageOfChange],
										[Diet_VegServings],
										[Education],
										[EmploymentDuration],
										[Exercise_AdvisedToIncrease],
										[Exercise_BestMethod],
										[Exercise_ConfidenceDiscomfort],
										[Exercise_ConfidenceHaveTime],
										[Exercise_ConfidenceMissGoals],
										[Exercise_ConfidenceTired],
										[Exercise_Moderate],
										[Exercise_Moderate_Minutes],
										[Exercise_Resources],
										[Exercise_StageOfChange],
										[Exercise_Vigorous],
										[Exercise_Vigorous_Minutes],
										[FastingGlucose],
										[FeltDown],
										[Goals],
										[Hearing_Devices],
										[Hearing_Impairment],
										[Height_Inches],
										[Helmet],
										[Immunization_ChickenPox],
										[Immunization_Flu],
										[Immunization_HepA],
										[Immunization_HepB],
										[Immunization_Measles],
										[Immunization_Meningococcal],
										[Immunization_Tetanus],
										[Immunization_Zoster],
										[Income],
										[JobCategory],
										[LittleInterest],
										[MaritalStatus],
										[PainFrequency],
										[PainLevel],
										[PreferredLanguage],
										[PregnancyStatus],
										[Presenteeism_Distracted],
										[Presenteeism_Energetic],
										[Presenteeism_Focus],
										[Presenteeism_Hopeless],
										[Presenteeism_Stress],
										[Presenteeism_Tasks],
										[Preventive_Aspirin],
										[Preventive_BloodPressure],
										[Preventive_Chlamydia],
										[Preventive_Cholesterol],
										[Preventive_Colonoscopy],
										[Preventive_Mammo],
										[Preventive_Pap],
										[Preventive_Stool],
										[ReadingAid],
										[RecreationalDrugUse],
										[SeatBelt],
										[SelfRatedHealth],
										[SelfRatedHealth_YearAgo],
										[Sleep_Hours],
										[Sleep_WakeupFeeling],
										[Stress_StageOfChange],
										[StressLevel_Health],
										[StressLevel_Home],
										[StressLevel_Work],
										[StressManage_Health],
										[StressManage_Home],
										[StressManage_Work],
										[Tobacco_BestMethod],
										[Tobacco_ConfidenceMorning],
										[Tobacco_ConfidenceSocializing],
										[Tobacco_ConfidenceTV],
										[Tobacco_ConfidenceUpset],
										[Tobacco_Resources],
										[Tobacco_StageOfChange],
										[Tobacco_Use],
										[Utilization_ERVisits],
										[Utilization_InpatientAdmissions],
										[Utilization_PhysicianVisits],
										[VisionImpairment],
										[WaistCircumference],
										[Weight_BestMethod],
										[Weight_CarryExcess],
										[Weight_ConfidenceGeneral],
										[Weight_Pounds],
										[Weight_Resources],
										[Weight_SelfPerceivedLoss],
										[Weight_StageOfChange],
										[WorkCulture_Control],
										[WorkCulture_Demands],
										[WorkCulture_Relationships],
										[WorkCulture_Reward],
										[WorkCulture_Role],
										[WorkCulture_Support]
										)
			) pvt
		) ha
		ON	(mem.MemberID = ha.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberAssessmentID,
			Activity_HighRisk,
			Tobacco_HighRisk,
			BMI_HighRisk,
			DepressionIndicator
		FROM
			DA_Evaluation.asmnt.HealthAssessmentReport
		WHERE
				HealthPlanID = 70 AND
				AssessmentCompleteDate >= @inBeginDate AND
				AssessmentCompleteDate < @inEndDate
		) har
		ON	(har.MemberAssessmentID = ha.MemberAssessmentID)
	WHERE
		grp.HealthPlanID = 70 and 
		grp.GroupNumber <> 'ZZAA'
		and mem.eligmemberid <> ''
		and mem.eligmemberid is not null
		and mem.eligmemberid not like 'e%'
		and mem.eligmemberid not like 's%'

SELECT
	*
FROM
	#Base

UNION ALL

SELECT
		'T',
		CAST(COUNT('D') as VARCHAR(30)) AS [RecordCount],
		CAST(CONVERT(VARCHAR(10),@inBeginDate,101) as VARCHAR) AS [BeginDate],
		CAST(CONVERT(VARCHAR(10),DATEADD(dd,-1,@inEndDate),101) as VARCHAR(80)) AS [EndDate],
		'' AS [T5],
		'' AS [T6],
		'' AS [T7],
		'' AS [T8],
		'' AS [T9],
		'' AS [T10],
		'' AS [T11],
		'' AS [T12],
		'' AS [T13],
		'' AS [T14],
		'' AS [T15],
		'' AS [T16],
		'' AS [T17],
		'' AS [T18],
		'' AS [T19],
		'' AS [T20],
		'' AS [T21],
		'' AS [T22],
		'' AS [T23],
		'' AS [T24],
		'' AS [T25],
		'' AS [T26],
		'' AS [T27],
		'' AS [T28],
		'' AS [T29],
		'' AS [T30],
		'' AS [T31],
		'' AS [T32],
		'' AS [T33],
		'' AS [T34],
		'' AS [T35],
		'' AS [T36],
		'' AS [T37],
		'' AS [T38],
		'' AS [T39],
		'' AS [T40],
		'' AS [T41],
		'' AS [T42],
		'' AS [T43],
		'' AS [T44],
		'' AS [T45],
		'' AS [T46],
		'' AS [T47],
		'' AS [T48],
		'' AS [T49],
		'' AS [T50],
		'' AS [T50],
		'' AS [T51],
		'' AS [T52],
		'' AS [T53],
		'' AS [T54],
		'' AS [T55],
		'' AS [T56],
		'' AS [T57],
		'' AS [T58],
		'' AS [T59],
		'' AS [T60],
		'' AS [T61],
		'' AS [T62],
		'' AS [T63],
		'' AS [T64],
		'' AS [T65],
		'' AS [T66],
		'' AS [T67],
		'' AS [T68],
		'' AS [T69],
		'' AS [T70],
		'' AS [T71],
		'' AS [T72],
		'' AS [T73],
		'' AS [T74],
		'' AS [T75],
		'' AS [T76],
		'' AS [T77],
		'' AS [T78],
		'' AS [T79],
		'' AS [T80],
		'' AS [T81],
		'' AS [T82],
		'' AS [T83],
		'' AS [T84],
		'' AS [T85],
		'' AS [T86],
		'' AS [T87],
		'' AS [T88],
		'' AS [T89],
		'' AS [T90],
		'' AS [T91],
		'' AS [T92],
		'' AS [T93],
		'' AS [T94],
		'' AS [T95],
		'' AS [T96],
		'' AS [T97],
		'' AS [T98],
		'' AS [T99],
		'' AS [T100],
		'' AS [T101],
		'' AS [T102],
		'' AS [T103],
		'' AS [T104],
		'' AS [T105],
		'' AS [T106],
		'' AS [T107],
		'' AS [T108],
		'' AS [T109],
		'' AS [T110],
		'' AS [T111],
		'' AS [T112],
		'' AS [T113],
		'' AS [T114],
		'' AS [T115],
		'' AS [T116],
		'' AS [T117],
		'' AS [T118],
		'' AS [T119],
		'' AS [T120],
		'' AS [T121],
		'' AS [T122],
		'' AS [T123],
		'' AS [T124],
		'' AS [T125],
		'' AS [T126],
		'' AS [T127],
		'' AS [T128],
		'' AS [T129],
		'' AS [T130],
		'' AS [T131],
		'' AS [T132],
		'' AS [T133],
		'' AS [T134],
		'' AS [T135],
		'' AS [T136],
		'' AS [T137],
		'' AS [T138],
		'' AS [T139],
		'' AS [T140],
		'' AS [T141],
		'' AS [T142],
		'' AS [T143],
		'' AS [T144]

FROM
		#Base
-- CLEAN UP
IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
BEGIN
	DROP TABLE #Base
END		
	
END

GO
