SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author: William Perez		
-- Create date: 2013-10-16
-- Description:	GameStop Coaching Report
-- =============================================
CREATE PROCEDURE [gamestop].[proc_Coaching] 
	@inRunDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

	-- DECLARES
	DECLARE
	@GroupID INT,
	@ActivityBegin DATETIME,
	@ActivityEnd DATETIME

	-- SETS
	SET @GroupID = 181275
	SET @ActivityBegin = '2013-04-01'
	SET @ActivityEnd = '2014-04-01' -- EXCLUSIVE
	SET @inRunDate = ISNULL(@inRunDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE())+1,0))

	-- RESULTS
	SELECT
		mem.AltID1 AS [EmployeeID],
		grp.GroupName,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS [DOB],
		mem.Relationship,
		CONVERT(VARCHAR(10),cch.FourthCoachingCallDate,101) AS [FourthCoachingCallDate],
		CASE WHEN bio.ScreeningDate IS NOT NULL THEN 'Y' ELSE '' END AS [BiometricScreening] -- DECIDED (ON A CLIENT CALL) AGAINST USING A DATE SINCE THE CLIENT'S VENDOR WOULD ALWAYS HAVE THE LATEST BIO DATA 
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = @GroupID)
		AND	(mem.RelationshipID IN (1,2,6))
	JOIN
		(
		SELECT
			MemberID,
			AppointmentStatusID,
			AppointmentStatusName,
			AppointmentTypeID,
			AppointmentTypeName,
			AppointmentBeginDate AS FourthCoachingCallDate,
			AppointmentEndDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentBeginDate) AS CoachSeq
		FROM
			DA_Production.prod.Appointment
		WHERE
			GroupID = @GroupID AND
			AppointmentStatusID = 4 AND
			AppointmentBeginDate >= @ActivityBegin AND
			AppointmentBeginDate < @ActivityEnd 
		) cch
		ON	(mem.MemberID = cch.MemberID)
		AND	(cch.CoachSeq = 4)
	LEFT JOIN
		(
		SELECT
			MemberID,
			MIN(ScreeningDate) AS ScreeningDate
		FROM
			DA_Production.prod.BiometricsScreening
		WHERE
			GroupID = @GroupID AND
			ScreeningDate >= @ActivityBegin AND
			ScreeningDate < @ActivityEnd 
		GROUP BY
			MemberID
		) bio
		ON	(mem.MemberID = bio.MemberID)
	WHERE
		cch.FourthCoachingCallDate < @inRunDate


END
GO
