SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-07
-- Description:	QA proc used to test any changes to the PepsiCo Incentives Report to AMEX
--
-- Notes:
--
-- Updates:		WilliamPe 2014-01-06
--              Added REPLACE function to Address1, Address2, and City. Logic will replace apostrophes
--
--              WilliamPe 2014-01-07
--              Added filter ReportedTo = 'AMEX' to the pepsico.Incentives_ReportLog table references.
--              The only exception is the reference into the #Final temp table. The latter was done to
--              ensure regardless of the members CS6 value (HSA, AMEX) they are only paid out once per activity
--                      
--              Renamed the Activity column in the table object to ActivityItemCode.  Then,
--              added a 'New' Actviity column to the table object at the end.  This new column
--              represents a conformed ActivityItemCode. Meaning, BIOMETRICOUTCOMES AND LIFESTYLECOACHINGSESSIONS
--              are now represented as ALTERNATIVES.  This was done since you can only get one record for these
--              activities.
--
--              Added logic to account for individual MAX and family MAX amount
--
--              WilliamPe 2014-01-27
--              Added filter in #Final temp insert that would kick out any records that did not have a message code.               
--
--              AdrienneB 2014-02-09--
--              Added REPLACE function to LastName. Logic will replace comma with a space.
--
--              AdrienneB 2014-02-26--
--              Added function to remove non-numeric characters from the phone number field.
--
--              AdrienneB 2014-02-28--
--              Added REPLACE function to replace "/" in the last name field with "-".
--
--              WilliamPe 2014-04-16--
--              Replacing " (double quotes) in Address1 columm with a blank ('')
--
--				NickD/EricH 20140523--
--				Added logic to exclude pha competition gift cards from the member/family cap calculations
--		
--				WilliamPe 20140530
--				Added conformed column for the incentive ReferenceID. I called the column SourceRecordID.
--				The referenceID for a Waiver record is populated with a non-numeric ID in this instance.
--				The ReferenceID is used to tie back the BiometricScreening to the source record in order to
--				get the stratification for the member.  For now, we are excluding waiver records until
--				Adrienne B. hears from PGS and PepsiCo on how to handle the message code for the
--				BiometricOutcomes reward when it is a waiver and has no stratification.
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
--			    3) Modified the code to pass MessageCode 104 for any BiometricOutcome waiver records. I added
--				   an IsWaiver column to the log table to show if the record is a waiver record.		   
--  
-- =============================================

