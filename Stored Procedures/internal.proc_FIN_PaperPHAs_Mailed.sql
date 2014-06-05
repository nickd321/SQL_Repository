SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2014-04-01
-- Description:	Finance Paper PHA Mailed Report
--
-- Notes:		This report will be delivered to Finance in order to 
--				invoice for every Paper PHA that is sent to a member
--				
--				Due to the batch sent job running over night, it is recommended to run this report
--				after or on the second day of each month.
--
-- =============================================

CREATE PROCEDURE [internal].[proc_FIN_PaperPHAs_Mailed]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;

	-- SETS
	SET @inBeginDate = ISNULL(@inBeginDate, DATEADD(mm,DATEDIFF(mm,0,GETDATE())-1,0))
	SET @inEndDate = ISNULL(@inEndDate, DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

	SELECT
		grp.HealthPlanName,
		grp.GroupName,
		mem.MemberID,
		mem.EligMemberID,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),bat.SentDate,101) AS [PaperPHASentDate]
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
	JOIN
		HRMS.dbo.LG_GenerateLetter genltr WITH (NOLOCK)
		ON	(mem.MemberID = genltr.BenefitsMemberID)
		AND	(genltr.Deleted = 0)
	JOIN
		HRMS.dbo.LG_Letter ltr WITH (NOLOCK)
		ON	(genltr.LetterID = ltr.LetterID)
		AND	(ltr.Deleted = 0)
	JOIN
		HRMS.dbo.LG_LetterType ltyp WITH (NOLOCK)
		ON	(ltr.LetterTypeID = ltyp.LetterTypeID)
		AND	(ltyp.Deleted = 0)
	JOIN
		HRMS.dbo.LG_SentBatch bat WITH (NOLOCK)
		ON	(genltr.SentBatchID = bat.SentBatchID)
		AND	(bat.Deleted = 0)
	WHERE
		ltyp.Name = 'Paper PHA Request' AND
		genltr.RequestedDate >= '2014-03-07' AND -- DEFAULT BEGIN DATE THAT EXCLUDES TEST DATA IN PRODUCTION
		bat.SentDate >= @inBeginDate AND
		bat.SentDate < @inEndDate
	ORDER BY
		1,2
		
END
GO
