SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [selfservice].[proc_Appointments]

AS BEGIN

	IF OBJECT_ID('selfservice.Appointments') IS NOT NULL BEGIN
		DROP TABLE selfservice.Appointments
	END

	SELECT
		clnt.[Type] AS ClientType,
		clnt.ClientID,
		clnt.ClientName,
		clnt.PlanSponsorName,
		mem.MemberID,
		enr.ProgramName,
		appt.AppointmentID,
		appt.AppointmentBeginDate,
		appt.AppointmentTypeName,
		appt.CoachName,
		elig.IsTermed,
		mem.FirstName,
		mem.LastName,
		mem.Birthdate,
		mem.Relationship,
		mem.EligMemberID + '-' + mem.EligMemberSuffix AS EligMemberID,
		mem.EmailAddress AS Email,
		ISNULL(addr.Address1,'') + ' ' + ISNULL(addr.Address2,'') AS [Address],
		addr.City,
		addr.[State],
		addr.ZipCode,
		mem.AltID1,
		mem.AltID2,
		cs.CS1,
		cs.CS2,
		cs.CS3,
		cs.CS4,
		cs.CS5,
		cs.CS6,
		cs.CS7,
		cs.CS8,
		cs.CS9,
		cs.CS10,
		cs.CS11,
		cs.CS12,
		cs.CS13,
		cs.CS14,
		cs.CS15,
		cs.CS16,
		cs.CS17,
		cs.CS18,
		cs.CS19,
		cs.CS20,
		cs.CS21,
		cs.CS22,
		cs.CS23,
		cs.CS24
	INTO
		DA_Reports.selfservice.Appointments
	FROM
		DA_Production.prod.Client clnt
	JOIN
		DA_Production.prod.Member mem
		ON	(clnt.GroupID = mem.GroupID)
	JOIN
		DA_Production.prod.Appointment appt
		ON	(mem.MemberID = appt.MemberID)
		AND	(appt.AppointmentStatusID = 4)
		AND	(YEAR(appt.AppointmentBeginDate) >= YEAR(GETDATE()) - 3) --Only show last 3 years of appointments
	JOIN
		DA_Production.prod.ProgramEnrollment enr
		ON	(mem.MemberID = enr.MemberID)
		AND	(enr.EnrollmentDate <= appt.AppointmentBeginDate)
		AND	(ISNULL(enr.TerminationDate,'1/1/3000') > appt.AppointmentBeginDate)
	LEFT JOIN
		(
		SELECT
			MemberID,
			ROW_NUMBER() OVER(PARTITION BY MemberID ORDER BY EffectiveDate DESC) AS Sequence,
			IsTermed
		FROM
			DA_Production.prod.Eligibility
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.Sequence = 1)
	LEFT JOIN
		DA_Production.prod.CSFields cs
		ON	(mem.MemberID = cs.MemberID)
	LEFT JOIN
		DA_Production.prod.[Address] addr
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)

	--Innocuous Output, so that this may be used within the report automation process
	SELECT 1 AS [Output]

END
GO
