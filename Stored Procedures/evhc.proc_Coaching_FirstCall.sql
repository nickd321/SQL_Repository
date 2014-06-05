SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		Nick Domokos
-- Create date: 2014-02-24
-- Description:	EVHC Anthem monthly Coaching Report
--
-- Notes:		Client wants to see members who completed
--				a call within the previous month
-- =============================================

CREATE PROCEDURE [evhc].[proc_Coaching_FirstCall]
	
	@inBeginDate DATETIME = NULL, 
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;
--Testing: DECLARE	@inBeginDate DATETIME,@inEndDate	DATETIME
	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

SELECT
	mem.FirstName,
	mem.LastName,
	CONVERT(VARCHAR(10),mem.Birthdate,101) AS [DOB],
	mem.Relationship,
	mem.Gender,
	addr.Address1,
	addr.Address2,
	addr.City,
	addr.[State],
	addr.ZipCode
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	mem.GroupID = hpg.GroupID
	AND	hpg.GroupID = 194355
LEFT JOIN
	DA_Production.prod.[Address] addr
	ON	(mem.MemberID = addr.MemberID)
	AND	(addr.AddressTypeID = 6)
JOIN
	(
	SELECT
		MemberID,
		AppointmentBeginDate,
		AppointmentEndDate,
		ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentBeginDate) AS [RowSeq]
	FROM
		DA_Production.prod.Appointment app
	WHERE
		AppointmentStatusID = 4 AND
		GroupID = 194355 AND
		AppointmentBeginDate >= '2013-09-30' AND
		AppointmentBeginDate < '2014-07-01'
	) app	
	ON	(mem.MemberID = app.MemberID)
	AND (app.RowSeq = 1) -- FirstCall
WHERE
	app.AppointmentBeginDate >= @inBeginDate AND
	app.AppointmentBeginDate < @inEndDate

END
GO
