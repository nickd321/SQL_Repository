SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Domokos
-- Create date: 4/24/2014
-- Description:	OneSubsea I Stepped It Up With My Execs Challenge

-- Notes:		
--				
--				
--				
--
-- Updates:		NickD_20140430
--				Added non-Fitbit Client Challenge ID
--
-- =============================================

CREATE PROCEDURE [onesubsea].[proc_Challenge_StepItUpWithMyExecs]
AS
BEGIN
	SET NOCOUNT ON;

SELECT
	mem.FirstName,
	mem.LastName,
	ISNULL(mem.AltID1,'') AS [AltID1],
	ISNULL(addr.Address1,'') AS [Address1],
	ISNULL(addr.Address2,'') AS [Address2],
	ISNULL(addr.City,'') AS [City],
	ISNULL(addr.State,'') AS [State],
	ISNULL(addr.ZipCode,'') AS [ZipCode],
	ISNULL(COALESCE(mem.AlternatePhone,mem.HomePhone,mem.CellPhone,mem.WorkPhone),'') AS [PhoneNumber],
	ISNULL(mem.EmailAddress,'') AS [Email],
	ISNULL(CS1,'') AS [DateofHire],
	ISNULL(CS2,'') AS [LocationCode],
	ISNULL(CS3,'') AS [ProcessCenterCode],
	ISNULL(CS4,'') AS [MedicalPlanIndicator],
	ISNULL(CONVERT(int,trk.MeasureValue),'') AS [NoFitbitSteps],
	ISNULL(CONVERT(int,act.MeasureValue),'') AS [FitbitSteps],
	ISNULL(CONVERT(int,trk.MeasureValue),'') + ISNULL(CONVERT(int,act.MeasureValue),'') AS [TotalSteps],
	CASE 
		WHEN ISNULL(CONVERT(int,act.MeasureValue),'') + ISNULL(CONVERT(int,trk.MeasureValue),'') >= 150000
		THEN 'Y'
		ELSE ''
	END AS [ChallengeCompletedFlag]
	
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = hpg.GroupID)
	AND	(hpg.GroupID = 202585)
	AND	(mem.Relationship = 'Primary')
JOIN
	DA_Production.prod.Challenge chlg
	ON	(chlg.MemberID = mem.MemberID)
	AND	(chlg.ClientChallengeID IN (1266, 1236))
LEFT JOIN
	(
	SELECT
		trk.MemberID,
		trk.TrackerDataSourceID,
		trk.TrackerEntryID,
		MemberChallengeID,
		SUM(CONVERT(int,Value)) AS [MeasureValue],
		'NoFitbit' AS [Measure]
	FROM
		DA_Production.prod.Tracker trk
		
	GROUP BY
		trk.MemberID,
		trk.TrackerDataSourceID,
		trk.TrackerEntryID,
		MemberChallengeID
	) trk
	ON  (trk.TrackerEntryID = 39)
		AND	(trk.TrackerDataSourceID = 32)
		AND	(trk.MemberChallengeID = chlg.MemberChallengeID)
		AND	(chlg.ClientChallengeID IN (1236,1266))
LEFT JOIN
	(
	SELECT
		prof.BenefitMemberID,
		SUM(act.Steps) AS [MeasureValue],
		'Fitbit' AS [Measure]
	FROM
		HealthTrackers.dbo.HT_MemberProfile prof
	JOIN
		HealthTrackers.dbo.HT_FitbitMonitorUser mon
		ON	(mon.MemberProfileID = prof.MemberProfileID)
		AND	(mon.Deleted = 0)
	JOIN
		HealthTrackers.dbo.HT_FitbitActivitySummary act
		ON	(mon.FitbitMonitorUserID = act.FitbitMonitorUserID)
		AND	(act.ActivityDate >= '4/7/2014')
		AND	(act.ActivityDate < '5/5/2014')
	GROUP BY
		prof.BenefitMemberID
	) act
	ON	(act.BenefitMemberID = mem.MemberID)
LEFT JOIN
	DA_Production.prod.CSFields csf
	ON	(csf.MemberID = mem.MemberID)
LEFT JOIN
	DA_Production.prod.Address addr
	ON	(addr.MemberID = mem.MemberID)
	AND	(addr.AddressTypeID = 6)
GROUP BY
	mem.FirstName,
	mem.LastName,
	ISNULL(mem.AltID1,''),
	ISNULL(addr.Address1,''),
	ISNULL(addr.Address2,''),
	ISNULL(addr.City,''),
	ISNULL(addr.State,''),
	ISNULL(addr.ZipCode,''),
	ISNULL(COALESCE(mem.AlternatePhone,mem.HomePhone,mem.CellPhone,mem.WorkPhone),''),
	ISNULL(mem.EmailAddress,''),
	ISNULL(CS1,''),
	ISNULL(CS2,''),
	ISNULL(CS3,''),
	ISNULL(CS4,''),
	ISNULL(CONVERT(int,trk.MeasureValue),''),
	ISNULL(CONVERT(int,act.MeasureValue),''),
	CASE 
		WHEN ISNULL(CONVERT(int,act.MeasureValue),'') + ISNULL(CONVERT(int,trk.MeasureValue),'') >= 150000
		THEN 'Y'
		ELSE ''
	END

ORDER BY 3,2
END


GO
