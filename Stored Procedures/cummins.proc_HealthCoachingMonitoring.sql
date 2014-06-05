SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [cummins].[proc_HealthCoachingMonitoring]

@PreviousMonthDate DATETIME = NULL,
@BenefitBeginDate DATETIME = NULL,
@BenefitEndDate DATETIME = NULL

AS BEGIN

/* 
::ASSUMPTIONS::

Designated Coaching Team
------------------------
Members and members' coach type will not change.
 - Brought issue up with Julie J.
Nurse coaches only handle Nurse Coaching appointments


Benefit Year
------------
1/1/2013 Through 1/1/2014 per Lindsay G. and confirmed (by her) with Cummins


Eligibility Criterion
---------------------
If eligible at any point within the period (month, year, program); member will be counted.

*/
SELECT
	@PreviousMonthDate = ISNULL(@PreviousMonthDate,DATEADD(MM,DATEDIFF(MM,0,GETDATE())-1,0)),
	@BenefitBeginDate = ISNULL(@BenefitBeginDate,'1/1/2014'),
	@BenefitEndDate = ISNULL(@BenefitEndDate,'1/1/2015')


--------STATIC LIST PER ELIZABETH T. AND TERI D.------------------------
DECLARE @DesignatedTeam AS TABLE (UserID INT NOT NULL, CoachType CHAR(2) NOT NULL)
INSERT INTO @DesignatedTeam
VALUES
	(174,'LS'),
	(719,'LS'),
	(991,'LS'),
	(926,'LS'),
	(125,'LS'),
	(166,'LS'),
	(963,'LS'),
	(621,'LS'),
	(400,'LS'),
	(318,'LS'),
	(417,'LS'),
	(402,'LS'),
	(136,'LS'),
	(584,'LS'),
	(605,'LS'),
	(891,'LS'),
	(729,'LS'),
	(1031,'LS'),
	(177,'LS'),
	(1543,'RN'),
	(1184,'RN'),
	(1544,'RN'),
	(920,'RN'),
	(812,'RN')
-----------------------------------

IF OBJECT_ID('TempDB.dbo.#Participation') IS NOT NULL BEGIN
	DROP TABLE #Participation
END

IF OBJECT_ID('TempDB.dbo.#CumminsFinal') IS NOT NULL BEGIN
	DROP TABLE #CumminsFinal
END


SELECT
	*
INTO
	#CumminsFinal
FROM
	(
	SELECT
		CASE WHEN appt.AppointmentTypeID = 26 THEN 'Nurse Coaching' ELSE 'Lifestyle Coaching' END AS CoachingType,
		dc.DesignatedCoaches,
		COUNT(DISTINCT CASE WHEN DATEDIFF(MM,@PreviousMonthDate,appt.AppointmentBeginDate) = 0 THEN appt.MemberID END) AS ParticipantsPriorMonth,
		COUNT(DISTINCT CASE WHEN appt.AppointmentBeginDate BETWEEN @BenefitBeginDate AND @BenefitEndDate THEN appt.MemberID END) AS ParticipantsYTD,
		COUNT(DISTINCT appt.MemberID) AS ParticipantsPTD,
		COUNT(DISTINCT CASE WHEN DATEDIFF(MM,@PreviousMonthDate,appt.AppointmentBeginDate) = 0 THEN appt.AppointmentID END) AS SessionsPriorMonth,
		COUNT(DISTINCT CASE WHEN appt.AppointmentBeginDate BETWEEN @BenefitBeginDate AND @BenefitEndDate THEN appt.AppointmentID END) AS SessionsYTD,
		COUNT(DISTINCT appt.AppointmentID) AS SessionsPTD,
		COUNT(DISTINCT CASE WHEN appt.GroupID = 38919 AND DATEDIFF(MM,@PreviousMonthDate,appt.AppointmentBeginDate) = 0 THEN appt.MemberID END) AS CumminsParticipantsPriorMonth,
		COUNT(DISTINCT CASE WHEN appt.GroupID = 38919 AND appt.AppointmentBeginDate BETWEEN @BenefitBeginDate AND @BenefitEndDate THEN appt.MemberID END) AS CumminsParticipantsYTD,
		COUNT(DISTINCT CASE WHEN appt.GroupID = 38919 THEN appt.MemberID END) AS CumminsParticipantsPTD,
		COUNT(DISTINCT CASE WHEN appt.GroupID = 38919 AND DATEDIFF(MM,@PreviousMonthDate,appt.AppointmentBeginDate) = 0 THEN appt.AppointmentID END) AS CumminsSessionsPriorMonth,
		COUNT(DISTINCT CASE WHEN appt.GroupID = 38919 AND appt.AppointmentBeginDate BETWEEN @BenefitBeginDate AND @BenefitEndDate THEN appt.AppointmentID END) AS CumminsSessionsYTD,
		COUNT(DISTINCT CASE WHEN appt.GroupID = 38919 THEN appt.AppointmentID END) AS CumminsSessionsPTD
	FROM
		DA_Production.prod.Appointment appt
	JOIN
		@DesignatedTeam team
		ON	(appt.CoachUserID = team.UserID)
	JOIN
		(
		SELECT
			CoachType,
			COUNT(UserID) AS DesignatedCoaches
		FROM
			@DesignatedTeam
		GROUP BY
			CoachType
		) dc
		ON	(CASE WHEN appt.AppointmentTypeID = 26 THEN 'RN' ELSE 'LS' END = dc.CoachType)
	WHERE
		appt.AppointmentStatusID = 4 AND --Completed
		DATEDIFF(MM,@PreviousMonthDate,appt.AppointmentBeginDate) <= 0
	GROUP BY
		CASE WHEN appt.AppointmentTypeID = 26 THEN 'Nurse Coaching' ELSE 'Lifestyle Coaching' END,
		dc.DesignatedCoaches
	) part
