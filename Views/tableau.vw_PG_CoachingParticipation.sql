SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW	[tableau].[vw_PG_CoachingParticipation]
AS

/****************************************************************************************************
View:			vw_PG_CoachingParticipation
Date:			7/1/13
Author:		BlairG
Requested by:	Jenie Squiric
WO:			2370
Objectives:		For use in Tableau Performance Guarantees
Notes:		This is leveraging the Coaching Participation Metric in the 
			Performance Guarantee system on HRLReports-2008
			
			
****************************************************************************************************/

SELECT 
	[ReportGroupPeriodResultID]
      ,[ReportGroupID]
      ,[ReportGroupPeriodID]
      ,[ReportGroupMetricID]
      ,[MetricID]
      ,[CalculationID]
      ,[CategoryID]
      ,[SourceID]
      ,[ApplicationID]
      ,[AggregationID]
      ,[ReportGroupName]
      ,[PeriodBeginDate]
      ,YEAR([PeriodBeginDate]) AS 'Benefit Year'
      ,CONVERT(VARCHAR(10),[PeriodBeginDate],101) AS 'Period Begin Date'
      ,[PeriodEndDate]
      ,[MetricName]
      ,[MetricDescription]
      ,[NumeratorDescription]
      ,[DenominatorDescription]
      ,[CategoryName]
      ,[SourceName]
      ,[ApplicationName]
      ,[AggregationName]
      ,[BenefitYearFlag]
      ,[M1]
      ,[M2]
      ,[M3]
      ,[M4]
      ,[M5]
      ,[M6]
      ,[M7]
      ,[M8]
      ,[M9]
      ,[M10]
      ,[M11]
      ,[M12]
      ,[Q1]
      ,[Q2]
      ,[Q3]
      ,[Q4]
      ,[YTD]
      ,[AddedDate]
      ,[DeletedDate]
  FROM 
	[DA_PerformanceMeasurement].[dbo].[tbl_ReportGroupPeriodResult] rgpr
WHERE
	MetricID = 9			-- Coaching Participation
	AND	DeletedDate IS NULL

GO
