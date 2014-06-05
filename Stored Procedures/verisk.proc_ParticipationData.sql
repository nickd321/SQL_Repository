SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Nick Domokos
-- Create date: 2014-03-19
-- Description:	Verisk Standard Participation Data
-- Vendor:		
--
-- Notes:		
--
-- Updates:
-- =============================================

CREATE PROCEDURE [verisk].[proc_ParticipationData]
	@inGroupID INT,
	@inBeginDate DATETIME,
	@inEndDate DATETIME
AS
BEGIN
	SET NOCOUNT ON;

	-- COACHING ACTIVITIES (WEB AND TELEPHONE)
	SELECT
		REPLACE(grp.GroupName,',','') AS CompanyName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS DOB,
		mem.Relationship,
		mem.Gender,
		mem.AltID1,
		'Telephone Coaching' AS ActivityType,
		enr.ProgramName AS ActivityDetail,
		CONVERT(VARCHAR(10),appt.AppointmentBeginDate,101) AS ActivityDate
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = @inGroupID)
	JOIN
		DA_Production.prod.Appointment appt WITH (NOLOCK)
		ON	(mem.MemberID = appt.MemberID)
		AND	(appt.AppointmentBeginDate >= @inBeginDate AND appt.AppointmentBeginDate < @inEndDate)
		AND (appt.AppointmentStatusID = 4)
	LEFT JOIN
		DA_Production.prod.ProgramEnrollment enr WITH (NOLOCK)
		ON	(appt.MemberID = enr.MemberID)
		AND	(appt.AppointmentBeginDate >= enr.EnrollmentDate AND appt.AppointmentBeginDate < ISNULL(enr.TerminationDate,'2999-12-31'))

	UNION ALL

	SELECT
		REPLACE(grp.GroupName,',','') AS CompanyName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS DOB,
		mem.Relationship,
		mem.Gender,
		mem.AltID1,
		'Web Class' AS ActivityType,
		web.CourseNameID AS ActivityDetail,
		CONVERT(VARCHAR(10),web.CourseCompleteDate,101) AS ActivityDate
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = @inGroupID)
	JOIN
		DA_Production.prod.WebClass web WITH (NOLOCK)
		ON	(mem.MemberID = web.MemberID)
		AND (web.CourseCompleteDate IS NOT NULL)
		AND	(web.CourseCompleteDate >= @inBeginDate)
		AND	(web.CourseCompleteDate < @inEndDate)
	GROUP BY
		REPLACE(grp.GroupName,',',''),
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101),
		mem.Relationship,
		mem.Gender,
		mem.AltID1,
		web.CourseNameID,
		CONVERT(VARCHAR(10),web.CourseCompleteDate,101)


END

GO
