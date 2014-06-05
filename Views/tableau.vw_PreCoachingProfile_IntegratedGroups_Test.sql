SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE VIEW	[tableau].[vw_PreCoachingProfile_IntegratedGroups_Test]
AS

/****************************************************************************************************
View:			vw_PreCoachingProfile_IntegratedGroups
Date:			5/13/13
Author:		BlairG
Requested by:	Adam V.
WO:			Part of 1484
Objectives:		For use in Tableau Coach Performance Metrics
Notes:		This is a near-total rewrite of the previous view used for this application
			Changes to ECR changed the way referrals from that system are tracked
			
			New Pre-coaching survey is now in place - uses a different ID: 23

****************************************************************************************************/

SELECT 
	--DISTINCT
	mem.MemberId,
	mem.GroupID,
	CASE WHEN lg.MemberID IS NULL THEN 0 ELSE 1 END AS HasOutboundReferral,
	lg.CompleteDate,
	'Q' + LTRIM(STR(DATEPART(QQ, KickOff_Srvy.AppointmentBeginDate))) AS 'OrderQuarter',
	ISNULL(mrp.HasChronicCondition, 0) AS HasChronicCondition,
	KickOff_Srvy.CoachName,
	KickOff_Srvy.AppointmentBeginDate AS SessionDate,
	KickOff_Srvy.CoachUserId,
	KickOff_Srvy.SurveyStartedDateTime,
	KickOff_Srvy.SurveyCompletedDateTime,
	CASE WHEN hpg.HealthPlanAffiliateID = 11 THEN GroupName ELSE HealthPlanName END AS ClientName
FROM 
	DA_Production.prod.Member mem
JOIN
	DA_Production.prod.HealthPlanGroup hpg
	ON	(hpg.GroupID = mem.GroupID)
JOIN 
	(
		SELECT 
			KickOff.MemberID,
			KickOff.CoachName,
			KickOff.AppointmentBeginDate,
			KickOff.AppointmentID,
			KickOff.CoachUserID,
			StartedDateTime 'SurveyStartedDateTime',
			mas.CompletedDateTime 'SurveyCompletedDateTime',
			mas.MemberAssessmentId,
			ROW_NUMBER() OVER (PARTITION BY KickOff.MemberID, KickOff.AppointmentID 
			     ORDER BY DATEDIFF(SECOND, mas.StartedDateTime, KickOff.AppointmentBeginDate)) 
			     'DateClosest'
		FROM 
			(
				SELECT
					MemberId,
					AppointmentID,
					CoachName,
					AppointmentBeginDate,
					CoachUserID
				FROM
					(
						SELECT
							MemberId,
							AppointmentID,
							CoachName,
							AppointmentBeginDate,
							CoachUserID,
							ROW_NUMBER() OVER (PARTITION BY MemberID 
							     ORDER BY AppointmentBeginDate) AS RowNum
							     
						FROM 
							DA_Production.prod.Appointment 
						WHERE
							AppointmentTypeID = 6 AND			--kick off
							AppointmentStatusID = 4 			--completed
					) KO	
				WHERE
					KO.RowNum = 1
			) KickOff
		JOIN    
			HRAQuiz.dbo.srvy_SurveyMember mem
			ON	(mem.BenefitsMemberId = KickOff.MemberId)
		JOIN 
			HRAQuiz.dbo.srvy_MemberAssessment mas
			ON	(mas.SurveyMemberId = mem.SurveyMemberId)
			AND	(mas.SurveyId = 13 OR mas.SurveyId = 23) -- the two Pre-Coaching surveys
			AND	(mas.Deleted = 0) 
			AND	(DATEADD(dd,DATEDIFF(dd,0,mas.StartedDateTime),0)<=DATEADD(dd,DATEDIFF(dd,0,KickOff.AppointmentBeginDate),0))
			AND	(mas.CompletedDateTime IS NOT NULL)
	) KickOff_Srvy
	ON	(mem.MemberID = KickOff_Srvy.MemberId)
	AND	(KickOff_Srvy.DateClosest = 1)
