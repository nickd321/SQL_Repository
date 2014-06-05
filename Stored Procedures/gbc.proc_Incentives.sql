SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-03-12
-- Description:	GBC Incentives Report to UHC
--
-- Updates:		WilliamPe 20140318
--				Updated code to change column M20 to '20140101' (New Incentive Plan Year.
--				Also, I added a case statement to change the effective date of a member 
--				if it is less than this year's incentive plan start date ('2014-01-01').
--				The effective date is passed in a couple places and is referred to as enrollment 
--				date in the final query.
--
-- =============================================

CREATE PROCEDURE [gbc].[proc_Incentives] 
	@inBeginDate DATETIME = NULL, 
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;
	
	
	-- FOR TESTING
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME
	
	-- DECLARES
	
	-- SETS
	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
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

	IF OBJECT_ID('tempDb.dbo.#Met') IS NOT NULL
	BEGIN
		DROP TABLE #Met
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
		END AS [IsCurrentlyEligible]
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
			-- MEMBER INFO
			mem.MemberID,
			-- PRIMARY INFO
			prm.EligMemberID,
			prm.SSN,
			prm.FirstName,
			prm.MiddleInitial,
			prm.LastName,
			prm.Address1,
			prm.Address2,
			prm.City,
			prm.[State],
			prm.ZipCode,
			prm.Birthdate,
			prm.EffectiveDate,
			prm.TerminationDate,
			CASE WHEN sps.MemberID IS NOT NULL THEN 1 ELSE 0 END AS [HasSpouse],
			-- MEMBER INFO
			mem.IsSpouse,
			mem.MedicalIndicator,
			mem.IncentiveOption,
			mai.ClientIncentivePlanID,
			mai.MemberActivityItemID,
			mai.ActivityItemID,
			pln.AIV_IsCount,
			pln.AIC_CompareValue,
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
			pln.AIL_MaxValue IS NOT NULL -- LIMIT TO ONLY CREDIT ActivityItem (s)
		) data
		
	-- DELETE DUPLICATE RECORDS
	DELETE #Incentive
	WHERE
		(ActivitySeq != 1 AND MultipleActivitySeq = 0) OR
		(MultipleActivitySeq > 1)

	-- THIS TEMP TABLE WILL BE USED TO DETERMINE THE DATE THE MEMBER MET THE GATE TO ENTRY
	SELECT
		ROW_NUMBER() OVER (PARTITION BY EligMemberID ORDER BY CreditDate) AS [RowID],
		MemberID,
		EligMemberID,
		HasSpouse,
		IsSpouse,
		Activity,
		ActivityDate,
		CreditDate,
		MetValue,
		NULL AS [RunningTotal]
	INTO 
		#Met
	FROM 
		(
		SELECT
			MemberID,
			EligMemberID,
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
			EligMemberID,
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
	CREATE UNIQUE CLUSTERED INDEX idx_temp_Met
	ON #Met (EligMemberID, RowID)


	-- CREATE A VARIABLE THAT WILL BE USED THROUGHOUT THE UPDATE
	DECLARE 
		@RunningTotal INT
	SET 
		@RunningTotal = 0

	-- THIS UPDATE WILL OCCUR IN THE ORDER OF EARLIEST TO LATEST DATES PER MEMBER
	-- FOR EACH ROW, THE RUNNING TOTAL WILL BE UPDATED ON THE WORKING TABLE
	-- AND THE VARIABLE WILL BE RECALCULATED		

	UPDATE 
		#Met
	SET 
		@RunningTotal = RunningTotal = MetValue + CASE WHEN RowID = 1 THEN 0 ELSE @RunningTotal END
	FROM 
		#Met

	-- POINTS EARNED TEMP
	SELECT
		ISNULL(SSN,'') AS [EmployeeID],
		FirstName AS [MemberFirstName],
		LastName AS [MemberLastName],
		ISNULL(MiddleInitial,'') AS [MemberMiddleInitial],
		ISNULL(Address1,'') AS [PermanentStreetAddress1],
		ISNULL(Address2,'') AS [PermanentStreetAddress2],
		ISNULL(City,'') AS [PermanentCity],
		ISNULL([State],'') AS [PermanentState],
		ISNULL(ZipCode,'') AS [PermanentZipCode],
		ISNULL(CONVERT(CHAR(8),BirthDate,112),'') AS [MemberBirthDate],
		CONVERT(CHAR(8),CASE WHEN EffectiveDate < '2014-01-01' THEN '2014-01-01' ELSE EffectiveDate END,112) AS [EnrollmentDate],
		ISNULL(CONVERT(CHAR(8),TerminationDate,112),'') AS [TerminationDate],
		SUM(Points) AS [Points]
	INTO
		#Points
	FROM
		(
		SELECT
			inc.MemberID,
			inc.SSN,
			inc.FirstName,
			inc.LastName,
			inc.MiddleInitial,
			inc.Address1,
			inc.Address2,
			inc.City,
			inc.[State],
			inc.ZipCode,
			inc.BirthDate,
			inc.EffectiveDate,
			inc.TerminationDate,
			inc.Activity,
			inc.ActivityDate,
			inc.CreditDate,
			earn.ReqsEarnedDate,
			CASE
				WHEN inc.CreditDate < earn.ReqsEarnedDate 
				THEN earn.ReqsEarnedDate
				ELSE inc.CreditDate
			END AS [PointsEarnedDate],
			inc.Points
		FROM
			#Incentive inc
		JOIN
			(
			SELECT
				EligMemberID,
				CreditDate AS 'ReqsEarnedDate'
			FROM
				#Met
			WHERE
				RunningTotal = 200 AND
				HasSpouse = 0
			
			UNION ALL
			
			SELECT
				EligMemberID,
				CreditDate AS 'ReqsEarnedDate'
			FROM
				#Met
			WHERE
				RunningTotal = 400 AND
				HasSpouse = 1
			) earn
			ON	(inc.EligMemberID = earn.EligMemberID)
		) data
	WHERE
		PointsEarnedDate >= @inBeginDate AND
		PointsEarnedDate < @inEndDate
	GROUP BY
		ISNULL(SSN,''),
		FirstName,
		LastName,
		ISNULL(MiddleInitial,''),
		ISNULL(Address1,''),
		ISNULL(Address2,''),
		ISNULL(City,''),
		ISNULL([State],''),
		ISNULL(ZipCode,''),
		ISNULL(CONVERT(CHAR(8),BirthDate,112),''),
		CONVERT(CHAR(8),CASE WHEN EffectiveDate < '2014-01-01' THEN '2014-01-01' ELSE EffectiveDate END,112),
		ISNULL(CONVERT(CHAR(8),TerminationDate,112),'')
	HAVING
		SUM(Points) > 0

	-- RECORD COUNT
	DECLARE
		@RecordCount INT
	
	SELECT
		@RecordCount = COUNT(EmployeeID)
	FROM
		#Points
		
	
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
		[H28],
		[H29],
		[H30],
		[H31],
		[H32],
		[H33],
		[H34],
		[H35],
		[H36],
		[H37],
		[H38],
		[H39],
		[H40],
		[H41],
		[H42],
		[H43],
		[H44],
		[H45],
		[H46],
		[H47],
		[H48],
		[H49],
		[H50],
		[H51],
		[H52],
		[H53]
	FROM
		(	
		-- HEADER
		SELECT
			REPLICATE('0',19) AS [H1], 
			'6' AS [H2], 
			'FSA' AS [H3], 
			'5426' AS [H4], 
			'GLOBRA02' AS [H5], 
			'001' AS [H6], 
			CONVERT(CHAR(8),GETDATE(),112) AS [H7], 
			'730563111' AS [H8], 
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',30,'Global Brass and Copper')) AS [H9], 
			'M' + CONVERT(CHAR(2),GETDATE(),101) AS [H10], 
			'0730563' AS [H11],
			'PROD' AS [H12],
			SPACE(1) AS [H13],
			SPACE(400) AS [H14],
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
			'' AS [H29],
			'' AS [H30],
			'' AS [H31],
			'' AS [H32],
			'' AS [H33],
			'' AS [H34],
			'' AS [H35],
			'' AS [H36],
			'' AS [H37],
			'' AS [H38],
			'' AS [H39],
			'' AS [H40],
			'' AS [H41],
			'' AS [H42],
			'' AS [H43],
			'' AS [H44],
			'' AS [H45],
			'' AS [H46],
			'' AS [H47],
			'' AS [H48],
			'' AS [H49],
			'' AS [H50],
			'' AS [H51],
			'' AS [H52],
			'' AS [H53],
			1 AS [Sort]
		
		UNION ALL
		
		-- MEMBER RECORDS
		SELECT
			SPACE(1) AS [M1],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',9,EmployeeID)) AS [M2],
			REPLICATE('0',9) AS [M3],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',30,MemberLastName)) AS [M4],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',14,MemberFirstName)) AS [M5],
			SPACE(1) AS [M6],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',1,MemberMiddleInitial)) AS [M7],
			SPACE(4) AS [M8],
			SPACE(4) AS [M9],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',30,PermanentStreetAddress1)) AS [M10],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',30,PermanentStreetAddress2)) AS [M11],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',15,PermanentCity)) AS [M12], 
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',2,PermanentState)) AS [M13], 
			SPACE(15) AS [M14],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',9,PermanentZipCode)) AS [M15], 
			SPACE(1) AS [M16], 
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',8,MemberBirthDate)) AS [M17],
			'0730563' AS [M18], 
			'0001' AS [M19], 
			'20140101' AS [M20], 
			SPACE(4) AS [M21], 
			SPACE(4) AS [M22], 
			SPACE(4) AS [M23], 
			SPACE(4) AS [M24],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',8,EnrollmentDate)) AS [M25], 
			SPACE(11) AS [M26], 
			'MED' AS [M27], 
			'E' AS [M28], 
			'+' AS [M29],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_LEFT('0',7,CONVERT(VARCHAR(4),Points) + REPLICATE('0',2))) AS [M30],
			SPACE(3) AS [M31], 
			SPACE(1) AS [M32], 
			SPACE(1) AS [M33], 
			SPACE(7) AS [M34], 
			SPACE(3) AS [M35], 
			SPACE(1) AS [M36], 
			SPACE(1) AS [M37], 
			SPACE(7) AS [M38], 
			SPACE(3) AS [M39], 
			SPACE(1) AS [M40], 
			SPACE(1) AS [M41], 
			SPACE(7) AS [M42], 
			SPACE(8) AS [M43], 
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',8,TerminationDate)) AS [M44],
			SPACE(1) AS [M45],
			SPACE(7) AS [M46],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_RIGHT('',8,EnrollmentDate)) AS [M47],
			SPACE(152) AS [M48],
			SPACE(1) AS [M49],
			SPACE(7) AS [M50],
			SPACE(8) AS [M51],
			SPACE(8) AS [M52],
			SPACE(7) AS [M53],
			2 AS [Sort]
		FROM
			#Points
		
		UNION ALL
		
		-- TRAILER RECORD
		SELECT
			REPLICATE('9',20) AS [T1],
			(SELECT * FROM DA_Reports.dbo.func_FIXEDWIDTH_PAD_LEFT('0',6,CONVERT(VARCHAR(6),@RecordCount))) AS [T2],
			SPACE(1) AS [T3],
			SPACE(10) AS [T4],
			SPACE(1) AS [T5],
			SPACE(10) AS [T6],
			SPACE(10) AS [T7],
			SPACE(10) AS [T8],
			SPACE(432) AS [T9],
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
			'' AS [T51],
			'' AS [T52],
			'' AS [T53],
			3 AS [Sort]
		) data
	ORDER BY
		Sort

END
GO
