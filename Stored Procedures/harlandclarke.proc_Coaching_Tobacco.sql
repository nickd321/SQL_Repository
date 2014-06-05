SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Domokos
-- Create date: 2014-04-08
-- Description:	Harland Clarke Tobacco Cessation Coaching Report
--
-- Notes:		
--
-- =============================================
CREATE PROCEDURE [harlandclarke].[proc_Coaching_Tobacco] 

AS
BEGIN
	SET NOCOUNT ON;

	SELECT
		mem.AltID1 AS [EmployeeID],
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		ISNULL(mem.MiddleInitial,'') AS [MiddleInitial],
		mem.LastName,
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS [Birthdate],
		mem.Relationship,
		ISNULL(csf.CS1,'') AS [Location],
		ISNULL(csf.CS2,'') AS [Company],
		ISNULL(csf.CS3,'') AS [MedicalPlan],
		ISNULL(csf.CS4,'') AS [Coverage/Tier],
		ISNULL(csf.CS5,'') AS [HireDate],
		CONVERT(VARCHAR(10),app.FirstEnrollmentDate,101) AS [FirstEnrollmentDate],
		app.[Count] AS [SessionsToDate],
		ISNULL(CONVERT(VARCHAR(10),app.LastAppointmentDate,101),'') AS [LastCompletedSessionDate]
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem
		ON	(hpg.GroupID = mem.GroupID)
		AND	(hpg.GroupID = 198713)
		AND (mem.RelationshipID IN (1,6))
	JOIN
		(
		SELECT 
			b.MemberID,
			MAX(a.AppointmentBeginDate) AS [LastAppointmentDate],
			MIN(b.EnrollmentDate) AS [FirstEnrollmentDate],
			COUNT(a.AppointmentBeginDate) AS [Count]
		FROM
			DA_Production.prod.ProgramEnrollment b
		LEFT JOIN
			DA_Production.prod.Appointment a
			ON	(a.MemberID = b.MemberID)
			AND	(a.AppointmentStatusID = 4)
			AND	(a.AppointmentBeginDate >= '10/1/2013')
			AND (a.AppointmentBeginDate BETWEEN b.EnrollmentDate AND ISNULL(b.TerminationDate,'2999-12-31'))
		WHERE
			(b.ProgramID = 1)
			AND	(b.EnrollmentDate >= '10/1/2013')
			AND (b.GroupID = 198713)
		GROUP BY
			b.MemberID
		) app
		ON	(app.MemberID = mem.MemberID)
	LEFT JOIN
		DA_Production.prod.CSFields csf
		ON	(csf.MemberID = mem.MemberID)

END
GO
