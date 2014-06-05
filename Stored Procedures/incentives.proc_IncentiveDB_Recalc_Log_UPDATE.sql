SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-01-31
-- Description:	Incentives Recalculation Log Update Stored Procedure 
--
-- Notes:		Please note this is for the groups that currently have an incentive plan 
--				programmed under the new framework that uses the newly created Incentive production database.
--				Currently, the only group is PepsiCo
--				
--				This procedure will be used by Justin Y. and team to 
--				update the recalc log once their nightly job parses through the member
--				list provided through the 'READ' proc.
--
-- Updates:		
--
-- =============================================

CREATE PROCEDURE [incentives].[proc_IncentiveDB_Recalc_Log_UPDATE] 
	@inLogID INT,
	@inRecalculated BIT,
	@inRecalculatedMessage VARCHAR(1000),
	@inRecalculatedDate DATETIME,
	@inRecalculatedBy VARCHAR(50)
AS
BEGIN

	UPDATE DA_Reports.incentives.IncentiveDB_Recalc_Log
	SET
		Recalculated = @inRecalculated, 
		RecalculatedMessage = @inRecalculatedMessage,
		RecalculatedDate = @inRecalculatedDate,
		RecalculatedBy = @inRecalculatedBy
	WHERE
		LogID = @inLogID

END


GO
GRANT EXECUTE ON  [incentives].[proc_IncentiveDB_Recalc_Log_UPDATE] TO [Incentive_User]
GO
