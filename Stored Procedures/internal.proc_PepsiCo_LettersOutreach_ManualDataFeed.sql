SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-16
-- Description:	Internal Pepsico Letters and Outreach Data Feeds
--
-- Notes:		
--
-- Updates:		WilliamPe 20140508
--				Updated code to incorporate table load and report output in one step
--			
--				WilliamPe 20140604
--				Updated code to account for the fact that the ReferenceID 
--				is not a numberic value for waiver records.  I am excluding
--				any waiver records from being evaluated for the letter or outreach.				
--
-- =============================================

CREATE PROCEDURE [internal].[proc_PepsiCo_LettersOutreach_ManualDataFeed] 
	@inReportType INT
AS
BEGIN

	IF @inReportType <= 0 OR @inReportType > 4
	BEGIN
	RAISERROR (N'Please pass integers 1,2,3 or 4 for the @inReportType INT parameter', -- Message text.
			   10, -- Severity,
			   1  -- State,
			   )
	END
 
	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#Activity') IS NOT NULL
	BEGIN
		DROP TABLE #Activity
	END

	IF OBJECT_ID('tempdb.dbo.#Final') IS NOT NULL
	BEGIN
		DROP TABLE #Final
	END
	
	
	/*-------------------------------------------- PART 1 --------------------------------------------*/
	IF @inReportType BETWEEN 1 AND 4
	BEGIN
	
		-- BASE TEMP
		SELECT
			mem.MemberID,
			grp.GroupName,
			mem.EligMemberID,
			mem.EligMemberSuffix,
			mem.FirstName,
			mem.LastName,
			mem.RelationshipID,
			mem.Birthdate,
			addr.Address1,
			addr.Address2,
			addr.City,
			addr.[State],
			addr.ZipCode,
			COALESCE(mem.AlternatePhone,mem.HomePhone,mem.WorkPhone,mem.CellPhone) AS [PhoneNumber],
			mem.EmailAddress,
			cs.CS1, -- SMOKER FLAG
			cs.CS2, -- TOBACCO SURCHARGE FLAG
			cs.CS3, -- ONLINE ELIGIBLE
			cs.CS4, -- COACHING ELIGIBLE
			cs.CS5, -- INCENTIVE ELIGIBLE
			cs.CS6, -- PAYOUT TYPE (AMEX OR HSA)
			cs.CS8, -- EXPAT STATUS
			cs.CS13, -- DIVISION CODE
			cs.CS14, -- DIVISION CODE NAME
			cs.CS15, -- LOCATION NAME
			cs.CS16, -- LOCATION CODE
			CASE WHEN ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) THEN 1 ELSE 0 END AS [IsCurrentlyEligible],
			CASE WHEN cs.CS8 = 'Y' THEN 1 ELSE 0 END AS [IsExpat],
			elig.EffectiveDate,
			elig.TerminationDate
		INTO 
			#Base
		FROM
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(grp.GroupID = mem.GroupID)
			AND	(mem.GroupID = 206772)
		JOIN
			DA_Production.prod.CSFields cs WITH (NOLOCK)
			ON	(mem.MemberID = cs.MemberID)
		LEFT JOIN
			DA_Production.prod.[Address] addr WITH (NOLOCK)
			ON	(mem.MemberID = addr.MemberID)
			AND	(addr.AddressTypeID = 6)
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
			mem.RelationshipID IN (1,2,6) AND
			cs.CS5 = 'Y'-- IncentiveEligible

	/*-------------------------------------------- PART 2 --------------------------------------------*/
		
		-- INCENTIVE TEMP
		SELECT
			pln.ClientIncentivePlanID,
			pa.ActivityItemID,
			pa.ActivityName,
			pa.ActivityDescription,
			ISNULL(pa.AI_Name,pa.AI_Instruction) AS [AI_NameInstruction],
			pa.ActivityItemCode,
			pa.AIC_ActivityValue,
			pa.AIC_CompareOperator,
			pa.AIC_CompareValue,
			pa.AIL_MaxValue,
			pa.TimePeriodName,
			mai.MemberID,
			mai.MemberActivityItemID,
			mai.ActivityValue,
			mai.ActivityDate,
			mai.AddDate AS [IncentiveActivityCreditDate],
			mai.RecordID,
			mai.ReferenceID,
			CASE WHEN ISNUMERIC(mai.ReferenceID) = 1 THEN mai.ReferenceID ELSE -8675309 END AS [SourceRecordID],
			mai.IsWaiver
		INTO
			#Incentive
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
			Incentive.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
			ON	(air.ActivityItemID = mai.ActivityItemID)
			AND	(pln.ClientIncentivePlanID = mai.ClientIncentivePlanID)
			AND	(mai.Deleted = 0)
		WHERE
			pln.Expired = 0 AND
			pln.ClientIncentivePlanID = 2 AND
			pa.ActivityItemCode IN ('BIOMETRICSCREENING','BIOMETRICOUTCOMES') AND
			mai.IsWaiver = 0 -- FILTERING OUT WAIVER RECORDS

	/*-------------------------------------------- PART 3 --------------------------------------------*/	

		-- ACTIVITY TEMP
		SELECT
			*
		INTO 
			#Activity
		FROM
			(
			SELECT
				b.MemberID,
				b.EligMemberID,
				b.EligMemberSuffix,
				b.FirstName,
				b.LastName,
				b.RelationshipID,
				b.Birthdate,
				b.Address1,
				b.Address2,
				b.City,
				b.[State],
				b.ZipCode,
				b.CS5,
				b.IsCurrentlyEligible,
				b.IsExpat,
				inc.ActivityItemID,
				inc.AI_NameInstruction,
				inc.ActivityName,
				inc.ActivityDescription,
				inc.ActivityItemCode,
				inc.ActivityDate,
				inc.IncentiveActivityCreditDate,
				inc.ActivityValue,
				inc.ReferenceID,
				scr.MemberScreeningID,
				scr.ScreeningDate,
				scr.StratifiedDate,
				scr.AddDate AS [BioLoadDate],
				scr.[Source] AS [FileSource],
				strat.StratificationDate,
				strat.MemberStratificationID,
				strat.MemberStratificationName,
				strat.StratificationSourceID,
				strat.StratificationSourceName,
				CASE WHEN cch.MemberID IS NOT NULL THEN 1 ELSE 0 END AS [IsEnrolledCoaching],
				CASE WHEN dm.MemberID IS NOT NULL THEN 1 ELSE 0 END AS [IsEnrolledDM],
				ROW_NUMBER() OVER (PARTITION BY b.MemberID, inc.ActivityItemCode ORDER BY inc.IncentiveActivityCreditDate) AS ActivitySeq
			FROM
				#Base b
			JOIN
				#Incentive inc
				ON	(b.MemberID = inc.MemberID)
			LEFT JOIN
				HRMS.dbo.MemberScreening scr WITH (NOLOCK)
				ON	(inc.SourceRecordID = scr.MemberScreeningID)
				AND	(inc.ActivityItemCode = 'BIOMETRICSCREENING')
			LEFT JOIN
				DA_Production.prod.Stratification strat WITH (NOLOCK)
				ON	(scr.MemberID = strat.MemberID)
				AND	(DATEDIFF(dd,0,scr.StratifiedDate) = DATEDIFF(dd,0,strat.StratificationDate))
				AND	(strat.StratificationSourceID IN (1,28,49))
			LEFT JOIN
				(
				SELECT
					MemberID,
					ProgramID,
					ProgramName,
					EnrollmentDate,
					TerminationDate,
					ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
				FROM
					DA_Production.prod.ProgramEnrollment
				WHERE
					GroupID = 206772 AND
					ISNULL(TerminationDate,'2999-12-31') >= DATEADD(dd,DATEDIFF(dd,0,GETDATE()),1)
				) cch
				ON	(b.MemberID = cch.MemberID)
				AND	(cch.RevTermSeq = 1)
			LEFT JOIN
				(
				SELECT
					mem.MemberID,
					res.ConditionID,
					res.VendorID,
					res.StatusID,
					res.StatusDate,
					cond.ConditionName,
					vend.VendorName,
					vend.VendorType,
					stat.StatusName,
					ROW_NUMBER() OVER (PARTITION BY mem.MemberID ORDER BY res.StatusDate DESC) AS RevDMSeq 
				FROM
					DA_Production.prod.Member mem WITH (NOLOCK)
				JOIN
					MCLASSECR.dbo.ResourceMemberResult res WITH (NOLOCK)
					ON	(mem.MemberID = res.MemberID)
				JOIN
					MCLASSECR.dbo.ResourceCondition cond WITH (NOLOCK)
					ON	(res.ConditionID = cond.ConditionID)
					AND	(res.VendorID = cond.VendorID)
				JOIN
					MCLASSECR.dbo.ResourceVendor vend WITH (NOLOCK)
					ON	(res.VendorID = vend.VendorID)
				JOIN
					MCLASSECR.dbo.ResourceStatus stat WITH (NOLOCK)
					ON	(res.StatusID = stat.StatusID)
				WHERE
					mem.GroupID = 206772 AND
					vend.VendorName = 'Carewise' AND
					stat.StatusID IN (1,2) -- ENROLLED; OPEN
				) dm
				ON	(b.MemberID = dm.MemberID)
				AND	(dm.RevDMSeq = 1)
			WHERE
				b.IsExpat = 0 AND
				b.IsCurrentlyEligible = 1
			) data
		WHERE
			ActivitySeq = 1
		
	/*-------------------------------------------- PART 4 --------------------------------------------*/	
		
		SELECT
			act.MemberID,
			act.EligMemberID,
			act.EligMemberSuffix,
			act.FirstName,
			act.LastName,
			act.RelationshipID,
			act.Birthdate,
			act.Address1,
			act.Address2,
			act.City,
			act.[State],
			act.ZipCode,
			act.CS5,
			act.IsCurrentlyEligible,
			act.IsExpat,
			act.IncentiveActivityCreditDate,
			act.MemberScreeningID,
			act.FileSource,
			act.ScreeningDate,
			act.MemberStratificationName,
			flat.BIOMETRICSCREENING,
			flat.BIOMETRICOUTCOMES,
			flat.COACHING,
			flat.DM,
			CASE WHEN flat.BIOMETRICOUTCOMES IS NOT NULL AND act.MemberStratificationName = 'Low' THEN 1 ELSE 0 END AS [LetterMetLow],
			CASE WHEN flat.BIOMETRICOUTCOMES IS NOT NULL AND act.MemberStratificationName IN ('Moderate','High') THEN 1 ELSE 0 END [LetterMetModHigh],
			CASE WHEN flat.BIOMETRICOUTCOMES IS NULL AND (flat.Coaching IS NOT NULL OR flat.DM IS NOT NULL) THEN 1 ELSE 0 END [LetterNotMetDMCoach],
			CASE WHEN flat.BIOMETRICOUTCOMES IS NULL AND flat.COACHING IS NULL AND flat.DM IS NULL THEN 1 ELSE 0 END AS [Outreach]
		INTO
			#Final
		FROM
			#Activity act
		JOIN
			(
			SELECT
				MemberID,
				[BIOMETRICSCREENING],
				[BIOMETRICOUTCOMES],
				[COACHING],
				[DM]
			FROM
				(
					SELECT
						MemberID,
						ActivityItemCode,
						'1' AS ActivityValue
					FROM
						#Activity
					WHERE
						ActivityItemCode = 'BIOMETRICSCREENING'
					UNION
					SELECT
						MemberID,
						ActivityItemCode,
						'1' AS ActivityValue
					FROM
						#Activity
					WHERE
						ActivityItemCode = 'BIOMETRICOUTCOMES'
					UNION
					SELECT
						MemberID,
						'COACHING' AS ActivityItemCode,
						'1'  AS ActivityValue
					FROM
						#Activity
					WHERE
						IsEnrolledCoaching = 1
					UNION
					SELECT
						MemberID,
						'DM' AS ActivityItemCode,
						'1'  AS ActivityValue
					FROM
						#Activity
					WHERE
						IsEnrolledDM = 1
					) data
					PIVOT
					(
					MIN(ActivityValue) FOR ActivityItemCode IN ([BIOMETRICSCREENING],[BIOMETRICOUTCOMES],[COACHING],[DM])
					) pvt
			) flat
			ON	(act.MemberID = flat.MemberID)
		WHERE
			act.ActivityItemCode = 'BIOMETRICSCREENING'
		GROUP BY
			act.MemberID,
			act.EligMemberID,
			act.EligMemberSuffix,
			act.FirstName,
			act.LastName,
			act.RelationshipID,
			act.Birthdate,
			act.Address1,
			act.Address2,
			act.City,
			act.[State],
			act.ZipCode,
			act.CS5,
			act.IsCurrentlyEligible,
			act.IsExpat,
			act.IncentiveActivityCreditDate,
			act.MemberScreeningID,
			act.FileSource,
			act.ScreeningDate,
			act.MemberStratificationName,
			flat.BIOMETRICSCREENING,
			flat.BIOMETRICOUTCOMES,
			flat.COACHING,
			flat.DM,
			CASE WHEN flat.BIOMETRICOUTCOMES IS NOT NULL AND act.MemberStratificationName = 'Low' THEN 1 ELSE 0 END,
			CASE WHEN flat.BIOMETRICOUTCOMES IS NOT NULL AND act.MemberStratificationName IN ('Moderate','High') THEN 1 ELSE 0 END,
			CASE WHEN flat.BIOMETRICOUTCOMES IS NULL AND (flat.Coaching IS NOT NULL OR flat.DM IS NOT NULL) THEN 1 ELSE 0 END,
			CASE WHEN flat.BIOMETRICOUTCOMES IS NULL AND flat.COACHING IS NULL AND flat.DM IS NULL THEN 1 ELSE 0 END
			

	/*-------------------------------------------- PART 5 --------------------------------------------*/

		DELETE DA_Reports.internal.PepsiCo_LettersOutreach_Log
		WHERE
			DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
			DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE())
		
	/*-------------------------------------------- PART 6 --------------------------------------------*/	

		INSERT INTO internal.PepsiCo_LettersOutreach_Log
		SELECT
			fin.MemberID,
			fin.EligMemberID,
			fin.EligMemberSuffix,
			fin.FirstName,
			fin.LastName,
			fin.RelationshipID,
			fin.Birthdate,
			fin.Address1,
			fin.Address2,
			fin.City,
			fin.[State],
			fin.ZipCode,
			fin.CS5,
			fin.IsCurrentlyEligible,
			fin.IsExpat,
			fin.IncentiveActivityCreditDate,
			fin.MemberScreeningID,
			fin.FileSource,
			fin.ScreeningDate,
			fin.MemberStratificationName,
			fin.BIOMETRICSCREENING,
			ISNULL(fin.BIOMETRICOUTCOMES,0) AS BIOMETRICOUTCOMES,
			ISNULL(fin.COACHING,0) AS COACHING,
			ISNULL(fin.DM,0) AS DM,
			CASE
				WHEN fin.LetterMetLow = 1 THEN 'LetterMetLow'
				WHEN fin.LetterMetModHigh = 1 THEN 'LetterMetModHigh'
				WHEN fin.LetterNotMetDMCoach = 1 THEN 'LetterNotMetDMCoach'
				WHEN fin.Outreach = 1 THEN 'Outreach'
			END AS ReportType,
			GETDATE() AS DateReported,
			GETDATE() AS AddedDate,
			SUSER_SNAME() AS AddedBy,
			NULL AS ModifiedBy,
			NULL AS Notes,
			0 AS Rerun
		FROM
			#Final fin
		LEFT JOIN
			internal.PepsiCo_LettersOutreach_Log lg
			ON	(fin.MemberID = lg.MemberID)
			AND	(lg.Rerun = 0)
		WHERE
			lg.MemberID IS NULL AND
			(LetterMetLow + LetterMetModHigh + LetterNotMetDMCoach + Outreach) = 1

		
	/*-------------------------------------------- PART 6 --------------------------------------------*/
		
		IF @inReportType = 1
		BEGIN
			SELECT
				'Passed3of4_LowStrat' AS OutreachLetter,
				MemberScreeningID,
				MemberID,
				FirstName,
				LastName,
				Address1,
				Address2,
				City,
				[State],
				ZipCode
			FROM
				DA_Reports.internal.PepsiCo_LettersOutreach_Log
			WHERE
				ReportType = 'LetterMetLow' AND
				DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
				DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE())
		END

		IF @inReportType = 2
		BEGIN
			SELECT
				'Passed3of4_ModHighStrat' AS OutreachLetter,
				MemberScreeningID,
				MemberID,
				FirstName,
				LastName,
				Address1,
				Address2,
				City,
				[State],
				ZipCode
			FROM
				DA_Reports.internal.PepsiCo_LettersOutreach_Log
			WHERE
				ReportType = 'LetterMetModHigh' AND
				DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
				DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE())
		END

		IF @inReportType = 3
		BEGIN
			SELECT
				'FailToMeet3of4_CoachingRequired' AS OutreachLetter,
				MemberScreeningID,
				MemberID,
				FirstName,
				LastName,
				Address1,
				Address2,
				City,
				[State],
				ZipCode
			FROM
				DA_Reports.internal.PepsiCo_LettersOutreach_Log
			WHERE
				ReportType = 'LetterNotMetDMCoach' AND
				DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
				DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE())
		END

		IF @inReportType = 4
		BEGIN
			SELECT
				CONVERT(VARCHAR(8),GETDATE(),112) AS Creation_Date,
				'HRDS - DA' AS Sendor_Name,
				'PEPSICO' AS Company_Name,
				MemberID,
				EligMemberID AS EligID,
				EligMemberSuffix AS Suffix,
				FirstName AS F_Name,
				LastName AS L_Name,
				CONVERT(VARCHAR(8),Birthdate,112) AS DOB,
				MemberStratificationName AS StratificationLevel,
				'' AS Reason,
				'PepsiCo pre-stratified file' AS Stratification_Source,
				FileSource AS Client_Source,
				CONVERT(VARCHAR(8),ScreeningDate,112) AS Biometric_Screening_Date
			FROM
				DA_Reports.internal.PepsiCo_LettersOutreach_Log
			WHERE
				ReportType = 'Outreach' AND
				DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
				DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE())
		END
	
	END

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END

	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempdb.dbo.#Activity') IS NOT NULL
	BEGIN
		DROP TABLE #Activity
	END

	IF OBJECT_ID('tempdb.dbo.#Final') IS NOT NULL
	BEGIN
		DROP TABLE #Final
	END

END
GO
