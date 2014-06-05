SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROC [selfservice].[proc_Finance_Coaching]

AS BEGIN

	IF OBJECT_ID('selfservice.Finance_Coaching') IS NOT NULL BEGIN
		DROP TABLE selfservice.Finance_Coaching
	END

	IF OBJECT_ID('tempDB.dbo.#ClientBenefitPeriods') IS NOT NULL BEGIN
		DROP TABLE #ClientBenefitPeriods
	END

	SELECT
		clnt.ClientName,
		CASE
			WHEN TypeID = 1 THEN ''
			WHEN clnt.IsRider = 0 THEN '[Core Plan Sponsors]'
			ELSE clnt.PlanSponsorName
		END AS PlanSponsor,
		clnt.GroupID,
		CASE WHEN ben.GroupID IS NOT NULL THEN 'True' ELSE 'False' END AS CoachingBenefit,
		CASE WHEN dt.MonthNumber = MONTH(clnt.EffectiveDate) THEN dt.YearNumber END AS BenefitYear,
		MIN(DATEADD(YY,dt.YearNumber-1900,DATEADD(MM,MONTH(clnt.EffectiveDate)-1,0))) AS BeginDate,
		MAX(DATEADD(YY,1,DATEADD(YY,dt.YearNumber-1900,DATEADD(MM,MONTH(clnt.EffectiveDate)-1,0)))) AS EndDate,
		DATENAME(MM,clnt.EffectiveDate) + ' - ' + DATENAME(MM,DATEADD(MM,-1,clnt.EffectiveDate)) AS BenefitMonths
	INTO
		#ClientBenefitPeriods
	FROM
		DA_Production.prod.Client clnt
	JOIN
		DA_Production.aid.DateReference dt
		ON	(clnt.EffectiveDate <= dt.FullDate)
		AND	(clnt.TerminationDate > dt.FullDate)
		AND	(dt.YearNumber BETWEEN 2009 AND YEAR(GETDATE()))
		AND	(dt.MonthNumber = MONTH(clnt.EffectiveDate))
		AND	(dt.IsMonthFloor = 1)
	JOIN
		(
		SELECT
			GroupID
		FROM
			DA_Production.prod.GroupProduct
		WHERE
			ProductCode IN ('CCH','LCH')
		) ben
		ON	(clnt.GroupID = ben.GroupID)
	GROUP BY
		clnt.ClientName,
		CASE
			WHEN TypeID = 1 THEN ''
			WHEN clnt.IsRider = 0 THEN '[Core Plan Sponsors]'
			ELSE clnt.PlanSponsorName
		END,
		clnt.GroupID,
		CASE WHEN ben.GroupID IS NOT NULL THEN 'True' ELSE 'False' END,
		CASE WHEN dt.MonthNumber = MONTH(clnt.EffectiveDate) THEN dt.YearNumber END,
		DATENAME(MM,clnt.EffectiveDate) + ' - ' + DATENAME(MM,DATEADD(MM,-1,clnt.EffectiveDate))


	-- Final Query
	SELECT
		cbp.ClientName,
		cbp.PlanSponsor,
		cbp.BenefitYear,
		cbp.BenefitMonths,
		MAX(cbp.CoachingBenefit) AS CoachingBenefit,
		elig.MemberID,
		CASE WHEN appt.MemberID IS NOT NULL THEN 1 ELSE 0 END AS Participated,
		appt.ProgramName,
		Stratification = (SELECT MemberStratificationName FROM DA_Production.prod.func_MemberHighestStratification(elig.MemberID,cbp.BeginDate,cbp.EndDate)),
		CASE
			WHEN COUNT(appt.AppointmentID) = 1 THEN '1 Session'
			WHEN COUNT(appt.AppointmentID) BETWEEN 2 AND 3 THEN '2 to 3 Sessions'
			WHEN COUNT(appt.AppointmentID) BETWEEN 4 AND 7 THEN '4 to 7 Sessions'
			WHEN COUNT(appt.AppointmentID) BETWEEN 8 AND 14 THEN '8 to 14 Sessions'
			WHEN COUNT(appt.AppointmentID) >= 15 THEN '15+ Sessions'
		END AS SessionIntensity,
		COUNT(appt.AppointmentID) AS SessionCount
	INTO
		DA_Reports.selfservice.Finance_Coaching
	FROM
		#ClientBenefitPeriods cbp
	LEFT JOIN
		DA_Production.prod.Eligibility elig
		ON	(cbp.GroupID = elig.GroupID)
		AND	(cbp.BeginDate < ISNULL(elig.TerminationDate,'1/1/3000'))
		AND	(cbp.EndDate > elig.EffectiveDate)
	LEFT JOIN
		(
		SELECT
			a.GroupID,
			p.ProgramName,
			a.AppointmentBeginDate,
			a.MemberID,
			a.AppointmentID
		FROM
			DA_Production.prod.ProgramEnrollment p
		JOIN
			DA_Production.prod.Appointment a
			ON	(p.MemberID = a.MemberID)
			AND	(p.EnrollmentDate <= a.AppointmentBeginDate)
			AND	(ISNULL(p.TerminationDate,'1/1/3000') > a.AppointmentBeginDate)
		WHERE
			a.AppointmentStatusID = 4
		) appt
		ON	(elig.MemberID = appt.MemberID)
		AND	(cbp.BeginDate <= appt.AppointmentBeginDate)
		AND	(cbp.EndDate > AppointmentBeginDate)
	GROUP BY
		cbp.ClientName,
		cbp.PlanSponsor,
		cbp.BenefitYear,
		cbp.BenefitMonths,
		appt.ProgramName,
		elig.MemberID,
		CASE WHEN appt.MemberID IS NOT NULL THEN 1 ELSE 0 END,
		cbp.BeginDate,
		cbp.EndDate

	--Innocuous Output, so that this may be used within the report automation process
	SELECT 1 AS [Output]

END
GO
