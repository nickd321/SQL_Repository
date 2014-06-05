SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [internal].[proc_Nemours_ManualIncentiveFeed]

	@BeginDate DATETIME = NULL,
	@EndDate DATETIME = NULL

AS BEGIN

	SET @BeginDate = ISNULL(@BeginDate,DATEADD(DD,-8,DATEADD(WK,DATEDIFF(WK,0,GETDATE()),0)))
	SET @EndDate = ISNULL(@EndDate,DATEADD(DD,-1,DATEADD(WK,DATEDIFF(WK,0,GETDATE()),0)))

	SELECT
		EligMemberID,
		EligMemberSuffix,
		FirstName,
		LastName,
		DOB,
		ActivityName,
		CONVERT(VARCHAR,ActivityDate,101) AS ActivityDate
	FROM
		(
		SELECT
			mem.EligMemberID,
			mem.EligMemberSuffix,
			mem.FirstName,
			mem.LastName,
			CONVERT(VARCHAR,mem.Birthdate,101) AS DOB,
			'Tobacco Cessation Program Participation' AS ActivityName,
			appt.AppointmentBeginDate AS ActivityDate,
			ROW_NUMBER() OVER(PARTITION BY mem.MemberID ORDER BY appt.AppointmentBeginDate) AS Seq
		FROM
			DA_Production.prod.Member mem
		JOIN
			DA_Production.prod.ProgramEnrollment prog
			ON	(mem.MemberID = prog.MemberID)
			AND	(prog.ProgramID = 1) --Tobacco Cessation
		JOIN
			DA_Production.prod.Appointment appt
			ON	(mem.MemberID = appt.MemberID)
			AND	(appt.AppointmentStatusID = 4)
			AND	(appt.AppointmentBeginDate >= '5/1/2013')
			AND	(appt.AppointmentBeginDate < '12/1/2013')
			AND	(appt.AppointmentBeginDate >= prog.EnrollmentDate)
			AND	(appt.AppointmentBeginDate < ISNULL(prog.TerminationDate,'12/31/2999'))
		WHERE
			mem.GroupID = 192768
		) rpt
	WHERE
		Seq = 5 AND
		ActivityDate >= @BeginDate AND
		ActivityDate < @EndDate
	
END
GO
