SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		William Perez
-- Create date: 2014-03-19
-- Description:	Verisk Standard Coaching Enrollment Report
-- Vendor:		
--
-- Notes:		
--
-- Updates:		
-- =============================================

CREATE PROCEDURE [verisk].[proc_Coaching_Enrollment]
	@inGroupID INT,
	@inBeginDate DATETIME,
	@inEndDate DATETIME
AS
BEGIN
	SET NOCOUNT ON;

	-- COACHING ENROLLMENT
	SELECT
		REPLACE(grp.GroupName,',','') AS CompanyName,
		mem.EligMemberID,
		mem.EligMemberSuffix,
		mem.FirstName,
		mem.LastName,
		CONVERT(VARCHAR(10),mem.Birthdate,101) AS DOB,
		mem.Relationship,
		mem.Gender,
		mem.AltID1,
		enr.ProgramName,
		CONVERT(VARCHAR(10),enr.EnrollmentDate,101) AS EnrollmentDate,
		ISNULL(CONVERT(VARCHAR(10),enr.TerminationDate,101),'') AS TerminationDate,
		CASE WHEN enr.TerminationDate IS NULL THEN DATEDIFF(dd,DATEADD(dd,0,enr.EnrollmentDate),DATEADD(dd,0,GETDATE())) 
			 ELSE DATEDIFF(dd,DATEADD(dd,0,enr.EnrollmentDate),DATEADD(dd,0,enr.TerminationDate)) END AS EnrollmentDuration   
	FROM
		DA_Production.prod.HealthPlanGroup grp WITH (NOLOCK)
	JOIN
		DA_Production.prod.Member mem WITH (NOLOCK)
		ON	(grp.GroupID = mem.GroupID)
		AND	(mem.GroupID = @inGroupID)
	JOIN
		DA_Production.prod.ProgramEnrollment enr WITH (NOLOCK)
		ON	(mem.MemberID = enr.MemberID)
		AND	(
			 -- NEW ENROLLMENTS IN THE PREVIOUS QUARTER
			 (enr.EnrollmentDate >= @inBeginDate AND enr.EnrollmentDate < @inEndDate) OR 
			 -- ONGOING ENROLLMENTS
			 (enr.TerminationDate IS NULL AND enr.EnrollmentDate < @inEndDate)
			)



END

GO
