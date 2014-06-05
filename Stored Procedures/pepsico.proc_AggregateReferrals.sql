SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Domokos
-- Create date: 3/12/2014
-- Description:	A pivoted aggregate report of Pepsi's inbound
--				and outbound referrals by vendor

-- =============================================

CREATE PROCEDURE [pepsico].[proc_AggregateReferrals]
@inBeginDate DATETIME = NULL,
@inEndDate DATETIME = NULL
AS

BEGIN
--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME
SET @inBeginDate = ISNULL(@inBeginDate,DATEADD(yy, DATEDIFF(yy,0,GETDATE()), 0))
SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))

SELECT
		CASE 
			WHEN DescriptionName = 'Referral' 
			THEN 'Inbound Referral'
			ELSE DescriptionName
		END AS [ReferralType],
		SubDescriptionName AS [Vendor],
		ISNULL([1],0) AS [Jan],
		ISNULL([2],0) AS [Feb],
		ISNULL([3],0) AS [Mar],
		ISNULL([4],0) AS [Apr],
		ISNULL([5],0) AS [May],
		ISNULL([6],0) AS [Jun],
		ISNULL([7],0) AS [Jul],
		ISNULL([8],0) AS [Aug],
		ISNULL([9],0) AS [Sep],
		ISNULL([10],0) AS [Oct],
		ISNULL([11],0) AS [Nov],
		ISNULL([12],0) AS [Dec]
		
	FROM
		(
		SELECT
			DescriptionName,
			SubDescriptionName,
			MONTH(CompleteDate) AS [Measure],
			1 AS [MeasureValue]
		FROM
			[DA_Production].[prod].[HMSLog]
		WHERE 
			DescriptionID IN (21,41)
			AND GroupID = 206772
			AND CompleteDate >= @inBeginDate
			AND CompleteDate < @inEndDate
		) inc
	PIVOT
		(
		SUM(MeasureValue) FOR Measure IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])
		) pvt
ORDER BY
	DescriptionName,
	SubDescriptionName

END
			
GO
