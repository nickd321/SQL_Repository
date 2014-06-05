SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO

CREATE FUNCTION [temp].[ufn_All_Group_Contracts](@GroupID INT, @BeginDate DATETIME, @EndDate DATETIME)
RETURNS VARCHAR(1000) 

AS  
 
BEGIN 
	DECLARE		@temp_return as VARCHAR(1000);

	SELECT		@temp_return = COALESCE(@temp_return + ', ', '') +
				CAST(ISNULL(ge.Contract,'') AS varchar(50))
	FROM		Benefits.dbo.GroupEnrollment ge (nolock)
	WHERE		ge.GroupID = @GroupID
	and			ge.Deleted = 0
	and			(DATEDIFF(DAY, ge.EffectiveDate, @EndDate) >= 0) 
	and			(	ge.TerminationDate IS NULL
				or	(DATEDIFF(DAY, @BeginDate, ge.TerminationDate) >= 0)
				) 
	GROUP BY	ge.Contract;

    IF (@temp_return IS NULL) 
        SET @temp_return = ''

	RETURN	(@temp_return)
END;

GO
