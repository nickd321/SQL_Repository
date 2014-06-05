SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-03-12
-- Description:	GBC Incentives Reconciliation Report
--
--				EricH 20140529
--				CS1 and CS2 added Per WO3868
-- =============================================

CREATE PROCEDURE [gbc].[proc_Incentives_Reconciliation] 
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;
	
	
	-- FOR TESTING
	--DECLARE @inEndDate DATETIME
	
	-- DECLARES
	
	-- SETS
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))
	
	-- CLEAN UP
	IF OBJECT_ID('tempDb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

	IF OBJECT_ID('tempDb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END
	
	IF OBJECT_ID('tempDb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

	IF OBJECT_ID('tempDb.dbo.#MemberMet') IS NOT NULL
	BEGIN
		DROP TABLE #MemberMet
	END

	IF OBJECT_ID('tempDb.dbo.#FamilyMet') IS NOT NULL
	BEGIN
		DROP TABLE #FamilyMet
	END
	
	IF OBJECT_ID('tempdb.dbo.#Points') IS NOT NULL
	BEGIN
		DROP TABLE #Points
	END

	-- PLAN ACTIVITY TEMP
	SELECT
		DISTINCT -- THERE MAY BE A ONE TO MANY RELATIONSHIP TO THE ActivityItemValue TABLE (i.e. CompareValue column)
		pln.ClientIncentivePlanID,
		cipvr.ValidationRuleValue,
		cipvr.CompareValue AS [CS4],
		pln.PlanLevel,
		pln.ActivityItemID,
		pln.ParentActivityItemID,
		pln.ActivityItemOperator,
		pln.ActivityName,
		pln.ActivityDescription,
		pln.AI_Name,
		pln.AI_Instruction,
		pln.AI_Start,
		pln.AI_End,
		pln.AI_NumDaysToComplete,
		pln.AI_IsRequired,
		pln.AI_IsRequiredStep,
		pln.AI_IsActionItem,
		pln.AI_IsHidden,
		aiv.ActivityValue AS [AIV_ActivityValue],
		aiv.IsCount AS [AIV_IsCount],
		pln.AIC_ActivityValue,
		pln.AIC_CompareValue,
		aic.IsCount AS [AIC_IsCount],
		pln.AIL_MaxValue,
		pln.TimePeriodName,
		ail.IsCount AS [AIL_IsCount]
	INTO
		#PlanActivity
	FROM
		DA_Reports.incentives.PlanActivity pln WITH (NOLOCK)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemValue aiv WITH (NOLOCK)
		ON	(pln.ActivityItemID = aiv.ActivityItemID)
		AND	(aiv.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemComplete aic WITH (NOLOCK)
		ON	(pln.ActivityItemID = aic.ActivityItemID)
		AND	(aic.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemLimit ail WITH (NOLOCK)
		ON	(pln.ActivityItemID = ail.ActivityItemID)
		AND	(ail.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ClientIncentivePlanValidationRule cipvr WITH (NOLOCK)
		ON	(pln.ClientIncentivePlanID = cipvr.ClientIncentivePlanID)
		AND	(cipvr.Deleted = 0)
	WHERE
		pln.ClientIncentivePlanID IN (1250,1252,1254,1256)
		
	-- BASE POPULATION TEMP
	SELECT
		mem.MemberID,
		grp.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.SubscriberSSN AS [SSN],
		mem.FirstName,
		mem.MiddleInitial,
		mem.LastName,
		mem.RelationshipID,
		CASE WHEN mem.RelationshipID IN (1,2) THEN 1 ELSE 0 END AS [IsSpouse],
		addr.Address1,
		addr.Address2,
		addr.City,
		addr.[State],
		addr.ZipCode,
		mem.Birthdate,
		elig.EffectiveDate,
		elig.TerminationDate,
		cs.CS3 AS [MedicalIndicator],
		cs.CS4 AS [IncentiveOption],
		CASE
			cs.CS4
			WHEN '1' THEN 1250
			WHEN '2' THEN 1256
			WHEN '5' THEN 1254
			WHEN '6' THEN 1252
		END AS ClientIncentivePlanID,
		CASE
			WHEN ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0)
			THEN 1
			ELSE 0
		END AS [IsCurrentlyEligible],
		cs.cs1 as 'LocationCode',
		cs.cs2 as 'PayCode'
	INTO
		#Base
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 194461)
	JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
		AND	(cs.CS4 IN ('1','2','5','6'))
		AND	(cs.CS3 = 'MED')
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
			DA_Production.prod.Eligibility
		WHERE
			GroupID = 194461
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)
		
	-- INCENTIVE ACTIVITY TEMP
	SELECT
		*,
		ROW_NUMBER() OVER (PARTITION BY MemberID, Activity ORDER BY ActivityDate, CreditDate) AS ActivitySeq,
		CASE WHEN ActivityValue != AIL_MaxValue THEN ROW_NUMBER() OVER (PARTITION BY MemberID, Activity, ActivityDate, CreditDate ORDER BY ActivityDate, CreditDate) ELSE 0 END AS MultipleActivitySeq
	INTO
		#Incentive
	FROM
		(
		SELECT 
			-- THERE MAY BE A ONE TO MANY RELATIONSHIP BETWEEN Healthyroads.dbo.IC_MemberActivityItem AND #PlanActivity
			-- (EX: 50 point value and 100 point value for quarter steps)
			DISTINCT
			mem.MemberID,
			prm.EligMemberID AS [EE_EligMemberID],
			prm.SSN AS [EE_SSN],
			prm.FirstName AS [EE_FirstName],
			prm.MiddleInitial AS [EE_MiddleInitial],
			prm.LastName AS [EE_LastName],
			prm.Address1 AS [EE_Addr1],
			prm.Address2 AS [EE_Addr2],
			prm.City AS [EE_City],
			prm.[State] AS [EE_State],
			prm.ZipCode AS [EE_ZipCode],
			prm.Birthdate AS [EE_Birthdate],
			prm.EffectiveDate AS [EE_EnrollmentDate],
			prm.TerminationDate AS [EE_TerminationDate],
			prm.IncentiveOption AS [EE_IncentivePlan],
			prm.MedicalIndicator AS [EE_Medical],
			CASE WHEN sps.MemberID IS NOT NULL THEN 1 ELSE 0 END AS [HasSpouse],
			mem.IsSpouse,
			sps.FirstName AS [SP_FirstName],
			sps.MiddleInitial AS [SP_MiddleInitial],
			sps.LastName AS [SP_LastName],
			sps.EffectiveDate AS [SP_EnrollmentDate],
			sps.TerminationDate AS [SP_TerminationDate],
			sps.IncentiveOption AS [SP_IncentivePlan],
			sps.MedicalIndicator AS [SP_Medical],
			mai.ClientIncentivePlanID,
			mai.MemberActivityItemID,
			mai.ActivityItemID,
			pln.AIV_IsCount,
			pln.AIC_CompareValue,
			mem.LocationCode,
			mem.paycode,
			CASE
				WHEN pln.AIV_IsCount = 1 THEN 1
				ELSE 0
			END AS [IsActivity],
			CASE
				WHEN pln.AIV_IsCount = 0 THEN 1
				ELSE 0
			END AS [IsPoints],
			mai.ActivityValue,
			pln.AIL_MaxValue,
			CASE
				WHEN pln.AIV_IsCount = 1 THEN 0 
				WHEN pln.AIC_CompareValue > 1 THEN 0 
				ELSE mai.ActivityValue
			END AS [Points],
			COALESCE(pln.AI_Instruction,pln.ActivityDescription,CASE WHEN cont.ActivityItemID IS NOT NULL THEN ISNULL(cont.AI_Instruction,cont.ActivityDescription) END) AS [Activity],
			mai.ActivityDate,
			mai.AddDate AS [CreditDate]
		FROM
			#Base mem
		JOIN
			#Base prm
			ON	(mem.EligMemberID = prm.EligMemberID)
			AND	(prm.IsSpouse = 0)
			AND	(prm.IsCurrentlyEligible = 1)
		LEFT JOIN
			#Base sps
			ON	(mem.EligMemberID = sps.EligMemberID)
			AND	(sps.IsSpouse = 1)
			AND	(sps.IsCurrentlyEligible = 1)
		JOIN
			Healthyroads.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
			ON	(mem.MemberID = mai.MemberID)
			AND	(mem.ClientIncentivePlanID = mai.ClientIncentivePlanID)
			AND	(mai.Deleted = 0)
		JOIN
			#PlanActivity pln
			ON	(mai.ActivityItemID = pln.ActivityItemID)
			AND	(mai.ClientIncentivePlanID = pln.ClientIncentivePlanID)
		LEFT JOIN
			#PlanActivity cont
			ON	(pln.ActivityItemID = cont.ParentActivityItemID)
		WHERE
			mem.IsCurrentlyEligible = 1 AND
			pln.AIL_MaxValue IS NOT NULL -- LIMIT TO ONLY CREDIT ActivityItem(s)
		) data
	WHERE
		CreditDate < @inEndDate
		
	-- DELETE DUPLICATE RECORDS
	DELETE #Incentive
	WHERE
		(ActivitySeq != 1 AND MultipleActivitySeq = 0) OR
		(MultipleActivitySeq > 1)
		

	-- MEMBER MET 
	SELECT
		ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY CreditDate) AS [RowID],
		MemberID,
		EE_EligMemberID,
		HasSpouse,
		IsSpouse,
		Activity,
		ActivityDate,
		CreditDate,
		MetValue,
		NULL AS [RunningTotal]
	INTO 
		#MemberMet
	FROM 
		(
		SELECT
			MemberID,
			EE_EligMemberID,
			HasSpouse,
			IsSpouse,
			Activity,
			ActivityDate,
			CreditDate,
			100 AS 'MetValue'
		FROM
			#Incentive pha
		WHERE
			Activity = 'Personal Health Assessment (Primary)'
		
		UNION ALL
		
		SELECT
			MemberID,
			EE_EligMemberID,
			HasSpouse,
			IsSpouse,
			Activity,
			ActivityDate,
			CreditDate,
			100 AS 'MetValue'
		FROM
			#Incentive pha
		WHERE
			Activity = 'Biometrics Screening'
		) act

	-- ENSURE THE DATA IS PHYSICALLY ORDERED THE WAY WE WANT, SO THE UPDATE WORKS
	-- AS NEEDED
	CREATE UNIQUE CLUSTERED INDEX idx_temp_MemberMet
	ON #MemberMet (MemberID, RowID)


	-- CREATE A VARIABLE THAT WILL BE USED THROUGHOUT THE UPDATE
	DECLARE 
		@RunningTotal INT
	SET 
		@RunningTotal = 0

	-- THIS UPDATE WILL OCCUR IN THE ORDER OF EARLIEST TO LATEST DATES PER MEMBER
	-- FOR EACH ROW, THE RUNNING TOTAL WILL BE UPDATED ON THE WORKING TABLE
	-- AND THE VARIABLE WILL BE RECALCULATED		

	UPDATE 
		#MemberMet
	SET 
		@RunningTotal = RunningTotal = MetValue + CASE WHEN RowID = 1 THEN 0 ELSE @RunningTotal END
	FROM 
		#MemberMet

	-- FAMILY MET 
	SELECT
		ROW_NUMBER() OVER (PARTITION BY EE_EligMemberID ORDER BY CreditDate) AS [RowID],
		MemberID,
		EE_EligMemberID,
		HasSpouse,
		IsSpouse,
		Activity,
		ActivityDate,
		CreditDate,
		MetValue,
		NULL AS [RunningTotal]
	INTO 
		#FamilyMet
	FROM 
		(
		SELECT
			MemberID,
			EE_EligMemberID,
			HasSpouse,
			IsSpouse,
			Activity,
			ActivityDate,
			CreditDate,
			100 AS 'MetValue'
		FROM
			#Incentive pha
		WHERE
			Activity = 'Personal Health Assessment (Primary)'
		
		UNION ALL
		
		SELECT
			MemberID,
			EE_EligMemberID,
			HasSpouse,
			IsSpouse,
			Activity,
			ActivityDate,
			CreditDate,
			100 AS 'MetValue'
		FROM
			#Incentive pha
		WHERE
			Activity = 'Biometrics Screening'
		) act

	-- ENSURE THE DATA IS PHYSICALLY ORDERED THE WAY WE WANT, SO THE UPDATE WORKS
	-- AS NEEDED
	CREATE UNIQUE CLUSTERED INDEX idx_temp_FamilyMet
	ON #FamilyMet (EE_EligMemberID, RowID)


	-- CREATE A VARIABLE THAT WILL BE USED THROUGHOUT THE UPDATE
	DECLARE 
		@FamilyTotal INT
	SET 
		@FamilyTotal = 0

	-- THIS UPDATE WILL OCCUR IN THE ORDER OF EARLIEST TO LATEST DATES PER MEMBER
	-- FOR EACH ROW, THE RUNNING TOTAL WILL BE UPDATED ON THE WORKING TABLE
	-- AND THE VARIABLE WILL BE RECALCULATED		

	UPDATE 
		#FamilyMet
	SET 
		@FamilyTotal = RunningTotal = MetValue + CASE WHEN RowID = 1 THEN 0 ELSE @FamilyTotal END
	FROM 
		#FamilyMet
		
	-- SUMMARY
	SELECT
		ISNULL(inc.EE_SSN,'') AS [EE_ID],
		inc.EE_Firstname,
		ISNULL(inc.EE_MiddleInitial,'') AS [EE_MiddleInitial],
		inc.EE_LastName,
		inc.LocationCode,
		inc.PayCode,
		ISNULL(inc.EE_Addr1,'') AS [EE_Addr1],
		ISNULL(inc.EE_Addr2,'') AS [EE_Addr2],
		ISNULL(inc.EE_City,'') AS [EE_City],
		ISNULL(inc.EE_State,'') AS [EE_State],
		ISNULL(inc.EE_ZipCode,'') AS [EE_ZipCode],
		ISNULL(CONVERT(VARCHAR(10),inc.EE_Birthdate,101),'') AS [EE_Birthdate],
		CONVERT(VARCHAR(10),inc.EE_EnrollmentDate,101) AS [EE_EnrollmentDate],
		ISNULL(CONVERT(VARCHAR(10),inc.EE_TerminationDate,101),'') AS [EE_TerminationDate],
		inc.EE_IncentivePlan,
		inc.EE_Medical,
		inc.HasSpouse,
		ISNULL(inc.SP_FirstName,'') AS [SP_FirstName],
		ISNULL(inc.SP_MiddleInitial,'') AS [SP_MiddleInitial],
		ISNULL(inc.SP_LastName,'') AS [SP_LastName],
		ISNULL(CONVERT(VARCHAR(10),inc.SP_EnrollmentDate,101),'') AS [SP_EnrollmentDate],
		ISNULL(CONVERT(VARCHAR(10),inc.SP_TerminationDate,101),'') AS [SP_TerminationDate],
		ISNULL(CAST(inc.SP_IncentivePlan AS VARCHAR),'') AS [SP_IncentivePlan],
		ISNULL(CAST(inc.SP_Medical AS VARCHAR),'') AS [SP_Medical],
		ISNULL(CONVERT(VARCHAR(10),emp.EE_EarnedDate,101),'') AS [EE_EarnedDate],
		ISNULL(CONVERT(VARCHAR(10),sps.SP_EarnedDate,101),'') AS [SP_EarnedDate],
		ISNULL(CONVERT(VARCHAR(10),fam.Fam_EarnedDate,101),'') AS [FAM_EarnedDate],
		CASE
			WHEN inc.HasSpouse = 0 AND emp.EE_EarnedDate IS NOT NULL THEN CAST(emppts.EE_Points AS VARCHAR)
			WHEN inc.HasSpouse = 1 AND fam.FAM_EarnedDate IS NOT NULL THEN CAST(emppts.EE_Points AS VARCHAR)
			ELSE ''
		END AS [EE_Points],
		CASE
			WHEN inc.HasSpouse = 1 AND fam.FAM_EarnedDate IS NOT NULL THEN CAST(spspts.SP_Points AS VARCHAR)
			ELSE ''
		END AS [SP_Points],
		CASE
			WHEN inc.HasSpouse = 0 AND emp.EE_EarnedDate IS NOT NULL THEN CAST(totpts.Total_Points AS VARCHAR) 
			WHEN inc.HasSpouse = 1 AND fam.FAM_EarnedDate IS NOT NULL THEN CAST(totpts.Total_Points AS VARCHAR)
			ELSE ''
		END AS [FTotal_Points]
					
	FROM
		#Incentive inc
	LEFT JOIN
		(
		SELECT
			EE_EligMemberID,
			MemberID,
			CreditDate AS 'EE_EarnedDate'
		FROM
			#MemberMet
		WHERE
			IsSpouse = 0 AND
			RunningTotal = 200
		) emp
		ON	(inc.EE_EligMemberID = emp.EE_EligMemberID)
	LEFT JOIN
		(
		SELECT
			EE_EligMemberID,
			MemberID,
			CreditDate AS 'SP_EarnedDate'
		FROM
			#MemberMet
		WHERE
			IsSpouse = 1 AND
			RunningTotal = 200
		) sps
		ON	(inc.EE_EligMemberID = sps.EE_EligMemberID)
	LEFT JOIN
		(
		SELECT
			EE_EligMemberID,
			MemberID,
			CreditDate AS 'FAM_EarnedDate'
		FROM
			#FamilyMet
		WHERE
			HasSpouse = 1 AND
			RunningTotal = 400
		) fam
		ON	(inc.EE_EligMemberID = fam.EE_EligMemberID)
	LEFT JOIN
		(
		SELECT
			EE_EligMemberID,
			MemberID,
			SUM(Points) AS 'EE_Points'
		FROM
			#Incentive
		WHERE
			IsSpouse = 0
		GROUP BY
			EE_EligMemberID,
			MemberID
		) emppts
		ON	(inc.EE_EligMemberID = emppts.EE_EligMemberID)
	LEFT JOIN
		(
		SELECT
			EE_EligMemberID,
			MemberID,
			SUM(Points) AS 'SP_Points'
		FROM
			#Incentive
		WHERE
			IsSpouse = 1
		GROUP BY
			EE_EligMemberID,
			MemberID
		) spspts
		ON	(inc.EE_EligMemberID = spspts.EE_EligMemberID)
	LEFT JOIN
		(
		SELECT
			EE_EligMemberID,
			SUM(Points) AS 'Total_Points'
		FROM
			#Incentive
		GROUP BY
			EE_EligMemberID
		) totpts
		ON	(inc.EE_EligMemberID = totpts.EE_EligMemberID)
	GROUP BY
		ISNULL(inc.EE_SSN,''),
		inc.EE_Firstname,
		ISNULL(inc.EE_MiddleInitial,''),
		inc.EE_LastName,
		ISNULL(inc.EE_Addr1,''),
		ISNULL(inc.EE_Addr2,''),
		ISNULL(inc.EE_City,''),
		ISNULL(inc.EE_State,''),
		ISNULL(inc.EE_ZipCode,''),
		ISNULL(CONVERT(VARCHAR(10),inc.EE_Birthdate,101),''),
		CONVERT(VARCHAR(10),inc.EE_EnrollmentDate,101),
		ISNULL(CONVERT(VARCHAR(10),inc.EE_TerminationDate,101),''),
		inc.EE_IncentivePlan,
		inc.EE_Medical,
		inc.HasSpouse,
		ISNULL(inc.SP_FirstName,''),
		ISNULL(inc.SP_MiddleInitial,''),
		ISNULL(inc.SP_LastName,''),
		ISNULL(CONVERT(VARCHAR(10),inc.SP_EnrollmentDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),inc.SP_TerminationDate,101),''),
		ISNULL(CAST(inc.SP_IncentivePlan AS VARCHAR),''),
		ISNULL(CAST(inc.SP_Medical AS VARCHAR),''),
		ISNULL(CONVERT(VARCHAR(10),emp.EE_EarnedDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),sps.SP_EarnedDate,101),''),
		ISNULL(CONVERT(VARCHAR(10),fam.Fam_EarnedDate,101),''),
		CASE
			WHEN inc.HasSpouse = 0 AND emp.EE_EarnedDate IS NOT NULL THEN CAST(emppts.EE_Points AS VARCHAR)
			WHEN inc.HasSpouse = 1 AND fam.FAM_EarnedDate IS NOT NULL THEN CAST(emppts.EE_Points AS VARCHAR)
			ELSE ''
		END,
		CASE
			WHEN inc.HasSpouse = 1 AND fam.FAM_EarnedDate IS NOT NULL THEN CAST(spspts.SP_Points AS VARCHAR)
			ELSE ''
		END,
		CASE
			WHEN inc.HasSpouse = 0 AND emp.EE_EarnedDate IS NOT NULL THEN CAST(totpts.Total_Points AS VARCHAR) 
			WHEN inc.HasSpouse = 1 AND fam.FAM_EarnedDate IS NOT NULL THEN CAST(totpts.Total_Points AS VARCHAR)
			ELSE ''
		END,
		inc.LocationCode,
		inc.PayCode

	-- DETAIL
	SELECT
		ISNULL(inc.EE_SSN,'') AS [EE_ID],
		inc.EE_Firstname,
		ISNULL(inc.EE_MiddleInitial,'') AS [EE_MiddleInitial],
		inc.EE_LastName,
		inc.LocationCode,
		inc.PayCode,
		ISNULL(inc.EE_Addr1,'') AS [EE_Addr1],
		ISNULL(inc.EE_Addr2,'') AS [EE_Addr2],
		ISNULL(inc.EE_City,'') AS [EE_City],
		ISNULL(inc.EE_State,'') AS [EE_State],
		ISNULL(inc.EE_ZipCode,'') AS [EE_ZipCode],
		ISNULL(CONVERT(VARCHAR(10),inc.EE_Birthdate,101),'') AS [EE_Birthdate],
		CONVERT(VARCHAR(10),inc.EE_EnrollmentDate,101) AS [EE_EnrollmentDate],
		ISNULL(CONVERT(VARCHAR(10),inc.EE_TerminationDate,101),'') AS [EE_TerminationDate],
		inc.EE_IncentivePlan,
		inc.EE_Medical,
		inc.HasSpouse,
		ISNULL(inc.SP_FirstName,'') AS [SP_FirstName],
		ISNULL(inc.SP_MiddleInitial,'') AS [SP_MiddleInitial],
		ISNULL(inc.SP_LastName,'') AS [SP_LastName],
		ISNULL(CONVERT(VARCHAR(10),inc.SP_EnrollmentDate,101),'') AS [SP_EnrollmentDate],
		ISNULL(CONVERT(VARCHAR(10),inc.SP_TerminationDate,101),'') AS [SP_TerminationDate],
		ISNULL(CAST(inc.SP_IncentivePlan AS VARCHAR),'') AS [SP_IncentivePlan],
		ISNULL(CAST(inc.SP_Medical AS VARCHAR),'') AS [SP_Medical],
		CASE WHEN inc.IsSpouse = 1 THEN 'Y' ELSE '' END AS [IsSpouseRecord],
		inc.Points,
		inc.Activity,
		CONVERT(VARCHAR(10),inc.ActivityDate,101) AS [ActivityDate],
		CONVERT(VARCHAR(10),inc.CreditDate,101) AS [CreditDate]	
	FROM
		#Incentive inc
	ORDER BY
		1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27	
END
GO
