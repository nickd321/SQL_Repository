SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-05
-- Description:	[incentives].[proc_TableLoad_PlanActivity] table load
--
-- Notes:		This is at the ActivityItem grain. I am using this table
--				as a reference for the Providence and PepsiCo reports.
--				This proc will be used to load the data daily and notify 
--				me if there were any new records inserted or updated.
--
-- Updates:		WilliamPe 20140310
--				Added GBC (Old Framework)		
--				
--				WilliamPe 20140314
--				Added CTCA (Old Framework)	
--
--				WilliamPe 20140324
--				Added Trizetto (Old Framework)	
--
-- =============================================

CREATE PROCEDURE [incentives].[proc_TableLoad_PlanActivity] 

AS
BEGIN

	SET NOCOUNT ON;

-- CLEAN UP
	IF OBJECT_ID('tempDb.dbo.#PlanActivity_HealthyRoads') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity_HealthyRoads
	END

	IF OBJECT_ID('tempDb.dbo.#Client_Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Client_Incentive
	END

	IF OBJECT_ID('tempDb.dbo.#PlanActivity_Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity_Incentive
	END

	IF OBJECT_ID('tempDb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END



/******************************************************************/
-- INSERT PLAN ACTIVITY TEMP SOURCING FROM HEALTHYROADS DATABASE --
/******************************************************************/
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

	SELECT
		grp.HealthPlanID,
		grp.GroupID,
		clnt.ClientID,
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
		aic.ActivityValue AS [AIC_ActivityValue],
		aic.CompareValue AS [AIC_CompareValue],
		aic.CompareOperator AS [AIC_CompareOperator],
		lim.MaxValue AS [AIL_MaxValue],
		lim.TimePeriodID AS [AIL_TimePeriod],
		per.Name AS [TimePeriodName],
		bio.Pregnant AS [AIB_Pregnant],
		bio.Smoking AS [AIB_Smoking],
		bio.Fasting AS [AIB_Fasting],
		bio.ExamTypeCode AS [AIB_ExamTypeCode]
	INTO
		#PlanActivity_Healthyroads
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
		-- PROVIDENCE
		(
		 grp.GroupID = 173174 AND 
		 clnt.IncentiveBeginDate >= '2013-09-01'
		)
		OR
		-- GBC
		(
		 grp.GroupID = 194461 AND
		 clnt.IncentiveBeginDate >= '2014-01-01'
		)
		OR
		-- CTCA
		(
		 grp.GroupID = 191393 AND
		 clnt.IncentiveBeginDate >= '2013-09-01'
		)
		OR
		-- Trizetto
		(
		 grp.GroupID = 194354 AND
		 clnt.IncentiveBeginDate >= '2014-01-01'
		)

/******************************************************************/
-- INSERT PLAN ACTIVITY TEMP SOURCING FROM INCENTIVE DATABASE    --
/******************************************************************/

	SELECT
		hpg.HealthPlanID,
		hpg.GroupID,
		clnt.ClientID
	INTO
		#Client_Incentive
	FROM
		Incentive.dbo.IC_Client clnt WITH (NOLOCK)
	JOIN
		DA_Production.prod.HealthPlanGroup hpg WITH (NOLOCK)
		ON	(clnt.ClientValue =
				CASE clnt.ClientTypeID
					WHEN 1 THEN CAST(hpg.GroupID AS VARCHAR)
					WHEN 2 THEN CAST(hpg.EligPlanID AS VARCHAR) + '-' + hpg.GroupNumber
					WHEN 3 THEN CAST(hpg.HealthPlanID AS VARCHAR)
					WHEN 4 THEN CAST(hpg.EligPlanID AS VARCHAR)
				END)
		AND	(clnt.ClientTypeID IN (1,2,3,4))
		AND	(clnt.Deleted = 0)

	UNION

	SELECT
		gben.HealthPlanID,
		gben.GroupID,
		clnt.ClientID
	FROM
		Incentive.dbo.IC_Client clnt WITH (NOLOCK)
	JOIN
		DA_Production.prod.GroupBenefit gben WITH (NOLOCK)
		ON	(clnt.ClientValue = gben.BenefitCode)
		AND	(clnt.ClientTypeID = 5)
		AND	(clnt.Deleted = 0)

	;WITH ActivityItemHierarchy_INC
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
				#Client_Incentive clnt
			JOIN
				Incentive.dbo.IC_ClientIncentivePlan cip WITH (NOLOCK)
				ON	(clnt.ClientID = cip.ClientID)
				AND	(cip.Deleted = 0)
			JOIN
				Incentive.dbo.IC_IncentivePlan ip WITH (NOLOCK)
				ON	(cip.IncentivePlanID = ip.IncentivePlanID)
				AND	(ip.Deleted = 0)
			JOIN
				Incentive.dbo.IC_ActivityPlan ap WITH (NOLOCK) 
				ON	(ip.IncentivePlanID = ap.IncentivePlanID)
				AND	(ap.Deleted = 0)
			JOIN 
				Incentive.dbo.IC_ActivityItem ai WITH (NOLOCK) 
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
				Incentive.dbo.IC_ActivityItem ai WITH (NOLOCK) 
			JOIN
				Incentive.dbo.IC_SubActivityItem sai WITH (NOLOCK)
				ON	(ai.ActivityItemID = sai.SubActivityItemID)
			JOIN
				ActivityItemHierarchy_INC aih
				ON	(sai.ActivityItemID = aih.ActivityItemID)
			WHERE
				ai.Deleted = 0
		)

	SELECT
		grp.HealthPlanID,
		grp.GroupID,
		clnt.ClientID,
		aih.ClientIncentivePlanID,
		aih.IncentivePlanID,
		aih.ActivityPlanID,
		aih.PlanActivityItemID,
		aih.PlanLevel,
		aih.ActivityItemID,
		aih.ParentActivityItemID,
		ai.ActivityItemOperator,
		ai.ActivityItemCode,
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
		ai.UnitID,
		unit.Name AS [UnitName],
		aic.ActivityValue AS [AIC_ActivityValue], 
		aic.CompareValue AS [AIC_CompareValue], 
		aic.CompareOperator AS [AIC_CompareOperator], 
		lim.MaxValue AS [AIL_MaxValue], 
		lim.TimePeriodID AS [AIL_TimePeriod], 
		per.Name AS [TimePeriodName], 
		bio.Pregnant AS [AIB_Pregnant], 
		bio.Smoking AS [AIB_Smoking], 
		bio.Fasting AS [AIB_Fasting], 
		bio.ExamTypeCode AS [AIB_ExamTypeCode] 
	INTO
		#PlanActivity_Incentive
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		#Client_Incentive clnt
		ON	(grp.GroupID = clnt.GroupID)
	JOIN
		Incentive.dbo.IC_ClientIncentivePlan cip WITH (NOLOCK)
		ON	(clnt.ClientID = cip.ClientID)
		AND	(cip.Deleted = 0)
	JOIN
		ActivityItemHierarchy_INC aih
		ON	(cip.ClientIncentivePlanID = aih.ClientIncentivePlanID)
	JOIN
		Incentive.dbo.IC_ActivityItem ai WITH (NOLOCK)
		ON	(aih.ActivityItemID = ai.ActivityItemID)
		AND	(ai.Deleted = 0)
	JOIN
		Incentive.dbo.IC_Unit unit WITH (NOLOCK)
		ON	(ai.UnitID = unit.UnitID)
		AND	(unit.Deleted = 0)
	LEFT JOIN
		Incentive.dbo.IC_Activity act WITH (NOLOCK)
		ON	(ai.ActivityID = act.ActivityID)
		AND	(act.Deleted = 0)
	LEFT JOIN
		Incentive.dbo.IC_ActivityItemComplete aic WITH (NOLOCK)
		ON	(ai.ActivityItemID = aic.ActivityItemID)
		AND	(aic.Deleted = 0)
	LEFT JOIN
		Incentive.dbo.IC_ActivityItemLimit lim WITH (NOLOCK)
		ON	(ai.ActivityItemID = lim.ActivityItemID)
		AND	(lim.Deleted = 0)
	LEFT JOIN
		Incentive.dbo.IC_TimePeriod per WITH (NOLOCK)
		ON	(lim.TimePeriodID = per.TimePeriodID)
	LEFT JOIN
		Incentive.dbo.IC_ActivityItemBiometric bio WITH (NOLOCK)
		ON	(ai.ActivityItemID = bio.ActivityItemID)
		AND	(bio.Deleted = 0)

/******************************************************************/
-- COMBINE INTO ONE PLAN ACTIVITY TEMP TABLE                      --
/******************************************************************/
	SELECT
		ROW_NUMBER() OVER (ORDER BY GroupID, ClientIncentivePlanID, PlanLevel, ActivityItemID) AS [RowID],
		*
	INTO
		#PlanActivity
	FROM
		(
		SELECT
			hrds.HealthPlanID,
			hrds.GroupID,
			hrds.ClientID,
			hrds.ClientIncentivePlanID,
			hrds.PlanLevel,
			hrds.ActivityItemID,
			hrds.ParentActivityItemID,
			hrds.ActivityItemOperator,
			hrds.ActivityItemCode,
			hrds.ActivityID,
			hrds.ActivityName,
			hrds.ActivityDescription,
			hrds.AI_OrderBy,
			hrds.AI_Name,
			hrds.AI_Instruction,
			hrds.AI_Start,
			hrds.AI_End,
			hrds.AI_NumDaysToComplete,
			hrds.AI_IsRequired,
			hrds.AI_IsRequiredStep,
			hrds.AI_IsActionItem,
			hrds.AI_IsHidden,
			hrds.UnitID,
			hrds.UnitName,
			hrds.AIC_ActivityValue,
			hrds.AIC_CompareValue,
			hrds.AIC_CompareOperator,
			hrds.AIL_MaxValue,
			hrds.AIL_TimePeriod,
			hrds.TimePeriodName,
			hrds.AIB_Pregnant,
			hrds.AIB_Smoking,
			hrds.AIB_Fasting,
			hrds.AIB_ExamTypeCode,
			0 AS [Expired]
		FROM
			#PlanActivity_Healthyroads hrds

		UNION ALL

		SELECT
			inc.HealthPlanID,
			inc.GroupID,
			inc.ClientID,
			inc.ClientIncentivePlanID,
			inc.PlanLevel,
			inc.ActivityItemID,
			inc.ParentActivityItemID,
			inc.ActivityItemOperator,
			inc.ActivityItemCode,
			inc.ActivityID,
			inc.ActivityName,
			inc.ActivityDescription,
			inc.AI_OrderBy,
			inc.AI_Name,
			inc.AI_Instruction,
			inc.AI_Start,
			inc.AI_End,
			inc.AI_NumDaysToComplete,
			inc.AI_IsRequired,
			inc.AI_IsRequiredStep,
			inc.AI_IsActionItem,
			inc.AI_IsHidden,
			inc.UnitID,
			inc.UnitName,
			inc.AIC_ActivityValue,
			inc.AIC_CompareValue,
			inc.AIC_CompareOperator,
			inc.AIL_MaxValue,
			inc.AIL_TimePeriod,
			inc.TimePeriodName,
			inc.AIB_Pregnant,
			inc.AIB_Smoking,
			inc.AIB_Fasting,
			inc.AIB_ExamTypeCode,
			0 AS [Expired]
		FROM
			#PlanActivity_Incentive inc
		) data
					
	CREATE UNIQUE CLUSTERED INDEX idx_temp_PlanActivity
	ON #PlanActivity (RowID)


/******************************************************************/
-- MERGE TARGET TABLE incentives.PlanActivity                     --
/******************************************************************/

	DECLARE @NewRecords TABLE
	(
		ActionTaken NVARCHAR(10),
		ActionTime DATETIME,
		ModifiedBy VARCHAR(100),
		HealthPlanID INT,
		GroupID INT, 
		ClientID INT,
		ClientIncentivePlanID INT, 
		PlanLevel INT, 
		ActivityItemID INT, 
		ParentActivityItemID INT, 
		ActivityItemOperator VARCHAR(20),
		ActivityItemCode VARCHAR(50),
		ActivityName VARCHAR(100),
		ActivityDescription VARCHAR(200),
		AI_OrderBy INT,
		AI_Instruction VARCHAR(1000)
	)
	

	MERGE incentives.PlanActivity tgt
	USING
		(
		SELECT TOP (100) PERCENT -- MERGE CONSTRUCT LOSES ORDER OF DATA; THIS IS A WORKAROUND TO MAINTAIN THE ORDER
			HealthPlanID,
			GroupID,
			ClientID,
			ClientIncentivePlanID,
			PlanLevel,
			ActivityItemID,
			ParentActivityItemID,
			ActivityItemOperator,
			ActivityItemCode,
			ActivityID,
			ActivityName,
			ActivityDescription,
			AI_OrderBy,
			AI_Name,
			AI_Instruction,
			AI_Start,
			AI_End,
			AI_NumDaysToComplete,
			AI_IsRequired,
			AI_IsRequiredStep,
			AI_IsActionItem,
			AI_IsHidden,
			UnitID,
			UnitName,
			AIC_ActivityValue,
			AIC_CompareValue,
			AIC_CompareOperator,
			AIL_MaxValue,
			AIL_TimePeriod,
			TimePeriodName,
			AIB_Pregnant,
			AIB_Smoking,
			AIB_Fasting,
			AIB_ExamTypeCode,
			Expired,
			HASHBYTES(
					'SHA1',
					(
					CAST(PlanLevel AS VARCHAR(10)) + '|' +
					CAST(ActivityItemID AS VARCHAR(10)) + '|' +
					ISNULL(CAST(ParentActivityItemID AS VARCHAR(10)),'') + '|' +
					ISNULL(ActivityItemOperator,'') + '|' +
					ISNULL(ActivityItemCode,'') + '|' +
					ISNULL(CAST(ActivityID AS VARCHAR(10)),'') + '|' +
					ISNULL(ActivityName,'') + '|' +
					ISNULL(ActivityDescription,'') + '|' +
					ISNULL(CAST(AI_OrderBy AS VARCHAR(10)),'') + '|' +
					ISNULL(AI_Name,'') + '|' +
					ISNULL(AI_Instruction,'') + '|' +
					ISNULL(CAST(CAST(AI_Start AS FLOAT) AS VARCHAR(30)),'') + '|' +
					ISNULL(CAST(CAST(AI_End AS FLOAT) AS VARCHAR(30)),'') + '|' +
					ISNULL(CAST(AI_NumDaysToComplete AS VARCHAR(10)),'') + '|' +
					ISNULL(CAST(AI_IsRequired AS VARCHAR(1)),'') + '|' +
					ISNULL(CAST(AI_IsRequiredStep AS VARCHAR(1)),'') + '|' +
					ISNULL(CAST(AI_IsActionItem AS VARCHAR(1)),'') + '|' +
					ISNULL(CAST(AI_IsHidden AS VARCHAR(1)),'') + '|' +
					ISNULL(CAST(UnitID AS VARCHAR(10)),'') + '|' +
					ISNULL(UnitName,'') + '|' +
					ISNULL(CAST(AIC_ActivityValue AS VARCHAR(10)),'') + '|' +
					ISNULL(AIC_CompareValue,'') + '|' +
					ISNULL(AIC_CompareOperator,'') + '|' +
					ISNULL(CAST(AIL_MaxValue AS VARCHAR(10)),'') + '|' +
					ISNULL(CAST(AIL_TimePeriod AS VARCHAR(10)),'') + '|' +
					ISNULL(TimePeriodName,'') + '|' +
					ISNULL(AIB_Pregnant,'') + '|' +
					ISNULL(AIB_Smoking,'') + '|' +
					ISNULL(AIB_Fasting,'') + '|' +
					ISNULL(AIB_ExamTypeCode,'')
					)) AS RecordHash
		FROM
			#PlanActivity
		ORDER BY GroupID, ClientIncentivePlanID, PlanLevel, ActivityItemID -- MERGE CONSTRUCT LOSES ORDER OF DATA
		) src
	ON	(tgt.GroupID = src.GroupID)
	AND	(tgt.ClientIncentivePlanID = src.ClientIncentivePlanID)
	AND	(tgt.RecordHash = src.RecordHash)
	WHEN MATCHED AND tgt.Expired = 1 THEN
		UPDATE SET tgt.Expired = 0
	WHEN NOT MATCHED BY TARGET THEN
		INSERT
			(
			HealthPlanID,
			GroupID,
			ClientID,
			ClientIncentivePlanID,
			PlanLevel,
			ActivityItemID,
			ParentActivityItemID,
			ActivityItemOperator,
			ActivityItemCode,
			ActivityID,
			ActivityName,
			ActivityDescription,
			AI_OrderBy,
			AI_Name,
			AI_Instruction,
			AI_Start,
			AI_End,
			AI_NumDaysToComplete,
			AI_IsRequired,
			AI_IsRequiredStep,
			AI_IsActionItem,
			AI_IsHidden,
			UnitID,
			UnitName,
			AIC_ActivityValue,
			AIC_CompareValue,
			AIC_CompareOperator,
			AIL_MaxValue,
			AIL_TimePeriod,
			TimePeriodName,
			AIB_Pregnant,
			AIB_Smoking,
			AIB_Fasting,
			AIB_ExamTypeCode,
			Expired,
			RecordHash
			)
		VALUES
			(
			src.HealthPlanID,
			src.GroupID,
			src.ClientID,
			src.ClientIncentivePlanID,
			src.PlanLevel,
			src.ActivityItemID,
			src.ParentActivityItemID,
			src.ActivityItemOperator,
			src.ActivityItemCode,
			src.ActivityID,
			src.ActivityName,
			src.ActivityDescription,
			src.AI_OrderBy,
			src.AI_Name,
			src.AI_Instruction,
			src.AI_Start,
			src.AI_End,
			src.AI_NumDaysToComplete,
			src.AI_IsRequired,
			src.AI_IsRequiredStep,
			src.AI_IsActionItem,
			src.AI_IsHidden,
			src.UnitID,
			src.UnitName,
			src.AIC_ActivityValue,
			src.AIC_CompareValue,
			src.AIC_CompareOperator,
			src.AIL_MaxValue,
			src.AIL_TimePeriod,
			src.TimePeriodName,
			src.AIB_Pregnant,
			src.AIB_Smoking,
			src.AIB_Fasting,
			src.AIB_ExamTypeCode,
			src.Expired,
			src.RecordHash
			)
	WHEN NOT MATCHED BY SOURCE AND tgt.Expired = 0 THEN
		UPDATE SET tgt.Expired = 1
	OUTPUT
		$action,
		GETDATE(),
		SUSER_SNAME(),
		inserted.HealthPlanID,
		inserted.GroupID,
		inserted.ClientID,
		inserted.ClientIncentivePlanID,
		inserted.PlanLevel,
		inserted.ActivityItemID,
		inserted.ParentActivityItemID,
		inserted.ActivityItemOperator,
		inserted.ActivityItemCode,
		inserted.ActivityName,
		inserted.ActivityDescription,
		inserted.AI_OrderBy,
		inserted.AI_Instruction
	INTO
		@NewRecords;

	DECLARE
		@RecordCount INT,
		@LastRestoreDate DATETIME

	SET @RecordCount = @@ROWCOUNT
	SET @LastRestoreDate = (
							SELECT
								MAX([rs].[restore_date]) AS [last_restore_date]
							FROM
								msdb..restorehistory rs
							JOIN
								msdb..backupset bs
								ON	([rs].[backup_set_id] = [bs].[backup_set_id])
							JOIN msdb..backupmediafamily bmf 
								ON	([bs].[media_set_id] = [bmf].[media_set_id])
							WHERE
								[rs].[destination_database_name] = 'Incentive'
							)
	
	
	SELECT
		HTML
	FROM
		(
		SELECT
			'<html><head><style>body {font-family:Verdana;font-size:12px;} td {border:solid #000000 1px;padding:2px;}</style></head><body>' +
			'<table cellpadding="0" cellspacing="0">' +
			'<tr style="font-weight:bold;background-color:#DEDEDE;">' +
			'<td>LoadRunDate</td>' +
			'<td>TotalRecord(s)</td>' +
			'<td>LastRestoreDate</td>' +
			'<td>RestoreCompleteBeforeLoad</td>' +
			'</tr>' AS HTML,
			1000 AS SortLevel
		UNION
		SELECT
			'<tr>' +
			'<td>' + CONVERT(CHAR(23),GETDATE(),121) + '</td>' +
			'<td>' + CAST(@RecordCount AS VARCHAR) + '</td>' + 
			'<td>' + CONVERT(CHAR(23),@LastRestoreDate,121) + '</td>' + 
			'<td>' + CASE WHEN @LastRestoreDate < GETDATE() THEN '1' ELSE '0' END + '</td>' + 
			'</tr>' AS HTML,
			2000 AS SortLevel		
		UNION
		SELECT
			'<tr style="font-weight:bold;background-color:#DEDEDE;">' +
			'<td>ActionTaken</td>' + 
			'<td>ActionTime</td>' + 
			'<td>ModifiedBy</td>' + 
			'<td>HealthPlanID</td>' + 
			'<td>GroupID</td>' +
			'<td>ClientID</td>' + 
			'<td>ClientIncentivePlanID</td>' +
			'<td>PlanLevel</td>' +
			'<td>ActivityItemID</td>' +
			'<td>ParentActivityItemID</td>' +
			'<td>ActivityItemOperator</td>' +
			'<td>ActivityItemCode</td>' +
			'<td>ActivityName</td>' +
			'<td>ActivityDescription</td>' +
			'<td>AI_OrderBy</td>' +
			'<td>AI_Instruction</td>' +
			'</tr>' AS HTML,
			3000 AS SortLevel
		UNION
		SELECT
			'<tr>' +
			'<td>' + ActionTaken + '</td>' +
			'<td>' + CONVERT(CHAR(23),ActionTime,121) + '</td>' +
			'<td>' + ModifiedBy + '</td>' +
			'<td>' + CAST(HealthPlanID AS VARCHAR) + '</td>' +
			'<td>' + CAST(GroupID AS VARCHAR) + '</td>' +
			'<td>' + CAST(ClientID AS VARCHAR) + '</td>' +
			'<td>' + CAST(ClientIncentivePlanID AS VARCHAR) + '</td>' +
			'<td>' + CAST(PlanLevel AS VARCHAR) + '</td>' +
			'<td>' + CAST(ActivityItemID AS VARCHAR) + '</td>' +
			'<td>' + ISNULL(CAST(ParentActivityItemID AS VARCHAR),'') + '</td>' +
			'<td>' + ISNULL(ActivityItemOperator,'') + '</td>' +
			'<td>' + ISNULL(ActivityItemCode,'') + '</td>' +
			'<td>' + ISNULL(ActivityName,'') + '</td>' +
			'<td>' + ISNULL(ActivityDescription,'') + '</td>' +
			'<td>' + ISNULL(CAST(AI_OrderBy AS VARCHAR),'') + '</td>' +
			'<td>' + ISNULL(AI_Instruction,'') + '</td>' +
			'</tr>' AS HTML,
			4000 AS SortLevel
		FROM
			@NewRecords
		) data
	ORDER BY SortLevel		



-- CLEAN UP
	IF OBJECT_ID('tempDb.dbo.#PlanActivity_HealthyRoads') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity_HealthyRoads
	END

	IF OBJECT_ID('tempDb.dbo.#Client_Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Client_Incentive
	END

	IF OBJECT_ID('tempDb.dbo.#PlanActivity_Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity_Incentive
	END

	IF OBJECT_ID('tempDb.dbo.#PlanActivity') IS NOT NULL
	BEGIN
		DROP TABLE #PlanActivity
	END

END
GO
