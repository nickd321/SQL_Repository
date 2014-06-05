SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [push].[vw_Challenge] AS

SELECT
	m.MemberID,
	m.Relationship,
	m.Gender,
	c.ChallengeCategoryName,
	COALESCE(c.ChallengeName,c.DefaultChallengeName) AS ChallengeName,
	c.ChallengeBeginDate,
	c.ChallengeEndDate,
	CASE WHEN CompletionDate IS NULL THEN 'Completed' ELSE 'Enrolled' END AS MemberStatus
FROM
	DA_Production.prod.Member m
JOIN
	DA_Production.prod.Challenge c
	ON	(m.MemberID = c.MemberID)
JOIN
	DA_Reports.push.ActiveFilter af
	ON	(c.GroupID = af.GroupID)
WHERE
	c.ChallengeBeginDate < DATEADD(QQ,DATEDIFF(QQ,0,GETDATE()),0)
GO
