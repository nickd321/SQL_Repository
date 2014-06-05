SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		William Perez
-- Create date: 2013-03-18
-- Description:	Standard Outbound Referral Report
--
-- Notes:				
-- NULL, '2013-03-26', '193629, 193623, 193993', 'Aetna,Alere,BCBS IL,BCBSAL,Health Advocate' 
-- =============================================
CREATE PROCEDURE [standard].[proc_Referrals_Outbound] 
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL,
	@inGroupIDs VARCHAR(1000),
	@inReferralSources VARCHAR(2000)

AS
BEGIN

	SET NOCOUNT ON;
	
	SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(yy,DATEDIFF(yy,0,DATEADD(mm,-1,GETDATE())),0))
	SET	@inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

	SELECT
		GroupName,
		mem.EligMemberID,
		mem.FirstName,
		mem.LastName,
		CONVERT(CHAR(10),mem.Birthdate,101) AS Birthdate,
		ref.SubDescriptionName AS ReferralDestination,
		CONVERT(CHAR(10),ref.CompleteDate,101) AS ReferralDate
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID IN (SELECT * FROM DA_Production.dbo.SPLIT(@inGroupIDs,',')))
	JOIN	
		(
		SELECT
			MemberID,
			SourceAddDate,
			CompleteDate,
			LogTypeID,
			LogTypeName,
			DescriptionID,
			DescriptionName,
			SubDescriptionID,
			SubDescriptionName,
			SourceID,
			SourceName,
			ParentLogID,
			Sequence
		FROM
			DA_Production.prod.HMSLog WITH (NOLOCK)
		WHERE
			GroupID IN (SELECT * FROM DA_Production.dbo.Split(@inGroupIDs,',')) AND
			DescriptionID = 41 AND
			SourceID IN (6,7,16) AND
			(CompleteDate >= @inBeginDate AND CompleteDate < @inEndDate) AND
		    (UPPER(@inReferralSources) = 'ALL' OR SubDescriptionName IN (SELECT * FROM DA_Production.dbo.SPLIT(@inReferralSources,',')))
		) ref
		ON	(mem.MemberID = ref.MemberID)
		
END



	
GO