CREATE PROCEDURE [pepsico].[proc_Incentives_AMEX] 

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
		REPLACE(REPLACE(mem.LastName,',',' '),'/','-') AS [LastName],
		mem.RelationshipID,
		CONVERT(VARCHAR(8),mem.Birthdate,112) AS [Birthdate],
		REPLACE(REPLACE(REPLACE(addr.Address1,'#',''),'''',''),'"','') AS [Address1],
		REPLACE(addr.Address2,'''','') AS [Address2],
		REPLACE(addr.City,'''','') AS [City],
		addr.[State],
		REPLACE(addr.ZipCode,'-','') AS [ZipCode],
		DA_Reports.dbo.func_RemoveNonNumericCharacters(COALESCE(mem.AlternatePhone,mem.HomePhone,mem.WorkPhone,mem.CellPhone)) AS [PhoneNumber],
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
        ON    (mem.MemberID = cs.MemberID)
	LEFT JOIN
        DA_Production.prod.[Address] addr WITH (NOLOCK)
        ON    (mem.MemberID = addr.MemberID)
        AND   (addr.AddressTypeID = 6)
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
		cs.CS6 = 'AMEX'

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
		AND (air.Deleted = 0)
	JOIN
		Incentive.dbo.IC_Reward rew WITH (NOLOCK)
		ON	(air.RewardID = rew.RewardID)
		AND (rew.Deleted = 0)
	JOIN
		Incentive.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
		ON	(air.ActivityItemID = mai.ActivityItemID)
		AND (pln.ClientIncentivePlanID = mai.ClientIncentivePlanID)
		AND (mai.Deleted = 0)
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
		b.IsExpat = 0 AND
        b.CS5 = 'Y' -- IncentiveEligible 

    UNION ALL

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
		NULL AS ActivityItemID,
		NULL AS AI_NameInstruction,
		NULL AS ActivityName,
		NULL AS ActivityDescription,
		'PRIMARYPHA' AS [ActivityItemCode],
		ha.AssessmentCompleteDate AS [ActivityDate],
		NULL AS [CreditDate],
		NULL AS [ActivityValue],
		75 AS RewardAmount,
		ha.MemberAssessmentID AS [SourceRecordID],
		NULL AS [IsWaiver],
		NULL AS [MemberScreeningID],
		NULL AS [ScreeningDate],
		NULL AS [BioLoadDate],
		NULL AS [StratificationDate],
		NULL AS [MemberStratificationID],
		NULL AS [MemberStratificationName],
		NULL AS [StratificationSourceID],
		NULL AS [StratificationSourceName]
	FROM
		#Base b
    JOIN
        DA_Production.prod.HealthAssessment ha WITH (NOLOCK)
        ON	(b.MemberID = ha.MemberID)
    WHERE
		b.IsExpat = 1 AND
        ha.IsPrimarySurvey = 1 AND
        ha.IsComplete = 1 AND
        ha.AssessmentCompleteDate < DATEADD(dd,120,b.EffectiveDate) AND
        ha.AssessmentCompleteDate < '2015-01-01'

/*-------------------------------------------- PART 4 --------------------------------------------*/
      
	-- DELETE RECORDS IF RERUNNING THE SAME DAY
	DELETE DA_Reports.pepsico.Incentives_ReportLog
	WHERE
		DATEDIFF(dd,0,DateReported) = DATEDIFF(dd,0,GETDATE()) AND
		DATEDIFF(dd,0,AddedDate) = DATEDIFF(dd,0,GETDATE()) AND
		ReportedTo = 'AMEX'
		
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
			CASE
				WHEN rwd.ActivityItemCode = 'PRIMARYPHA' THEN '100' 
				WHEN rwd.ActivityItemCode = 'BIOMETRICSCREENING' THEN '102'
				WHEN rwd.ActivityItemCode = 'BIOMETRICOUTCOMES' AND flat.BIOSTRATIFICATION = 'Low' THEN '103'
				WHEN rwd.ActivityItemCode = 'BIOMETRICOUTCOMES' AND flat.BIOSTRATIFICATION IN ('Moderate','High') THEN '104'
				-- PER ADRIENNE B. AND JOCELYN R., WAIVER OUTCOME RECORDS SHOULD BE PASSED WITH MESSAGECODE 104
				WHEN rwd.ActivityItemCode = 'BIOMETRICOUTCOMES' AND rwd.IsWaiver = 1 THEN '104' 
				WHEN rwd.ActivityItemCode = 'LIFESTYLECOACHINGSESSIONS' THEN '105'
			END AS [MessageCode],
			rwd.MemberStratificationName AS [Stratification],
			GETDATE() AS [DateReported],
			'AMEX' AS [ReportedTo],
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
		DA_Reports.pepsico.Incentives_ReportLog lg
		ON	(data.MemberID = lg.MemberID)
		AND	(data.Activity = lg.Activity)
		AND	(lg.Rerun = 0)
	LEFT JOIN
		-- EXTRA FILTER TO MATCH RECORDS BY FIRST, LAST, DOB AND ACTIVITY
		-- IN ORDER TO PREVENT DUPLICATE ACTIVITY RECORDS WHEN THERE ARE DUPLICATE MEMBER RECORDS
		DA_Reports.pepsico.Incentives_ReportLog merg
		ON	(data.FirstName = merg.FirstName)
		AND	(data.LastName = merg.LastName)
		AND	(CAST(data.Birthdate AS DATETIME) = CAST(merg.Birthdate AS DATETIME))
		AND	(data.Activity = merg.Activity)
		AND	(merg.Rerun = 0)
		-- EXCEPTIONS (VALIDATED BY ADRIENNE B. AND PGS)	
		AND	(merg.MemberID NOT IN (23147430,23178332))           
	WHERE
		data.ActivitySeq = 1 AND
		data.MessageCode IS NOT NULL AND 
		lg.Activity IS NULL AND
		merg.Activity IS NULL
	ORDER BY
		data.MemberID,
		data.ActivityDate,
		data.Activity

/*-------------------------------------------- PART 6 --------------------------------------------*/

	INSERT INTO DA_Reports.pepsico.Incentives_ReportLog
    SELECT
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
				DA_Reports.pepsico.Incentives_ReportLog
			WHERE
				Rerun = 0 AND
				Activity <> 'PHACompetitionWinner'
			GROUP BY
				EligMemberID
			HAVING
				SUM(Amount) <= 500 -- (250: PRIMARY | 250: SPOUSE)
			) famHistMax
			ON	(earnchk.EligMemberID = famHistMax.EligMemberID)
		LEFT JOIN
			(
			SELECT
				MemberID,
				SUM(Amount) AS [MemberAmountEarned]
			FROM
				DA_Reports.pepsico.Incentives_ReportLog
			WHERE
				Rerun = 0 AND
				Activity <> 'PHACompetitionWinner'
			GROUP BY
				MemberID
			HAVING
				SUM(Amount) <= 250 -- (250: PRIMARY | 250: SPOUSE)
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

/*-------------------------------------------- PART 7 --------------------------------------------*/   

	DECLARE
		@ReportRunDate DATETIME,
		@FileName VARCHAR(50),
		@FormattedRunDate VARCHAR(50),
		@RowCount INT,
		@TotalAmount INT
	SET
		@ReportRunDate = DATEADD(HOUR,DATEDIFF(HOUR,0,GETDATE()),0)
	SET
		@FileName = 'B2B.ORDER.DETAILS.P.' + REPLACE(CONVERT(VARCHAR(10),@ReportRunDate,110),'-','') + REPLACE(CONVERT(VARCHAR(8),@ReportRunDate,108),':','') + '.TXT'
	SET
		@FormattedRunDate = REPLACE(CONVERT(VARCHAR(10),@ReportRunDate,110),'-','') + REPLACE(CONVERT(VARCHAR(8),@ReportRunDate,108),':','')
	SET
		@RowCount = 
					(
					SELECT
						COUNT(fin.MemberID) 
					FROM
						#Final fin 
					JOIN 
						DA_Reports.pepsico.Incentives_ReportLog lg 
						ON	(fin.MemberID = lg.MemberiD)
						AND (fin.Activity = lg.Activity)
						AND (DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
						AND (DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
						AND (lg.ReportedTo = 'AMEX')
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
						DA_Reports.pepsico.Incentives_ReportLog lg 
						ON	(fin.MemberID = lg.MemberiD)
						AND	(fin.Activity = lg.Activity)
						AND	(DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
						AND	(DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
						AND (lg.ReportedTo = 'AMEX')
					WHERE
						lg.Rerun = 0
					)

/*-------------------------------------------- PART 8 --------------------------------------------*/

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
		[H17],
		[H18],
		[H19],
		[H20],
		[H21],
		[H22],
		[H23],
		[H24],
		[H25],
		[H26],
		[H27],
		[H28]
	FROM
		(
			SELECT
				'H' AS [H1], -- 1| 1 TO 1
				(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',40,@FileName)) AS [H2], -- 40| 2 TO 41
				(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',35,'PEPSI')) AS [H3], -- 35| 42 to 76
				(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_LEFT]('',14,@FormattedRunDate)) AS [H4],-- 14| 77 to 90
				(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',25,'HealthyLiving')) AS [H5], -- 25| 91 to 115
				'102768' AS [H6], -- 6| 116 to 121
				(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',35,'Healthyroads')) AS [H7], -- 35| 122 to 156
				SPACE(1) AS [H8], -- 1| 157 to 157
				'Y' AS [H9], -- 1| 158 to 158
				SPACE(1222) AS [H10], -- 1222| 159 to 1380
				'' AS [H11],
				'' AS [H12],
				'' AS [H13],
				'' AS [H14],
				'' AS [H15],
				'' AS [H16],
				'' AS [H17],
				'' AS [H18],
				'' AS [H19],
				'' AS [H20],
				'' AS [H21],
				'' AS [H22],
				'' AS [H23],
				'' AS [H24],
				'' AS [H25],
				'' AS [H26],
				'' AS [H27],
				'' AS [H28],
				1 AS [SortPosition]

			UNION ALL

			SELECT
				[D1],
				LEFT(CAST(ROW_NUMBER() OVER (ORDER BY D2) AS VARCHAR(15)) + SPACE(15),15) AS [D2],
				[D3],
				[D4],
				[D5],
				[D6],
				[D7],
				[D8],
				[D9],
				[D10],
				[D11],
				[D12],
				[D13],
				[D14],
				[D15],
				[D16],
				[D17],
				[D18],
				[D19],
				[D20],
				[D21],
				[D22],
				[D23],
				[D24],
				[D25],
				[D26],
				[D27],
				[D28],
				2 AS [SortPosition]
			FROM
				(
					SELECT
						'D' AS [D1], -- 1| 1 to 1
						fin.EligMemberID AS [D2],
						(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',50,fin.EligMemberID)) AS [D3],
						SPACE(50) AS [D4],
						(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',21,fin.FirstName)) AS [D5],
						(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',21,fin.LastName)) AS [D6],
						(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',21,LEFT(fin.FirstName,1) + SPACE(1) + fin.LastName)) AS [D7],
						CASE WHEN fin.Address1 IS NOT NULL
							  THEN (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',50,fin.Address1))
							  ELSE (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',50,''))
						END AS [D8],
						CASE WHEN fin.Address2 IS NOT NULL
							  THEN (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',50,fin.Address2))
							  ELSE (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',50,''))
						END AS [D9],
						CASE WHEN fin.City IS NOT NULL
							  THEN (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',20,fin.City))
							  ELSE (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',20,''))
						END AS [D10],
						CASE WHEN fin.[State] IS NOT NULL
							  THEN (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',2,fin.[State]))
							  ELSE (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',2,''))
						END AS [D11],
						CASE WHEN fin.ZipCode IS NOT NULL
							  THEN (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_LEFT]('',9,fin.ZipCode))
							  ELSE (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_LEFT]('',9,''))
						END AS [D12],
						CASE WHEN fin.PhoneNumber IS NOT NULL
							  THEN (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_LEFT]('',10,fin.PhoneNumber))
							  ELSE (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_LEFT]('',10,''))
						END AS [D13],
						CASE WHEN fin.EmailAddress IS NOT NULL
							  THEN (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',50,fin.EmailAddress))
							  ELSE (SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',50,''))
						END AS [D14],
						(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_LEFT]('0',10,CONVERT(MONEY,fin.Amount))) AS [D15],
						SPACE(300) AS [D16], 
						'AMEXB2B' AS [D17],
						SPACE(8) AS [D18],
						SPACE(9) AS [D19],
						(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_RIGHT]('',21,fin.MessageCode)) AS [D20],
						SPACE(8) AS [D21],
						SPACE(25) AS [D22],
						SPACE(15) AS [D23],
						SPACE(2) AS [D24],
						SPACE(25) AS [D25],
						SPACE(50) AS [D26],
						SPACE(30) AS [D27],
						SPACE(500) AS [D28]
					FROM
						#Final fin
					JOIN
						DA_Reports.pepsico.Incentives_ReportLog lg
						ON	(fin.MemberID = lg.MemberID)
						AND (fin.Activity = lg.Activity)
						AND (DATEDIFF(dd,0,lg.DateReported) = DATEDIFF(dd,0,GETDATE()))
						AND (DATEDIFF(dd,0,lg.AddedDate) = DATEDIFF(dd,0,GETDATE()))
						AND (lg.ReportedTo = 'AMEX')
					WHERE
						lg.Rerun = 0
				) data

			UNION ALL

			SELECT
				'T' AS [T1],
				(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_LEFT]('0',9,@RowCount)) AS [T2], 
				(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_LEFT]('',8,LEFT(@FormattedRunDate,8))) AS [T3],
				(SELECT * FROM [dbo].[func_FIXEDWIDTH_PAD_LEFT]('0',12,CONVERT(MONEY,ISNULL(@TotalAmount,0)))) AS [T4],
				SPACE(1350) AS [T5],
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
				3 AS [SortPosition]
			) results 
		ORDER BY
			SortPosition


END
GO
