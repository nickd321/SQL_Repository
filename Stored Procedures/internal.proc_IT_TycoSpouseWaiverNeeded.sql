SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [internal].[proc_IT_TycoSpouseWaiverNeeded]

	@ReportDate DATETIME = NULL

AS BEGIN

	SET @ReportDate = ISNULL(@ReportDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0));

	WITH MemberDetails AS
	(
	SELECT
		mem.MemberID,
		mem.EligMemberID,
		mem.RelationshipID,
		mem.CS4,
		memenr.EffectiveDate,
		memenr.TerminationDate,
		ROW_NUMBER() OVER(PARTITION BY mem.MemberID ORDER BY memenr.EffectiveDate DESC) AS InvSeq
	FROM
		Benefits.dbo.Member mem
	JOIN
		Benefits.dbo.MemberEnrollment memenr
		ON	(mem.MemberID = memenr.MemberID)
		AND	(memenr.Deleted = 0)
	WHERE
		mem.GroupID = 193629 AND
		mem.RelationshipID IN (1,2,6)
	)

	SELECT
		sp.MemberID
	FROM
		MemberDetails prm
	JOIN
		MemberDetails sp
		ON	(prm.EligMemberID = sp.EligMemberID)
		AND	(sp.RelationshipID IN (1,2))
		AND	(sp.InvSeq = 1)
		AND	(sp.TerminationDate >= @ReportDate)
	LEFT JOIN
		Healthyroads.dbo.IC_MemberActivityItemWaiver wvr
		ON	(sp.MemberID = wvr.MemberID)
		AND	(ActivityItemID = 3210)
		AND	(Deleted = 0)
	WHERE
		prm.CS4 = '2' AND
		prm.TerminationDate IS NULL AND
		prm.RelationshipID = 6 AND
		prm.InvSeq = 1 AND
		wvr.MemberID IS NULL
	
END
GO
