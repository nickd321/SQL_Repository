SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Adrienne Bellomo
-- Create date: 2014-04-24
-- Description:	Areva Tobacco Outreach 

-- Notes: This is for Work Order # 3310	
--
-- Updates:
-- =============================================

CREATE PROCEDURE [areva].[proc_HealthAssessment_TobaccoOutreach]
	
AS
BEGIN
	SET NOCOUNT ON;
	

SELECT 
	CONVERT(VARCHAR(8),GETDATE(),112) AS Creation_Date,
	'HRDS – DA' as Sendor_Name,
	'AREVA' as Company_Name,
	mr.MemberID, 
	m.EligMemberID as EligID,
	m.EligMemberSuffix as Suffix,
	m.firstname as F_Name,
	m.lastname as L_Name,
	CONVERT(VARCHAR(8),m.Birthdate,112) AS DOB, 
	'High' as StratificationLevel,
	'' as Reason,
	'Tobacco Scrub' as Stratification_Source,
	ha.assessmentcompletedate
  FROM [DA_Production].[prod].[HealthAssessment_MeasureResponse] mr
  inner join DA_Production.prod.HealthAssessment ha on mr.MemberAssessmentID = ha.MemberAssessmentID
  inner join DA_Production.prod.Member m on m.MemberID = mr.MemberID
  where MeasureID = 149 --'Tobacco_Use'
  and Response = 1
  and mr.GroupID = 191545
  and ha.AssessmentCompleteDate >= '2014-01-01' 
  order by ha.assessmentcompletedate
  
  END
GO
