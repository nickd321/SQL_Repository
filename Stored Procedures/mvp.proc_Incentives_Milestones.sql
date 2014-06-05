SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

/****************************************************************************************************
Report Title:	MVP IncentiveMilestones
Requestor:		
Date:			06/09/2011
Owner:			Nick Moore
Author:			Nick Moore

Objectives:		- 

Notes:			- 

Updates:		1/18/2012 Tom R.
                Per WO585.  Apparently, incentive data from the 2011 incentive year 
                got recalculated so the old records in our incentives tables were 
                expired and new records added.  So that 2011 data
                was showing up on this report for the period 1/1/2012 - 1/15/2012.
                Per discussion with Nick, I added
                two new filters on ActivityDate and IncentiveEffectiveDate.

				2/22/2012 - NICKM
				Added the ActivityItemID of 2401, so that e-coaching classes in the new incentive
				period are captured.
				
				2/27/2012 - TOMR
				We received a new version of the table
				HrlDw.dbo.UT_Lookup_MVPIncentiveMilestones
				so I update the coding. See WO689.
				
				3/8/2012 - TOMR 
				This generation (05) does not have code changes.  
				But I wanted to note that I created an ad hoc
				version of this report to fix the errors 
				found in WO730.  That fix is not needed for
				the production version.  See:\\cdr\cdr-dept\HS Research\Reports\Ad-hoc\(Tom)\MVP\WO730_Fix_MVP_IncentiveMilestones.sql
				
				10/30/2012 - WILLIAMPE
				Per WO1290, some of the activity for MemberID 16344724 did not show on the biweekly report.
				This was due to the fact that the activitydate was being used as a filter.  To correct the issue,
				I eliminated this filter, and also changed the RecordEffectiveBeginDate filter to be less than the @inEndDate.

				11/05/2013 - WilliamPe
				Added BCAT (CS2)
				
				04/18/2014 - WilliamPe
				Retired proc on HrlDw as the MVP Language lookup table was no longer needed (confirmed with the client).
				I modified the code to point directly to the Healthyroads database.
				
****************************************************************************************************/

CREATE PROCEDURE [mvp].[proc_Incentives_Milestones] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL

