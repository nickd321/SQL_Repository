SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-09-17
-- Description:	Yamaha Redemption Report
--
-- Notes:		This report will be used for tax purposes
--				Report only needed for 4 out of the 5 Yamaha groups that are using the reward gift cards
--
--
-- Updates:		WilliamPe 20131003
--				Updated CS Field Names (WO2769)
--
-- =============================================
CREATE PROCEDURE [yamaha].[proc_Incentives_Redemptions]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL

AS
BEGIN
	SET NOCOUNT ON;

	-- FOR TESTING
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

	-- DECLARES
	DECLARE @GroupID VARCHAR(1000)

	-- SETS
	SET @GroupID = '201849,201850,201851,201852'
	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(yy,DATEDIFF(yy,0,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0)),0))
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

	-- RESULTS
	SELECT  
		grp.GroupName,
		grp.GroupNumber,
		ISNULL(mem.EligMemberID,'') AS [EligMemberID],
		ISNULL(mem.EligMemberSuffix,'') AS [EligMemberSuffix],
		mem.FirstName,
		ISNULL(mem.MiddleInitial,'') AS [MiddleInitial],
		mem.LastName,
		mem.Relationship,
		ISNULL(addr.Address1,'') AS [Address1],
		ISNULL(addr.Address2,'') AS [Address2],
		ISNULL(addr.City,'') AS [City],
		ISNULL(addr.[State],'') AS [State],
		ISNULL(addr.ZipCode,'') AS [ZipCode],
		ISNULL(mem.EmailAddress,'') AS [Email],
		ISNULL(cs.CS1,'') AS [Location],
		ISNULL(cs.CS2,'') AS [SalaryVsHourly],
		ISNULL(cs.CS3,'') AS [CostCenter],
		ISNULL(cs.CS4,'') AS [CompanyCode],
		ISNULL(cs.CS5,'') AS [HomeDepartment],
		ISNULL(cs.CS6,'') AS [Shift],
		ISNULL(cs.CS7,'') AS [BusinessUnit],
		ISNULL(cs.CS8,'') AS [MedicalPlan],
		ISNULL(cs.CS9,'') AS [JobTitle],
		ISNULL(cs.CS10,'') AS [JobRole],
		ISNULL(mem.AltID1,'') AS [EmployeeID],
		CONVERT(VARCHAR(10),red.RequestDate,101) AS [RedeemRequestDate],
		red.RedeemedAmount * red.Quantity AS [AmountRedeemed]
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem  WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID IN (SELECT * FROM DA_Production.dbo.Split(@GroupID,',')))
	LEFT JOIN
		DA_Production.prod.[Address] addr WITH (NOLOCK)
		ON	(mem.MemberID = addr.MemberID)
		AND	(addr.AddressTypeID = 6)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		DA_Production.prod.IncentiveRedemption red WITH (NOLOCK)
		ON	(mem.MemberID = red.MemberID)
		AND	(red.RequestDate >= @inBeginDate)
		AND	(red.RequestDate < @inEndDate)

END
GO
