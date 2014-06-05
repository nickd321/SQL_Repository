SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 3/5/2014
-- Description:	Cohu Tobacco Surcharge Report

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [cohu].[proc_Coaching_Tobacco]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
	
AS
BEGIN

	SET NOCOUNT ON;

	SET @inBeginDate = ISNULL(@inBeginDate,'11/1/2013')
	SET @inEndDate = ISNULL(@inEndDate,'11/1/2014')	

	SELECT
		hpg.GroupName,
		hpg.GroupNumber,
		ISNULL(mem.EligMemberID,'') AS [EligMemberID],
		ISNULL(mem.AltID1,'') AS [EmployeeID],
		mem.FirstName,
		mem.LastName,
		ISNULL(addr.Address1,'') AS [Address1],
		ISNULL(addr.Address2,'') AS [Address2],
		ISNULL(addr.City,'') AS [City],
		ISNULL(addr.State,'') AS [State],
		ISNULL(addr.ZipCode,'') AS [ZipCode],
		ISNULL(mem.EmailAddress,'') AS [EmailAddress],
		ISNULL(csf.CS1,'') AS [CompanyName],
		ISNULL(csf.CS2,'') AS [Department#],
		ISNULL(csf.CS3,'') AS [MedicalElection],
		ISNULL(csf.CS4,'') AS [SmokerVsNon],
		'Y' AS [CompletedFourCalls],
		app.AppointmentBeginDate AS [CompletedFourCallsDate]
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem
		ON	(mem.GroupID = hpg.GroupID)
		AND	(hpg.GroupID = 203286)
		AND	(mem.RelationshipID = 6)
	JOIN
		DA_Production.prod.CSFields csf
		ON	(csf.MemberID = mem.MemberID)
		AND	(csf.CS4 = 'Smoker')
	LEFT JOIN
		DA_Production.prod.[Address] addr
		ON	(addr.MemberID = mem.MemberID)
		AND	(addr.AddressTypeID = 6)
	JOIN
		(
		SELECT
			MemberID,
			AppointmentBeginDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY AppointmentBeginDate) AS [AppSeq]
		FROM
			DA_Production.prod.Appointment
		WHERE
			(AppointmentBeginDate >= @inBeginDate) AND 
			(AppointmentBeginDate < @inEndDate) AND
			(AppointmentStatusID = 4)
		) app
		ON	(app.MemberID = mem.MemberID)
		AND	(app.AppSeq = 4)

END
GO
