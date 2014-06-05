SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 2/19/2014
-- Description:	Coaching participation report for Wells

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [wells].[proc_Coaching_Participation]
	@inBeginDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

	 --Testing: DECLARE @inBeginDate DATETIME SET @inBeginDate = NULL
	SET @inBeginDate = ISNULL(@inBeginDate,'1/1/2014')

	SELECT
		hpg.GroupName,
		mem.FirstName,
		mem.LastName,
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),'') AS [DOB],
		ISNULL(csf.CS1,'') AS [LocationCode],
		ISNULL(csf.CS2,'') AS [MedicalIndicator],
		ISNULL(csf.CS3,'') AS [UnionStatus],
		COUNT(app.AppointmentID) AS [NumberofCompletedCoachingCalls]
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem
		ON	(hpg.GroupID = mem.GroupID)
		AND	(hpg.GroupID = 199640)
		AND	(mem.RelationshipID = 6) -- PRIMARY ONLY
	JOIN
		DA_Production.prod.Appointment app
		ON	(app.MemberID = mem.MemberID)
		AND	(app.AppointmentBeginDate >= @inBeginDate)
		AND	(app.AppointmentStatusID = 4)
	LEFT JOIN
		DA_Production.prod.CSFields csf
		ON	(csf.MemberID = mem.MemberID)
	GROUP BY
		hpg.GroupName,
		mem.FirstName,
		mem.LastName,
		ISNULL(CONVERT(VARCHAR(10),mem.Birthdate,101),''),
		ISNULL(csf.CS1,''),
		ISNULL(csf.CS2,''),
		ISNULL(csf.CS3,'') 

END
GO
