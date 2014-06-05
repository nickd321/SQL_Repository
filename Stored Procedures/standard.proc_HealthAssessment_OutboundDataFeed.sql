SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Moore
-- Created By:	William Perez
-- Create date: 2013-07-26
-- Description:	Standard Health Assessment Outbound Data Feed
--
-- Notes:		The original code was taken from a report Nick created for a specific client
--				I added some extra columns (eligmemberid, eligmembersuffix, etc.).
--				This was done to mimic the first nine columns of the standard Biometrics Outbound Data Feed.
--				The only column I did not use is Gender (since this is a question on the PHA).
--
-- =============================================
CREATE PROCEDURE [standard].[proc_HealthAssessment_OutboundDataFeed]
	@inGroupID INT,
	@inBeginDate DATETIME,
	@inEndDate DATETIME
AS
BEGIN

	SET NOCOUNT ON;
	
	SELECT
		CompanyName,
		EligMemberID,
		EligMemberSuffix,
		FirstName,
		LastName,
		DOB,
		Relationship,
		AltID1,
		MemberAssessmentID,
		AssessmentCompleteDate,
		[AbsenteeDays],
		[Alcohol_Current],
		[Alcohol_Days5Plus],
		[Alcohol_Frequency],
		[Alcohol_MaxDrinks],
		[Alcohol_Remorse],
		[Birthdate],
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
		[Diet_FishServings],
		[Diet_FruitServings],
		[Diet_GrainServings],
		[Diet_MeatAltServings],
		[Diet_PoultryServings],
		[Diet_RedMeatServings],
		[Diet_Resources],
		[Diet_StageOfChange],
		[Diet_VegServings],
		[DriveSpeedLimit],
		[Education],
		[EmploymentDuration],
		[Exercise_AdvisedToIncrease],
		[Exercise_BestMethod],
		[Exercise_ConfidenceDiscomfort],
		[Exercise_ConfidenceHaveTime],
		[Exercise_ConfidenceMissGoals],
		[Exercise_ConfidenceTired],
		[Exercise_Light_Minutes],
		[Exercise_Moderate],
		[Exercise_Moderate_Minutes],
		[Exercise_Resources],
		[Exercise_StageOfChange],
		[Exercise_Vigorous],
		[Exercise_Vigorous_Minutes],
		[FastingGlucose],
		[FeltDown],
		[Gender],
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
		[SafeSex],
		[SeatBelt],
		[SecondhandSmoke],
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
		[Tobacco_QuitDate],
		[Tobacco_Resources],
		[Tobacco_StageOfChange],
		[Tobacco_Use],
		[TobaccoStatements],
		[Utilization_ERVisits],
		[Utilization_InpatientAdmissions],
		[Utilization_PhysicianVisits],
		[VisionImpairment],
		[WaistCircumference],
		[Weight_BestMethod],
		[Weight_CarryExcess],
		[Weight_ConfidenceGeneral],
		[Weight_Fluctuation],
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
	FROM
		(
		SELECT
			REPLACE(grp.GroupName,',','') AS CompanyName,
			mem.EligMemberID AS EligMemberID,
			mem.EligMemberSuffix AS EligMemberSuffix,
			mem.FirstName,
			mem.LastName,
			CONVERT(VARCHAR,mem.Birthdate,101) AS DOB,
			mem.Relationship AS Relationship,
			mem.AltID1,
			CONVERT(VARCHAR,ha.AssessmentCompleteDate,101) AS AssessmentCompleteDate,
			ha.MemberAssessmentID,
			hamr.Measure,
			hamr.Response
		FROM
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(grp.GroupID = mem.GroupID)
			AND (mem.GroupID = @inGroupID)
		JOIN
			DA_Production.prod.HealthAssessment ha WITH (NOLOCK)
			ON	(mem.MemberID = ha.MemberID)
			AND	(ha.AssessmentCompleteDate >= @inBeginDate)
			AND	(ha.AssessmentCompleteDate < @inEndDate)
			AND	(ha.IsComplete = 1)
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
										[AbsenteeDays],
										[Alcohol_Current],
										[Alcohol_Days5Plus],
										[Alcohol_Frequency],
										[Alcohol_MaxDrinks],
										[Alcohol_Remorse],
										[Birthdate],
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
										[Diet_FishServings],
										[Diet_FruitServings],
										[Diet_GrainServings],
										[Diet_MeatAltServings],
										[Diet_PoultryServings],
										[Diet_RedMeatServings],
										[Diet_Resources],
										[Diet_StageOfChange],
										[Diet_VegServings],
										[DriveSpeedLimit],
										[Education],
										[EmploymentDuration],
										[Exercise_AdvisedToIncrease],
										[Exercise_BestMethod],
										[Exercise_ConfidenceDiscomfort],
										[Exercise_ConfidenceHaveTime],
										[Exercise_ConfidenceMissGoals],
										[Exercise_ConfidenceTired],
										[Exercise_Light_Minutes],
										[Exercise_Moderate],
										[Exercise_Moderate_Minutes],
										[Exercise_Resources],
										[Exercise_StageOfChange],
										[Exercise_Vigorous],
										[Exercise_Vigorous_Minutes],
										[FastingGlucose],
										[FeltDown],
										[Gender],
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
										[SafeSex],
										[SeatBelt],
										[SecondhandSmoke],
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
										[Tobacco_QuitDate],
										[Tobacco_Resources],
										[Tobacco_StageOfChange],
										[Tobacco_Use],
										[TobaccoStatements],
										[Utilization_ERVisits],
										[Utilization_InpatientAdmissions],
										[Utilization_PhysicianVisits],
										[VisionImpairment],
										[WaistCircumference],
										[Weight_BestMethod],
										[Weight_CarryExcess],
										[Weight_ConfidenceGeneral],
										[Weight_Fluctuation],
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

END
GO