JOIN
	(
	SELECT
		COUNT(DISTINCT CASE WHEN EffectiveDate < DATEADD(MM,1,@PreviousMonthDate) AND ISNULL(TerminationDate,'12/31/2999') > @PreviousMonthDate THEN MemberID END) AS EligibleMonth,
		COUNT(DISTINCT CASE WHEN EffectiveDate <= @BenefitEndDate AND ISNULL(TerminationDate,'12/31/2999') > @BenefitBeginDate THEN MemberID END) AS EligibleYTD,
		COUNT(DISTINCT MemberID) AS EligiblePTD
	FROM
		DA_Production.prod.Eligibility
	WHERE
		GroupID = 38919 AND --Cummins
		DATEDIFF(MM,@PreviousMonthDate,EffectiveDate) <= 0
	) elig
	ON	(1 = 1)




SELECT
	CoachingType,
	Metric,
	TemporalUnit AS DateMeasure,
	Numerator,
	Denominator,
	CAST(ROUND(CAST(Numerator AS FLOAT) / CAST(Denominator AS FLOAT),1) AS DECIMAL(18,1)) AS [Ratio n:1]
FROM
	(
	--Metrics #1,5
	SELECT
		1.1 AS Sort,
		CoachingType,
		'Healthyroads Participants w/Designated Coach per Designated Coach' AS Metric,
		'Prior Month' AS TemporalUnit,
		ParticipantsPriorMonth AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		1.2 AS Sort,
		CoachingType,
		'Healthyroads Participants w/Designated Coach per Designated Coach' AS Metric,
		'Year to Date' AS TemporalUnit,
		ParticipantsYTD AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		1.3 AS Sort,
		CoachingType,
		'Healthyroads Participants w/Designated Coach per Designated Coach' AS Metric,
		'Program to Date' AS TemporalUnit,
		ParticipantsPTD AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL

	--Metrics #2,6
	SELECT
		2.1 AS Sort,
		CoachingType,
		'Cummins Participants w/Designated Coach per Designated Coach' AS Metric,
		'Prior Month' AS TemporalUnit,
		CumminsParticipantsPriorMonth AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		2.2 AS Sort,
		CoachingType,
		'Cummins Participants w/Designated Coach per Designated Coach' AS Metric,
		'Year to Date' AS TemporalUnit,
		CumminsParticipantsYTD AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		2.3 AS Sort,
		CoachingType,
		'Cummins Participants w/Designated Coach per Designated Coach' AS Metric,
		'Program to Date' AS TemporalUnit,
		CumminsParticipantsPTD AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL

	--Metrics #3,7
	SELECT
		3.1 AS Sort,
		CoachingType,
		'Eligible Cummins Members per Designated Coach' AS Metric,
		'Prior Month' AS TemporalUnit,
		EligibleMonth AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		3.2 AS Sort,
		CoachingType,
		'Eligible Cummins Members per Designated Coach' AS Metric,
		'Year to Date' AS TemporalUnit,
		EligibleYTD AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		3.3 AS Sort,
		CoachingType,
		'Eligible Cummins Members per Designated Coach' AS Metric,
		'Program to Date' AS TemporalUnit,
		EligiblePTD AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL

	--Metrics #4,8
	SELECT
		4.1 AS Sort,
		CoachingType,
		'Cummins Sessions w/Designated Coach per Designated Coach' AS Metric,
		'Prior Month' AS TemporalUnit,
		CumminsSessionsPriorMonth AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		4.2 AS Sort,
		CoachingType,
		'Cummins Sessions w/Designated Coach per Designated Coach' AS Metric,
		'Year to Date' AS TemporalUnit,
		CumminsSessionsYTD AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		4.3 AS Sort,
		CoachingType,
		'Cummins Sessions w/Designated Coach per Designated Coach' AS Metric,
		'Program to Date' AS TemporalUnit,
		CumminsSessionsPTD AS Numerator,
		DesignatedCoaches AS Denominator
	FROM
		#CumminsFinal
	UNION ALL

	--Metric #9
	SELECT
		5.1 AS Sort,
		'Total Lifestyle and Nurse Coaching' AS CoachingType,
		'Cummins Participants per Eligible Cummins Members' AS Metric,
		'Prior Month' AS TemporalUnit,
		SUM(CumminsParticipantsPriorMonth) AS Numerator,
		MAX(EligibleMonth) AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		5.2 AS Sort,
		'Total Lifestyle and Nurse Coaching' AS CoachingType,
		'Cummins Participants per Eligible Cummins Members' AS Metric,
		'Year to Date' AS TemporalUnit,
		SUM(CumminsParticipantsYTD) AS Numerator,
		MAX(EligibleYTD) AS Denominator
	FROM
		#CumminsFinal
	UNION ALL
	SELECT
		5.3 AS Sort,
		'Total Lifestyle and Nurse Coaching' AS CoachingType,
		'Cummins Participants per Eligible Cummins Members' AS Metric,
		'Program to Date' AS TemporalUnit,
		SUM(CumminsParticipantsPTD) AS Numerator,
		MAX(EligiblePTD) AS Denominator
	FROM
		#CumminsFinal
	) rpt