AS
BEGIN
	SET NOCOUNT ON;
	
	-- FOR TESTING
	-- DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

	-- DECLARES
	DECLARE @ClientIncentivePlanID VARCHAR(1000)
	
	-- SETS
	SET @inBeginDate = ISNULL(@inBeginDate, DATEADD(dd,-1,DATEADD(wk,DATEDIFF(wk,0,GETDATE())-2,0)))
	SET @inEndDate = ISNULL(@inEndDate, DATEADD(wk,2,@inBeginDate))

	SELECT
		@ClientIncentivePlanID = COALESCE(@ClientIncentivePlanID + ', ', '') + CAST(ClientIncentivePlanID AS VARCHAR(10))
	FROM
		(
		SELECT
			ClientIncentivePlanID
		FROM
			DA_Production.prod.GroupIncentivePlan WITH (NOLOCK)
		WHERE
			HealthPlanID = 71 AND
			@inBeginDate >= IncentiveBeginDate AND
			@inBeginDate < IncentiveEndDate
		GROUP BY
			ClientIncentivePlanID
		) cip

	-- CLEAN UP	
	IF OBJECT_ID('tempdb.dbo.#PlanHierarchy') IS NOT NULL
	BEGIN
		DROP TABLE #PlanHierarchy
	END

	IF OBJECT_ID('tempdb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END
	
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END
	
	-- PLAN HIERARCHY TEMP
	;WITH ActivityItemHierarchy_HRDS
		AS
		(
			SELECT
				cip.ClientIncentivePlanID,
				ip.IncentivePlanID,
				ap.ActivityPlanID,
				ap.ActivityItemID AS [PlanActivityItemID],
				ai.ActivityItemID,
				CAST(NULL AS INT) AS [ParentActivityItemID],			
				CAST(0 AS INT) AS [PlanLevel]
			FROM
				Healthyroads.dbo.IC_IncentivePlan ip WITH (NOLOCK)
			JOIN
				Healthyroads.dbo.IC_ClientIncentivePlan cip WITH (NOLOCK)
				ON	(ip.IncentivePlanID = cip.IncentivePlanID)
				AND	(cip.Deleted = 0)
			JOIN
				Healthyroads.dbo.IC_ActivityPlan ap WITH (NOLOCK) 
				ON	(ip.IncentivePlanID = ap.IncentivePlanID)
				AND	(ap.Deleted = 0)
			JOIN 
				Healthyroads.dbo.IC_ActivityItem ai WITH (NOLOCK) 
				ON	(ap.ActivityItemID = ai.ActivityItemID)
				AND	(ai.Deleted = 0)
			
		UNION ALL 

			SELECT
				aih.ClientIncentivePlanID,
				aih.IncentivePlanID,
				aih.ActivityPlanID,
				aih.PlanActivityItemID,
				ai.ActivityItemID,
				sai.ActivityItemID AS [ParentActivityItemID],			
				aih.PlanLevel + 1 AS [PlanLevel]
			FROM
				Healthyroads.dbo.IC_ActivityItem ai WITH (NOLOCK) 
			JOIN
				Healthyroads.dbo.IC_SubActivityItem sai WITH (NOLOCK)
				ON	(ai.ActivityItemID = sai.SubActivityItemID)
			JOIN
				ActivityItemHierarchy_HRDS aih
				ON	(sai.ActivityItemID = aih.ActivityItemID)
			WHERE
				ai.Deleted = 0
		)
	SELECT DISTINCT
		grp.HealthPlanID,
		--grp.GroupID,
		--clnt.ClientID,
		aih.ClientIncentivePlanID,
		aih.IncentivePlanID,
		aih.ActivityPlanID,
		aih.PlanActivityItemID,
		aih.PlanLevel,
		aih.ActivityItemID,
		aih.ParentActivityItemID,
		ai.ActivityItemOperator,
		'' AS [ActivityItemCode],
		ai.ActivityID,
		act.Name AS [ActivityName],
		act.[Description] AS [ActivityDescription],
		ai.OrderBy AS [AI_OrderBy],
		ai.Name AS [AI_Name],
		ai.Instruction AS [AI_Instruction],
		ai.StartDate AS [AI_Start],
		ai.EndDate AS [AI_End],
		ai.NumberOfDaysToComplete AS [AI_NumDaysToComplete],
		ai.IsRequired AS [AI_IsRequired],
		ai.IsRequiredStep AS [AI_IsRequiredStep],
		ai.IsActionItem AS [AI_IsActionItem],
		ai.IsHidden AS [AI_IsHidden],
		-1 AS [UnitID],
		'' AS [UnitName],	
		aiv.ActivityValue AS [AIV_ActivityValue],
		aiv.IsCount AS [AIV_IsCount],
		aic.ActivityValue AS [AIC_ActivityValue],
		aic.IsCount AS [AIC_IsCount],
		aic.CompareValue AS [AIC_CompareValue],
		aic.CompareOperator AS [AIC_CompareOperator],
		lim.MaxValue AS [AIL_MaxValue],
		lim.IsCount AS [AIL_IsCount],
		lim.TimePeriodID AS [AIL_TimePeriod],
		per.Name AS [TimePeriodName],
		bio.Pregnant AS [AIB_Pregnant],
		bio.Smoking AS [AIB_Smoking],
		bio.Fasting AS [AIB_Fasting],
		bio.ExamTypeCode AS [AIB_ExamTypeCode],
		CASE
			WHEN aiv.IsCount = 1 THEN 1
			ELSE 0
		END AS [IsActivity],
		CASE
			WHEN aiv.IsCount = 0 THEN 1
			ELSE 0
		END AS [IsPoints]
	INTO
		#PlanHierarchy
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.GroupIncentivePlan clnt WITH (NOLOCK)
		ON	(grp.GroupID = clnt.GroupID)
	JOIN
		ActivityItemHierarchy_HRDS aih
		ON	(clnt.ClientIncentivePlanID = aih.ClientIncentivePlanID)
	JOIN
		Healthyroads.dbo.IC_ActivityItem ai WITH (NOLOCK)
		ON	(aih.ActivityItemID = ai.ActivityItemID)
		AND	(ai.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_Activity act WITH (NOLOCK)
		ON	(ai.ActivityID = act.ActivityID)
		AND	(act.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemValue aiv WITH (NOLOCK)
		ON	(ai.ActivityItemID = aiv.ActivityItemID)
		AND	(aiv.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemComplete aic WITH (NOLOCK)
		ON	(ai.ActivityItemID = aic.ActivityItemID)
		AND	(aic.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemLimit lim WITH (NOLOCK)
		ON	(ai.ActivityItemID = lim.ActivityItemID)
		AND	(lim.Deleted = 0)
	LEFT JOIN
		Healthyroads.dbo.IC_TimePeriod per WITH (NOLOCK)
		ON	(lim.TimePeriodID = per.TimePeriodID)
	LEFT JOIN
		Healthyroads.dbo.IC_ActivityItemBiometric bio WITH (NOLOCK)
		ON	(ai.ActivityItemID = bio.ActivityItemID)
		AND	(bio.Deleted = 0)
	WHERE
		grp.HealthPlanID = 71 AND
		clnt.ClientIncentivePlanID IN (SELECT * FROM [DA_Reports].[dbo].[SPLIT] (@ClientIncentivePlanID,','))
	ORDER BY
		2,8,9

	-- GET PLAN INFORMATION
	SELECT
		DISTINCT -- THERE MAY BE A ONE TO MANY RELATIONSHIP TO THE ActivityItemValue TABLE (i.e. CompareValue column)
		hi.ClientIncentivePlanID,
		hi.PlanLevel,
		hi.ActivityItemID,
		hi.ParentActivityItemID, -- MORE THAN ONE PARENTACTIVITYITEMID IN SOME CASES
		hi.ActivityItemOperator,
		hi.ActivityName,
		hi.ActivityDescription,
		hi.AI_Name,
		hi.AI_Instruction,
		hi.AI_Start,
		hi.AI_End,
		hi.AI_NumDaysToComplete,
		hi.AI_IsRequired,
		hi.AI_IsRequiredStep,
		hi.AI_IsActionItem,
		hi.AI_IsHidden,
		--hi.AIV_ActivityValue, -- MORE THAN ONE ActivityValue IN SOME CASES
		hi.AIV_IsCount,
		hi.AIC_ActivityValue,
		hi.AIC_IsCount,
		hi.AIC_CompareValue,
		hi.AIL_MaxValue,
		hi.AIL_IsCount,
		hi.TimePeriodName,
		hi.IsActivity,
		hi.IsPoints
	INTO
		#PlanActivity
	FROM
		#PlanHierarchy hi

	SELECT
		mem.MemberID,
		grp.GroupNumber,
		cs.CS2 AS [BCAT],
		grp.GroupName,
		mem.AltID1 AS [GUID],
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		CONVERT(CHAR(10),mem.BirthDate,101) AS [DOB],
		mai.ClientIncentivePlanID,
		mai.MemberActivityItemID,
		mai.ActivityItemID,
		mai.ReferenceID,
		pln.AIV_IsCount,
		pln.AIC_CompareValue,
		pln.IsActivity,
		pln.IsPoints,
		mai.ActivityValue,
		pln.AIL_MaxValue,
		CASE
			WHEN pln.IsActivity = 1 THEN 0
			WHEN pln.AIC_CompareValue > 1 THEN 0
			ELSE mai.ActivityValue
		END AS [Points],
		CASE
			WHEN COALESCE(pln.AI_Instruction,pln.ActivityDescription) = 'E-Coaching Course'
			THEN COALESCE(pln.AI_Instruction,pln.ActivityDescription) + ': ' + mai.ReferenceID
			ELSE
				COALESCE
				(pln.AI_Instruction,
							pln.ActivityDescription,
								CASE
									WHEN cch.ParentActivityItemID IS NOT NULL 
									THEN COALESCE(cch.AI_Instruction,
														cch.ActivityDescription) + ' - ' + cch.AIC_CompareValue + ' calls' 
								END
				) 
		END AS [Activity],
		mai.ActivityDate,
		mai.AddDate AS [CreditDate]
	INTO
		#Incentive
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.HealthPlanID = 71)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		Healthyroads.dbo.IC_MemberActivityItem mai WITH (NOLOCK)
		ON	(mem.MemberID = mai.MemberID)
		AND	(mai.Deleted = 0)
	JOIN
		#PlanActivity pln
		ON	(mai.ActivityItemID = pln.ActivityItemID)
		AND	(mai.ClientIncentivePlanID = pln.ClientIncentivePlanID)
	LEFT JOIN
		#PlanActivity cch
		ON	(pln.ActivityItemID = cch.ParentActivityItemID)
		AND	(pln.ClientIncentivePlanID = cch.ClientIncentivePlanID)
		AND	(COALESCE(cch.AI_Instruction,cch.ActivityDescription) = 'Phone-Based Coaching Session')
	WHERE
		mai.AddDate >= @inBeginDate AND
		mai.AddDate < @inEndDate 
		
	SELECT
		GroupNumber AS [Employer Group ID],
		BCAT,
		GroupName AS [Employer Group Name],
		[GUID],
		EligMemberID AS [Member ID],
		EligMemberSuffix AS [Member Suffix],
		FirstName AS [First Name],
		LastName AS [Last Name],
		DOB,
		Activity AS [Milestone Completed],
		Points AS [Incentive Amount Based on Milestone],
		CONVERT(CHAR(10),ActivityDate,101) AS [Date Points Awarded],
		CONVERT(CHAR(10),GETDATE(),101) AS [File Creation Date]
	FROM
		#Incentive
	WHERE
		Points >= CASE WHEN Activity LIKE '%Phone%Coaching%' THEN 1 ELSE 0 END
	ORDER BY
		GroupName,
		LastName,
		FirstName,
		ActivityDate	

	-- CLEAN UP	
	IF OBJECT_ID('tempdb.dbo.#PlanHierarchy') IS NOT NULL
	BEGIN
		DROP TABLE #PlanHierarchy
	END

	IF OBJECT_ID('tempdb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END
	
	IF OBJECT_ID('tempdb.dbo.#Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Incentive
	END

END
GO
