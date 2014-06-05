SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE VIEW [push].[vw_Coaching] AS

SELECT
	m.MemberID,
	m.Relationship,
	m.Gender,
	pe.ProgramEnrollmentID,
	pe.ProgramName,
	a.AppointmentID,
	a.AppointmentBeginDate,
	a.AppointmentStatusName,
	ISNULL(a.AppointmentFormatName,'Phone') AS AppointmentFormatName,
	ROW_NUMBER() OVER(PARTITION BY m.MemberID, pe.ProgramEnrollmentID ORDER BY a.AppointmentID) AS AppointmentSequence,
	ROW_NUMBER() OVER(PARTITION BY m.MemberID, pe.ProgramEnrollmentID ORDER BY a.AppointmentID DESC) AS AppointmentInverseSequence
FROM
	DA_Production.prod.Member m
JOIN
	DA_Production.prod.ProgramEnrollment pe
	ON	(m.MemberID = pe.MemberID)
JOIN
	DA_Production.prod.Appointment a
	ON	(pe.MemberID = a.MemberID)
	AND	(pe.EnrollmentDate <= a.AppointmentBeginDate)
	AND	(ISNULL(pe.TerminationDate,'1/1/3000') > a.AppointmentBeginDate)
	AND (a.AppointmentStatusID IN (1,4))
JOIN
	DA_Reports.push.ActiveFilter af
	ON	(a.GroupID = af.GroupID)
WHERE
	a.AppointmentBeginDate < DATEADD(QQ,DATEDIFF(QQ,0,GETDATE()),0)
GO
