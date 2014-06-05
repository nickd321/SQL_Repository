SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-02-20
-- Description:	Tyco Recalculation Log Table Load
--
-- Notes:		
--
-- Updates:		
--
-- =============================================

CREATE PROCEDURE [incentives].[proc_HealthyroadsDB_Recalc_Log_LOAD_Tyco]

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
		CS4,
		CASE WHEN RTRIM(LTRIM(CS4)) = '2' THEN 1 ELSE 0 END AS TrackingValue,
		EffectiveDate,
		ExpiryDate,
		CASE WHEN ExpiryDate = '2999-12-31' THEN 1 ELSE 0 END AS IsCurrentRecord
	INTO
		#CSFields
	FROM
		DA_Production.prod.vw_CSFIelds_History
	WHERE
		GroupID = 193629 AND
		EffectiveDate >= '2013-09-01'

	SELECT
		cs.RevSeq AS RevSeq_One,
		cs.HealthPlanID,
		cs.GroupID,
		cs.MemberID,
		cs.CS4 AS CS4_One,
		cs.TrackingValue AS TrackingValue_One,
		cs.EffectiveDate AS EffectiveDate_One,
		cs.ExpiryDate AS ExpiryDate_One,
		cs.IsCurrentRecord,
		dos.RevSeq AS RevSeq_Two,
		dos.CS4 AS CS4_Two,
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
		ISNULL(cs.CS4,-1) != ISNULL(dos.CS4,-1) AND
		(cs.TrackingValue - dos.TrackingValue) = 1
	ORDER BY
		cs.MemberID, cs.RevSeq

	INSERT INTO DA_Reports.incentives.HealthyroadsDB_Recalc_Log
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
			'CS4' + ' = ' + ISNULL(CS4_Two,'NULL') + ',' + 'CS4' + ' = ' + ISNULL(CS4_One,'NULL') AS Change,
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


	IF OBJECT_ID('tempdb.dbo.#CSFields') IS NOT NULL
	BEGIN
		DROP TABLE #CSFields 
	END

	IF OBJECT_ID('tempdb.dbo.#Change') IS NOT NULL
	BEGIN
		DROP TABLE #Change
	END

END
GO
