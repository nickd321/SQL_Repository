SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



-- =============================================
-- Author:		Nick Domokos
-- Create date: 3/31/2014
-- Description:	Internal report of duplicate member records for the Magellan rider group: Lowe's

-- Notes:		
--				
--				
--				
--
-- Updates:		NickD_20140430
--				Added an eligiblity termination flag.
--
-- =============================================

CREATE PROCEDURE [internal].[proc_Magellan_LowesMemberDuplicates]

AS
BEGIN
	SET NOCOUNT ON;
	
	-- CLEAN UP
	IF OBJECT_ID('tempdb.dbo.#Base') IS NOT NULL
	BEGIN
		DROP TABLE #Base
	END
	
	SELECT
		hpg.HealthPlanID,
		hpg.HealthPlanName,
		hpg.GroupNumber,
		hpg.GroupName,
		mem.MemberID,
		mem.EligMemberID,
		mem.EligmemberSuffix AS [Suffix],
		mem.AltID1,
		mem.FirstName,
		mem.LastName,
		mem.BirthDate,	
		elig.EffectiveDate,
		elig.TerminationDate,
		-- NOT USING IsTermed COLUMN IN DA_Production.prod.Eligibility SINCE THAT COLUMN DOES NOT TAKE INTO ACCOUNT FUTURE TERMINATION DATES
		CASE WHEN ISNULL(elig.TerminationDate,'2999-12-31') > DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0) THEN 0 ELSE 1 END AS [IsTermed] 
	INTO
		#Base
	FROM
		DA_Production.prod.HealthPlanGroup hpg
	JOIN
		DA_Production.prod.Member mem
		ON	(hpg.GroupID = mem.GroupID)
		AND	(mem.GroupID = 150645)
	JOIN
		(
		SELECT
			MemberID,
			EffectiveDate,
			TerminationDate,
			ROW_NUMBER() OVER (PARTITION BY MemberID ORDER BY ISNULL(TerminationDate,'2999-12-31') DESC) AS RevTermSeq
		FROM
			DA_Production.prod.Eligibility
		WHERE
			GroupID = 150645
		) elig
		ON	(mem.MemberID = elig.MemberID)
		AND	(elig.RevTermSeq = 1)	

	SELECT
		mem.HealthPlanID,
		mem.HealthPlanName,
		mem.GroupNumber,
		mem.GroupName,
		mem.MemberID,
		ISNULL(mem.EligMemberID,'') AS [EligMemberID],
		ISNULL(mem.Suffix,'') AS [Suffix],
		mem.AltID1,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS [DOB],
		CASE WHEN mem.IsTermed = 1 THEN 'Y' ELSE '' END AS [TermedMemberFlag]
	FROM
		(
		SELECT
			MemberID,
			EligMemberID,
			Suffix,
			AltID1,
			FirstName,
			LastName,
			Birthdate,
			IsTermed,
			ROW_NUMBER() OVER (PARTITION BY FirstName, LastName, Birthdate ORDER BY EligMemberID) AS [DupSeq]
		FROM
			#Base
		) dup
	JOIN
		#Base mem
		ON	(mem.FirstName = dup.FirstName)
		AND	(mem.LastName = dup.LastName)
		AND	(mem.Birthdate = dup.Birthdate)
	WHERE
		dup.DupSeq = 2
	ORDER BY
		mem.LastName,
		mem.FirstName,
		mem.Birthdate

END

GO
