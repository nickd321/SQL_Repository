SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 3/13/2014
-- Description:	Racetrac Healthyroads Registration Contact Information

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [racetrac].[proc_HRDSRegistration_ContactInfo]
AS
BEGIN
SELECT 
	grp.GroupName,
	grp.GroupNumber,
	mem.EligMemberID,
	mem.EligMemberSuffix,
	mem.FirstName,
	mem.LastName,
	--mem.BirthDate,
	rel.RelationshipDescription AS [Relationship],
	ISNULL(addr.Address1,'') AS [Address1],
	ISNULL(addr.Address2,'') AS [Address2],
	ISNULL(addr.City,'') AS [City],
	ISNULL(addr.State,'') AS [State],
	ISNULL(addr.ZipCode,'') AS [ZipCode],
	ISNULL(mem.HomePhone,'') AS [HomePhone],
	ISNULL(mem.Email,'') AS [Email],
	ISNULL(mem.CS1,'') AS [Plan],
	ISNULL(Mem.CS2,'') AS [Area],
	ISNULL(mem.CS3,'') AS [JobCode],
	ISNULL(mem.CS4,'') AS [Department]
FROM
	Benefits.dbo.[Group] grp
JOIN
	Benefits.dbo.Member mem
	ON	(grp.GroupID = mem.GroupID)
	AND	(mem.Deleted = 0)
JOIN
	ASHApplicationPermissions.dbo.ApplicationUsers perm  WITH (NOLOCK)
	ON	(mem.SSOID = perm.UserID)
	--AND (perm.DateCreated >= '10/1/2013')
	AND	(perm.ApplicationID = 11) -- Healthyroads
	AND	(perm.Deleted = 0)
JOIN
	Benefits.dbo.Relationship rel
	ON (mem.RelationshipID = rel.RelationshipID)
LEFT JOIN
	Benefits.dbo.MemberAddress addr
	ON	(mem.MemberID = addr.MemberID)
	AND (AddressTypeID = 6)
WHERE
	grp.GroupID = 203016
	ORDER BY 2,1
	
END
GO