ORDER BY
	CoachingType,
	Sort

--Informational Measures
SELECT
	'Health Coaching Groups with Active Members' AS Measure,
	COUNT(DISTINCT gp.GroupID) AS Value
FROM
	DA_Production.prod.GroupProduct gp
JOIN
	DA_Production.prod.Appointment appt
	ON	(gp.GroupID = appt.GroupID)
	AND	(appt.AppointmentStatusID = 4)
WHERE
	gp.ProductCode = 'CCH'
UNION ALL
SELECT
	'Average Completed Sessions per Cummins Participant (YTD)' AS Measure,
	CAST(ROUND(COUNT(AppointmentID) / COUNT(DISTINCT MemberID) + 0.0,1) AS INT) AS Value
FROM
	DA_Production.prod.Appointment
WHERE
	GroupID = 38919 AND
	AppointmentStatusID = 4 AND
	AppointmentBeginDate >= @BenefitBeginDate AND
	AppointmentBeginDate < @BenefitEndDate
UNION ALL
SELECT
	'Volume of Online Coaching Enrollments (PTD)' AS Measure,
	COUNT(ProgramEnrollmentID) AS Value
FROM
	DA_Production.prod.ProgramEnrollment
WHERE
	SourceID = 1
UNION ALL
SELECT
	'Volume of Online Coaching Enrollments - Cummins Specific (PTD)' AS Measure,
	COUNT(ProgramEnrollmentID) AS Value
FROM
	DA_Production.prod.ProgramEnrollment
WHERE
	SourceID = 1 AND
	GroupID = 38919

END
GO
