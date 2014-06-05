SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2014-04-10
-- Description:	Pepsico Cross Referral Report
--
-- Notes:		Description below taken from requirements document:
--
--				"The purpose of this report is to provide a file to Carewise, UHC/Optum, and 
--				Anthem on behalf of PepsiCo to indicate which members are participating in 
--				Healthyroads Lifestyle Management and/or Tobacco Cessation programs in order 
--				to enhance the user experience and/or help with appropriate referrals."
--
-- Updates:		WilliamPe 20140422
--				Modified Record Count Fixed Width logic to Pad Left with 0's
--
--				WilliamPe 20140530
--				There was a bug with the TobaccoCoachingLast logic.  This has been updated.
--				Went through the exercise of validating the definitions used for the BioLMStatus
--				and TobaccoCessationStatus. I went through the several combination/permutations
--				that could occur between five specific columns (last, sched, enroll, count, four). 
--				From there, I determined which combinations would actually occur given the the 
--				report logic and business logic. 
--
--              \\ashusers-vol2\dept2\DataAnalytics\SQL Server Management\HRLReports-2008\Databases\DA_Reports\Procedures\pepsico\Research\
--
--
-- =============================================

CREATE PROCEDURE [pepsico].[proc_CrossReferral]
	@inReportType INT
AS
BEGIN

	SET NOCOUNT ON;

	-- FOR TESTING
	--DECLARE @inReportType INT
	
	IF @inReportType <= 0 OR @inReportType > 3
	BEGIN
	RAISERROR (N'Please pass integers 1,2,3 for the @inReportType parameter. Parameters are @inReportType INT and @inEndDate DATETIME = NULL', -- Message text.
			   10, -- Severity,
			   1  -- State,
			   )
	END
	
	-- CLEAN UP

	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END

	IF OBJECT_ID('tempdb.dbo.#Waivers') IS NOT NULL
	BEGIN
		DROP TABLE #Waivers
	END
	
	IF OBJECT_ID('tempdb.dbo.#Appointment') IS NOT NULL
	BEGIN
		DROP TABLE #Appointment
	END
	
	IF OBJECT_ID('tempdb.dbo.#BioResults') IS NOT NULL
	BEGIN
		DROP TABLE #BioResults
	END
	
	IF OBJECT_ID('tempdb.dbo.#Outcomes') IS NOT NULL
	BEGIN
		DROP TABLE #Outcomes
	END
	
	IF OBJECT_ID('tempdb.dbo.#Activity') IS NOT NULL
	BEGIN
		DROP TABLE #Activity
	END
	
	IF OBJECT_ID('tempdb.dbo.#ActivityDenorm') IS NOT NULL
	BEGIN
		DROP TABLE #ActivityDenorm
	END
	
	IF OBJECT_ID('tempdb.dbo.#Final') IS NOT NULL
	BEGIN
		DROP TABLE #Final
	END


	IF @inReportType BETWEEN 1 AND 3
	BEGIN
	
		-- BASE TEMP
		SELECT
			*
		INTO
			#Base
		FROM
			(
			SELECT
				mem.MemberID,
				grp.GroupName,
				mem.EligMemberID,
				mem.EligMemberSuffix,
				mem.FirstName,
				mem.LastName,
				mem.RelationshipID,
				CASE
					mem.RelationshipID
					WHEN 1 THEN 'SP'
					WHEN 6 THEN 'EE'
					WHEN 2 THEN 'SD'
				END AS [Relationship],
				CONVERT(VARCHAR(8),mem.Birthdate,112) AS [DOB],
				mem.SubscriberSSN AS [SSN],
				mem.Gender,
				cs.CS1, -- SMOKER FLAG
				cs.CS2, -- TOBACCO SURCHARGE FLAG
				cs.CS3, -- ONLINE ELIGIBLE
				cs.CS4, -- COACHING ELIGIBLE
				cs.CS5, -- INCENTIVE ELIGIBLE
				cs.CS6, -- PAYOUT TYPE (AMEX OR HSA)
				cs.CS8, -- EXPAT STATUS
				cs.CS9, -- HEALTH PLAN
				PARSENAME(REPLACE(cs.CS9,'|','.'),2) AS CS9_LR_Pos1,
				PARSENAME(REPLACE(cs.CS9,'|','.'),1) AS CS9_LR_Pos2,
				cs.CS11, -- CWH Eligibility
				cs.CS13, -- DIVISION CODE
				cs.CS14, -- DIVISION CODE NAME
				cs.CS15, -- LOCATION NAME
				cs.CS16, -- LOCATION CODE
				CASE
					WHEN ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) 
					THEN 1 
					ELSE 0 
				END AS [IsCurrentlyEligible],
				CASE
					WHEN cs.CS8 = 'Y' 
					THEN 1 
					ELSE 0 
				END AS [IsExpat],
				elig.EffectiveDate,
				elig.TerminationDate
			FROM
				DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
			JOIN
				DA_Production.prod.Member mem WITH (NOLOCK)
				ON	(grp.GroupID = mem.GroupID)
				AND	(mem.GroupID = 206772)
			JOIN
				DA_Production.prod.CSFields cs WITH (NOLOCK)
				ON	(mem.MemberID = cs.MemberID)
			JOIN
				(
				SELECT
					MemberID,
					EffectiveDate,
					TerminationDate,
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
				FROM
					DA_Production.prod.Eligibility WITH (NOLOCK)
				WHERE
					GroupID = 206772
				) elig
				ON	(mem.MemberID = elig.MemberID)
				AND	(elig.RevTermSeq = 1)
			WHERE
				mem.RelationshipID IN (1,2,6)
			) data
		WHERE
			RTRIM(LTRIM(CS9_LR_Pos2)) IN ('Anthem BlueCross BlueShield','UnitedHealthcare') OR
			RTRIM(LTRIM(CS11)) = 'Y' AND
			IsCurrentlyEligible = 1

		-- WAIVERS TEMP
		SELECT
			mai.MemberID,
			mai.MemberActivityItemID,
			ISNULL(pa.AI_Name,pa.AI_Instruction) AS [AI_NameInstruction],
			pa.ActivityItemCode,
			mai.ActivityDate,
			mai.AddDate AS [SourceAddDate],
			mai.ModifiedDate,
			mai.RecordID,
			mai.ReferenceID,
			mai.IsWaiver
		INTO
			#Waivers
		FROM
			DA_Reports.incentives.[Plan] pln WITH (NOLOCK)
		JOIN
			DA_Reports.incentives.[PlanActivity] pa WITH (NOLOCK)
			ON	(pln.ClientIncentivePlanID = pa.ClientIncentivePlanID)
			AND	(pa.Expired = 0)
		JOIN
			Incentive.dbo.IC_ActivityItemReward air WITH (NOLOCK)
			ON	(pa.ActivityItemID = air.ActivityItemID)
			AND	(air.Deleted = 0)
		JOIN
			Incentive.dbo.IC_Reward rew WITH (NOLOCK)
			ON	(air.RewardID = rew.RewardID)
			AND	(rew.Deleted = 0)
		JOIN
			Incentive.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
			ON	(air.ActivityItemID = mai.ActivityItemID)
			AND	(pln.ClientIncentivePlanID = mai.ClientIncentivePlanID)
			AND	(mai.Deleted = 0)
		WHERE
			pln.Expired = 0 AND
			pln.ClientIncentivePlanID = 2 AND
			mai.IsWaiver = 1
			
		
		-- APPOINTMENT TEMP
		SELECT
			b.MemberID,
			app.AppointmentID,
			app.AppointmentStatusID,
			stat.StatusDesc AS [AppointmentStatusName],
			app.AppointmentTypeID,
			typ.Name AS [AppointmentTypeName],
			app.AppointmentStartTime,
			app.AddDate,
			app.ModifiedDate,
			app.CancelDate,
			ISNULL(enr.ProgramID,-1) AS [ProgramID],
			ISNULL(enr.ProgramName,-1) AS [ProgramName],
			enr.EnrollmentDate,
			enr.TerminationDate
		INTO
			#Appointment
		FROM
			#Base b
		JOIN
			HRMS.dbo.Appointment app WITH (NOLOCK)
			ON	(b.MemberID = app.MemberID)
			AND	(app.Deleted = 0)
		JOIN
			HRMS.dbo.AppointmentStatus stat WITH (NOLOCK)
			ON	(app.AppointmentStatusID = stat.AppointmentStatusID)
			AND	(stat.Deleted = 0)
		JOIN
			HRMS.dbo.AppointmentType typ WITH (NOLOCK)
			ON	(app.AppointmentTypeID = typ.AppointmentTypeID)
			AND	(typ.Deleted = 0)
		LEFT JOIN
			(
			SELECT
				b.MemberID,
				prg.ProgramID,
				prg.ProgramName,
				pe.EnrollmentDate,
				pe.TerminationDate
			FROM
				#Base b
			JOIN
				Benefits.dbo.ProgramEnrollment pe WITH (NOLOCK)
				ON	(b.MemberID = pe.MemberID)
				AND	(pe.Deleted = 0)
			JOIN
				Benefits.dbo.Program prg WITH (NOLOCK)
				ON	(pe.ProgramID = prg.ProgramID)
			) enr
			ON	(b.MemberID = enr.MemberID)
			AND	(app.AppointmentStartTime BETWEEN enr.EnrollmentDate AND ISNULL(CAST(enr.TerminationDate AS DATETIME),'2999-12-31'))
		WHERE
			app.AppointmentStartTime >= '2014-01-01' AND
			app.AppointmentStartTime < '2015-01-01'
		
		-- BIOMETRICS SCREENING AND RESULTS TEMP
		SELECT
			MemberID,
			MemberScreeningID,
			IsFasting,
			IsPregnant,
			ScreeningDate,
			SourceAddDate,
			Measure,
			MeasureValue
		INTO
			#BioResults
		FROM
			(	
			SELECT
				b.MemberID,
				scr.MemberScreeningID,
				scr.IsFasting,
				scr.IsPregnant,
				scr.ScreeningDate,
				scr.SourceAddDate,
				CAST(res.Systolic AS FLOAT) AS Systolic,
				CAST(res.Diastolic AS FLOAT) AS Diastolic,
				CAST(res.Cholesterol AS FLOAT) AS Cholesterol,
				CAST(res.Glucose AS FLOAT) AS Glucose,
				res.BMI
			FROM
				#Base b
			JOIN
				DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
				ON	(b.MemberID = scr.MemberID)
				AND (scr.ScreeningDate >= '2014-01-01')
				AND	(scr.ScreeningDate < '2015-01-01')
			JOIN
				DA_Production.prod.BiometricsScreeningResults res WITH (NOLOCK)
				ON	(scr.MemberScreeningID = res.MemberScreeningID)
			) data
			UNPIVOT
			(
			MeasureValue FOR Measure IN ([Systolic],[Diastolic],[Cholesterol],[Glucose],[BMI])
			) unpvt
		
		-- OUTCOMES TEMP
		SELECT
			MemberID,
			MemberScreeningID,
			IsFasting,
			ScreeningDate,
			SourceAddDate,
			Measure,
			MeasureValue,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY SourceAddDate) AS OutcomesSeq
		INTO
			#Outcomes
		FROM
			(
			SELECT
				MemberID,
				MemberScreeningID,
				IsFasting,
				ScreeningDate,
				SourceAddDate,
				Measure,
				CAST(MeasureValue AS VARCHAR(50)) AS MeasureValue,
				ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY SourceAddDate) AS MeasureSeq
			FROM
				#BioResults
			WHERE
				Measure = 'Glucose' AND
				(
					(IsFasting = 1 AND MeasureValue < 126) OR
					(IsFasting = 0 AND MeasureValue < 200)
				)
			
			UNION ALL
			
			SELECT
				MemberID,
				MemberScreeningID,
				IsFasting,
				ScreeningDate,
				SourceAddDate,
				Measure,
				CAST(MeasureValue AS VARCHAR(50)) AS MeasureValue,
				ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY SourceAddDate) AS MeasureSeq
			FROM
				#BioResults
			WHERE
				Measure = 'BMI' AND
				MeasureValue < 30
			
			UNION ALL
			
			SELECT
				MemberID,
				MemberScreeningID,
				IsFasting,
				ScreeningDate,
				SourceAddDate,
				Measure,
				CAST(MeasureValue AS VARCHAR(50)) AS MeasureValue,
				ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY SourceAddDate) AS MeasureSeq
			FROM
				#BioResults
			WHERE
				Measure = 'Cholesterol' AND
				MeasureValue < 240
			
			UNION ALL

			SELECT
				sysdiag.MemberID,
				sysdiag.MemberScreeningID,
				sysdiag.IsFasting,
				sysdiag.ScreeningDate,
				sysdiag.SourceAddDate,
				'BloodPressure' AS Measure,
				CAST(sysdiag.MeasureValue AS VARCHAR(50)) + '/' + CAST(diadiag.MeasureValue AS VARCHAR(50)) AS MeasureValue,
				ROW_NUMBER() OVER (PARTITION BY sysdiag.MemberID ORDER BY sysdiag.SourceAddDate) AS MeasureSeq
			FROM
				#BioResults sysdiag
			JOIN
				#BioResults diadiag
				ON	(sysdiag.MemberScreeningID = diadiag.MemberScreeningID)
				AND	(diadiag.Measure = 'Diastolic')
				AND	(diadiag.MeasureValue < 90)
			WHERE
				sysdiag.Measure = 'Systolic' AND
				sysdiag.MeasureValue < 140
			) outc
		WHERE
			MeasureSeq = 1
		
		SELECT
			*
		INTO
			#Activity
		FROM
			(
			-- PHA
			SELECT
				MemberID,
				'PHA' AS Activity,
				SourceName
				SourceID,
				ActivityDate,
				SourceAddDate,
				IsWaiver
			FROM
				(
				SELECT
					b.MemberID,
					'DA_Production.prod.HealthAssessment' AS SourceName,
					pha.MemberAssessmentID AS SourceID,
					pha.AssessmentCompleteDate AS ActivityDate,
					pha.SourceAddDate,
					NULL AS IsWaiver
				FROM
					#Base b
				JOIN
					DA_Production.prod.HealthAssessment pha WITH (NOLOCK)
					ON	(b.MemberID = pha.MemberID)
					AND	(pha.IsComplete = 1)
					AND	(pha.IsPrimarySurvey = 1)
					AND	(pha.AssessmentCompleteDate >= '2014-01-01')
					AND	(pha.AssessmentCompleteDate < '2015-01-01')
					
				UNION ALL
				
				SELECT
					MemberID,
					'Incentive.dbo.IC_MemberActivityItem' AS SourceName,
					MemberActivityItemID AS SourceID,
					ActivityDate,
					SourceAddDate,
					IsWaiver
				FROM
					#Waivers
				WHERE
					ActivityItemCode = 'PRIMARYPHA' AND
					IsWaiver = 1
				) pha
			
			UNION ALL
			
			-- BIO
			SELECT
				MemberID,
				'BIO' AS Activity,
				SourceName
				SourceID,
				ActivityDate,
				SourceAddDate,
				IsWaiver
			FROM
				(
				SELECT
					MemberID,
					'DA_Production.prod.BiometricsScreening' AS SourceName,
					MemberScreeningID AS SourceID,
					ScreeningDate AS ActivityDate,
					SourceAddDate,
					NULL AS IsWaiver	
				FROM
					#BioResults
				GROUP BY
					MemberID,
					MemberScreeningID,
					ScreeningDate,
					SourceAddDate
				
				UNION ALL
				
				SELECT
					MemberID,
					'Incentive.dbo.IC_MemberActivityItem' AS SourceName,
					MemberActivityItemID AS SourceID,
					ActivityDate,
					SourceAddDate,
					IsWaiver
				FROM
					#Waivers
				WHERE
					ActivityItemCode = 'BIOMETRICSCREENING' AND
					IsWaiver = 1
				) bio
			
			UNION ALL
			
			-- OUTCOMES
			SELECT
				MemberID,
				'OUTCOMES' AS Activity,
				SourceName
				SourceID,
				ActivityDate,
				SourceAddDate,
				IsWaiver
			FROM
				(
				SELECT
					MemberID,
					'DA_Production.prod.BiometricsScreeningResults' AS SourceName,
					MemberScreeningID AS SourceID,
					ScreeningDate AS ActivityDate,
					SourceAddDate,
					NULL AS IsWaiver
				FROM
					#Outcomes
				WHERE
					OutcomesSeq = 3

				UNION ALL
				
				SELECT
					MemberID,
					'Incentive.dbo.IC_MemberActivityItem' AS SourceName,
					MemberActivityItemID AS SourceID,
					ActivityDate,
					SourceAddDate,
					IsWaiver
				FROM
					#Waivers
				WHERE
					ActivityItemCode = 'BIOMETRICOUTCOMES' AND
					IsWaiver = 1		
				) outc
			
			UNION ALL
				
			-- COACHING
			SELECT
				MemberID,
				'COACHING' AS Activity,
				SourceName
				SourceID,
				ActivityDate,
				SourceAddDate,
				IsWaiver	
			FROM
				(
				SELECT
					MemberID,
					SourceName,
					SourceID,
					ActivityDate,
					SourceAddDate,
					NULL AS IsWaiver
				FROM
					(
					SELECT
						ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentStartTime) AS CoachSeq,
						MemberID,
						AppointmentID AS SourceID,
						'HRMS.dbo.Appointment' AS SourceName,
						AppointmentStartTime AS ActivityDate,
						AddDate AS SourceAddDate,
						ModifiedDate,
						CancelDate
					FROM
						#Appointment
					WHERE
						AppointmentStatusID = 4
					) cch
				WHERE
					CoachSeq = 4 
					
				UNION ALL
				
				SELECT
					MemberID,
					'Incentive.dbo.IC_MemberActivityItem' AS SourceName,
					MemberActivityItemID AS SourceID,
					ActivityDate,
					SourceAddDate,
					IsWaiver
				FROM
					#Waivers
				WHERE
					ActivityItemCode = 'LIFESTYLECOACHINGSESSIONS' AND
					IsWaiver = 1		
				) outc
			) data
			
		SELECT
			MemberID,
			[PHA],
			[BIO],
			[OUTCOMES],
			[COACHING],
			[LMCOACHINGSCHED],
			[LMCOACHINGLAST],
			[LMCOACHINGFOUR],
			[LMCOACHINGCOUNT],
			[LMCOACHINGENROLL],
			[TOBCOACHINGSCHED],
			[TOBCOACHINGLAST],
			[TOBCOACHINGFOUR],
			[TOBCOACHINGCOUNT],
			[TOBCOACHINGENROLL],
			[PREGNANT],
			[OUTREACH],
			[DECLINEUNABLE],
			[OUTREACHCOUNT]
		INTO
			#ActivityDenorm
		FROM
			(
			SELECT
				MemberID,
				Activity,
				CONVERT(VARCHAR(8),MIN(ActivityDate),112) AS ActivityValue
			FROM
				#Activity
			WHERE
				Activity = 'PHA'
			GROUP BY
				MemberID,
				Activity
			UNION ALL
			SELECT
				MemberID,
				Activity,
				CONVERT(VARCHAR(8),MAX(ActivityDate),112) AS ActivityValue
			FROM
				#Activity
			WHERE
				Activity = 'BIO'
			GROUP BY
				MemberID,
				Activity
			UNION ALL
			SELECT
				MemberID,
				Activity,
				CONVERT(VARCHAR(8),MIN(ActivityDate),112) AS ActivityValue
			FROM
				#Activity
			WHERE
				Activity = 'OUTCOMES'
			GROUP BY
				MemberID,
				Activity				
			UNION ALL
			SELECT
				MemberID,
				Activity,
				CONVERT(VARCHAR(8),MIN(ActivityDate),112) AS ActivityValue
			FROM
				#Activity
			WHERE
				Activity = 'COACHING'
			GROUP BY
				MemberID,
				Activity
			UNION ALL
			SELECT
				MemberID,
				'LMCOACHINGSCHED' AS Activity,
				CONVERT(VARCHAR(8),AppointmentStartTime,112) AS ActivityValue
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentStartTime) AS PendingSeq,
					MemberID,
					AppointmentStartTime,
					AppointmentStatusID,
					AppointmentStatusName,
					ProgramID,
					ProgramName
				FROM
					#Appointment
				WHERE
					AppointmentStatusID = 1 AND
					ProgramID <> 1 AND -- LIFESTYLE MANAGEMENT
					AppointmentStartTime >= DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)			
				) lm
			WHERE
				PendingSeq = 1
			UNION ALL
			SELECT
				MemberID,
				'LMCOACHINGLAST' AS Activity,
				CONVERT(VARCHAR(8),AppointmentStartTime,112) AS ActivityValue
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentStartTime DESC) AS RevCompleteSeq,
					MemberID,
					AppointmentStartTime,
					AppointmentStatusID,
					AppointmentStatusName,
					ProgramID,
					ProgramName
				FROM
					#Appointment
				WHERE
					AppointmentStatusID = 4 AND
					ProgramID <> 1 AND -- LIFESTYLE MANAGEMENT
					AppointmentStartTime < DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)			
				) lm
			WHERE
				RevCompleteSeq = 1
			UNION ALL
			SELECT
				MemberID,
				'LMCOACHINGFOUR' AS Activity,
				CONVERT(VARCHAR(8),AppointmentStartTime,112) AS ActivityValue
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentStartTime) AS CompleteSeq,
					MemberID,
					AppointmentStartTime,
					AppointmentStatusID,
					AppointmentStatusName,
					ProgramID,
					ProgramName
				FROM
					#Appointment
				WHERE
					AppointmentStatusID = 4 AND
					ProgramID <> 1 AND -- LIFESTYLE MANAGEMENT
					AppointmentStartTime < DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)			
				) lm
			WHERE
				CompleteSeq = 4
			UNION ALL
			SELECT
				MemberID,
				'LMCOACHINGCOUNT' AS Activity,
				CAST(CompleteCount AS VARCHAR(3)) AS ActivityValue
			FROM
				(
				SELECT
					MemberID,
					COUNT(AppointmentID) AS CompleteCount
				FROM
					#Appointment
				WHERE
					AppointmentStatusID = 4 AND
					ProgramID <> 1 AND -- LIFESTYLE MANAGEMENT
					AppointmentStartTime < DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)	
				GROUP BY
					MemberID	
				) lm
			UNION ALL
			SELECT
				MemberID,
				'LMCOACHINGENROLL' AS Activity,
				CONVERT(VARCHAR(8),EnrollmentDate,112) AS ActivityValue
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY b.MemberID ORDER BY pe.EnrollmentDate DESC) AS RevEnrollSeq,
					b.MemberID,
					prg.ProgramID,
					prg.ProgramName,
					pe.EnrollmentDate,
					pe.TerminationDate
				FROM
					#Base b
				JOIN
					Benefits.dbo.ProgramEnrollment pe WITH (NOLOCK)
					ON	(b.MemberID = pe.MemberID)
					AND	(pe.Deleted = 0)
				JOIN
					Benefits.dbo.Program prg WITH (NOLOCK)
					ON	(pe.ProgramID = prg.ProgramID)
				WHERE
					prg.ProgramID <> 1 AND -- LIFESTYLE MANAGEMENT
					pe.TerminationDate IS NULL
				) lm
			WHERE
				RevEnrollSeq = 1
			UNION ALL
			SELECT
				MemberID,
				'TOBCOACHINGSCHED' AS Activity,
				CONVERT(VARCHAR(8),AppointmentStartTime,112) AS ActivityValue
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentStartTime) AS PendingSeq,
					MemberID,
					AppointmentStartTime,
					AppointmentStatusID,
					AppointmentStatusName,
					ProgramID,
					ProgramName
				FROM
					#Appointment
				WHERE
					AppointmentStatusID = 1 AND
					ProgramID = 1 AND -- TOBACCO CESSATION
					AppointmentStartTime >= DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)			
				) tob
			WHERE
				PendingSeq = 1
			UNION ALL
			SELECT
				MemberID,
				'TOBCOACHINGLAST' AS Activity,
				CONVERT(VARCHAR(8),AppointmentStartTime,112) AS ActivityValue
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentStartTime DESC) AS RevCompleteSeq,
					MemberID,
					AppointmentStartTime,
					AppointmentStatusID,
					AppointmentStatusName,
					ProgramID,
					ProgramName
				FROM
					#Appointment
				WHERE
					AppointmentStatusID = 4 AND
					ProgramID = 1 AND -- TOBACCO CESSATION
					AppointmentStartTime < DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)			
				) tob
			WHERE
				RevCompleteSeq = 1
			UNION ALL
			SELECT
				MemberID,
				'TOBCOACHINGFOUR' AS Activity,
				CONVERT(VARCHAR(8),AppointmentStartTime,112) AS ActivityValue
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentStartTime) AS CompleteSeq,
					MemberID,
					AppointmentStartTime,
					AppointmentStatusID,
					AppointmentStatusName,
					ProgramID,
					ProgramName
				FROM
					#Appointment
				WHERE
					AppointmentStatusID = 4 AND
					ProgramID = 1 AND -- TOBACCO CESSATION
					AppointmentStartTime < DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)			
				) tob
			WHERE
				CompleteSeq = 4
			UNION ALL
			SELECT
				MemberID,
				'TOBCOACHINGCOUNT' AS Activity,
				CAST(CompleteCount AS VARCHAR(3)) AS ActivityValue
			FROM
				(
				SELECT
					MemberID,
					COUNT(AppointmentID) AS CompleteCount
				FROM
					#Appointment
				WHERE
					AppointmentStatusID = 4 AND
					ProgramID = 1 AND -- TOBACCO CESSATION
					AppointmentStartTime < DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)	
				GROUP BY
					MemberID	
				) tob
			UNION ALL
			SELECT
				MemberID,
				'TOBCOACHINGENROLL' AS Activity,
				CONVERT(VARCHAR(8),EnrollmentDate,112) AS ActivityValue
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY b.MemberID ORDER BY pe.EnrollmentDate DESC) AS RevEnrollSeq,
					b.MemberID,
					prg.ProgramID,
					prg.ProgramName,
					pe.EnrollmentDate,
					pe.TerminationDate
				FROM
					#Base b
				JOIN
					Benefits.dbo.ProgramEnrollment pe WITH (NOLOCK)
					ON	(b.MemberID = pe.MemberID)
					AND	(pe.Deleted = 0)
				JOIN
					Benefits.dbo.Program prg WITH (NOLOCK)
					ON	(pe.ProgramID = prg.ProgramID)
				WHERE
					prg.ProgramID = 1 AND -- TOBACCO CESSATION
					pe.TerminationDate IS NULL
				) tob
			WHERE
				RevEnrollSeq = 1
			UNION ALL
			SELECT
				MemberID,
				'PREGNANT' AS Activity,
				CAST(IsPregnant AS VARCHAR(3)) AS ActivityValue
			FROM
				(
				SELECT 
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ScreeningDate DESC) AS RevBioSeq,
					MemberID,
					ScreeningDate,
					SourceAddDate,
					IsPregnant
				FROM
					#BioResults
				GROUP BY
					MemberID,
					ScreeningDate,
					SourceAddDate,
					IsPregnant
				) preg
			WHERE
				preg.RevBioSeq = 1	
			UNION ALL
			SELECT
				MemberID,
				'OUTREACH' AS Activity,
				CONVERT(VARCHAR(8),LastActionDate,112) AS ActivityValue 
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY cmp.MemberID ORDER BY cmp.SourceAddDate DESC) AS RevAddDate,
					cmp.MemberID,
					cmp.CompletedDate,
					cmp.LastActionDate,
					cmp.SourceAddDate,
					cmp.OutreachCompleteResultID,
					cmp.OutreachCompleteResultName,
					cmp.LastActionResultID,
					cmp.LastActionResultName	
				FROM
					#Base b
				JOIN
					DA_Production.prod.OutreachCampaign cmp WITH (NOLOCK)
					ON	(b.MemberID = cmp.MemberID)
				WHERE
					cmp.GroupCampaignName = 'Biometric - Values Not Met' AND
					cmp.SourceAddDate < DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)
				) inout
			WHERE
				RevAddDate = 1 AND
				CompletedDate IS NULL
			UNION ALL
			SELECT
				MemberID,
				'DECLINEUNABLE' AS Activity,
				CONVERT(VARCHAR(8),LastActionDate,112) AS ActivityValue 
			FROM
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY cmp.MemberID ORDER BY cmp.SourceAddDate DESC) AS RevAddDate,
					cmp.MemberID,
					cmp.CompletedDate,
					cmp.LastActionDate,
					cmp.SourceAddDate,
					cmp.OutreachCompleteResultID,
					cmp.OutreachCompleteResultName,
					cmp.LastActionResultID,
					cmp.LastActionResultName	
				FROM
					#Base b
				JOIN
					DA_Production.prod.OutreachCampaign cmp WITH (NOLOCK)
					ON	(b.MemberID = cmp.MemberID)
				WHERE
					cmp.GroupCampaignName = 'Biometric - Values Not Met' AND 
					cmp.SourceAddDate < DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) 
				) una
			WHERE
				RevAddDate = 1 AND
				CompletedDate IS NOT NULL AND
				(
					OutreachCompleteResultName = 'Unable to Reach' OR
					(OutreachCompleteResultName = 'Reached' AND LastActionResultName = 'Not Interested')
				)
			UNION ALL
			SELECT
				MemberID,
				'OUTREACHCOUNT' AS Activity,
				CAST(OutreachCount AS VARCHAR(3)) AS ActivityValue 
			FROM
				(
				SELECT
					cmp.MemberID,
					COUNT(cmp.MemberID) AS OutreachCount
				FROM
					#Base b
				JOIN
					DA_Production.prod.OutreachCampaign cmp WITH (NOLOCK)
					ON	(b.MemberID = cmp.MemberID)
				WHERE
					cmp.GroupCampaignName = 'Biometric - Values Not Met' AND
					cmp.SourceAddDate < DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)
				GROUP BY
					cmp.MemberID
				) outc
			) data
			PIVOT
			(
			MAX(ActivityValue) FOR Activity IN (
												[PHA],
												[BIO],
												[OUTCOMES],
												[COACHING],
												[LMCOACHINGSCHED],
												[LMCOACHINGLAST],
												[LMCOACHINGFOUR],
												[LMCOACHINGCOUNT],
												[LMCOACHINGENROLL],
												[TOBCOACHINGSCHED],
												[TOBCOACHINGLAST],
												[TOBCOACHINGFOUR],
												[TOBCOACHINGCOUNT],
												[TOBCOACHINGENROLL],
												[PREGNANT],
												[OUTREACH],
												[DECLINEUNABLE],
												[OUTREACHCOUNT]
												)
			) pvt


		SELECT
			b.MemberID,
			b.EligMemberID,
			b.SSN,
			b.FirstName,
			b.LastName,
			b.DOB,
			b.Relationship,
			b.Gender,
			b.CS1,
			b.CS2,
			b.CS5,
			b.CS9,
			b.CS9_LR_Pos2,
			b.CS11,
			act.PHA AS [PHACompletionDate],
			act.BIO AS [BioCompletionDate],
			CASE WHEN CS5 = 'Y' THEN 'Yes' ELSE 'No' END AS [LMIncentiveEligible],
			CASE
				WHEN CS5 != 'Y' THEN 'N/A'
				WHEN CS5 = 'Y' AND 
					(
						act.BIO IS NOT NULL AND
						(act.OUTCOMES IS NOT NULL OR act.COACHING IS NOT NULL)
					) THEN 'Yes'
				ELSE 'No'
			END AS [LMIncentiveMet],
			/* 
			   Permutations that could occur between five specific columns (1 = True column populated with data; 0 = False) for the LMCoaching. 
			   One should note that the production system looks like it allows members to have pending appointments without an active program.
			   Therefore, I am defining 'enrolled' differently for the BioLMStatus.  Meaning, the tobacco status below is not considering the TobSched column
			   when determing if the member is currently enrolled since there must be a tobacco program enrollment associated to an appointment.
			   
				LMSched | LMLast | LMFour | LMCount | LMEnroll
				1)  0|1|1|1|0 = COMPLETE
				2)  0|1|0|1|0 = DISENROLLED/TERMINATED
				3)  0|0|0|0|1 = ENROLLED
				4)  0|1|0|1|1 = ENROLLED
				5)  0|1|1|1|1 = ENROLLED
				6)  1|0|0|0|1 = ENROLLED
				7)  1|1|0|1|1 = ENROLLED
				8)  1|1|1|1|1 = ENROLLED
				9)  1|1|1|1|0 = ENROLLED
				10) 1|1|0|1|0 = ENROLLED
			*/		
			CASE
				WHEN act.LMCOACHINGENROLL IS NOT NULL OR 
				     (act.LMCOACHINGSCHED IS NOT NULL AND act.LMCOACHINGLAST IS NOT NULL AND act.LMCOACHINGENROLL IS NULL) THEN 'ENROLLED'
				WHEN act.LMCOACHINGFOUR IS NOT NULL AND LMCOACHINGSCHED IS NULL AND LMCOACHINGENROLL IS NULL THEN 'COMPLETE'
				WHEN act.LMCOACHINGCOUNT IS NOT NULL AND 
				     act.LMCOACHINGFOUR IS NULL AND 
				     (act.LMCOACHINGENROLL IS NOT NULL OR (act.LMCOACHINGSCHED IS NOT NULL AND act.LMCOACHINGLAST IS NOT NULL AND act.LMCOACHINGENROLL IS NULL)) THEN 'DISENROLLED/TERMINATED'
				WHEN act.OUTREACH IS NOT NULL THEN 'OUTREACH'
				WHEN act.DECLINEUNABLE IS NOT NULL THEN 'DECLINED/UNABLE TO REACH'
				WHEN act.OUTREACHCOUNT IS NULL THEN 'NO CONTACT'
				ELSE 'NO CONTACT'			
			END AS [BioLMStatus],
			CASE
				WHEN act.LMCOACHINGENROLL IS NOT NULL OR 
				     (act.LMCOACHINGSCHED IS NOT NULL AND act.LMCOACHINGLAST IS NOT NULL AND act.LMCOACHINGENROLL IS NULL)
				THEN CONVERT(VARCHAR(8),DA_Reports.dbo.func_MAX_DATETIME(act.LMCOACHINGLAST,act.LMCOACHINGENROLL),112)
				WHEN act.LMCOACHINGFOUR IS NOT NULL AND LMCOACHINGSCHED IS NULL AND LMCOACHINGENROLL IS NULL
				THEN CONVERT(VARCHAR(8),DA_Reports.dbo.func_MAX_DATETIME(act.LMCOACHINGFOUR,act.LMCOACHINGLAST),112)
				WHEN act.LMCOACHINGCOUNT IS NOT NULL AND 
				     act.LMCOACHINGFOUR IS NULL AND 
				     (act.LMCOACHINGENROLL IS NOT NULL OR (act.LMCOACHINGSCHED IS NOT NULL AND act.LMCOACHINGLAST IS NOT NULL AND act.LMCOACHINGENROLL IS NULL)) 
				THEN act.LMCOACHINGLAST
				WHEN act.OUTREACH IS NOT NULL THEN act.OUTREACH
				WHEN act.DECLINEUNABLE IS NOT NULL THEN act.DECLINEUNABLE
			END AS [BioLMStatusDate],
			CASE
				WHEN ISNULL(CS2,'') != 'Y' THEN 'N/A'
				WHEN (CS2 = 'Y' AND CS1 = 'N') OR (CS2 = 'Y' AND act.TOBCOACHINGFOUR IS NOT NULL) THEN 'No'
				WHEN CS2 = 'Y' AND CS1 = 'Y' AND act.TOBCOACHINGFOUR IS NULL THEN 'Yes'
			END AS [TobaccoSurchargeApplied],
			/* 
			    Permutations that could occur between five specific columns (1 = True column populated with data; 0 = False) for the Tobacco measures
			    The tobacco status logic is not using the TobSched column when determing if the member is currently enrolled since there must be a 
			    tobacco program enrollment associated to an appointment.
			    
				TobSched | TobLast | TobFour | TobCount | TobEnroll
				1) 0|1|1|1|0 = COMPLETE
				2) 0|1|0|1|0 = DISENROLLED/TERMINATED
				3) 0|0|0|0|1 = ENROLLED
				4) 0|1|0|1|1 = ENROLLED
				5) 0|1|1|1|1 = ENROLLED
				6) 1|0|0|0|1 = ENROLLED
				7) 1|1|0|1|1 = ENROLLED
				8) 1|1|1|1|1 = ENROLLED
                9) 0|0|0|0|0 = NO CONTACT
			*/				
			CASE
				WHEN act.TOBCOACHINGENROLL IS NOT NULL THEN 'ENROLLED'
				WHEN act.TOBCOACHINGFOUR IS NOT NULL AND act.TOBCOACHINGENROLL IS NULL THEN 'COMPLETE'
				WHEN act.TOBCOACHINGCOUNT IS NOT NULL AND act.TOBCOACHINGFOUR IS NULL AND TOBCOACHINGENROLL IS NULL THEN 'DISENROLLED/TERMINATED'
				ELSE 'NO CONTACT'
			END AS [TobaccoCessationStatus],
			CASE
				WHEN act.TOBCOACHINGENROLL IS NOT NULL
				THEN CONVERT(VARCHAR(8),DA_Reports.dbo.func_MAX_DATETIME(act.TOBCOACHINGLAST,act.TOBCOACHINGENROLL),112)
				WHEN act.TOBCOACHINGFOUR IS NOT NULL AND act.TOBCOACHINGENROLL IS NULL
				THEN CONVERT(VARCHAR(8),DA_Reports.dbo.func_MAX_DATETIME(act.TOBCOACHINGFOUR,act.TOBCOACHINGLAST),112)
				WHEN act.TOBCOACHINGCOUNT IS NOT NULL AND act.TOBCOACHINGFOUR IS NULL AND TOBCOACHINGENROLL IS NULL THEN act.TOBCOACHINGLAST
			END AS [TobaccoCessationStatusDate],
			act.PREGNANT AS [PregnancyIndicator],
			act.OUTCOMES,
			act.COACHING,
			act.LMCOACHINGSCHED,
			act.LMCOACHINGLAST,
			act.LMCOACHINGFOUR,
			act.LMCOACHINGCOUNT,
			act.LMCOACHINGENROLL,
			act.TOBCOACHINGSCHED,
			act.TOBCOACHINGLAST,
			act.TOBCOACHINGFOUR,
			act.TOBCOACHINGCOUNT,	
			act.TOBCOACHINGENROLL,
			act.OUTREACH,
			act.DECLINEUNABLE,
			act.OUTREACHCOUNT	
		INTO
			#Final
		FROM
			#Base b
		JOIN
			#ActivityDenorm act
			ON	(b.MemberID = act.MemberID)

		DECLARE
			@RecordCount VARCHAR(10),
			@CreationDate VARCHAR(8)

		IF @inReportType = 1
		BEGIN	
		
			DELETE DA_Reports.pepsico.CrossReferral_ReportLog
			WHERE
				DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
				DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE()) AND
				ReportedTo = 'CAREWISE'
		

			INSERT INTO DA_Reports.pepsico.CrossReferral_ReportLog
			SELECT
				fin.MemberID,
				fin.EligMemberID,
				fin.CS1,
				fin.CS2,
				fin.CS5,
				fin.CS9,
				fin.CS11,
				fin.PHACompletionDate,
				fin.BioCompletionDate,
				fin.LMIncentiveEligible,
				fin.LMIncentiveMet,
				fin.BioLMStatus,
				fin.BioLMStatusDate,
				fin.TobaccoSurchargeApplied,
				fin.TobaccoCessationStatus,
				fin.TobaccoCessationStatusDate,
				fin.PregnancyIndicator,
				GETDATE() AS [DateReported],
				'CAREWISE' AS [ReportedTo],
				GETDATE() AS [AddedDate],
				SUSER_SNAME() AS [AddedBy],
				NULL AS [ModifiedDate],
				NULL AS [ModifiedBy],
				NULL AS [Notes],
				0 AS [Rerun],
				fin.OUTCOMES,
				fin.COACHING,
				fin.LMCOACHINGSCHED,
				fin.LMCOACHINGLAST,
				fin.LMCOACHINGFOUR,
				fin.LMCOACHINGCOUNT,
				fin.LMCOACHINGENROLL,
				fin.TOBCOACHINGSCHED,
				fin.TOBCOACHINGLAST,
				fin.TOBCOACHINGFOUR,
				fin.TOBCOACHINGCOUNT,	
				fin.TOBCOACHINGENROLL,
				fin.OUTREACH,
				fin.DECLINEUNABLE,
				fin.OUTREACHCOUNT	
			FROM
				#Final fin
			LEFT JOIN
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY DateReported DESC, ReportLogID DESC) AS RevReportedSeq,
					MemberID,
					PHACompletionDate,
					BioCompletionDate,
					LMIncentiveEligible,
					LMIncentiveMet,
					BioLMStatus,
					TobaccoSurchargeApplied,
					TobaccoCessationStatus,
					TobaccoCessationStatusDate,
					PregnancyIndicator,
					DateReported
				FROM
					DA_Reports.pepsico.CrossReferral_ReportLog lg
				WHERE
					Rerun = 0 AND
					ReportedTo = 'CAREWISE'
				) lg
				ON	(lg.MemberID = fin.MemberID)
				AND	(RevReportedSeq = 1)
			WHERE
				fin.CS11 = 'Y' AND
				(
					(ISNULL(fin.PHACompletionDate,'29991231') != ISNULL(lg.PHACompletionDate,'29991231')) OR
					(ISNULL(fin.BioCompletionDate,'29991231') != ISNULL(lg.BioCompletionDate,'29991231')) OR
					(fin.LMIncentiveEligible != ISNULL(lg.LMIncentiveEligible,'-1')) OR
					(fin.LMIncentiveMet != ISNULL(lg.LMIncentiveMet,'-1')) OR
					(fin.BioLMStatus != ISNULL(lg.BioLMStatus,'-1')) OR
					(fin.TobaccoSurchargeApplied != ISNULL(lg.TobaccoSurchargeApplied,'-1')) OR
					(fin.TobaccoCessationStatus != ISNULL(lg.TobaccoCessationStatus,'-1')) OR
					(ISNULL(fin.PregnancyIndicator,-1) != ISNULL(lg.PregnancyIndicator,-1))
				)

			SET
				@RecordCount =
								(
									SELECT 
										COUNT(fin.MemberID) 
									FROM
										#Final fin
									JOIN
										DA_Reports.pepsico.CrossReferral_ReportLog lg
										ON	(fin.MemberID = lg.MemberID)
										AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
										AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
										AND	(lg.ReportedTo = 'CAREWISE')
									WHERE
										lg.Rerun = 0
								)
			SET
				@CreationDate = CONVERT(VARCHAR(8),GETDATE(),112)
				
			SELECT
				[H1],
				[H2],
				[H3],
				[H4],
				[H5],
				[H6],
				[H7],
				[H8],
				[H9],
				[H10],
				[H11],
				[H12],
				[H13],
				[H14],
				[H15],
				[H16]
			FROM
				(
				SELECT
					'10900' + 'HRDS' + @CreationDate + (SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_LEFT('0',6,@RecordCount)) AS [H1],
					'' AS [H2],
					'' AS [H3],
					'' AS [H4],
					'' AS [H5],
					'' AS [H6],
					'' AS [H7],
					'' AS [H8],
					'' AS [H9],
					'' AS [H10],
					'' AS [H11],
					'' AS [H12],
					'' AS [H13],
					'' AS [H14],
					'' AS [H15],
					'' AS [H16],
					1 AS [Seq]
					
				UNION ALL
				
				SELECT
					fin.EligMemberID AS [D1],
					fin.FirstName AS [D2],
					fin.LastName AS [D3],
					fin.DOB AS [D4],
					fin.Relationship AS [D5],
					fin.Gender AS [D6],
					ISNULL(fin.PHACompletionDate,'') AS [D7],
					ISNULL(fin.BioCompletionDate,'') AS [D8],
					fin.LMIncentiveEligible AS [D9],
					fin.LMIncentiveMet AS [D10],
					fin.BioLMStatus AS [D11],
					ISNULL(fin.BioLMStatusDate,'') AS [D12],
					fin.TobaccoSurchargeApplied AS [D13],
					fin.TobaccoCessationStatus AS [D14],
					ISNULL(fin.TobaccoCessationStatusDate,'') AS [D15],
					ISNULL(fin.PregnancyIndicator,'') AS [D16],
					2 AS [Seq]
				FROM
					#Final fin
				JOIN
					DA_Reports.pepsico.CrossReferral_ReportLog lg
					ON	(fin.MemberID = lg.MemberID)
					AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
					AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
					AND	(lg.ReportedTo = 'CAREWISE')
					AND	(lg.Rerun = 0)
				) data
			ORDER BY
				Seq
		
		END
		
		IF @inReportType = 2
		BEGIN	

			DELETE DA_Reports.pepsico.CrossReferral_ReportLog
			WHERE
				DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
				DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE()) AND
				ReportedTo = 'ANTHEM'
				
			INSERT INTO DA_Reports.pepsico.CrossReferral_ReportLog
			SELECT
				fin.MemberID,
				fin.EligMemberID,
				fin.CS1,
				fin.CS2,
				fin.CS5,
				fin.CS9,
				fin.CS11,
				fin.PHACompletionDate,
				fin.BioCompletionDate,
				fin.LMIncentiveEligible,
				fin.LMIncentiveMet,
				fin.BioLMStatus,
				fin.BioLMStatusDate,
				fin.TobaccoSurchargeApplied,
				fin.TobaccoCessationStatus,
				fin.TobaccoCessationStatusDate,
				fin.PregnancyIndicator,
				GETDATE() AS [DateReported],
				'ANTHEM' AS [ReportedTo],
				GETDATE() AS [AddedDate],
				SUSER_SNAME() AS [AddedBy],
				NULL AS [ModifiedDate],
				NULL AS [ModifiedBy],
				NULL AS [Notes],
				0 AS [Rerun],
				fin.OUTCOMES,
				fin.COACHING,
				fin.LMCOACHINGSCHED,
				fin.LMCOACHINGLAST,
				fin.LMCOACHINGFOUR,
				fin.LMCOACHINGCOUNT,
				fin.LMCOACHINGENROLL,
				fin.TOBCOACHINGSCHED,
				fin.TOBCOACHINGLAST,
				fin.TOBCOACHINGFOUR,
				fin.TOBCOACHINGCOUNT,	
				fin.TOBCOACHINGENROLL,
				fin.OUTREACH,
				fin.DECLINEUNABLE,
				fin.OUTREACHCOUNT	
			FROM
				#Final fin
			LEFT JOIN
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY DateReported DESC, ReportLogID DESC) AS RevReportedSeq,
					MemberID,
					PHACompletionDate,
					BioCompletionDate,
					LMIncentiveEligible,
					LMIncentiveMet,
					BioLMStatus,
					TobaccoSurchargeApplied,
					TobaccoCessationStatus,
					TobaccoCessationStatusDate,
					PregnancyIndicator
				FROM
					DA_Reports.pepsico.CrossReferral_ReportLog lg
				WHERE
					Rerun = 0 AND
					ReportedTo = 'ANTHEM'
				) lg
				ON	(lg.MemberID = fin.MemberID)
				AND	(RevReportedSeq = 1)
			WHERE
				fin.CS9_LR_Pos2 = 'Anthem BlueCross BlueShield' AND
				(
					(ISNULL(fin.PHACompletionDate,'29991231') != ISNULL(lg.PHACompletionDate,'29991231')) OR
					(ISNULL(fin.BioCompletionDate,'29991231') != ISNULL(lg.BioCompletionDate,'29991231')) OR
					(fin.LMIncentiveEligible != ISNULL(lg.LMIncentiveEligible,'-1')) OR
					(fin.LMIncentiveMet != ISNULL(lg.LMIncentiveMet,'-1')) OR
					(fin.BioLMStatus != ISNULL(lg.BioLMStatus,'-1')) OR
					(fin.TobaccoSurchargeApplied != ISNULL(lg.TobaccoSurchargeApplied,'-1')) OR
					(fin.TobaccoCessationStatus != ISNULL(lg.TobaccoCessationStatus,'-1')) OR
					(ISNULL(fin.PregnancyIndicator,-1) != ISNULL(lg.PregnancyIndicator,-1))
				)

			SET
				@RecordCount =
								(
									SELECT 
										COUNT(fin.MemberID) 
									FROM
										#Final fin
									JOIN
										DA_Reports.pepsico.CrossReferral_ReportLog lg
										ON	(fin.MemberID = lg.MemberID)
										AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
										AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
										AND	(lg.ReportedTo = 'ANTHEM')
									WHERE
										lg.Rerun = 0
								)
			SET
				@CreationDate = CONVERT(VARCHAR(8),GETDATE(),112)
				
			SELECT
				[H1],
				[H2],
				[H3],
				[H4],
				[H5],
				[H6],
				[H7],
				[H8],
				[H9],
				[H10],
				[H11],
				[H12],
				[H13],
				[H14],
				[H15],
				[H16],
				[H17]
			FROM
				(
				SELECT
					'10900' + 'HRDS' + @CreationDate + (SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_LEFT('0',6,@RecordCount)) AS [H1],
					'' AS [H2],
					'' AS [H3],
					'' AS [H4],
					'' AS [H5],
					'' AS [H6],
					'' AS [H7],
					'' AS [H8],
					'' AS [H9],
					'' AS [H10],
					'' AS [H11],
					'' AS [H12],
					'' AS [H13],
					'' AS [H14],
					'' AS [H15],
					'' AS [H16],
					'' AS [H17],
					1 AS [Seq]
					
				UNION ALL
				
				SELECT
					fin.EligMemberID AS [D1],
					fin.SSN AS [D2],
					fin.FirstName AS [D3],
					fin.LastName AS [D4],
					fin.DOB AS [D5],
					fin.Relationship AS [D6],
					fin.Gender AS [D7],
					ISNULL(fin.PHACompletionDate,'') AS [D8],
					ISNULL(fin.BioCompletionDate,'') AS [D9],
					fin.LMIncentiveEligible AS [D10],
					fin.LMIncentiveMet AS [D11],
					fin.BioLMStatus AS [D12],
					ISNULL(fin.BioLMStatusDate,'') AS [D13],
					fin.TobaccoSurchargeApplied AS [D14],
					fin.TobaccoCessationStatus AS [D15],
					ISNULL(fin.TobaccoCessationStatusDate,'') AS [D16],
					ISNULL(fin.PregnancyIndicator,'') AS [D17],
					2 AS [Seq]
				FROM
					#Final fin
				JOIN
					DA_Reports.pepsico.CrossReferral_ReportLog lg
					ON	(fin.MemberID = lg.MemberID)
					AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
					AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
					AND	(lg.ReportedTo = 'ANTHEM')
					AND	(lg.Rerun = 0)
				) data
			ORDER BY
				Seq
		
		END

		IF @inReportType = 3
		BEGIN	

			DELETE DA_Reports.pepsico.CrossReferral_ReportLog
			WHERE
				DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
				DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE()) AND
				ReportedTo = 'UHC_OPTUM'
				
			INSERT INTO DA_Reports.pepsico.CrossReferral_ReportLog
			SELECT
				fin.MemberID,
				fin.EligMemberID,
				fin.CS1,
				fin.CS2,
				fin.CS5,
				fin.CS9,
				fin.CS11,
				fin.PHACompletionDate,
				fin.BioCompletionDate,
				fin.LMIncentiveEligible,
				fin.LMIncentiveMet,
				fin.BioLMStatus,
				fin.BioLMStatusDate,
				fin.TobaccoSurchargeApplied,
				fin.TobaccoCessationStatus,
				fin.TobaccoCessationStatusDate,
				fin.PregnancyIndicator,
				GETDATE() AS [DateReported],
				'UHC_OPTUM' AS [ReportedTo],
				GETDATE() AS [AddedDate],
				SUSER_SNAME() AS [AddedBy],
				NULL AS [ModifiedDate],
				NULL AS [ModifiedBy],
				NULL AS [Notes],
				0 AS [Rerun],
				fin.OUTCOMES,
				fin.COACHING,
				fin.LMCOACHINGSCHED,
				fin.LMCOACHINGLAST,
				fin.LMCOACHINGFOUR,
				fin.LMCOACHINGCOUNT,
				fin.LMCOACHINGENROLL,
				fin.TOBCOACHINGSCHED,
				fin.TOBCOACHINGLAST,
				fin.TOBCOACHINGFOUR,
				fin.TOBCOACHINGCOUNT,	
				fin.TOBCOACHINGENROLL,
				fin.OUTREACH,
				fin.DECLINEUNABLE,
				fin.OUTREACHCOUNT	
			FROM
				#Final fin
			LEFT JOIN
				(
				SELECT
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY DateReported DESC, ReportLogID DESC) AS RevReportedSeq,
					MemberID,
					PHACompletionDate,
					BioCompletionDate,
					LMIncentiveEligible,
					LMIncentiveMet,
					BioLMStatus,
					TobaccoSurchargeApplied,
					TobaccoCessationStatus,
					TobaccoCessationStatusDate,
					PregnancyIndicator
				FROM
					DA_Reports.pepsico.CrossReferral_ReportLog lg
				WHERE
					Rerun = 0 AND
					ReportedTo = 'UHC_OPTUM'
				) lg
				ON	(lg.MemberID = fin.MemberID)
				AND	(RevReportedSeq = 1)
			WHERE
				fin.CS9_LR_Pos2 = 'UnitedHealthcare' AND
				(
					(ISNULL(fin.PHACompletionDate,'29991231') != ISNULL(lg.PHACompletionDate,'29991231')) OR
					(ISNULL(fin.BioCompletionDate,'29991231') != ISNULL(lg.BioCompletionDate,'29991231')) OR
					(fin.LMIncentiveEligible != ISNULL(lg.LMIncentiveEligible,'-1')) OR
					(fin.LMIncentiveMet != ISNULL(lg.LMIncentiveMet,'-1')) OR
					(fin.BioLMStatus != ISNULL(lg.BioLMStatus,'-1')) OR
					(fin.TobaccoSurchargeApplied != ISNULL(lg.TobaccoSurchargeApplied,'-1')) OR
					(fin.TobaccoCessationStatus != ISNULL(lg.TobaccoCessationStatus,'-1')) OR
					(ISNULL(fin.PregnancyIndicator,-1) != ISNULL(lg.PregnancyIndicator,-1))
				)
				
			SET
				@RecordCount =
								(
									SELECT 
										COUNT(fin.MemberID) 
									FROM
										#Final fin
									JOIN
										DA_Reports.pepsico.CrossReferral_ReportLog lg
										ON	(fin.MemberID = lg.MemberID)
										AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
										AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
										AND	(lg.ReportedTo = 'UHC_OPTUM')
									WHERE
										lg.Rerun = 0
								)
			SET
				@CreationDate = CONVERT(VARCHAR(8),GETDATE(),112)
				
			SELECT
				[H1],
				[H2],
				[H3],
				[H4],
				[H5],
				[H6],
				[H7],
				[H8],
				[H9],
				[H10],
				[H11],
				[H12],
				[H13],
				[H14],
				[H15],
				[H16],
				[H17]
			FROM
				(
				SELECT
					'10900' + 'HRDS' + @CreationDate + (SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_LEFT('0',6,@RecordCount)) AS [H1],
					'' AS [H2],
					'' AS [H3],
					'' AS [H4],
					'' AS [H5],
					'' AS [H6],
					'' AS [H7],
					'' AS [H8],
					'' AS [H9],
					'' AS [H10],
					'' AS [H11],
					'' AS [H12],
					'' AS [H13],
					'' AS [H14],
					'' AS [H15],
					'' AS [H16],
					'' AS [H17],
					1 AS [Seq]
					
				UNION ALL
				
				SELECT
					fin.EligMemberID AS [D1],
					fin.SSN AS [D2],
					fin.FirstName AS [D3],
					fin.LastName AS [D4],
					fin.DOB AS [D5],
					fin.Relationship AS [D6],
					fin.Gender AS [D7],
					ISNULL(fin.PHACompletionDate,'') AS [D8],
					ISNULL(fin.BioCompletionDate,'') AS [D9],
					fin.LMIncentiveEligible AS [D10],
					fin.LMIncentiveMet AS [D11],
					fin.BioLMStatus AS [D12],
					ISNULL(fin.BioLMStatusDate,'') AS [D13],
					fin.TobaccoSurchargeApplied AS [D14],
					fin.TobaccoCessationStatus AS [D15],
					ISNULL(fin.TobaccoCessationStatusDate,'') AS [D16],
					ISNULL(fin.PregnancyIndicator,'') AS [D17],
					2 AS [Seq]
				FROM
					#Final fin
				JOIN
					DA_Reports.pepsico.CrossReferral_ReportLog lg
					ON	(fin.MemberID = lg.MemberID)
					AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
					AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
					AND	(lg.ReportedTo = 'UHC_OPTUM')
					AND	(lg.Rerun = 0)
				) data
			ORDER BY
				Seq
		
		END
	
	END
	
	-- CLEAN UP

	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END

	IF OBJECT_ID('tempdb.dbo.#Waivers') IS NOT NULL
	BEGIN
		DROP TABLE #Waivers
	END
	
	IF OBJECT_ID('tempdb.dbo.#Appointment') IS NOT NULL
	BEGIN
		DROP TABLE #Appointment
	END
	
	IF OBJECT_ID('tempdb.dbo.#BioResults') IS NOT NULL
	BEGIN
		DROP TABLE #BioResults
	END
	
	IF OBJECT_ID('tempdb.dbo.#Outcomes') IS NOT NULL
	BEGIN
		DROP TABLE #Outcomes
	END
	
	IF OBJECT_ID('tempdb.dbo.#Activity') IS NOT NULL
	BEGIN
		DROP TABLE #Activity
	END
	
	IF OBJECT_ID('tempdb.dbo.#ActivityDenorm') IS NOT NULL
	BEGIN
		DROP TABLE #ActivityDenorm
	END
	
	IF OBJECT_ID('tempdb.dbo.#Final') IS NOT NULL
	BEGIN
		DROP TABLE #Final
	END
	
END
GO
