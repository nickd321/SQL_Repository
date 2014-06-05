SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 2014-02-20
-- Description:	Mondelez Outbound Health Assessment Condition Risk Data Feed
--
--
-- =============================================

CREATE PROCEDURE [mondelez].[proc_HealthAssessment_ConditionsRisks] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	
	SET NOCOUNT ON;

	SET @inBeginDate = ISNULL(@inBeginDate,'2013-01-01')
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))
	
	
	SELECT
		REPLACE(grp.GroupName,',','') AS CompanyName,
		ISNULL(mem.EligMemberID,'') AS EligMemberID,
		ISNULL(mem.EligMemberSuffix,'') AS EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS DOB,
		ISNULL(mem.AltID1,'') AS AltID1,
		ISNULL(mem.SubscriberSSN,'') AS SSN,
		mem.Relationship,
		CONVERT(VARCHAR(10),ham.AssessmentCompleteDate,101) AS AssessmentCompleteDate,
		ham.Activity_HighRisk,
		ham.Diet_HighRisk,
		ham.Stress_HighRisk,
		ham.Tobacco_HighRisk,
		ham.BloodPressure_HighRisk,
		ham.FastingGlucose_HighRisk,
		ham.Cholesterol_HighRisk,
		ham.BMI,
		ham.BMI_HighRisk,
		ham.Condition_Allergies,
		ham.Condition_Arthritis,
		ham.Condition_Asthma,
		ham.Condition_BackNeck,
		ham.Condition_Cancer,
		ham.Condition_ChronicPain,
		ham.Condition_COPD,
		ham.Condition_Depression,
		ham.Condition_Diabetes,
		ham.Condition_HeartCirculatory,
		ham.Condition_Hyperlipidemia,
		ham.Condition_Hypertension,
		ham.Condition_MetabolicSyndrome,
		ham.Condition_Migraine,
		ham.Condition_Obesity,
		ham.Condition_Stroke,
		ham.DepressionIndicator,
		ham.Gender,
		ham.Weight_Pounds
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 204296)
	JOIN
		DA_Evaluation.asmnt.HealthAssessmentReport ham WITH (NOLOCK)
		ON	(mem.MemberID = ham.MemberID)
		AND	(ham.AssessmentCompleteDate >= @inBeginDate)
		AND	(ham.AssessmentCompleteDate < @inEndDate)
END
GO
