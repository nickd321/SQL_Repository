SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 3/21/2014
-- Description:	Memorial Care Coaching Completions for Tobacco Requirement.

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [memorialcare].[proc_Tobacco_CoachingCompletions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;
--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME
SET @inBeginDate = ISNULL(@inBeginDate,'2/1/2014')
SET @inEndDate = ISNULL(@inEndDate,DATEADD(DD,DATEDIFF(dd,0,GETDATE()),0))

SELECT
	hpg.GroupName,
	ISNULL(mem.AltID1,'') AS [EmployeeNumber],
	mem.FirstName,
	mem.LastName,
	ISNULL(csf.CS1,'') AS [Location],
	CONVERT(VARCHAR(10),one.AppointmentBeginDate,101) AS [DateOfFirstCall],
	CONVERT(VARCHAR(10),five.AppointmentBeginDate,101) AS [DateofFifthCall]
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = hpg.GroupID)
	AND	(hpg.GroupID = 208094)
JOIN
	(
	SELECT
		a.MemberID,
		a.AppointmentBeginDate,
		ROW_NUMBER() OVER (PARTITION BY a.MemberID ORDER BY a.AppointmentBeginDate) AS [RowSeq]
	FROM
		DA_Production.prod.Appointment a
	JOIN
		DA_Production.prod.ProgramEnrollment b
		ON	(a.MemberID = b.MemberID)
	WHERE
		(a.AppointmentStatusID = 4)
		AND	(a.AppointmentBeginDate >= @inBeginDate)
		AND	(a.AppointmentBeginDate < @inEndDate)
		AND (b.ProgramID = 1)
		AND	(a.AppointmentBeginDate BETWEEN b.EnrollmentDate AND ISNULL(b.TerminationDate,'2999-12-31'))
	) one
	ON	(one.MemberID = mem.MemberID)
	AND	(one.RowSeq = 1)
JOIN
	(
	SELECT
		a.MemberID,
		a.AppointmentBeginDate,
		ROW_NUMBER() OVER (PARTITION BY a.MemberID ORDER BY a.AppointmentBeginDate) AS [RowSeq]
	FROM
		DA_Production.prod.Appointment a
	JOIN
		DA_Production.prod.ProgramEnrollment b
		ON	(a.MemberID = b.MemberID)
	WHERE
		(a.AppointmentStatusID = 4)
		AND	(a.AppointmentBeginDate >= @inBeginDate)
		AND	(a.AppointmentBeginDate < @inEndDate)
		AND (b.ProgramID = 1)
		AND	(a.AppointmentBeginDate BETWEEN b.EnrollmentDate AND ISNULL(b.TerminationDate,'2999-12-31'))
	) five
	ON	(five.MemberID = mem.MemberID)
	AND	(five.RowSeq = 5)
LEFT JOIN
	DA_Production.prod.CSFields csf
	ON	(mem.MemberID = csf.MemberID)

END
GO
