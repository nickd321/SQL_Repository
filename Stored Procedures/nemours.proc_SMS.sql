SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Nick Moore
-- Create date: 201306012
-- Description:	Nemours SMS Report
--
-- Notes:
-- 
-- Updates:		WilliamPe 20130617
--				Had a phone conversation with Mark Mulray on 2013-06-17 to gather the report specifications.				
--				
--				This report now incorporates logic where the rule for the month of January is that the member must
--				have earned 60 points and passed the 60 point threshold in the month of January.
--				Any subsequent months, the "New" row should show only distinct counts of those members who have completed activities
--				for the first time during the calendar year.  The same logic is also used for February completers
--			
--				In order to accomplish this, I added dummy activity records for the month the member met the incentive.
--				Then, the sub query that grabs all the actual activity data only uses dates that fall after the incentive met month.
--				If there is not an incentive met month, then only the activity from 2/1/2013 on is used for the member.
--
--				I also included logic to count a member's activity during the month only if the activity month is not the month they met the incentive
--				This was done to exclude the dummy records from the activity counts.
--
--				WilliamPe 20131028
--				Added challenges from Incentive System (external data feed) as Nemours did not have a formally programmed challenged through HRDS.
--				I left the HRDS challenge in the case they might have one before they term (end of the year).
--
--				WilliamPe 20131029
--				Confirmed with Mark Mulray from Nemours that they will not use the HRDS challenge.  They will be sending in a second feed in November.
--				Added activityitemid for second challenge data feed.
--
-- =============================================

CREATE PROCEDURE [nemours].[proc_SMS]
	@inBeginDate DATETIME = NULL,
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;
	
	--DECLARE @inBeginDate DATETIME, @inEndDate DATETIME
	
/*======================================================= SETS ======================================================*/	

	SET @inBeginDate = '2013-02-01'  -- HARDCODING 2/1/13 DATE IN ORDER TO IGNORE JANUARY ACTIVITY FURTHER DOWN IN THE CODE
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),0))


/*===================================================== CLEAN UP ====================================================*/
	
	IF OBJECT_ID('TempDB.dbo.#RunningPointsTotal') IS NOT NULL BEGIN
		DROP TABLE #RunningPointsTotal
	END
	
	IF OBJECT_ID('TempDB.dbo.#MetIncentive') IS NOT NULL BEGIN
		DROP TABLE #MetIncentive
	END

	IF OBJECT_ID('TempDB.dbo.#ActivityData') IS NOT NULL BEGIN
		DROP TABLE #ActivityData
	END

	IF OBJECT_ID('TempDB.dbo.#DenormActivityData') IS NOT NULL BEGIN
		DROP TABLE #DenormActivityData
	END

/*======================= GET RUNNING TOTAL TO DETERMINE DAY MEMBER PASSED 60 POINT THRESHOLD =======================*/

	SELECT
		ROW_NUMBER() OVER (PARTITION BY act.MemberID ORDER BY act.ActivityDate) AS 'MemberRowID',
		act.MemberID,
		act.ActivityDate, 
		act.ActivityValue AS Points,
		NULL AS 'RunningTotal'
	INTO 
		#RunningPointsTotal
	FROM
		DA_Production.prod.Member mem
	JOIN
		Healthyroads.dbo.IC_MemberActivityItem act
		ON	(mem.MemberID = act.MemberID)
		AND	(act.ClientIncentivePlanID = 767)
		AND	(act.Deleted = 0)
	WHERE
		mem.GroupID = 192768

	-- ENSURE THE DATA IS PHYSICALLY ORDERED THE WAY WE WANT, SO THE UPDATE WORKS
	-- AS NEEDED
	CREATE UNIQUE CLUSTERED INDEX idx_temp_MemberActivity
	ON #RunningPointsTotal (MemberID, MemberRowID)


	-- CREATE A VARIABLE THAT WILL BE USED THROUGHOUT THE UPDATE
	DECLARE 
		@RunningTotal INT
	SET 
		@RunningTotal = 0

	-- THIS UPDATE WILL OCCUR IN THE ORDER OF EARLIEST TO LATEST DATES PER MEMBER
	-- FOR EACH ROW, THE RUNNING TOTAL WILL BE UPDATED ON THE WORKING TABLE
	-- AND THE VARIABLE WILL BE RECALCULATED		

	UPDATE 
		#RunningPointsTotal
	SET 
		@RunningTotal = RunningTotal = Points + CASE WHEN MemberRowID = 1 THEN 0 ELSE @RunningTotal END
	FROM 
		#RunningPointsTotal


