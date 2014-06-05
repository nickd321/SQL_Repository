SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [push].[vw_Outcomes] AS

WITH ECRResult AS
(
SELECT
	GroupID,
	MemberID,
	StartDate,
	BMI,
	CASE ActivityRisk WHEN 'High' THEN 3 WHEN 'Moderate' THEN 2 ELSE 1 END AS ActivityRisk,
	CASE DietRisk WHEN 'High' THEN 3 WHEN 'Moderate' THEN 2 ELSE 1 END AS DietRisk,
	CASE ObesityRisk WHEN 'High' THEN 3 WHEN 'Moderate' THEN 2 ELSE 1 END AS ObesityRisk,
	CASE StressRisk WHEN 'High' THEN 3 WHEN 'Moderate' THEN 2 ELSE 1 END AS StressRisk,
	CASE TobaccoRisk WHEN 'High' THEN 3 WHEN 'Moderate' THEN 2 ELSE 1 END AS TobaccoRisk,
	ROW_NUMBER() OVER(PARTITION BY MemberID ORDER BY StartDate) AS Sequence,
	ROW_NUMBER() OVER(PARTITION BY MemberID ORDER BY StartDate DESC) AS InverseSequence
FROM
	DA_Production.prod.ECRCaseSession
)

SELECT
	m.MemberID,
	m.Relationship,
	m.Gender,
	er2.Sequence AS SessionCount,
	AVG(CASE WHEN er1.BMI > er2.BMI THEN 1 ELSE 0 END) AS DecreasedWeight,
	AVG(CASE WHEN er1.ActivityRisk > er2.ActivityRisk THEN 1 ELSE 0 END) AS DecreasedActivityRisk,
	AVG(CASE WHEN er1.DietRisk > er2.DietRisk THEN 1 ELSE 0 END) AS DecreasedDietRisk,
	AVG(CASE WHEN er1.ObesityRisk > er2.ObesityRisk THEN 1 ELSE 0 END) AS DecreasedObesityRisk,
	AVG(CASE WHEN er1.StressRisk > er2.StressRisk THEN 1 ELSE 0 END) AS DecreasedStressRisk,
	AVG(CASE WHEN er1.TobaccoRisk > er2.TobaccoRisk THEN 1 ELSE 0 END) AS DecreasedTobaccoRisk,
	er1.ActivityRisk AS ActivityRisk_T1,
	er1.DietRisk AS DietRisk_T1,
	er1.ObesityRisk AS ObesityRisk_T1,
	er1.StressRisk AS StressRisk_T1,
	er1.TobaccoRisk AS TobaccoRisk_T1,
	er2.ActivityRisk AS ActivityRisk_T2,
	er2.DietRisk AS DietRisk_T2,
	er2.ObesityRisk AS ObesityRisk_T2,
	er2.StressRisk AS StressRisk_T2,
	er2.TobaccoRisk AS TobaccoRisk_T2
FROM
	DA_Production.prod.Member m
JOIN
	ECRResult er1
	ON	(m.MemberID = er1.MemberID)
	AND	(er1.Sequence = 1)
JOIN
	ECRResult er2
	ON	(er1.MemberID = er2.MemberID)
	AND	(er2.Sequence > 1)
	AND	(er2.InverseSequence = 1)
JOIN
	DA_Reports.push.ActiveFilter af
	ON	(er1.GroupID = af.GroupID)
WHERE
	er2.StartDate < DATEADD(QQ,DATEDIFF(QQ,0,GETDATE()),0)
GROUP BY
	m.MemberID,
	m.Relationship,
	m.Gender,
	er2.Sequence,
	er1.ActivityRisk,
	er1.DietRisk,
	er1.ObesityRisk,
	er1.StressRisk,
	er1.TobaccoRisk,
	er2.ActivityRisk,
	er2.DietRisk,
	er2.ObesityRisk,
	er2.StressRisk,
	er2.TobaccoRisk
GO
