SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-12-11
-- Description:	Clean Harbors Coaching Report
--
-- Notes:		This report is tied to coaching sessions completed during the time
--				the member was enrolled in the Tobacco Cessation program
--	
-- =============================================
CREATE PROCEDURE [cleanharbors].[proc_Coaching] 

AS
BEGIN

	SET NOCOUNT ON;

	-- DECLARES
	DECLARE
		@GroupID INT,
		@ActivityBegin DATETIME,
		@ActivityEnd DATETIME

	-- SETS
	SET @GroupID = 192767
	SET @ActivityBegin = '2013-09-20'
	SET @ActivityEnd = '2014-10-01'

	SELECT
		grp.GroupName,
		mem.AltID1 AS [EmployeeID],
		mem.FirstName,
		mem.LastName,
		ISNULL(cs.CS1,'') AS [BenefitPlan],
		ISNULL(cs.CS2,'') AS [BenefitOption],
		ISNULL(cs.CS3,'') AS [Location],
		ISNULL(cs.CS5,'') AS [MercerMedicalEffectiveDate],
		CONVERT(VARCHAR(10),tob.AppointmentBeginDate,101) AS [CoachCallsCompleted]     
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 192767)
		AND (mem.RelationshipID = 6) -- Primary Only
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		(
		SELECT
			app.MemberID,
			prg.ProgramID,
			prg.ProgramName,
			prg.EnrollmentDate,
			prg.TerminationDate,
			app.AppointmentBeginDate,
			ROW_NUMBER() OVER (PARTITION BY app.MemberID ORDER BY app.AppointmentBeginDate) AS TobCoachSeq
		FROM
			DA_Production.prod.ProgramEnrollment prg WITH (NOLOCK)
		JOIN
			DA_Production.prod.Appointment app WITH (NOLOCK)
			ON	(prg.MemberID = app.MemberID)
			AND (app.AppointmentStatusID = 4) -- Call Completed
			AND (app.AppointmentBeginDate >= @ActivityBegin)
			AND (app.AppointmentBeginDate < @ActivityEnd)
		WHERE
			prg.GroupID = 192767 AND
			prg.ProgramID = 1 AND -- Tobacco Cessation Program
			app.AppointmentBeginDate >= prg.EnrollmentDate AND
			app.AppointmentBeginDate < ISNULL(prg.TerminationDate,'2999-12-31')
		) tob
		ON	(mem.MemberID = tob.MemberID)
		AND (tob.TobCoachSeq = 3)
	ORDER BY 
		3,4


END

GO
