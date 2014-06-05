SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 4/22/2014
-- Description:	Givaudan Quarterly Steps Report

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [givaudan].[proc_Steps_Quarterly]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME
SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(qq,DATEDIFF(qq,0,GETDATE())-1,0))
SET @inEndDate = ISNULL(@inEndDate,DATEADD(qq,DATEDIFF(qq,0,GETDATE()),0))

SELECT
	grp.GroupName,
	mem.FirstName,
	mem.LastName,
	CONVERT(VARCHAR(10),Birthdate,101) AS [Birthdate],
	mem.AltID1 AS [EmployeeID],
	SUM(lg.TotalSteps) AS [TotalSteps]
FROM
	DA_Production.prod.HealthPlanGroup grp
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = grp.GroupID)
	AND	(mem.GroupID = 195332)
JOIN
	DA_Production.prod.ActivityMonitorLog lg
	ON	(mem.MemberID = lg.MemberID)
	AND	(lg.ActivityDate >= @inBeginDate)
	AND (lg.ActivityDate < @inEndDate)
	AND	(lg.ActivityType = 'Actiped')
GROUP BY
	grp.GroupName,
	mem.FirstName,
	mem.LastName,
	CONVERT(VARCHAR(10),Birthdate,101),
	mem.AltID1
END
GO
