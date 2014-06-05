SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-05
-- Description:	[incentives].[proc_TableLoad_Plan] table load
--
-- Notes:		This is at the ClientIncentivePlan grain. I am using this table
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

CREATE PROCEDURE [incentives].[proc_TableLoad_Plan] 

AS
BEGIN

	SET NOCOUNT ON;

	IF OBJECT_ID('tempDb.dbo.#Client_Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Client_Incentive
	END

	IF OBJECT_ID('tempDb.dbo.#Plan') IS NOT NULL
	BEGIN
		DROP TABLE #Plan
	END

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


	SELECT
		grp.HealthPlanID,
		grp.GroupID,
		inc.ClientID,
		inc.ClientIncentivePlanID,
		inc.IncentivePlanID,
		ap.ActivityPlanID,
		inc.IncentiveBeginDate AS [PlanStart],
		inc.IncentiveEndDate AS [PlanEnd],
		'Healthyroads' AS [SourceDatabase],
		0 AS [Expired]
	INTO
		#Plan
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.GroupIncentivePlan inc WITH (NOLOCK)
		ON	(grp.GroupID = inc.GroupID)
	JOIN
		Healthyroads.dbo.IC_ActivityPlan ap WITH (NOLOCK)
		ON	(inc.IncentivePlanID = ap.IncentivePlanID)
		AND	(ap.Deleted = 0)
	WHERE
		-- PROVIDENCE
		(
		 grp.GroupID = 173174 AND 
		 inc.IncentiveBeginDate >= '2013-09-01'
		)
		OR
		-- GBC
		(
		 grp.GroupID = 194461 AND
		 inc.IncentiveBeginDate >= '2014-01-01'
		)
		OR
		-- CTCA
		(
		 grp.GroupID = 191393 AND
		 inc.IncentiveBeginDate >= '2013-09-01'
		)
		OR
		-- Trizetto
		(
		 grp.GroupID = 194354 AND
		 inc.IncentiveBeginDate >= '2014-01-01'
		)
 
	UNION ALL

	SELECT
		grp.HealthPlanID,
		grp.GroupID,
		clnt.ClientID,
		cip.ClientIncentivePlanID,
		cip.IncentivePlanID,
		ap.ActivityPlanID,
		cip.StartDate AS [PlanStart],
		cip.EndDate AS [PlanEnd],
		'Incentive' AS [SourceDatabase],
		0 AS [Expired]
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
		Incentive.dbo.IC_ActivityPlan ap WITH (NOLOCK)
		ON	(cip.IncentivePlanID = ap.IncentivePlanID)
		AND	(ap.Deleted = 0)
	ORDER BY
		1,2,4

		
	DECLARE @NewRecords TABLE
	(
		ActionTaken NVARCHAR(10),
		ActionTime DATETIME,
		ModifiedBy VARCHAR(100),
		HealthPlanID INT,
		GroupID INT, 
		ClientID INT,
		ClientIncentivePlanID INT, 
		IncentivePlanID INT, 
		ActivityPlanID INT, 
		PlanStart DATETIME, 
		PlanEnd DATETIME,
		SourceDatabase VARCHAR(1000),
		Expired BIT,
		RecordHash VARBINARY(100)

	)

	MERGE DA_Reports.incentives.[Plan] tgt
	USING
		(
		SELECT
			HealthPlanID,
			GroupID,
			ClientID,
			ClientIncentivePlanID,
			IncentivePlanID,
			ActivityPlanID,
			PlanStart,
			PlanEnd,
			SourceDatabase,
			Expired,
			-- IF THE RECORD HASH IS MODIFIED MUST MODIFY THE TRIGGER ON THE TABLE AS WELL
			HASHBYTES(
				'SHA1',
				(
				CAST(IncentivePlanID AS VARCHAR(10)) + '|' +
				CAST(ActivityPlanID AS VARCHAR(10)) + '|' +
				CAST(CAST(PlanStart AS FLOAT) AS VARCHAR(30)) + '|' +
				CAST(CAST(PlanEnd AS FLOAT) AS VARCHAR(30)) + '|' +
				SourceDatabase
				)) AS RecordHash
		FROM
			#Plan
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
			IncentivePlanID,
			ActivityPlanID,
			PlanStart,
			PlanEnd,
			SourceDatabase,
			Expired,
			RecordHash
			)
		VALUES
			(
			src.HealthPlanID,
			src.GroupID,
			src.ClientID,
			src.ClientIncentivePlanID,
			src.IncentivePlanID,
			src.ActivityPlanID,
			src.PlanStart,
			src.PlanEnd,
			src.SourceDatabase,
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
		inserted.IncentivePlanID,
		inserted.ActivityPlanID,
		inserted.PlanStart,
		inserted.PlanEnd,
		inserted.SourceDatabase,
		inserted.Expired,
		inserted.RecordHash 
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
			'<td>IncentivePlanID</td>' +
			'<td>ActivityPlanID</td>' +
			'<td>PlanStart</td>' +
			'<td>PlanEnd</td>' +
			'<td>SourceDatabase</td>' +
			'<td>Expired</td>' +
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
			'<td>' + CAST(IncentivePlanID AS VARCHAR) + '</td>' +
			'<td>' + CAST(ActivityPlanID AS VARCHAR) + '</td>' +
			'<td>' + CONVERT(CHAR(23),PlanStart,121) + '</td>' +
			'<td>' + CONVERT(CHAR(23),PlanEnd,121) + '</td>' +
			'<td>' + SourceDatabase + '</td>' +
			'<td>' + CAST(Expired AS VARCHAR) + '</td>' +
			'</tr>' AS HTML2,
			4000 AS SortLevel
		FROM
			@NewRecords
		) data
	ORDER BY SortLevel
	

	IF OBJECT_ID('tempDb.dbo.#Client_Incentive') IS NOT NULL
	BEGIN
		DROP TABLE #Client_Incentive
	END

	IF OBJECT_ID('tempDb.dbo.#Plan') IS NOT NULL
	BEGIN
		DROP TABLE #Plan
	END

END
GO
