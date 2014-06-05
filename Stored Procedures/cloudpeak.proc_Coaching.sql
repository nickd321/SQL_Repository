SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-11-01
-- Description:	Cloud Peak Coaching Report
-- =============================================

CREATE PROCEDURE [cloudpeak].[proc_Coaching]

AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		grp.GroupName,
		mem.FirstName,
		mem.LastName,
		mem.AltID1 AS EEID,
		mem.Relationship,
		cs.CS1 AS Location,
		prg.ProgramName AS CurrentProgram,
		CONVERT(VARCHAR(10),cch.AppointmentBeginDate,101) AS FourthCoachingCall
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 195179)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		(
		SELECT
			MemberID,
			AppointmentTypeName,
			AppointmentStatusName,
			AppointmentBeginDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentBeginDate) AS CoachSeq
		FROM
			DA_Production.prod.Appointment
		WHERE
			GroupID = 195179 AND
			AppointmentStatusID = 4 AND
			AppointmentBeginDate >= '2013-01-01'
		) cch
		ON	(mem.MemberID = cch.MemberID)
		AND	(cch.CoachSeq = 4)
	LEFT JOIN
		(
		SELECT
			MemberID,
			ProgramID,
			ProgramName,
			EnrollmentDate,
			TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.ProgramEnrollment
		WHERE
			GroupID = 195179
		) prg
		ON	(mem.MemberID = prg.MemberID)
		AND	(prg.RevTermSeq = 1)
 

 END
GO
