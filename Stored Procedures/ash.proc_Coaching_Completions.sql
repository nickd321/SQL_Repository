SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 2/11/2014
-- Description:	Report for ASH waived members
--				who have completed 8 or more coaching calls.
--
-- Notes:		The request (3415) was for coaching completions
--				for long-term waivers, but it should be noted that this procedure 
--				looks at the entire population
--		  
-- Updates:
--
-- =============================================

CREATE PROCEDURE [ash].[proc_Coaching_Completions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
	
AS BEGIN

	SET NOCOUNT ON;

	SET	@inBeginDate = ISNULL(@inBeginDate,'10/1/2013')
	SET	@inEndDate = ISNULL(@inEndDate,'10/1/2014')
	
	SELECT
		FirstName,
		LastName,
		Relationship,
		EligMemberSuffix AS [Suffix],
		AltID1 AS [EEID],
		CONVERT(CHAR(10),elig.EffectiveDate,121) AS [EffectiveDate],
		CONVERT(CHAR(10),appt.AppointmentBeginDate,121) AS [EightCallsCompletedDate]
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem
		ON	hpg.GroupID = mem.GroupID
		AND	hpg.GroupID = 1110
	JOIN
		DA_Production.prod.Eligibility elig
		ON	elig.MemberID = mem.MemberID
		AND	elig.TerminationDate IS NULL
	JOIN
		(
		SELECT
			MemberID,
			AppointmentBeginDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentBeginDate) AS ApptSeq
		FROM 
			DA_Production.prod.Appointment app
		WHERE
			AppointmentBeginDate >= @inBeginDate
			AND	AppointmentBeginDate < @inEndDate
			AND AppointmentStatusID = 4
			AND GroupID = 1110
		) appt
		ON mem.MemberID = appt.MemberID
		AND appt.ApptSeq = 8
END
GO
