SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-31
-- Description:	PepsiCo Incentives Recalculation Log Table Load
--
-- Notes:		
--
-- Updates:		
--
-- =============================================


CREATE PROCEDURE [incentives].[proc_IncentiveDB_Recalc_Log_LOAD_PepsiCo] 
	
AS
BEGIN

	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb.dbo.#CSFields') IS NOT NULL
	BEGIN
		DROP TABLE #CSFields 
	END

	IF OBJECT_ID('tempdb.dbo.#Change') IS NOT NULL
	BEGIN
		DROP TABLE #Change
	END

	SELECT
		ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY EffectiveDate DESC, ExpiryDate DESC) AS RevSeq,
		HealthPlanID,
		GroupID,
		MemberID,
		CS5,
		CASE WHEN RTRIM(LTRIM(CS5)) = 'Y' THEN 1 ELSE 0 END AS TrackingValue,
		EffectiveDate,
		ExpiryDate,
		CASE WHEN ExpiryDate = '2999-12-31' THEN 1 ELSE 0 END AS IsCurrentRecord
	INTO
		#CSFields
	FROM
		DA_Production.prod.vw_CSFIelds_History
	WHERE
		GroupID = 206772 
	
	SELECT
		cs.RevSeq AS RevSeq_One,
		cs.HealthPlanID,
		cs.GroupID,
		cs.MemberID,
		cs.CS5 AS CS5_One,
		cs.TrackingValue AS TrackingValue_One,
		cs.EffectiveDate AS EffectiveDate_One,
		cs.ExpiryDate AS ExpiryDate_One,
		cs.IsCurrentRecord,
		dos.RevSeq AS RevSeq_Two,
		dos.CS5 AS CS5_Two,
		dos.TrackingValue AS TrackingValue_Two,
		dos.EffectiveDate AS EffectiveDate_Two,
		dos.ExpiryDate AS ExpiryDate_Two,
		cs.TrackingValue - dos.TrackingValue AS ChangeDirection
	INTO
		#Change
	FROM
		#CSFields cs
	JOIN
		#CSFields dos
		ON	(cs.MemberID = dos.MemberID)
		AND	(dos.RevSeq = cs.RevSeq + 1)
	WHERE
		ISNULL(cs.CS5,-1) != ISNULL(dos.CS5,-1) AND
		(cs.TrackingValue - dos.TrackingValue) = 1

	INSERT INTO DA_Reports.incentives.IncentiveDB_Recalc_Log
	SELECT
		chg.HealthPlanID,
		chg.GroupID,
		chg.MemberID,
		chg.ChangeDate,
		chg.Change,
		0 AS RecalculatedFlag,
		NULL AS RecalculatedMessage,
		NULL AS RecalculatedDate,
		NULL AS RecalculatedBy,
		GETDATE() AS AddDate,
		REPLACE(SUSER_SNAME(),'CORP\','') AS AddedBy,
		NULL AS DA_Notes
	FROM	
		(
		SELECT
			HealthPlanID,
			GroupID,
			MemberID,
			EffectiveDate_One AS ChangeDate,
			'CS5' + ' = ' + ISNULL(CS5_Two,'NULL') + ',' + 'CS5' + ' = ' + ISNULL(CS5_One,'NULL') AS Change,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY EffectiveDate_One DESC) AS ChangeDateSeqDesc
		FROM
			#Change
		) chg
	LEFT JOIN
		DA_Reports.incentives.IncentiveDB_Recalc_Log lg
		ON	(chg.MemberID = lg.MemberID)
		AND	(chg.ChangeDate = lg.ChangeDate)
	WHERE
		lg.MemberID IS NULL AND
		chg.ChangeDateSeqDesc = 1 
	
	DECLARE @RecordCount INT
	SET @RecordCount = @@ROWCOUNT
	
	SELECT
		HTML
	FROM
		(
		SELECT
			'<html><head><style>body {font-family:Verdana;font-size:12px;} td {border:solid #000000 1px;padding:2px;}</style></head><body>' +
			'<table cellpadding="0" cellspacing="0">' +
			'<tr style="font-weight:bold;background-color:#DEDEDE;">' +
			'<td>LoadRunDate</td><td>TotalRecord(s)</td>' +
			'</tr>' AS HTML,
			1000 AS SortLevel
		UNION
		SELECT
			'<tr>' +
			'<td>' + CONVERT(CHAR(23),GETDATE(),121) + '</td>' +
			'<td>' + CAST(@RecordCount AS VARCHAR) + '</td>' + 
			'</tr>' AS HTML,
			2000 AS SortLevel
		) data
	ORDER BY
		SortLevel
	
END
GO
