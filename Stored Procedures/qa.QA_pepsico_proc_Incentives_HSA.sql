SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-07
-- Description:	QA proc used to test any changes to the PepsiCo Incentives Report to Aon Hewitt (HSA)
--
-- Notes:
--
-- Updates:		WilliamPe 20140416
--				Added Deleted Column to #Final temp table.  Defaults to 0.
--	
--				WilliamPe 20140602
--				Several modifications were made to this version:
--
--				1) Removed the hard-coded members from code. The list of members were the source and target records
--				   provided to us by IT. This was only temporary until the members were properly merged.
--				   After removing these records, I updated the report log MemberID column with the target record.
--				   The mapping can be found in the table DA_Imports.dbo.PepsiCo_IT_MergeRecords_20140602.
--				   I added an 'OldMemberID' column to the log table to capture the history of the record.
--				
--				2) Used code that NickD wrote to prevent activity records from being inserted and reported based on
--				   FirstName, LastName, Birthdate, and Activity.
--
--				3) Hard coded a couple MemberID's as Adrienne confirmed they were exceptions to the rule implemented in #2
--
-- =============================================

CREATE PROCEDURE [qa].[QA_pepsico_proc_Incentives_HSA]

AS
	BEGIN

	SET NOCOUNT ON;

	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END

	IF OBJECT_ID('tempdb.dbo.#IncentiveActivity') IS NOT NULL
	BEGIN
		DROP TABLE #IncentiveActivity
	END

	IF OBJECT_ID('tempdb.dbo.#Reward') IS NOT NULL
	BEGIN
		DROP TABLE #Reward
	END

	IF OBJECT_ID('tempdb.dbo.#Final') IS NOT NULL
	BEGIN
		DROP TABLE #Final
	END

