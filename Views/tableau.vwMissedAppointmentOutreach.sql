SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW	[tableau].[vwMissedAppointmentOutreach]
AS

/****************************************************************************************************
View:			vwMissedAppointmentOutreach
Date:			04/09/2013
Author:		Blair Gibb

Objectives:	
			Tableau Dashboard: Performance Standards  

			The process for storing outreach information changed in Nov 2012.  This view will
			take the place of the earlier view in HrlDw

****************************************************************************************************/

SELECT
	HealthPlanID,
	GroupID,
	MemberID,
	OutreachMemberID,
	StartedDate,
	CompletedDate,
	OutreachTypeName,
	OutreachCompleteResultName,
	LastActionTypeName,
	LastActionResultName,
	LastActionDate,
	OutreachGroupID,
	GroupCampaignName
FROM
	[DA_Production].[prod].[OutreachCampaign] orc
WHERE
	OutreachTypeID IN (6,7)						-- 'Missed Kickoff' or 'Missed Appointment'
	AND	(LastActionTypeID = 1)					-- Outreach Rep Call
GO
