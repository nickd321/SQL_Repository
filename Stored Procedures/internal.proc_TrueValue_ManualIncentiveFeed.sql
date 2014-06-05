SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		William Perez
-- Create date: 2013-10-23
-- Description:	True Value Met or Improved Outcomes Report
--
-- Updates:		WilliamPe/NickD 2014-04-15
--				Changed logic to point to new hire population incentive plan
--				The "current" population outcomes report is no longer needed.
--				
--				Changes were made to #Biometrics temp table only:
--				1) Updated Time2 logic
--				2) Member must meet criteria within 90 days of date of hire
--				3) Changed hire date filter to include only those hired on or after 10/1/2013
--				
-- =============================================


CREATE PROCEDURE [internal].[proc_TrueValue_ManualIncentiveFeed] 

AS
BEGIN
	SET NOCOUNT ON;

	-- DECLARES
	DECLARE @RunDate DATETIME

	-- SET
	SET @RunDate = GETDATE()

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Biometrics') IS NOT NULL
	BEGIN
		DROP TABLE #Biometrics
	END

	IF OBJECT_ID('tempdb.dbo.#BioSeq') IS NOT NULL
	BEGIN
		DROP TABLE #BioSeq
	END

	IF OBJECT_ID('tempdb.dbo.#Denorm') IS NOT NULL
	BEGIN
		DROP TABLE #Denorm
	END

	-- GET ALL BIOMETRICS WITHIN RANGE
	SELECT 
		mem.MemberID,
		cs.CS3 AS Medical,
		CASE WHEN ISDATE(cs.CS4) = 1 THEN CAST(cs.CS4 AS DATETIME) END AS HireDate,
		mem.Gender,
		scr.MemberScreeningID,
		scr.ScreeningDate,
		scr.SourceAddDate AS [LoadDate],
		scr.FileSource,
		CASE
			WHEN scr.ScreeningDate >= '2012-01-01' AND scr.ScreeningDate < '2013-09-01' THEN 'Time1'
			WHEN scr.ScreeningDate >= '2013-09-01' AND 
				 scr.ScreeningDate < DATEADD(dd,90,CASE WHEN ISDATE(cs.CS4) = 1 THEN CAST(cs.CS4 AS DATETIME) END) AND
				 scr.ScreeningDate < '2014-09-01' THEN 'Time2'			 
		END AS [Time],
		scr.IsPregnant,
		scr.IsFasting,
		res.Systolic,
		res.Diastolic,
		res.Cholesterol,
		res.Glucose,
		res.BMI,
		res.WaistCircumference
	INTO
		#Biometrics
	FROM
		DA_Production.prod.Member mem WITH (NOLOCK)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
		ON	(mem.MemberID = scr.MemberID)
	LEFT JOIN
		DA_Production.prod.BiometricsScreeningResults res WITH (NOLOCK)
		ON	(scr.MemberScreeningID = res.MemberScreeningID)
	WHERE
		mem.GroupID = 202586 AND
		scr.ScreeningDate >= '2012-01-01' AND 
		scr.ScreeningDate < '2014-09-01' AND
		RTRIM(LTRIM(cs.CS3)) = 'Y' AND -- INCLUDE ONLY THOSE ENROLLED IN MEDICAL
		CASE WHEN ISDATE(cs.CS4) = 1 THEN CAST(cs.CS4 AS DATETIME) END >= '2013-10-01' -- INCLUDE ONLY "NEW HIRE" EMPLOYEE POPULATION
	

	
	-- ELIMINATE MULTIPLE RECORDS IN TIME 1 OR TIME 2
	SELECT
		*
	INTO
		#BioSeq
	FROM
		(
		-- PER CONVERSATION WITH ALICIA D., CHOOSING LATEST SCREENING RECORD DETERMINED BY SCREENING DATE IF THERE IS MORE THAN ONE IN TIME 1
		SELECT
			MemberID,
			Medical,
			HireDate,
			Gender,
			MemberScreeningID,
			ScreeningDate,
			LoadDate,
			FileSource,
			[Time],
			IsPregnant,
			IsFasting,
			Systolic,
			Diastolic,
			Cholesterol,
			Glucose,
			BMI,
			WaistCircumference,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ScreeningDate DESC) AS ScreeningSeq,
			'DESC' AS SequenceType
		FROM
			#Biometrics
		WHERE
			[Time] = 'Time1'

		UNION ALL

		-- INCLUDING FIRST RECORD IN TIME 2 DETERMINED BY LOAD DATE (SOURCEADDDATE), SINCE THAT IS THE RECORD THAT SLAVISA WOULD PULL IN FOR THE BIOMETRIC COMPLETION RECORD
		SELECT
			MemberID,
			Medical,
			HireDate,
			Gender,
			MemberScreeningID,
			ScreeningDate,
			LoadDate,
			FileSource,
			[Time],
			IsPregnant,
			IsFasting,
			Systolic,
			Diastolic,
			Cholesterol,
			Glucose,
			BMI,
			WaistCircumference,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY LoadDate, MemberScreeningID) AS ScreeningSeq,
			'ASC' AS SequenceType
		FROM
			#Biometrics
		WHERE
			[Time] = 'Time2'
		) data
	WHERE
		ScreeningSeq = 1

	-- DENORMALIZE DATA
	SELECT
		bioTWO.MemberID,
		bioTWO.Medical,
		bioTWO.HireDate,
		bioTWO.Gender,
		-- SCREENING TIME 2
		bioTWO.MemberScreeningID AS ScreeningID_TWO,
		bioTWO.ScreeningDate AS ScreeningDate_TWO,
		bioTWO.LoadDate AS LoadDate_TWO,
		bioTWO.IsPregnant AS IsPregnant_TWO,
		bioTWO.IsFasting AS IsFasting_TWO,
		bioTWO.Systolic AS Systolic_TWO,
		bioTWO.Diastolic AS Diastolic_TWO,
		bioTWO.Cholesterol AS Cholesterol_TWO,
		bioTWO.Glucose AS Glucose_TWO,
		bioTWO.BMI AS BMI_TWO,
		bioTWO.WaistCircumference AS Waist_TWO,
		-- SCREENING TIME 1
		bioONE.MemberScreeningID AS ScreeningID_ONE,
		bioONE.ScreeningDate AS ScreeningDate_ONE,
		bioONE.LoadDate AS LoadDate_ONE,
		bioONE.IsPregnant AS IsPregnant_ONE,
		bioONE.IsFasting AS IsFasting_ONE,
		bioONE.Systolic AS Systolic_ONE,
		bioONE.Diastolic AS Diastolic_ONE,
		bioONE.Cholesterol AS Cholesterol_ONE,
		bioONE.Glucose AS Glucose_ONE,
		bioONE.BMI AS BMI_ONE,
		bioONE.WaistCircumference AS Waist_ONE
	INTO
		#Denorm
	FROM
		#BioSeq bioTWO
	LEFT JOIN
		#BioSeq bioONE
		ON	(bioTWO.MemberID = bioONE.MemberID)
		AND (bioONE.[Time] = 'Time1')
	WHERE
		bioTWO.[Time] = 'Time2'

	-- RESULTS
	SELECT
		CONVERT(VARCHAR(10),@RunDate,101) AS Creation_Date,
		'TrueValueOutcomesIncentiveFile' + CONVERT(VARCHAR(8),@RunDate,112) + '.xls' AS [File_Name],
		'HRDS Analytics' AS Sendor_Name,
		grp.GroupName AS Group_Name,
		mem.EligMemberID AS EligID,
		mem.EligMemberSuffix AS Suffix,
		mem.FirstName AS F_Name,
		mem.LastName AS L_Name,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS DOB,
		act.Incentive_Activity_Name,
		CONVERT(VARCHAR(10),act.Activity_Date_Met,101) AS Activity_Date_Met
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK) 
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
	JOIN
		(
			-- CHOLESTEROL
			SELECT
				MemberID,
				'Met or improved Total Cholesterol' AS Incentive_Activity_Name,
				ScreeningDate_TWO AS Activity_Date_Met
			FROM
				(
				SELECT
					MemberID,
					ScreeningDate_TWO,
					ScreeningDate_ONE,
					Cholesterol_TWO,
					Cholesterol_ONE,
					100.0 *(Cholesterol_TWO - Cholesterol_ONE)/Cholesterol_ONE AS Change,
					CASE
						WHEN Cholesterol_TWO <= 239
						THEN 1
					END AS Met,
					CASE
						WHEN Cholesterol_TWO > 239 AND (100.0 *(Cholesterol_TWO - Cholesterol_ONE)/Cholesterol_ONE) <= -5 
						THEN 1
					END AS Improved
				FROM
					#Denorm
				WHERE
					Cholesterol_TWO IS NOT NULL
				) chl
			WHERE
				Met = 1 OR Improved = 1

			UNION 

			-- GLUCOSE
			SELECT 
				MemberID,
				'Met or improved Glucose' AS Incentive_Activity_Name,
				ScreeningDate_TWO AS Activity_Date_Met
			FROM
				(
				SELECT
					MemberID,
					ScreeningDate_TWO,
					ScreeningDate_ONE,
					IsFasting_TWO,
					IsFasting_ONE,
					Glucose_TWO,
					Glucose_ONE,
					CASE
						WHEN IsFasting_ONE = IsFasting_TWO
						THEN 100.0 * (Glucose_TWO - Glucose_ONE)/Glucose_ONE 
					END AS Change,
					CASE
						WHEN (IsFasting_TWO = 1 AND Glucose_TWO <= 109) OR (IsFasting_TWO = 0 AND Glucose_TWO <= 139)
						THEN 1
					END AS Met,
					CASE
						WHEN (IsFasting_ONE = IsFasting_TWO) AND 
							 ((IsFasting_TWO = 1 AND Glucose_TWO > 109) OR (IsFasting_TWO = 0 AND Glucose_TWO > 139)) AND
							 (100.0 * (Glucose_TWO - Glucose_ONE)/Glucose_ONE <= -5) 
						THEN 1
					END AS Improved
				FROM	
					#Denorm
				WHERE
					Glucose_TWO IS NOT NULL
				) glu
			WHERE
				Met = 1 OR Improved = 1

			UNION 

			-- BMI 
			SELECT
				MemberID,
				'Met or improved BMI or Waist Circumference' AS Incentive_Activity_Name,
				ScreeningDate_TWO AS Activity_Date_Met
			FROM
				(
				SELECT
					MemberID,
					Gender,
					ScreeningDate_TWO,
					ScreeningDate_ONE,
					Waist_TWO,
					Waist_ONE,
					Waist_TWO - Waist_ONE AS Change,
					CASE
						WHEN (Gender = 'M' AND Waist_TWO <= 40) OR (Gender = 'F' AND Waist_TWO <= 35)
						THEN 1
					END AS Met,
					CASE
						WHEN ((Gender = 'M' AND Waist_TWO > 40) OR (Gender = 'F' AND Waist_TWO > 35)) AND
							 (Waist_TWO - Waist_ONE <= -1)
						THEN 1
					END AS Improved
				FROM
					#Denorm
				WHERE
					Waist_TWO IS NOT NULL
				) wst
			WHERE
				Met = 1 OR Improved = 1

			UNION

			-- WAIST CIRCUMFERENCE
			SELECT 
				MemberID,
				'Met or improved BMI or Waist Circumference' AS Incentive_Activity_Name,
				ScreeningDate_TWO AS Activity_Date_Met
			FROM
				(
				SELECT
					MemberID,
					ScreeningDate_TWO,
					ScreeningDate_ONE,
					BMI_TWO,
					BMI_ONE,
					100.0 * (BMI_TWO - BMI_ONE)/BMI_ONE AS Change,
					CASE
						WHEN BMI_TWO <= 27.5
						THEN 1
					END AS Met,
					CASE
						WHEN (BMI_TWO > 27.5) AND
							 (100.0 * (BMI_TWO - BMI_ONE)/BMI_ONE <= -5)
						THEN 1
					END AS Improved
				FROM
					#Denorm
				WHERE
					BMI_TWO IS NOT NULL
				) bmi
			WHERE
				Met = 1 OR Improved = 1

			UNION 

			-- BLOOD PRESSURE
			SELECT
				MemberID,
				'Met or improved Blood Pressure' AS Incentive_Activity_Name,
				ScreeningDate_TWO AS Activity_Date_Met
			FROM
				(
				SELECT
					MemberID,
					ScreeningDate_TWO,
					ScreeningDate_ONE,
					Systolic_TWO,
					Systolic_ONE,
					Diastolic_TWO,
					Diastolic_ONE,
					100.0 * (Systolic_TWO - Systolic_ONE)/Systolic_ONE AS SystolicChange,
					100.0 * (Diastolic_TWO - Diastolic_ONE)/Diastolic_ONE AS DiastolicChange,
					CASE
						WHEN Systolic_TWO <= 139
						THEN 1
						ELSE 0
					END AS SystolicMet,
					CASE 
						WHEN (Systolic_TWO > 139) AND (100.0 * (Systolic_TWO - Systolic_ONE)/Systolic_ONE) <= -5 
						THEN 1
						ELSE 0
					END AS SystolicImproved,
					CASE
						WHEN Diastolic_TWO <= 89
						THEN 1
						ELSE 0 
					END AS DiastolicMet,
					CASE
						WHEN (Diastolic_TWO > 89) AND (100.0 * (Diastolic_TWO - Diastolic_ONE)/Diastolic_ONE) <= -5 
						THEN 1
						ELSE 0
					END AS DiastolicImproved
				FROM
					#Denorm
				WHERE
					Systolic_TWO IS NOT NULL AND
					Diastolic_TWO IS NOT NULL
				) bp
			GROUP BY
				MemberID,
				ScreeningDate_TWO
			HAVING
				SUM(SystolicMet + SystolicImproved + DiastolicMet + DiastolicImproved) = 2
		) act
		ON	(mem.MemberID = act.MemberID)
	ORDER BY
		EligID,
		Suffix,
		Incentive_Activity_Name
	
	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Biometrics') IS NOT NULL
	BEGIN
		DROP TABLE #Biometrics
	END

	IF OBJECT_ID('tempdb.dbo.#BioSeq') IS NOT NULL
	BEGIN
		DROP TABLE #BioSeq
	END

	IF OBJECT_ID('tempdb.dbo.#Denorm') IS NOT NULL
	BEGIN
		DROP TABLE #Denorm
	END

END

GO
