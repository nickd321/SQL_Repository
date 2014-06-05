SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 4/28/2014
-- Description:	Monthly steps report for Haldex

-- Notes:		
--				
--				
--				
--
-- Updates:
--
-- =============================================

CREATE PROCEDURE [haldex].[proc_Activity_Steps]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN
	SET NOCOUNT ON;

--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME

SET @inBeginDate = ISNULL(@inBeginDate,'1/1/2014')
SET @inEndDate = ISNULL(@inEndDate,'12/13/2014')


SELECT
	hpg.GroupName,
	ISNULL(mem.AltID1,'') AS [EmployeeFileNumber],
	ISNULL(mem.EligMemberID,'') AS [EligMemberID],
	ISNULL(mem.EligMemberSuffix,'') AS [EligMemberSuffix],
	mem.FirstName,
	ISNULL(mem.MiddleInitial,'') AS [MiddleInitial],
	mem.LastName,
	CONVERT(VARCHAR(10),Birthdate,101) AS [Birthdate],
	mem.Relationship,
	ISNULL(mem.EmailAddress,'') AS [Email],
	ISNULL(csf.CS1,'') AS [Location],
	ISNULL(act.[1],0) AS [Q1Steps],
	ISNULL(act.[2],0) AS [Q2Steps],
	ISNULL(act.[3],0) AS [Q3Steps],
	ISNULL(act.[4],0) AS [Q4Steps],
	ISNULL(act.[1],0) + ISNULL(act.[2],0) + ISNULL(act.[3],0) + ISNULL(act.[4],0) AS [TotalSteps]
FROM
	DA_Production.prod.HealthPlanGroup hpg
JOIN
	DA_Production.prod.Member mem
	ON	(mem.GroupID = hpg.GroupID)
	AND	(hpg.GroupID = 204729)
JOIN
	(
	SELECT
		MemberID,
		[1],
		[2],
		[3],
		[4]
	FROM
		(
		SELECT
			MemberID,
			TotalSteps AS [MeasureValue],
			DATEPART(qq,ActivityDate) AS [Measure]
		FROM
			DA_Production.prod.ActivityMonitorLog
		WHERE
			(ActivityDate >= @inBeginDate)
			AND	(ActivityDate < @inEndDate)
		) act
	PIVOT
		(
		SUM(MeasureValue) FOR Measure IN ([1],[2],[3],[4])
		) pvt
	) act
	ON	(act.MemberID = mem.MemberID)
LEFT JOIN
	DA_Production.prod.CSFields csf
	ON	(csf.MemberID = mem.MemberID)
	
END
GO
