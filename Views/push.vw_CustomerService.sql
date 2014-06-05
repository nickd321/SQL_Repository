SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [push].[vw_CustomerService] AS

SELECT
	m.MemberID,
	m.Relationship,
	m.Gender,
	hl.LogID,
	hl.CompleteDate,
	hl.SourceName,
	hl.LogTypeName,
	hl.DescriptionName,
	hl.SubDescriptionName
FROM
	DA_Production.prod.Member m
JOIN
	DA_Production.prod.HMSLog hl
	ON	(m.MemberID = hl.MemberID)
JOIN
	DA_Reports.push.ActiveFilter af
	ON	(hl.GroupID = af.GroupID)
WHERE
	hl.CompleteDate < DATEADD(QQ,DATEDIFF(QQ,0,GETDATE()),0)
GO
