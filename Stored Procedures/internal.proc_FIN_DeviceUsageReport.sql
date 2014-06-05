SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [internal].[proc_FIN_DeviceUsageReport]

	@BeginDate DATETIME = NULL,
	@EndDate DATETIME = NULL

AS BEGIN

	SET @BeginDate = ISNULL(@BeginDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
	SET @EndDate = ISNULL(@EndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

	SELECT 
		cnt.[Health Plan Name],
		cnt.[Group Name],
		cnt.MemberID,
		cnt.[Registration Date],
		cnt.Steps,
		cnt.IsActive
	FROM 
		(
		SELECT 
			aml.MemberID AS MemberID,
			MAX(grp.HealthPlanName) AS 'Health Plan Name',
			MAX(grp.GroupName) AS 'Group Name',
			MAX(am.RegistrationDate) AS 'Registration Date',
			SUM(aml.TotalSteps) AS 'Steps',
			CASE WHEN SUM(aml.TotalSteps) < 100 THEN 'N' ELSE 'Y' END AS IsActive
		FROM 
			(
				SELECT 
					MonitorUserID,
					MAX(RegistrationDate) AS RegistrationDate
				FROM
					[DA_Production].prod.ActivityMonitor
				WHERE
					RegistrationDate <= @EndDate
					AND 
					DeviceName != 'Personal Access Point'
				GROUP BY
					MonitorUserID
			) am

		JOIN
			[DA_Production].[prod].[ActivityMonitorLog] aml
			ON	(am.MonitorUserID = aml.MonitorUserID)
		JOIN
			[DA_Production].prod.HealthPlanGroup grp
			ON	(aml.GroupID = grp.GroupID)
		WHERE
			aml.ActivityDate BETWEEN @BeginDate AND @EndDate
		GROUP BY
			aml.MemberID,
			am.RegistrationDate
		) cnt
	ORDER BY
		cnt.[Health Plan Name],
		cnt.[Group Name]
	
END
GO
