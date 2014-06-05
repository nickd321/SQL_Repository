SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW	[tableau].[vw_PreCoachingProfile]
AS

/****************************************************************************************************
View:			vw_PreCoachingProfile
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
	mem.MemberId,
	mem.GroupID,
	CASE 
		WHEN ref.MemberID IS NULL THEN 0 ELSE 1 
	END HasReferral,
	mrp.HasChronicCondition,
	mrp.HasDepression,
	KickOff_Srvy.CoachName,
	KickOff_Srvy.AppointmentBeginDate AS SessionDate,
	-- The following line, if done in Tableau, causes the extract refresh to take around 20 minutes.
	-- doing the work here makes it take 2 seconds...
	'Q' + LTRIM(STR(DATEPART(QQ, KickOff_Srvy.AppointmentBeginDate))) AS 'OrderQuarter',
	-- All date hierarchy fields are in SQL now
	YEAR(KickOff_Srvy.AppointmentBeginDate) AS 'OrderYear',
	DAY(KickOff_Srvy.AppointmentBeginDate) AS 'OrderDay',
	KickOff_Srvy.CoachUserId,
	KickOff_Srvy.SurveyStartedDateTime,
	KickOff_Srvy.SurveyCompletedDateTime,
	confirm.ConfirmationDate,
	CASE WHEN integ.IsIntegrated = 1 THEN 1 ELSE 0 END AS IsIntegrated,
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
					MemberId
					,AppointmentID
					,CoachName
					,AppointmentBeginDate
					,CoachUserID
				FROM 
					DA_Production.prod.Appointment 
				WHERE
					AppointmentTypeID = 6 AND			--kick off
					AppointmentStatusID = 4 AND			--completed
					AppointmentBeginDate >= '11/16/2012'	--referrals from ECR start at this date
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
JOIN
	(
		-- Find the Members with a chronic condition (marked none of the above on chronic illness question)
		-- OR depression (Marked yes to one of the depression questions)
		-- Only need whether they did or not, so just set a flag for each in the query
		SELECT
			MemberAssessmentId,
			SUM(CASE WHEN ChronicCondition > 0 THEN 1 ELSE 0 END) AS HasChronicCondition,
			SUM(CASE WHEN Depression > 0 THEN 1 ELSE 0 END) AS HasDepression
		FROM

		(
			-- UNION takes care of the possible multiple rows returned in the first query
			-- by collapsing all of the rows into one
			
				SELECT 
					MemberAssessmentId,
					QuestionID AS 'ChronicCondition',
					0 AS 'Depression'
				FROM 
					HRAQuiz.dbo.srvy_MemberResponse 
				WHERE 
					Deleted = 0
					AND 
						--Members who marked a chronic condition on either of the Pre-coaching surveys
					(QuestionId IN (694, 1179) AND AnswerText <> 'None of the above')
			UNION 
				SELECT 
					MemberAssessmentId,
					0 AS 'ChronicCondition',
					MAX(QuestionId) AS 'Depression'
				FROM 
					HRAQuiz.dbo.srvy_MemberResponse 
				WHERE 
					Deleted = 0
					AND 
						--Members who answered yes to a depression screening question on either of the Pre-coaching surveys
					(QuestionId IN (731, 732, 1223, 1222) AND AnswerText = 'Yes')		
				GROUP BY
					MemberAssessmentId
		) un
		GROUP BY
			MemberAssessmentId
	) mrp 
	ON	(mrp.MemberAssessmentId = KickOff_Srvy.MemberAssessmentId)

JOIN
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
	-- This subquery finds the referral data from the ECR system.
	-- This methodology only pulls data from 11/16/2012 on
	(
		SELECT
			DISTINCT
			sess.MemberID

		FROM
			MCLASSECR.dbo.HN_session sess
		JOIN 
			MCLASSECR.dbo.HN_session_ECR ecr
			ON	(sess.SessionID = ecr.SessionID)
		JOIN 
			MCLASSECR.dbo.Ut_casesession csess
			ON	(ecr.caseid = csess.caseid)
			AND	(ecr.seq = csess.seq)
		JOIN 
			MCLASSECR.dbo.HN_sessionresource sres
			ON	(sres.SessionID = ecr.SessionID)
		JOIN 
			MCLASSECR.dbo.HN_resource res
			ON	(res.resourceid = sres.resourceid)
		JOIN 
			MCLASSECR.dbo.HN_resourcetype rtyp
			ON	(res.resourcetypeid = rtyp.resourcetypeid)
		JOIN 
			MCLASSECR.dbo.HN_responsedetail rdet
			ON	(rdet.responsedetailid = sres.responsedetailid)
		JOIN 
			MCLASSECR.dbo.HN_response resp
			ON	(resp.responseid = rdet.responseid)
		JOIN 
			MCLASSECR.dbo.Ut_caseassessment ca
			ON	(ecr.caseid = ca.caseid and ecr.Seq = ca.Seq)  -- to get SurveyId

		WHERE
			sess.SessionTypeId = '2'		-- This is ECR Session referral data only (vs. Health Navigator data)
			AND	(csess.FormSectionId = '1')	-- this is the Kick Off session referral data where the Pre-Coaching profile resides in the ECR.
			AND	(ca.SurveyId IN (13,23))	-- these are the two pre-coaching surveys
			AND	(resp.ResponseID IN (1,2))	-- 1=Accepted, 2=Refused
			
	) ref
	ON ref.MemberID = mem.MemberID
	
LEFT JOIN
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
GO
