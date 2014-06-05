SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-11-13
-- Description:	Telligen E-Coaching Completion Report
--
-- Notes:		Client wants to see members who completed at least one e-coaching course
--				during the previous month
-- =============================================
CREATE PROCEDURE [telligen].[proc_ECoaching_Completions]
	
	@inBeginDate DATETIME = NULL, 
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

	SELECT
		grp.GroupName,
		mem.FirstName,
		mem.LastName,
		ISNULL(addr.Address1,'') AS Address1,
		ISNULL(addr.Address2,'') AS Address2,
		ISNULL(addr.City,'') AS City,
		ISNULL(addr.[State],'') AS [State],
		ISNULL(addr.ZipCode,'') AS ZipCode,
		ISNULL(mem.EmailAddress,'') AS EmailAddress,
		ISNULL(mem.AltID1,'') AS [UniqueIdentifier],
		ISNULL(cs.CS1,'') AS BusinessUnit,
		ISNULL(cs.CS2,'') AS HireDate,
		ISNULL(cs.CS3,'') AS LocationDescription,
		ISNULL(cs.CS4,'') AS SupervisorName
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 202842)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	LEFT JOIN
		DA_Production.prod.[Address] addr WITH (NOLOCK)
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)
	JOIN
		Healthyroads.dbo.EC_MemberCourse ec
		ON	(mem.MemberID = ec.MemberID)
		AND	(ec.CompletedDate >= @inBeginDate)
		AND	(ec.CompletedDate < @inEndDate)
		AND	(ec.Deleted = 0)
	GROUP BY
		grp.GroupName,
		mem.FirstName,
		mem.LastName,
		ISNULL(addr.Address1,''),
		ISNULL(addr.Address2,''),
		ISNULL(addr.City,''),
		ISNULL(addr.[State],''),
		ISNULL(addr.ZipCode,''),
		ISNULL(mem.EmailAddress,''),
		ISNULL(mem.AltID1,''),
		ISNULL(cs.CS1,''),
		ISNULL(cs.CS2,''),
		ISNULL(cs.CS3,''),
		ISNULL(cs.CS4,'')
	ORDER BY
		2,3

END
GO
