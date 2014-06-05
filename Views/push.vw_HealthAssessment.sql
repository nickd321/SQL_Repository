SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [push].[vw_HealthAssessment] AS

SELECT
	m.MemberID,
	m.Relationship,
	m.Gender,
	ha.MemberAssessmentID,
	ha.AssessmentCompleteDate,
	ha.EntryMethodName,
	ha.EntrySourceName,
	ha.StratificationLevelName
FROM
	DA_Production.prod.Member m
JOIN
	DA_Production.prod.HealthAssessment ha
	ON	(m.MemberID = ha.MemberID)
JOIN
	DA_Reports.push.ActiveFilter af
	ON	(ha.GroupID = af.GroupID)
WHERE
	ha.IsPrimarySurvey = 1 AND
	ha.AssessmentCompleteDate < DATEADD(QQ,DATEDIFF(QQ,0,GETDATE()),0)
GO
