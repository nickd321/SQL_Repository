SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [internal].[proc_IT_TycoCSChange]

	@ReportDate DATETIME = NULL

AS BEGIN

	SET @ReportDate = ISNULL(@ReportDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0));

	SELECT
		new.MemberID
	FROM
		DA_Production.prod.CSFields new
	JOIN
		DA_Production.prod.Eligibility elig
		ON	(new.MemberID = new.MemberID)
		AND	(elig.IsTermed = 0)
	JOIN
		DA_Production.archive.CSFields prev
		ON	(new.MemberID = prev.MemberID)
		AND	(prev.CS4 != '2')
		AND	(DATEADD(mm,DATEDIFF(mm,0,prev.ArchiveDate),0) = @ReportDate)
	WHERE
		new.GroupID IN (193993,193623,193629) AND
		new.CS4 = '2' AND
		DATEADD(mm,DATEDIFF(mm,0,new.AddDate),0) = @ReportDate
	GROUP BY
		new.MemberID
	
END
GO
