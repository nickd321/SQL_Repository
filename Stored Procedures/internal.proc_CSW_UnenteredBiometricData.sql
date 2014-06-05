SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [internal].[proc_CSW_UnenteredBiometricData]

	@BeginDate DATETIME = NULL,
	@EndDate DATETIME = NULL
	
AS BEGIN

	SET @BeginDate = DATEADD(dd, DATEDIFF(dd, 0, DATEADD(m,-2, DATEADD(d,1-DATEPART(d,getdate()),GETDATE()))), 0)
	SET @EndDate = DATEADD(dd, DATEDIFF(dd, 0, DATEADD(m,-1, DATEADD(d,1-DATEPART(d,getdate()),GETDATE()))), 0)
	
SELECT 
	DISTINCT
	mem.LastName,
	mem.FirstName,
      lg.MemberID,
      mem.GroupID,
      hpg.GroupName,
      DATEADD(dd, DATEDIFF(dd, 0, lg.CompleteDate), 0) AS CompleteDate,
      lg.UserFullName AS CreatedBy
FROM 
	DA_Production.prod.HMSLog lg
JOIN
	DA_Production.prod.Member mem
	ON	(lg.MemberID = mem.MemberID)
JOIN
	DA_Production.prod.HealthPlanGroup hpg
	ON	(mem.GroupID = hpg.GroupID)
LEFT JOIN
	(
		SELECT 
			MemberID,
			ScreeningDate
		FROM 
			DA_Production.prod.BiometricsScreening
		WHERE
			(ScreeningDate >= @BeginDate)
			--AND	(ScreeningDate < @EndDate)
	) bio
	ON	(lg.MemberID = bio.MemberID)
	AND	(bio.ScreeningDate >= lg.CompleteDate)
WHERE
	lg.DescriptionID = 58	-- '%physician reported %'
	AND	(lg.SubDescriptionName LIKE 'Data entered' OR lg.SubDescriptionName LIKE 'Received completed form')
	AND	(lg.CompleteDate >= @BeginDate)
	AND	(bio.ScreeningDate IS NULL)

	--AND	(CompleteDate < @EndDate)

ORDER BY
	mem.LastName,
	mem.FirstName

END
GO
