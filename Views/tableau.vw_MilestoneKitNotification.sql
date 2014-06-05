SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE VIEW	[tableau].[vw_MilestoneKitNotification]

AS
SELECT
	MemberID,
	BenefitYearStartDate,
	BenefitYearEndDate,
	KitEligDate,
	'Q' + LTRIM(STR(DATEPART(QQ, KitEligDate))) AS 'OrderQuarter',
	YEAR(KitEligDate) AS 'OrderYear',
	DAY(KitEligDate) AS 'OrderDay',

	CASE WHEN KitOfferedFlag > 0 THEN 1 ELSE 0 END AS KitOfferedFlag
FROM
	(
	SELECT
		main.BenefitMemberID AS MemberID,
		main.BenefitYearStartDate,
		main.BenefitYearEndDate,
		main.KitEligDate,
		SUM(CASE
			WHEN (
				(DATEDIFF(dd, ContactDate, KitEligDate) <= 0) 
				OR (main.EmailNotificationDate IS NOT NULL) 
				OR (main.CoachNotificationDate IS NOT NULL)
				OR (main.EmailQueue_ReceivedDate IS NOT NULL)
				) 
			THEN 1
			ELSE 0 
		END) AS KitOfferedFlag
	FROM 
		DA_Production.prod.Member mem
		
	JOIN		
		(
			-- HRMS.dbo.Milestone kits has duplicate entries for some member/benefit year combinations
			-- Also, there are times when the BenefitYearEndDate has different fractional times on the dates
			-- that is why the dates are floored in the query
			
			SELECT DISTINCT
				MR.BenefitMemberID,
				DATEADD(dd, DATEDIFF(dd, 0, MR.BenefitYearStartDate), 0) AS BenefitYearStartDate,
				DATEADD(dd, DATEDIFF(dd, 0, MR.BenefitYearEndDate), 0) AS BenefitYearEndDate,
				notify.EmailNotificationDate,
				notify.CoachNotificationDate,
				EmailQueue.ReceivedDate as [EmailQueue_ReceivedDate],
				CASE
					WHEN DATEDIFF(dd, FHP.HighStratDate, PR.FirstPR) > 0 
						OR DATEDIFF(dd, FHP.HighStratDate, S4.FourthSession) > 0 
					THEN 'High or Medium'
					ELSE 'Low' 
				END Stratification,
				CASE
					WHEN DATEDIFF(dd, FHP.HighStratDate, PR.FirstPR) > 0 
						OR DATEDIFF(dd, FHP.HighStratDate, S4.FourthSession) > 0 
					THEN PR.FirstPR
					ELSE S4.FourthSession 
				END KitEligDate,
				CASE 
					WHEN MKMC.IsContacted = 1 THEN ContactDate
					ELSE NULL 
				END ContactDate
			FROM
				
				HRMS.dbo.MilestoneRedeem MR
				
				LEFT JOIN
					(			--First progress review for members in MilestoneRedeem by benefit year
					SELECT
						MS.MemberID,
						MR.BenefitYearStartDate,
						MR.BenefitYearEndDate,
						MIN(MS.AppointmentBeginDate) FirstPR
					FROM
						HRMS.dbo.MilestoneRedeem MR
					JOIN
						DA_Production.prod.Appointment MS
						ON	(MR.BenefitMemberID = MS.MemberID)
						AND	(MS.AppointmentBeginDate BETWEEN BenefitYearStartDate AND BenefitYearEndDate)
						AND	(MS.AppointmentStatusID = 4)
						AND	(MS.AppointmentTypeID = 14)
					GROUP BY
						MS.MemberID,
						MR.BenefitYearStartDate,
						MR.BenefitYearEndDate
					) AS PR
				ON	(MR.BenefitMemberID = PR.MemberID)
				AND	(PR.BenefitYearStartDate = MR.BenefitYearStartDate)
				AND	(PR.BenefitYearEndDate = MR.BenefitYearEndDate)

				LEFT JOIN
					(			--Completed fourth session for members in MilestoneRedeem by benefit year
					SELECT
						RS.MemberID,
						RS.BenefitYearStartDate,
						RS.BenefitYearEndDate,
						RS.AppointmentBeginDate FourthSession
					FROM
						(
						SELECT
							MS.MemberID,
							MR.BenefitYearStartDate,
							MR.BenefitYearEndDate,
							MS.AppointmentBeginDate,
							ROW_NUMBER() OVER(PARTITION BY MS.MemberID ORDER BY MS.AppointmentBeginDate) AS RunningSessions
						FROM
							HRMS.dbo.MilestoneRedeem MR
						JOIN
							DA_Production.prod.Appointment MS
							ON	(MR.BenefitMemberID = MS.MemberID)
							AND	(MS.AppointmentStatusID = 4)
							AND	(MS.AppointmentBeginDate BETWEEN BenefitYearStartDate AND BenefitYearEndDate)
						) AS RS
					WHERE
						RS.RunningSessions = 4
					) AS S4
					
				ON	(MR.BenefitMemberID = S4.MemberID)
				AND	(S4.BenefitYearStartDate = MR.BenefitYearStartDate)
				AND	(S4.BenefitYearEndDate = MR.BenefitYearEndDate)
				
				LEFT JOIN
					(						--First high opp stratification for members in MilestoneRedeem 
					SELECT
						ST.MemberID,
						MIN(ST.StratificationDate) HighStratDate
					FROM
						HRMS.dbo.MilestoneRedeem MR
					JOIN
						DA_Production.prod.Stratification ST
						ON	(MR.BenefitMemberID = ST.MemberID)
					WHERE
						ST.MemberStratificationName <> 'Low' --Either High or Medium is fine
					GROUP BY 
						ST.MemberID
					) FHP
				ON	(MR.BenefitMemberID = FHP.MemberID)
				
								-- Notifications by Coach
				LEFT JOIN
					HRMS.dbo.MilestoneKitMemberContacted MKMC
					ON	(MKMC.MemberID = MR.BenefitMemberID)
					AND	(MKMC.ContactDate BETWEEN MR.BenefitYearStartDate AND MR.BenefitYearEndDate)

								-- New email notifications as of 11/15/2012 and coach notifications as of 2013-02-07 
				LEFT JOIN
					(
						SELECT 
							appt.MemberID,
							an.NotificationDate,
							CASE WHEN an.AppointmentNotificationTypeID = 1 THEN an.NotificationDate ELSE NULL END AS 'EmailNotificationDate',
							CASE WHEN an.AppointmentNotificationTypeID = 2 THEN an.NotificationDate ELSE NULL END AS 'CoachNotificationDate'
						FROM 
							HRMS.dbo.AppointmentNotification an
						JOIN
							HRMS.dbo.Appointment appt
							ON	(an.AppointmentID = appt.AppointmentID)
							AND	(appt.Deleted = 0)
						WHERE
							an.AppointmentNotificationActionID = 1
							AND	(an.Deleted = 0)
					) AS notify
				ON	(MR.BenefitMemberID = notify.MemberID)
				AND	(notify.NotificationDate BETWEEN MR.BenefitYearStartDate AND MR.BenefitYearEndDate)

								--Email notification via email EmailQueue as of Jan 2014
				LEFT JOIN 
					(
						SELECT
							BenefitMemberID,
							ReceivedDate
						FROM Healthyroads.EmailQueue.LoggedEmails
						WHERE EmailTemplateID = 41  --Template to use for MSK emails
					) as EmailQueue
				ON (EmailQueue.BenefitMemberID = MR.BenefitMemberID)
				AND (EmailQueue.ReceivedDate BETWEEN MR.BenefitYearStartDate AND MR.BenefitYearEndDate)
				
		) AS main
		ON	(main.BenefitMemberID = mem.MemberID)
		AND	(main.KitEligDate IS NOT NULL)
		
	GROUP BY
		main.BenefitMemberID,
		main.BenefitYearStartDate,
		main.BenefitYearEndDate,
		main.KitEligDate
	) cnt
	

	


GO