/*=================================== DETERMINE DAY PASSED 60 POINT THRESHOLD =======================================*/
		
	SELECT
		MemberID,
		DATEADD(mm,DATEDIFF(mm,0,MIN(ActivityDate)),0) AS MetIncentiveDate
	INTO
		#MetIncentive
	FROM
		#RunningPointsTotal
	WHERE
		RunningTotal >= 60
	GROUP BY
		MemberID
	HAVING
		MONTH(MIN(ActivityDate)) IN (1,2)
		
/*=============================================== GET ACTIVITY DATA =================================================*/	
	
	SELECT
		LocationCode,
		MonthYear,
		ActivityMonth,
		Activity,
		MemberID,
		ROW_NUMBER() OVER(PARTITION BY MemberID, Activity ORDER BY ActivityMonth) AS MemberActivitySequence,
		ROW_NUMBER() OVER(PARTITION BY MemberID ORDER BY ActivityMonth) AS MemberSequence,
		MetIncentiveMonth
	INTO
		#ActivityData
	FROM
		(
			SELECT
				ISNULL(cs.CS1,'[Not Provided]') AS LocationCode,
				DATENAME(mm,inc.ActivityMonth) + ' ' + CAST(YEAR(inc.ActivityMonth) AS CHAR(4)) AS MonthYear,
				inc.ActivityMonth,
				inc.Activity,
				inc.MemberID,
				1 AS MetIncentiveMonth		
			FROM
				(
				-- CREATING DUMMY ACTIVITY RECORDS FOR THE MONTH THE MEMBER MET THE INCENTIVE
				-- THIS IS DONE SO THAT THE MEMBER SHOWS UP IN THE "RETURNING" ROW FOR ANY SUBSEQUENT MONTHS THEY COMPLETE ACTIVITIES
				SELECT
					MemberID,
					'Met Incentive' AS Activity,
					MetIncentiveDate AS ActivityMonth
				FROM
					#MetIncentive
				UNION
				SELECT
					MemberID,
					'Onsite Coaching' AS Activity,
					MetIncentiveDate AS ActivityMonth
				FROM
					#MetIncentive
				UNION
				SELECT
					MemberID,
					'Phone Coaching' AS Activity,
					MetIncentiveDate AS ActivityMonth
				FROM
					#MetIncentive
				UNION
				SELECT
					MemberID,
					'E-Coaching' AS Activity,
					MetIncentiveDate AS ActivityMonth
				FROM
					#MetIncentive
				UNION
				SELECT
					MemberID,
					'Challenge' AS Activity,
					MetIncentiveDate AS ActivityMonth
				FROM
					#MetIncentive						
				) inc
			LEFT JOIN
				DA_Production.prod.CSFields cs
				ON	(inc.MemberID = cs.MemberID)
			
			UNION 	
			
			SELECT
				ISNULL(cs.CS1,'[Not Provided]') AS LocationCode,
				DATENAME(mm,act.ActivityMonth) + ' ' + CAST(YEAR(act.ActivityMonth) AS CHAR(4)) AS MonthYear,
				act.ActivityMonth,
				act.Activity,
				act.MemberID,
				0 AS MetIncentiveMonth
			FROM
				(
				-- GET ACTIVITIES	
				SELECT
					appt.MemberID,
					CASE appt.AppointmentFormatID
						WHEN 4 THEN 'Onsite Coaching'
						ELSE 'Phone Coaching'
					END AS Activity,
					DATEADD(mm,DATEDIFF(mm,0,appt.AppointmentBeginDate),0) AS ActivityMonth
				FROM
					DA_Production.prod.Appointment appt
				WHERE
					appt.GroupID = 192768 AND
					appt.AppointmentStatusID = 4 AND
					(appt.AppointmentFormatID IN (1,4) OR appt.AppointmentFormatID IS NULL)
				UNION
				SELECT
					web.MemberID,
					'E-Coaching' AS Activity,
					DATEADD(mm,DATEDIFF(mm,0,web.SourceAddDate),0) AS ActivityMonth
				FROM
					DA_Production.prod.WebClass web
				WHERE
					web.GroupID = 192768
				UNION
				SELECT -- External Data Feed
					act.MemberID,
					'Challenge' AS Activity,
					DATEADD(mm,DATEDIFF(mm,0,act.ActivityDate),0) AS ActivityMonth				
				FROM
					Healthyroads.dbo.IC_MemberActivityItem act
				WHERE
					act.ClientIncentivePlanID = 954 AND
					act.ActivityItemID IN (5069, 5070) AND
					act.Deleted = 0
				UNION
				SELECT -- Challenges through HRDS
					chlg.MemberID,
					'Challenge' AS Activity,
					DATEADD(mm,DATEDIFF(mm,0,chlg.CompletionDate),0) AS ActivityMonth				
				FROM
					DA_Production.prod.Challenge chlg
				WHERE
					chlg.GroupID = 192768
				) act
			LEFT JOIN
				DA_Production.prod.CSFields cs
				ON	(act.MemberID = cs.MemberID)
			LEFT JOIN
				#MetIncentive met
				ON	(act.MemberID = met.MemberID)
			WHERE
				-- THIS WILL FILTER OUT ANY ACTIVITIES THAT FALL IN THE SAME MONTH AS THE MET INCENTIVE DATE
				-- ACTIVITIES SHOULD EITHER BE GREATER THAN/EQUAL TO THE INCENTIVE MONTH.  IF THERE IS NO INCENTIVE DATE,
				-- THEN THE ACTIVITY MONTH MUST BE GREATER THAN/EQUAL TO 2/1/2013
				act.ActivityMonth >= ISNULL(DATEADD(mm,1,met.MetIncentiveDate),@inBeginDate) AND
				act.ActivityMonth < @inEndDate
		) data