/*-------------------------------------------- PART 1 --------------------------------------------*/

	-- BASE TEMP
	SELECT
		mem.MemberID,
		grp.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		REPLACE(mem.FirstName,'''','') AS [FirstName],
		mem.LastName,
		mem.RelationshipID,
		CONVERT(VARCHAR(8),mem.Birthdate,112) AS [Birthdate],
		REPLACE(REPLACE(addr.Address1,'#',''),'''','') AS [Address1],
		REPLACE(addr.Address2,'''','') AS [Address2],
		REPLACE(addr.City,'''','') AS [City],
		addr.[State],
		REPLACE(addr.ZipCode,'-','') AS [ZipCode],
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
		cs.CS6 = 'HSA' 

/*-------------------------------------------- PART 2 --------------------------------------------*/
	
	-- INCENTIVE ACTIVITY TEMP
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
		rew.RewardAmount,
		mai.MemberID,
		mai.MemberActivityItemID,
		mai.ActivityValue,
		mai.ActivityDate,
		mai.AddDate AS [CreditDate],
		mai.RecordID,
		mai.ReferenceID,
		CASE WHEN ISNUMERIC(mai.ReferenceID) = 1 THEN ReferenceID ELSE -8675309 END AS [SourceRecordID],
		mai.IsWaiver
	INTO
		#IncentiveActivity
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
		pln.ClientIncentivePlanID = 2

/*-------------------------------------------- PART 3 --------------------------------------------*/	
	-- REWARD TEMP
	SELECT
		b.MemberID,
		b.GroupName,
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
		b.PhoneNumber,
		b.EmailAddress,
		b.CS1,
		b.CS2,
		b.CS3,
		b.CS4,
		b.CS5,
		b.CS6,
		b.CS8,
		b.CS13,
		b.CS14,
		b.CS15,
		b.CS16,
		b.IsCurrentlyEligible,
		b.IsExpat,
		b.EffectiveDate,
		b.TerminationDate,
		inc.ActivityItemID,
		inc.AI_NameInstruction,
		inc.ActivityName,
		inc.ActivityDescription,
		inc.ActivityItemCode,
		inc.ActivityDate,
		inc.CreditDate,
		inc.ActivityValue,
		inc.RewardAmount,
		inc.ReferenceID,
		inc.SourceRecordID,
		inc.IsWaiver,
		scr.MemberScreeningID,
		scr.ScreeningDate,
		scr.SourceAddDate AS [BioLoadDate],
		strat.StratificationDate,
		strat.MemberStratificationID,
		strat.MemberStratificationName,
		strat.StratificationSourceID,
		strat.StratificationSourceName
	INTO
		#Reward
	FROM
		#Base b
	JOIN
		#IncentiveActivity inc
		ON	(b.MemberID = inc.MemberID)
	LEFT JOIN
        DA_Production.prod.BiometricsScreening scr WITH (NOLOCK)
        ON	(inc.SourceRecordID = scr.MemberScreeningID)
        AND	(inc.ActivityItemCode = 'BIOMETRICSCREENING')
	LEFT JOIN
		DA_Production.prod.Stratification strat WITH (NOLOCK)
		ON	(scr.MemberID = strat.MemberID)
		AND	(DATEDIFF(dd,0,scr.SourceAddDate) = DATEDIFF(dd,0,strat.StratificationDate))
		AND	(strat.StratificationSourceID IN (1,28,49))
	WHERE
		b.IsExpat = 0 AND -- HSA NOT AVAILABLE TO EXPATS
		b.CS5 = 'Y' -- IncentiveEligible


/*-------------------------------------------- QA ONLY -------------------------------------------*/
	
	TRUNCATE TABLE DA_Reports.qa.QA_pepsico_Incentives_ReportLog

	INSERT INTO DA_Reports.qa.QA_pepsico_Incentives_ReportLog
	SELECT
		*
	FROM
		DA_Reports.pepsico.Incentives_ReportLog

/*-------------------------------------------- QA ONLY -------------------------------------------*/

/*-------------------------------------------- PART 4 --------------------------------------------*/

	-- DELETE RECORDS IF RERUNNING THE SAME DAY
	DELETE DA_Reports.qa.QA_pepsico_Incentives_ReportLog
	WHERE
		DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
		DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE()) AND
		ReportedTo = 'HSA'

/*-------------------------------------------- PART 5 --------------------------------------------*/	
	
	SELECT
		data.MemberID,
		data.EligMemberID,
		data.EligMemberSuffix,
		data.FirstName,
		data.LastName,
		data.RelationshipID,
		data.Birthdate,
		data.Address1,
		data.Address2,
		data.City,
		data.[State],
		data.ZipCode,
		data.PhoneNumber,
		data.EmailAddress,
		data.CS1,
		data.CS2,
		data.CS3,
		data.CS4,
		data.CS5,
		data.CS6,
		data.CS8,
		data.CS13,
		data.CS14,
		data.CS15,
		data.CS16,
		data.ActivityItemCode,
		data.ActivityDate,
		data.Amount,
		data.MessageCode,
		data.Stratification,
		data.DateReported,
		data.ReportedTo,
		data.ReportEndDate,
		data.AddedDate,
		data.AddedBy,
		data.ModifiedBy,
		data.Notes,
		data.Rerun,
		data.Activity,
		data.Deleted,
		data.OldMemberID,
		data.IsWaiver
	INTO
		#Final
	FROM
		(
		SELECT
			rwd.MemberID,
			rwd.EligMemberID,
			rwd.EligMemberSuffix,
			rwd.FirstName,
			rwd.LastName,
			rwd.RelationshipID,
			rwd.Birthdate,
			rwd.Address1,
			rwd.Address2,
			rwd.City,
			rwd.[State],
			rwd.ZipCode,
			rwd.PhoneNumber,
			rwd.EmailAddress,
			rwd.CS1,
			rwd.CS2,
			rwd.CS3,
			rwd.CS4,
			rwd.CS5,
			rwd.CS6,
			rwd.CS8,
			rwd.CS13,
			rwd.CS14,
			rwd.CS15,
			rwd.CS16,
			rwd.ActivityItemCode,
			rwd.ActivityDate,
			rwd.RewardAmount AS [Amount],
			NULL AS [MessageCode],
			rwd.MemberStratificationName AS [Stratification],
			GETDATE() AS [DateReported],
			'HSA' AS [ReportedTo],
			NULL AS [ReportEndDate],
			GETDATE() AS [AddedDate],
			SUSER_SNAME() AS [AddedBy],
			NULL AS [ModifiedBy],
			NULL AS [Notes],
			0 AS [Rerun],
			CASE 
				WHEN rwd.ActivityItemCode IN ('BIOMETRICOUTCOMES','LIFESTYLECOACHINGSESSIONS')
				THEN 'ALTERNATIVES' 
				ELSE rwd.ActivityItemCode 
			END AS [Activity],
			ROW_NUMBER() OVER (PARTITION BY rwd.MemberID, CASE 
															 WHEN rwd.ActivityItemCode IN ('BIOMETRICOUTCOMES','LIFESTYLECOACHINGSESSIONS')
															 THEN 'ALTERNATIVES' 
															 ELSE rwd.ActivityItemCode 
														  END ORDER BY rwd.ActivityDate) AS [ActivitySeq],
			0 AS [Deleted],
			NULL AS [OldMemberID],
			rwd.IsWaiver
		FROM
			#Reward rwd
		JOIN
			(
			SELECT
				MemberID,
				[PRIMARYPHA],
				[BIOMETRICSCREENING],
				[BIOMETRICOUTCOMES],
				[BIOSTRATIFICATION],
				[LIFESTYLECOACHINGSESSIONS]
			FROM
				(
					SELECT
						MemberID,
						ActivityItemCode,
						CAST(RewardAmount AS VARCHAR(4)) AS RewardAmount
					FROM
						#Reward
					WHERE
						ActivityItemCode = 'PRIMARYPHA'
					UNION
					SELECT
						MemberID,
						ActivityItemCode,
						CAST(RewardAmount AS VARCHAR(4)) AS RewardAmount
					FROM
						#Reward
					WHERE
						ActivityItemCode = 'BIOMETRICSCREENING'
					UNION
					SELECT
						MemberID,
						ActivityItemCode,
						CAST(RewardAmount AS VARCHAR(4)) AS RewardAmount
					FROM
						#Reward
					WHERE
						ActivityItemCode = 'BIOMETRICOUTCOMES'
					UNION
					SELECT
						MemberID,
						'BIOSTRATIFICATION' AS ActivityItemCode,
						MemberStratificationName AS RewardAmount
					FROM
						#Reward
					WHERE
						ActivityItemCode = 'BIOMETRICSCREENING'
					UNION
					SELECT
						MemberID,
						ActivityItemCode,
						CAST(RewardAmount AS VARCHAR(4)) AS RewardAmount
					FROM
						#Reward
					WHERE
						ActivityItemCode = 'LIFESTYLECOACHINGSESSIONS'
					) data
					PIVOT
					(
					MIN(RewardAmount) FOR ActivityItemCode IN ([PRIMARYPHA],[BIOMETRICSCREENING],[BIOMETRICOUTCOMES],[BIOSTRATIFICATION],[LIFESTYLECOACHINGSESSIONS])
					) pvt
			) flat
			ON	(rwd.MemberID = flat.MemberID)
		) data
	LEFT JOIN
		-- DO NOT INCLUDE A FILTER ON THE REPORTEDTO COLUMN
		-- MEMBERS COULD SWITCH FROM HSA TO AMEX AND SHOULD ONLY BE PAID OUT ONCE REGARDLESS
		DA_Reports.qa.QA_pepsico_Incentives_ReportLog lg
		ON	(data.MemberID = lg.MemberID)
		AND	(data.Activity = lg.Activity)
		AND	(lg.Rerun = 0)
	LEFT JOIN
		-- EXTRA FILTER TO MATCH RECORDS BY FIRST, LAST, DOB AND ACTIVITY
		-- IN ORDER TO PREVENT DUPLICATE ACTIVITY RECORDS WHEN THERE ARE DUPLICATE MEMBER RECORDS
		DA_Reports.qa.QA_pepsico_Incentives_ReportLog merg
		ON	(data.FirstName = merg.FirstName)
		AND	(data.LastName = merg.LastName)
		AND	(CAST(data.Birthdate AS DATETIME) = CAST(merg.Birthdate AS DATETIME))
		AND	(data.Activity = merg.Activity)
		AND	(merg.Rerun = 0)
		-- EXCEPTIONS (VALIDATED BY ADRIENNE B. AND PGS)	
		AND	(merg.MemberID NOT IN (23147430,23178332))  
	WHERE
		data.ActivitySeq = 1 AND
		lg.Activity IS NULL AND
		merg.Activity IS NULL
	ORDER BY
		data.MemberID,
		data.ActivityDate,
		data.Activity
		

/*-------------------------------------------- PART 5 --------------------------------------------*/
	INSERT INTO DA_Reports.qa.QA_pepsico_Incentives_ReportLog
	SELECT
/*-------------------------------------------- QA ONLY -------------------------------------------*/		
		-1 AS [ReportLogID],
/*-------------------------------------------- QA ONLY -------------------------------------------*/
		fin.*
	FROM
		#Final fin
	JOIN
		(
		SELECT
			earnchk.MemberID,
			newMemMax.NewCreditsMemberAmount + ISNULL(memHistMax.MemberAmountEarned,0) AS [MemberTotal],
			newFamMax.NewCreditsFamilyAmount + ISNULL(famHistMax.FamilyAmountEarned,0) AS [FamilyTotal],
			CASE
				WHEN (newMemMax.NewCreditsMemberAmount + ISNULL(memHistMax.MemberAmountEarned,0)) <= 250
				THEN 1 ELSE 0
			END AS [MemberBelowMax],
			CASE
				WHEN (newFamMax.NewCreditsFamilyAmount + ISNULL(famHistMax.FamilyAmountEarned,0)) <= 500
				THEN 1 ELSE 0
			END AS [FamilyBelowMax]
		FROM
			#Final earnchk
		JOIN
			(
			SELECT
				EligMemberID,
				SUM(Amount) AS [NewCreditsFamilyAmount]
			FROM
				#Final
			GROUP BY	
				EligMemberID
			HAVING
				SUM(Amount) <= 500 -- (250: PRIMARY | 250: SPOUSE)
			) newFamMax
			ON	(earnchk.EligMemberID = newFamMax.EligMemberID)
		JOIN
			(
			SELECT
				MemberID,
				SUM(Amount) AS [NewCreditsMemberAmount]
			FROM
				#Final
			GROUP BY	
				MemberID
			HAVING
				SUM(Amount) <= 250 -- (250: PRIMARY | 250: SPOUSE)
			) newMemMax
			ON	(earnchk.MemberID = newMemMax.MemberID)
		LEFT JOIN
			(
			SELECT
				EligMemberID,
				SUM(Amount) AS [FamilyAmountEarned]
			FROM
				DA_Reports.qa.QA_pepsico_Incentives_ReportLog 
			WHERE
				Rerun = 0
			GROUP BY
				EligMemberID
			HAVING
				SUM(Amount) <= 500	-- (250: PRIMARY | 250: SPOUSE)
			) famHistMax
			ON	(earnchk.EligMemberID = famHistMax.EligMemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				SUM(Amount) AS [MemberAmountEarned]
			FROM
				DA_Reports.qa.QA_pepsico_Incentives_ReportLog 
			WHERE
				Rerun = 0
			GROUP BY
				MemberID
			HAVING
				SUM(Amount) <= 250	-- (250: PRIMARY | 250: SPOUSE)
			) memHistMax
			ON	(earnchk.MemberID = memHistMax.MemberID)
		GROUP BY
			earnchk.MemberID,
			newMemMax.NewCreditsMemberAmount,
			ISNULL(memHistMax.MemberAmountEarned,0),
			newFamMax.NewCreditsFamilyAmount,
			ISNULL(famHistMax.FamilyAmountEarned,0)
		) maxchk
		ON	(fin.MemberID = maxchk.MemberID)
		AND	(maxchk.FamilyBelowMax = 1)
		AND	(maxchk.MemberBelowMax = 1)


/*-------------------------------------------- PART 6 --------------------------------------------*/

	DECLARE
		@ReportRunDate VARCHAR(8),
		@RowCount INT,
		@TotalAmount INT
	SET
		@ReportRunDate = CONVERT(VARCHAR(8),GETDATE(),112)
	SET
		@RowCount = 
					(
					SELECT
						COUNT(DISTINCT fin.EligMemberID) 
					FROM
						#Final fin 
					JOIN 
						DA_Reports.qa.QA_pepsico_Incentives_ReportLog lg 
						ON	(fin.MemberID = lg.MemberiD)
						AND	(fin.Activity = lg.Activity)
						AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
						AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
						AND	(lg.ReportedTo = 'HSA')
					WHERE
						lg.Rerun = 0
					)
	SET
		@TotalAmount = 
					(
					SELECT
						SUM(fin.Amount)
					FROM
						#Final fin 
					JOIN 
						DA_Reports.qa.QA_pepsico_Incentives_ReportLog lg
						ON	(fin.MemberID = lg.MemberiD)
						AND	(fin.Activity = lg.Activity)
						AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
						AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
						AND	(lg.ReportedTo = 'HSA')
					WHERE
						lg.Rerun = 0
					)

/*-------------------------------------------- PART 7 --------------------------------------------*/


	SELECT
		[H1],
		[H2],
		[H3],
		[H4],
		[H5],
		[H6],
		[H7],
		[H8]
	FROM
		(
		SELECT
			'H' AS [H1],
			'PEPSICO' AS [H2],
			'HSAFILE' AS [H3],
			@ReportRunDate AS [H4],
			'' AS [H5],
			'' AS [H6],
			'' AS [H7],
			'' AS [H8],
			1 AS [SortPosition]

		UNION ALL

		SELECT
			'D' AS [D1],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',20,GlobalID)) AS [D2],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',21,LastName)) AS [D3],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',21,FirstName)) AS [D4],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',8,DOB)) AS [D5],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',10,CONVERT(MONEY,ISNULL(SUM(EEAmount),0) ) )) AS [D6],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',10,CONVERT(MONEY,ISNULL(SUM(SPAmount),0) ) )) AS [D7],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',10,CONVERT(MONEY,ISNULL(SUM(EEAmount),0) + ISNULL(SUM(SPAmount),0) ) )) AS [D8],
			2 AS [SortPosition]
		FROM
			(
			SELECT
				amnt.MemberID,
				prmem.EligMemberID AS [GlobalID],
				prmem.Lastname,
				prmem.FirstName,
				CONVERT(VARCHAR(8),prmem.Birthdate,112) AS [DOB],
				CASE
					WHEN amnt.RelationshipID IN (1,2) THEN 'Spouse'
					WHEN amnt.RelationshipID = 6 THEN 'Primary'
				END AS [Relationship],
				amnt.Activity,
				CASE WHEN amnt.RelationshipID = 6 THEN amnt.Amount END AS [EEAmount],
				CASE WHEN amnt.RelationshipID IN (1,2) THEN amnt.Amount END AS [SPAmount]
			FROM
				#Final amnt 
			JOIN
				DA_Production.prod.Member prmem WITH (NOLOCK)
				ON	(prmem.EligMemberID = amnt.EligMemberID)
				AND	(prmem.GroupID = 206772)
				AND	(prmem.RelationshipID = 6)
			JOIN 
				DA_Reports.qa.QA_pepsico_Incentives_ReportLog lg 
				ON	(amnt.MemberID = lg.MemberiD)
				AND	(amnt.Activity = lg.Activity)
				AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
				AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
				AND	(lg.ReportedTo = 'HSA')
			WHERE
				lg.Rerun = 0
			) fin
		GROUP BY
			GlobalID,
			LastName,
			FirstName,
			DOB

		UNION ALL

		SELECT
			'T' AS [T1],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',9,@RowCount)) AS [T2],
			(SELECT * FROM dbo.func_FIXEDWIDTH_PAD_RIGHT('',12,@TotalAmount)) AS [T3],
			'' AS [T4],
			'' AS [T5],
			'' AS [T6],
			'' AS [T7],
			'' AS [T8],
			3 AS [SortPosition]
		) data
	ORDER BY
		SortPosition

END
GO
