SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 3/13/2014
-- Description:	Cancer Treatment Centers of America Tobacco Cessation Coaching Report
--
-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [ctca].[proc_Coaching_TobaccoCessation]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
	
AS
BEGIN

	SET NOCOUNT ON;
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME
	SET @inBeginDate = ISNULL(@inBeginDate,'2013-09-01')
	SET @inEndDate = ISNULL(@inEndDate,'2014-01-01')
	
	SELECT
		data.GroupName,
		data.GroupNumber,
		ISNULL(data.EligMemberID,'') AS [EligMemberID],
		data.EligMemberSuffix,
		data.FirstName,
		ISNULL(data.MiddleInitial,'') AS [MiddleInitial],
		data.LastName,
		ISNULL(CONVERT(VARCHAR(10),data.Birthdate,101),'') AS [Birthdate],
		data.Relationship,
		ISNULL(data.SubscriberSSN,'') AS [SSN],
		ISNULL(data.MedicalOption,'') AS [MedicalOption],
		ISNULL(data.Location,'') AS [Location],
		ISNULL(data.EligibilityIndicator,'') AS [EligibilityIndicator]
	FROM
		(
		SELECT
			mem.MemberID,
			hpg.GroupName,
			hpg.GroupNumber,
			mem.EligMemberID,
			mem.EligMemberSuffix,
			mem.FirstName,
			mem.MiddleInitial,
			mem.LastName,
			mem.Birthdate,
			mem.Relationship,
			mem.SubscriberSSN,
			ISNULL(csf.CS4,'') AS [MedicalOption],
			ISNULL(csf.CS2,'') AS [Location],
			ISNULL(csf.CS3,'') AS [EligibilityIndicator],
			enr.ProgramEnrollmentID,
			enr.ProgramID,
			enr.EnrollmentDate,
			enr.TerminationDate,
			app.AppointmentBeginDate,
			app.AppointmentStatusID,
			ROW_NUMBER() OVER (PARTITION BY mem.MemberID ORDER BY app.AppointmentBeginDate) AS [CoachSeq]
		FROM
			DA_Production.prod.HealthPlanGroup hpg
		JOIN
			DA_Production.prod.Member mem
			ON	(hpg.GroupID = mem.GroupID)
			AND	(hpg.GroupID = 191393)
		JOIN
			DA_Production.prod.ProgramEnrollment enr WITH (NOLOCK)
			ON	(mem.MemberID = enr.MemberID)
			AND	(enr.ProgramID = 1) -- TOBACCO PROGRAM
		JOIN
			DA_Production.prod.Appointment app WITH (NOLOCK)
			ON	(mem.MemberID = app.MemberID)
			AND	(app.AppointmentStatusID = 4)
			AND	(app.AppointmentBeginDate BETWEEN enr.EnrollmentDate AND ISNULL(enr.TerminationDate,'2999-12-31'))
		LEFT JOIN
			DA_Production.prod.CSFields csf
			ON	(csf.MemberID = mem.MemberID)
		WHERE
			app.AppointmentBeginDate >= @inBeginDate AND
			app.AppointmentBeginDate < @inEndDate
		) data
	WHERE
		CoachSeq = 6

END
GO
