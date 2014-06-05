SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

-- =============================================
-- Author:		William Perez
-- Create date: 2013-04-05
-- Description:	Givaudan Weekly Nutrition Report
-- =============================================
CREATE PROCEDURE [givaudan].[proc_WebClass_Nutrition]
	@inEndDate DATETIME = NULL
AS
BEGIN

	SET NOCOUNT ON;
	
	SET @inEndDate = ISNULL(@inEndDate,DATEADD(wk,DATEDIFF(wk,0,GETDATE()),4))


	SELECT
		GroupName,
		EligMemberID,
		FirstName,
		MiddleInitial,
		LastName,
		Birthdate,
		Location,
		COUNT(CourseNameID) AS [CourseCount],
		CONVERT(CHAR(10),MIN(CourseCompleteDate),101) AS [FirstCompleteDate],
		CONVERT(CHAR(10),MAX(CourseCompleteDate),101) AS [LastCompleteDate]
	FROM
		(
		SELECT
			grp.GroupName,
			mem.EligMemberID,
			mem.FirstName,
			ISNULL(mem.MiddleInitial,'') AS MiddleInitial,
			mem.LastName,
			CONVERT(CHAR(10),mem.BirthDate,101) AS Birthdate,
			cs.CS1 AS [Location],
			web.CourseNameID,
			web.CourseCompleteDate
		FROM
			DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
		JOIN
			DA_Production.prod.Member mem WITH (NOLOCK)
			ON	(grp.GroupID = mem.GroupID)
			AND	(mem.GroupID = 195332)
		JOIN
			DA_Production.prod.CSFields cs WITH (NOLOCK)
			ON	(mem.MemberID = cs.MemberID)
		JOIN
			DA_Production.prod.WebClass web WITH (NOLOCK)
			ON	(mem.MemberID = web.MemberID)
			AND	(web.CourseNameID IN ('NutritionandHealthyEatingLevel1','NutritionandHealthyEatingLevel2'))
			AND (web.CourseCompleteDate >= '2013-01-01')
			AND	(web.CourseCompleteDate < '2013-05-01')
			AND (web.CourseCompleteDate < @inEndDate)
		GROUP BY
			grp.GroupName,
			mem.EligMemberID,
			mem.FirstName,
			mem.MiddleInitial,
			mem.LastName,
			mem.BirthDate,
			cs.CS1,
			web.CourseNameID,
			web.CourseCompleteDate
		) data
	GROUP BY
		GroupName,
		EligMemberID,
		FirstName,
		MiddleInitial,
		LastName,
		Birthdate,
		Location
		
	
END

GO