/*=========================================== DENORMALIZE ACTIVITY DATA =============================================*/

	SELECT
		LocationCode,
		MonthYear,
		ActivityMonth,
		MemberID,
		MetIncentiveMonth,
		[E-Coaching],
		[Phone Coaching],
		[Onsite Coaching],
		[Challenge],
		[Met Incentive]
	INTO
		#DenormActivityData
	FROM
		#ActivityData data
	PIVOT
		(
		MIN(MemberActivitySequence) FOR Activity IN
												(
												[E-Coaching],
												[Phone Coaching],
												[Onsite Coaching],
												[Challenge],
												[Met Incentive]
												)
		) pvt

/*================================================ FINAL RESULTS ====================================================*/


	SELECT
		dnd.LocationCode,
		dnd.MonthYear,
		dnd.ParticipantType,
		dnd.[E-Coaching],
		dnd.[Phone Coaching],
		dnd.[Onsite Coaching],
		dnd.Challenge,
		dnd.[Met Incentive],
		dnd.UniqueMTD,
		ISNULL(CAST(uytd.UniqueYTD AS VARCHAR),'') AS UniqueYTD
	FROM
		(
		SELECT
			1 AS SortNumber,
			LocationCode,
			MonthYear,
			ActivityMonth,
			'New' AS ParticipantType,
			-- ADDED LOGIC TO IGNORE DUMMY ACTIVITY RECORDS IN THE ACTIVITY COUNTS
			COUNT(DISTINCT CASE WHEN [E-Coaching] = 1 AND MetIncentiveMonth = 0 THEN MemberID END) AS [E-Coaching],
			COUNT(DISTINCT CASE WHEN [Phone Coaching] = 1 AND MetIncentiveMonth = 0 THEN MemberID END) AS [Phone Coaching],
			COUNT(DISTINCT CASE WHEN [Onsite Coaching] = 1 AND MetIncentiveMonth = 0 THEN MemberID END) AS [Onsite Coaching],
			COUNT(DISTINCT CASE WHEN [Challenge] = 1 AND MetIncentiveMonth = 0 THEN MemberID END) AS [Challenge],
			COUNT(DISTINCT CASE [Met Incentive] WHEN 1 THEN MemberID END) AS [Met Incentive],
			COUNT(DISTINCT CASE WHEN [Challenge] = 1 OR [Onsite Coaching] = 1 OR [Phone Coaching] = 1 OR [E-Coaching] = 1 OR [Met Incentive] = 1 THEN MemberID END) AS [UniqueMTD]
		FROM
			#DenormActivityData
		GROUP BY
			LocationCode,
			MonthYear,
			ActivityMonth
		UNION
		SELECT
			1 AS SortNumber,
			LocationCode,
			MonthYear,
			ActivityMonth,
			'Returning' AS ParticipantType,
			COUNT(DISTINCT CASE WHEN [E-Coaching] > 1 THEN MemberID END) AS [E-Coaching],
			COUNT(DISTINCT CASE WHEN [Phone Coaching] > 1 THEN MemberID END) AS [Phone Coaching],
			COUNT(DISTINCT CASE WHEN [Onsite Coaching] > 1 THEN MemberID END) AS [Onsite Coaching],
			COUNT(DISTINCT CASE WHEN [Challenge] > 1 THEN MemberID END) AS [Challenge],
			0 AS [Met Incentive],   -- THERE SHOULD NEVER BE MORE THAN ONE RECORD FOR MET INCENTIVE (SEE MET INCENTIVE TEMP TABLE)
			COUNT(DISTINCT CASE WHEN [Challenge] != 1 OR [Onsite Coaching] != 1 OR [Phone Coaching] != 1 OR [E-Coaching] != 1 OR [Met Incentive] != 1 THEN MemberID END) AS [UniqueMTD]
		FROM
			#DenormActivityData
		GROUP BY
			LocationCode,
			MonthYear,
			ActivityMonth
		UNION
		SELECT
			2 AS SortNumber,
			'[All Locations]' AS LocationCode,
			MonthYear,
			ActivityMonth,
			'New' AS ParticipantType,
			-- ADDED LOGIC TO IGNORE DUMMY ACTIVITY RECORDS IN THE ACTIVITY COUNTS
			COUNT(DISTINCT CASE WHEN [E-Coaching] = 1 AND MetIncentiveMonth = 0 THEN MemberID END) AS [E-Coaching],
			COUNT(DISTINCT CASE WHEN [Phone Coaching] = 1 AND MetIncentiveMonth = 0 THEN MemberID END) AS [Phone Coaching],
			COUNT(DISTINCT CASE WHEN [Onsite Coaching] = 1 AND MetIncentiveMonth = 0 THEN MemberID END) AS [Onsite Coaching],
			COUNT(DISTINCT CASE WHEN [Challenge] = 1 AND MetIncentiveMonth = 0 THEN MemberID END) AS [Challenge],
			COUNT(DISTINCT CASE [Met Incentive] WHEN 1 THEN MemberID END) AS [Met Incentive],
			COUNT(DISTINCT CASE WHEN [Challenge] = 1 OR [Onsite Coaching] = 1 OR [Phone Coaching] = 1 OR [E-Coaching] = 1 OR [Met Incentive] = 1 THEN MemberID END) AS [UniqueMTD]
		FROM
			#DenormActivityData
		GROUP BY
			MonthYear,
			ActivityMonth
		UNION
		SELECT
			2 AS SortNumber,
			'[All Locations]' AS LocationCode,
			MonthYear,
			ActivityMonth,
			'Returning' AS ParticipantType,
			COUNT(DISTINCT CASE WHEN [E-Coaching] > 1 THEN MemberID END) AS [E-Coaching],
			COUNT(DISTINCT CASE WHEN [Phone Coaching] > 1 THEN MemberID END) AS [Phone Coaching],
			COUNT(DISTINCT CASE WHEN [Onsite Coaching] > 1 THEN MemberID END) AS [Onsite Coaching],
			COUNT(DISTINCT CASE WHEN [Challenge] > 1 THEN MemberID END) AS [Challenge],
			0 AS [Met Incentive],   -- THERE SHOULD NEVER BE MORE THAN ONE RECORD FOR MET INCENTIVE (SEE MET INCENTIVE TEMP TABLE)
			COUNT(DISTINCT CASE WHEN [Challenge] != 1 OR [Onsite Coaching] != 1 OR [Phone Coaching] != 1 OR [E-Coaching] != 1 OR [Met Incentive] != 1 THEN MemberID END) AS [UniqueMTD]
		FROM
			#DenormActivityData
		GROUP BY
			MonthYear,
			ActivityMonth
		) dnd
	LEFT JOIN
		(
		SELECT
			LocationCode,
			ActivityMonth AS ActivityMonth,
			'New' AS ParticipantType,
			COUNT(DISTINCT MemberID) AS [UniqueYTD]
		FROM
			#ActivityData
		WHERE
			MemberSequence = 1
		GROUP BY
			LocationCode,
			ActivityMonth
		UNION
		SELECT
			'[All Locations]' AS LocationCode,
			ActivityMonth AS ActivityMonth,
			'New' AS ParticipantType,
			COUNT(DISTINCT MemberID) AS [UniqueYTD]
		FROM
			#ActivityData
		WHERE
			MemberSequence = 1
		GROUP BY
			ActivityMonth
		) uytd
		ON	(dnd.LocationCode = uytd.LocationCode)
		AND	(dnd.ActivityMonth = uytd.ActivityMonth)
		AND	(dnd.ParticipantType = uytd.ParticipantType)
	ORDER BY
		dnd.SortNumber,
		dnd.LocationCode,
		dnd.ActivityMonth,
		dnd.ParticipantType

/*===================================================== CLEAN UP ====================================================*/
	
	IF OBJECT_ID('TempDB.dbo.#RunningPointsTotal') IS NOT NULL BEGIN
		DROP TABLE #RunningPointsTotal
	END
	
	IF OBJECT_ID('TempDB.dbo.#MetIncentive') IS NOT NULL BEGIN
		DROP TABLE #MetIncentive
	END

	IF OBJECT_ID('TempDB.dbo.#ActivityData') IS NOT NULL BEGIN
		DROP TABLE #ActivityData
	END

	IF OBJECT_ID('TempDB.dbo.#DenormActivityData') IS NOT NULL BEGIN
		DROP TABLE #DenormActivityData
	END

	
END
GO
