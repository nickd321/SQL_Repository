SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [push].[vw_BiometricsScreening] AS

SELECT
	m.MemberID,
	m.Relationship,
	m.Gender,
	bs.MemberScreeningID,
	bs.ScreeningDate,
	bs.Location,
	bs.FileSource
FROM
	DA_Production.prod.Member m
JOIN
	DA_Production.prod.BiometricsScreening bs
	ON	(m.MemberID = bs.MemberID)
JOIN
	DA_Reports.push.ActiveFilter af
	ON	(bs.GroupID = af.GroupID)
WHERE
	bs.ScreeningDate < DATEADD(QQ,DATEDIFF(QQ,0,GETDATE()),0)
GO
