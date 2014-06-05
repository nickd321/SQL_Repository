SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-11-18
-- Description:	Premier Met or Improved Outcomes Report
-- =============================================


CREATE PROCEDURE [internal].[proc_Premier_ManualIncentiveFeed] 

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
		mem.Gender,
		scr.MemberScreeningID,
		scr.ScreeningDate,
		scr.SourceAddDate AS [LoadDate],
		scr.FileSource,
		CASE
			WHEN scr.ScreeningDate >= '2012-01-01' AND scr.ScreeningDate < '2013-01-01' THEN 'Time1'
			WHEN scr.ScreeningDate >= '2013-09-01' AND scr.ScreeningDate < '2013-12-03' THEN 'Time2'
		END AS [Time],
		scr.IsPregnant,
		scr.IsFasting,
		res.Systolic,
		res.Diastolic,
		res.Cholesterol,
		res.WaistCircumference,
		res.HDL
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
		mem.GroupID = 182533 AND
		(
			(scr.ScreeningDate >= '2012-01-01' AND scr.ScreeningDate < '2013-01-01') OR
			(scr.ScreeningDate >= '2013-09-01' AND scr.ScreeningDate < '2013-12-03')
		)


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
			WaistCircumference,
			HDL,
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
			WaistCircumference,
			HDL,
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
		bioTWO.WaistCircumference AS Waist_TWO,
		bioTWO.HDL AS HDL_TWO,
		-- SCREENING TIME 1
		bioONE.MemberScreeningID AS ScreeningID_ONE,
		bioONE.ScreeningDate AS ScreeningDate_ONE,
		bioONE.LoadDate AS LoadDate_ONE,
		bioONE.IsPregnant AS IsPregnant_ONE,
		bioONE.IsFasting AS IsFasting_ONE,
		bioONE.Systolic AS Systolic_ONE,
		bioONE.Diastolic AS Diastolic_ONE,
		bioONE.Cholesterol AS Cholesterol_ONE,
		bioONE.WaistCircumference AS Waist_ONE,
		bioONE.HDL AS HDL_ONE
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
		'PremierIncIncentiveFile' + CONVERT(VARCHAR(8),@RunDate,112) + '.xls' AS [File_Name],
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

			-- HDL
			SELECT
				MemberID,
				'Met or improved HDL Cholesterol' AS Incentive_Activity_Name,
				ScreeningDate_TWO AS Activity_Date_Met
			FROM
				(
				SELECT
					MemberID,
					ScreeningDate_TWO,
					ScreeningDate_ONE,
					HDL_TWO,
					HDL_ONE,
					HDL_TWO - HDL_ONE AS Change,
					CASE
						WHEN (Gender = 'M' AND HDL_TWO >= 40) OR (Gender = 'F' AND HDL_TWO >= 50)
						THEN 1
					END AS Met,
					CASE
						WHEN ((Gender = 'M' AND HDL_TWO < 40) OR (Gender = 'F' AND HDL_TWO < 50)) AND
							 ((HDL_TWO - HDL_ONE) >= 5)
						THEN 1
					END AS Improved
				FROM
					#Denorm
				WHERE
					HDL_TWO IS NOT NULL
				) hdl
			WHERE
				Met = 1 OR Improved = 1

			UNION ALL

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
					Cholesterol_TWO - Cholesterol_ONE AS Change,
					CASE
						WHEN Cholesterol_TWO <= 239
						THEN 1
					END AS Met,
					CASE
						WHEN Cholesterol_TWO > 239 AND ((Cholesterol_TWO - Cholesterol_ONE) <= -19)
						THEN 1
					END AS Improved
				FROM
					#Denorm
				WHERE
					Cholesterol_TWO IS NOT NULL
				) chl
			WHERE
				Met = 1 OR Improved = 1

			UNION ALL

			-- WAIST CIRCUMFERENCE 
			SELECT
				MemberID,
				'Met or improved Waist Circumference' AS Incentive_Activity_Name,
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
							 ((Waist_TWO - Waist_ONE) <= -2)
						THEN 1
					END AS Improved
				FROM
					#Denorm
				WHERE
					Waist_TWO IS NOT NULL
				) wst
			WHERE
				Met = 1 OR Improved = 1

			UNION ALL

			-- BLOOD PRESSURE
			-- SYSTOLIC
			SELECT
				MemberID,
				'Met or improved Systolic' AS Incentive_Activity_Name,
				ScreeningDate_TWO AS Activity_Date_Met
			FROM
				(
				SELECT
					MemberID,
					ScreeningDate_TWO,
					ScreeningDate_ONE,
					Systolic_TWO,
					Systolic_ONE,
					Systolic_TWO - Systolic_ONE AS Change,
					CASE
						WHEN Systolic_TWO <= 139
						THEN 1
					END AS Met,
					CASE 
						WHEN (Systolic_TWO > 139) AND ((Systolic_TWO - Systolic_ONE) <= -9)
						THEN 1
					END AS Improved
				FROM
					#Denorm
				WHERE
					Systolic_TWO IS NOT NULL 
				) bp_sys
			WHERE
				Met = 1 OR Improved = 1

			UNION ALL

			-- BLOOD PRESSURE
			-- DIASTOLIC
			SELECT
				MemberID,
				'Met or improved Diastolic' AS Incentive_Activity_Name,
				ScreeningDate_TWO AS Activity_Date_Met
			FROM
				(
				SELECT
					MemberID,
					ScreeningDate_TWO,
					ScreeningDate_ONE,
					Diastolic_TWO,
					Diastolic_ONE,
					Diastolic_TWO - Diastolic_ONE AS Change,
					CASE
						WHEN Diastolic_TWO <= 89
						THEN 1
					END AS Met,
					CASE
						WHEN (Diastolic_TWO > 89) AND ((Diastolic_TWO - Diastolic_ONE) <= -5)
						THEN 1
					END AS Improved
				FROM
					#Denorm
				WHERE
					Diastolic_TWO IS NOT NULL
				) bp_dia
			WHERE
				Met = 1 OR Improved = 1

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
