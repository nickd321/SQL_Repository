SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-31
-- Description:	Incentives Recalculation Log Read Stored Procedure
--
-- Notes:		Please note this is for the groups that currently have an incentive plan 
--				programmed under the old/current framework using the Healthyroads database.
--					
--				This procedure will be used by Justin Y. and team to 
--				read the members he needs to recalculate
--
-- Updates:		
--
-- =============================================

CREATE PROCEDURE [incentives].[proc_HealthyroadsDB_Recalc_Log_READ] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL,
	@inRecalculated BIT = NULL
AS
BEGIN

	SET NOCOUNT ON;

	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),-1)) 
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0))
	SET @inRecalculated = ISNULL(@inRecalculated,0)

	SELECT
		LogID,
		HealthPlanID,
		GroupID,
		MemberID,
		ChangeDate, 
		Change,
		Recalculated,
		RecalculatedMessage,
		RecalculatedDate,
		RecalculatedBy,
		AddDate, 
		AddedBy
	FROM
		DA_Reports.incentives.HealthyroadsDB_Recalc_Log WITH (NOLOCK)
	WHERE
		-- @inEndDate IS EXCLUSIVE TO PREVENT OVERLAP
		AddDate >= @inBeginDate AND 
		AddDate < @inEndDate AND 
		Recalculated = @inRecalculated
	
END


GO
GRANT EXECUTE ON  [incentives].[proc_HealthyroadsDB_Recalc_Log_READ] TO [Incentive_User]
GO
