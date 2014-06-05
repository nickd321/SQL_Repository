SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-06-10
-- Description:	Havi Group Activity Monitor Report
--
-- Notes:		This report will track the number of minutes 
--				completed (connected steps only; no manual or reclassified).
--				Date ranges are from 4/1/2013 through 10/31/2013.
--				The report is cumulative and will run biweekly.
--			
--				Client also wanted to know the registration date and if they purchased the pebble
--				versus exchanging an actiped for a pebble through their HR department.
--				I was able to determine this by finding the earliest pebble registration date and
--				then determined if it was purchased if the purchase date was earlier than the registration date.
--
-- Updates:		WilliamPe 20130714
--				Per WO2403, added Total steps.  Please note that this group only accepts steps from the device.
--
--				WilliamPe 20131212
--				Per WO3032, modified activitydate cap from 2013-11-01 to 2014-01-01
--
-- =============================================

CREATE PROCEDURE [havi].[proc_MonitorActivity]
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;
	
	SET @inEndDate = ISNULL(@inEndDate, DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))

	SELECT
		grp.GroupName,
		mem.FirstName,
		ISNULL(mem.MiddleInitial,'') AS MiddleInitial,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS Birthdate,
		ISNULL(cs.CS1,'') AS Location,
		CONVERT(VARCHAR(10),reg.FirstRegistrationDate,101) AS RegistrationDate,
		CASE WHEN purch.OrderDate IS NOT NULL AND purch.OrderDate < reg.FirstRegistrationDate THEN 'Y' ELSE '' END AS PurchasedPebble,
		SUM(lg.TotalTime)/60 AS TotalMinutes, -- Source unit of measure is in seconds
		SUM(lg.TotalSteps) AS TotalSteps
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = 197699)
	LEFT JOIN
		DA_Production.prod.CSFields cs WITH (NOLOCK)
		ON	(mem.MemberID = cs.MemberID)
	JOIN
		DA_Production.prod.ActivityMonitorLog lg
		ON	(mem.MemberID = lg.MemberID)
	LEFT JOIN
		(
		SELECT
			MemberID,
			DeviceName,
			SerialNumber,
			FirstRegistrationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY FirstRegistrationDate) AS RegDateSeq
		FROM
			(
			SELECT
				MemberID,
				DeviceName,
				SerialNumber,
				MIN(RegistrationDate) AS FirstRegistrationDate
			FROM
				DA_Production.prod.ActivityMonitor (NOLOCK)
			WHERE
				GroupID = 197699 AND
				DeviceName = 'Pebble'
			GROUP BY
				MemberID,
				DeviceName,
				SerialNumber
			) act
		) reg
		ON	(mem.MemberID = reg.MemberID)
		AND	(reg.RegDateSeq = 1)
	LEFT JOIN
		(
		SELECT
			mem.MemberID,
			ord.OrderID,
			ord.CreateDate AS OrderDate,
			ord.OrderStatusID,
			ord.ShippedDate,
			ord.ParentOrderID,
			ord.AddDate,
			prodOpt.ProductOptionID,
			prodOpt.SKU,
			prodOpt.Name,
			prodOpt.ProductID,
			ROW_NUMBER() OVER (PARTITION BY mem.MemberID ORDER BY ord.CreateDate) AS OrderDateSeq
		FROM
			DA_Production.prod.Member mem WITH (NOLOCK)
		JOIN
			HealthyStore.dbo.HS_Customer cust WITH (NOLOCK)
			ON	(cust.SiteMemberID = mem.MemberID)
			AND	(cust.Deleted = 0)
		JOIN
			HealthyStore.dbo.HS_Order ord WITH (NOLOCK)
			ON	(ord.CustomerID = cust.CustomerID)
			AND	(ord.Deleted = 0)
			AND	(ord.OrderStatusID <> 6) --Cancelled
		JOIN
			HealthyStore.dbo.HS_OrderItem item
			ON	(ord.OrderID = item.OrderID)
		JOIN
			HealthyStore.dbo.HS_ProductOption prodOpt
			ON	(item.ProductOptionID = prodOpt.ProductOptionID)
			AND	(prodOpt.SKU IN ('850-160','850-164','850-161','850-163'))
		WHERE
			mem.GroupID = 197699
		) purch
		ON	(purch.MemberID = mem.MemberID)
		AND	(purch.OrderDateSeq = 1)
	WHERE
		lg.ActivityType = 'Actiped' AND  -- only connected steps allowed
		lg.ActivityDate >= '2013-04-01' AND
		lg.ActivityDate < @inEndDate AND
		lg.ActivityDate < '2014-01-01'
	GROUP BY
		grp.GroupName,
		mem.FirstName,
		mem.MiddleInitial,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101),
		ISNULL(cs.CS1,''),
		CONVERT(VARCHAR(10),reg.FirstRegistrationDate,101),
		CASE WHEN purch.OrderDate IS NOT NULL AND purch.OrderDate < reg.FirstRegistrationDate THEN 'Y' ELSE '' END
		
	
END
GO
