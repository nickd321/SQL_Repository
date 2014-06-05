SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [push].[vw_Outreach] AS

SELECT
	m.MemberID,
	m.Relationship,
	m.Gender,
	oc.OutreachMemberID,
	oc.CompletedDate,
	oc.OutreachTypeName,
	oc.OutreachCompleteResultName,
	oc.LastActionResultName,
	oc.LastActionTypeName,
	oc.LiveCallsCompleted,
	oc.IVRCallsCompleted
FROM
	DA_Production.prod.Member m
JOIN
	DA_Production.prod.OutreachCampaign oc
	ON	(m.MemberID = oc.MemberID)
JOIN
	DA_Reports.push.ActiveFilter af
	ON	(oc.GroupID = af.GroupID)
WHERE
	oc.CompletedDate < DATEADD(QQ,DATEDIFF(QQ,0,GETDATE()),0)
GO
