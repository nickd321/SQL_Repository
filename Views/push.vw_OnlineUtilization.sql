SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [push].[vw_OnlineUtilization] AS

SELECT DISTINCT
	m.MemberID,
	m.Relationship,
	m.Gender,
	wa.ActivityDate,
	wa.Activity
FROM
	DA_Production.prod.Member m
JOIN
	(
	SELECT
		GroupID,
		MemberID,
		'Tracker' AS Activity,
		DATEADD(DD,DATEDIFF(DD,0,ValueDate),0) AS ActivityDate
	FROM
		DA_Production.prod.Tracker
	WHERE
		TrackerDataSourceID IN (1,2,8,32,128,256,512)
	GROUP BY
		GroupID,
		MemberID,
		DATEADD(DD,DATEDIFF(DD,0,ValueDate),0)

	UNION ALL

	SELECT
		GroupID,
		MemberID,
		'Planner' AS Activity,
		DATEADD(DD,DATEDIFF(DD,0,SourceAddDate),0) AS ActivityDate
	FROM
		DA_Production.prod.Planner

	UNION ALL

	SELECT
		GroupID,
		MemberID,
		'Web Class' AS Actvity,
		DATEADD(DD,DATEDIFF(DD,0,CourseCompleteDate),0) AS ActivityDate
	FROM
		DA_Production.prod.WebClass
	) wa
	ON	(m.MemberID = wa.MemberID)
JOIN
	DA_Reports.push.ActiveFilter af
	ON	(wa.GroupID = af.GroupID)
WHERE
	wa.ActivityDate < DATEADD(QQ,DATEDIFF(QQ,0,GETDATE()),0)
GO