LEFT JOIN
	(
		-- Find the Members with a chronic condition (marked none of the above on chronic illness question)
		-- OR depression (Marked yes to one of the depression questions)
		-- Only need whether they did or not, so just set a flag for each in the query
		SELECT
			MemberAssessmentId,
			MAX(CASE WHEN ISNULL(ChronicCondition, 0) > 0 THEN 1 ELSE 0 END) AS HasChronicCondition
		FROM
			(
				SELECT 
					MemberAssessmentId,
					QuestionID AS 'ChronicCondition'
				FROM 
					HRAQuiz.dbo.srvy_MemberResponse 
				WHERE 
					Deleted = 0
					AND 
						--Members who marked a chronic condition on either of the Pre-coaching surveys
					(QuestionId IN (694, 1179) AND AnswerText <> 'None of the above')
			) chronic
		GROUP BY
			MemberAssessmentId
	) mrp 
	ON	(mrp.MemberAssessmentId = KickOff_Srvy.MemberAssessmentId)

LEFT JOIN
	-- this query finds the PCPs that have been confirmed
	(
	SELECT
		ch.memberid,
		cr.addtime AS ConfirmationDate
	FROM 
		mclassecr.dbo.ut_confirmationresponse cr
	JOIN 
		mclassecr.dbo.ut_casesession cs
		ON	(cr.caseid = cs.caseid AND cr.seq = cs.seq)
	JOIN 
		mclassecr.dbo.ut_caseheader ch 
		ON	(ch.caseid = cs.caseid)
	JOIN 
		mclassecr.dbo.ut_section s
		ON	(s.sectionid = cs.formsectionid)
	WHERE 
		cr.questionid = '2842'
	) confirm
	ON	(confirm.MemberID = mem.MemberID)
	AND	(confirm.ConfirmationDate >= KickOff_Srvy.SurveyStartedDateTime)

LEFT JOIN
	-- find the 'Outbound Referral' log entries
	DA_Production.prod.HMSLog lg
	ON	(mem.MemberID = lg.MemberID)
	AND	(DescriptionID = 41)
JOIN
	-- This query finds the 'integrated groups' that for now are hard-coded
	(
	SELECT
		mem.MemberID,
		1 AS IsIntegrated		
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem
		ON	(hpg.GroupID = mem.GroupID)
	WHERE
		hpg.GroupID IN 
		(
			181276,	-- Automatic Data Processing
			53409,	-- Aetna Health and Wellness Medicare
			53736,	-- Aetna National
			131110,	-- Broadridge Financial Solutions
			191393,	-- Cancer Treatment Centers of America (CTCA)
			132766,	-- Career Education Corp
			38919,	-- Cummins, Inc
			37231,	-- ExxonMobil Corporation
			181275,	-- GameStop
			194461,	-- Global Brass and Copper
			143735,	-- Houghton Mifflin Harcourt
			182280,	-- Lenovo, Inc
			62687,	-- Management & Training Corporation
			197698,	-- Mercedes-Benz USA, LLC
			121527,	-- NEIMAN MARCUS GROUP, INC.
			189532,	-- Synopsys, Inc.
			194353	-- Windstream Corporation
		)
		OR
		hpg.HealthPlanID IN
		(
			64,		-- Golden Living
			68,		-- Optima-Sentara
			80,		-- Capital Blue Cross (CBC)
			71,		-- MVP Preferred Care Health Plan
			142,		-- Nordstrom
			137,		-- Providence
			178		-- Tyco International
		)
	) integ
	ON	(mem.MemberID = integ.MemberID)
GROUP BY
	mem.MemberId,
	mem.GroupID,
	CASE WHEN lg.MemberID IS NULL THEN 0 ELSE 1 END,
	lg.CompleteDate,
	ISNULL(mrp.HasChronicCondition, 0),
	KickOff_Srvy.CoachName,
	KickOff_Srvy.AppointmentBeginDate,
	KickOff_Srvy.CoachUserId,
	KickOff_Srvy.SurveyStartedDateTime,
	KickOff_Srvy.SurveyCompletedDateTime,
	CASE WHEN hpg.HealthPlanAffiliateID = 11 THEN GroupName ELSE HealthPlanName END

GO
