SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW	[tableau].[vw_AppointmentsScheduledOnline]
AS

/****************************************************************************************************
View:		vw_AppointmentsScheduledOnline
Date:		03/28/2013
Author:		Blair Gibb

Objectives:	See Request #1227
			Tableau Dashboard for New Coaching Appointments created Online  

			Create a dashboard showing the count of appointments created online 
			and the status of the appointment.  Volume and final status of call are important. 
			
			- Online coaching appointments are identified by the AppointmentSourceID
			and AppointmentSourceName   This was implemented on 1/11/2013, which is why
			that date is hard-coded into the view.

****************************************************************************************************/

SELECT
	AppointmentSourceName,
	AppointmentSourceID,
	SourceAddDate,
	AppointmentBeginDate,
	AppointmentEndDate,
	AppointmentTypeID,
	AppointmentTypeName,
	MemberID,
	AppointmentStatusName,
	AppointmentStatusID,
	AppointmentCancelDate,
	-- The following line, if done in Tableau, causes the extract refresh to take around 20 minutes.
	-- doing the work here makes it take 2 seconds...
	'Q' + LTRIM(STR(DATEPART(QQ, SourceAddDate))) AS 'OrderQuarter',
	-- All date hierarchy fields are in SQL now
	YEAR(SourceAddDate) AS 'OrderYear',
	DAY(SourceAddDate) AS 'OrderDay'
FROM 
	DA_Production.prod.Appointment
WHERE
	SourceAddDate > '1/10/2013'
GO
