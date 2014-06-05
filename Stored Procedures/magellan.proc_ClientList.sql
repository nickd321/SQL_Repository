SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [magellan].[proc_ClientList]

AS BEGIN

	SELECT 
		GroupName
	FROM 
		DA_Production.prod.HealthPlanGroup
	WHERE
		HealthPlanAffiliateID = 377
	ORDER BY
		GroupName
	
END
GO
