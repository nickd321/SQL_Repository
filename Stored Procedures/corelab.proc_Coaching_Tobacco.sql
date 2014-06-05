SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2014-02-09
-- Description:	Core Laboraties Tobacco Coaching Report
--
-- Notes:		
--
-- Updates:
--
--
-- =============================================
CREATE PROCEDURE [corelab].[proc_Coaching_Tobacco]

AS
BEGIN

	SET NOCOUNT ON;
	
	-- CLEAN UP
	IF OBJECT_ID('tempDb.dbo.#Coaching') IS NOT NULL
	BEGIN
		DROP TABLE #Coaching
	END

	SELECT
		mem.MemberID,
		grp.GroupName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		ISNULL(mem.AltID1,'') AS [EmployeeID],
		ISNULL(cs.CS1,'') AS [BusinessUnit],
		ISNULL(cs.CS2,'') AS [Location],
		prg.ProgramID,
		prg.ProgramName,
		prg.EnrollmentDate,
		prg.TerminationDate,
		app.AppointmentBeginDate,
		app.AppointmentStatusID,
		app.AppointmentStatusName,
		ROW_NUMBER() OVER (PARTITION BY mem.MemberID, prg.ProgramID ORDER BY app.AppointmentBeginDate) AS [CoachSeq]
	INTO
		#Coaching
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 200926)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		DA_Production.prod.ProgramEnrollment prg WITH (NOLOCK)
		ON	(mem.MemberID = prg.MemberID)
		AND	(prg.ProgramID = 1) -- Tobacco Cessation
	JOIN
		DA_Production.prod.Appointment app WITH (NOLOCK)
		ON	(prg.MemberID = app.MemberID)
		AND	(app.AppointmentStatusID = 4) -- CompletedCall
		AND	(app.AppointmentBeginDate >= '2013-10-01')
		AND	(app.AppointmentBeginDate BETWEEN prg.EnrollmentDate AND ISNULL(prg.TerminationDate,'2999-12-31'))

	SELECT 
		mem.GroupName,
		mem.FirstName,
		mem.LastName,
		mem.EmployeeID,
		mem.BusinessUnit,
		mem.Location,
		CONVERT(VARCHAR(10),un.AppointmentBeginDate,101) AS [Tobacco_FirstCall],
		CONVERT(VARCHAR(10),sis.AppointmentBeginDate,101) AS [Tobacco_SixthCall]
	FROM
		#Coaching mem
	JOIN
		#Coaching un
		ON	(mem.MemberID = un.MemberID)
		AND	(un.CoachSeq = 1)
	JOIN
		#Coaching sis
		ON	(mem.MemberID = sis.MemberID)
		AND	(sis.CoachSeq = 6)
	GROUP BY
		mem.GroupName,
		mem.FirstName,
		mem.LastName,
		mem.EmployeeID,
		mem.BusinessUnit,
		mem.Location,
		CONVERT(VARCHAR(10),un.AppointmentBeginDate,101),
		CONVERT(VARCHAR(10),sis.AppointmentBeginDate,101)

	-- CLEAN UP
	IF OBJECT_ID('tempDb.dbo.#Coaching') IS NOT NULL
	BEGIN
		DROP TABLE #Coaching
	END


END
GO
