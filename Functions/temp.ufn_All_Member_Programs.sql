SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO

CREATE FUNCTION [temp].[ufn_All_Member_Programs](@MemberID INT, @BeginDate DATETIME, @EndDate DATETIME)
RETURNS VARCHAR(1000) 

AS  
 
BEGIN 
	DECLARE		@temp_return as VARCHAR(1000);

	SELECT		@temp_return = COALESCE(@temp_return + ', ', '') +
				CAST(ISNULL(prog.ProgramName,'') AS varchar(50))
	FROM		Benefits.dbo.ProgramEnrollment pe (nolock) 
	JOIN		Benefits.dbo.Program prog (nolock) 
				on	pe.ProgramID = prog.ProgramID
	WHERE		pe.MemberID = @MemberID  
	and			pe.Deleted = 0				
	and			(DATEDIFF(DAY, pe.EnrollmentDate, @EndDate) >= 0) 
	and			(	pe.TerminationDate IS NULL
				or	(DATEDIFF(DAY, @BeginDate, pe.TerminationDate) >= 0)
				)
	GROUP BY	prog.ProgramName;

    IF (@temp_return IS NULL) 
        SET @temp_return = ''

	RETURN	(@temp_return)
END;
GO
