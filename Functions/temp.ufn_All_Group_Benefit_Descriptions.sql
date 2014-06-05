SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO

CREATE FUNCTION [temp].[ufn_All_Group_Benefit_Descriptions](@GroupID INT, @BeginDate DATETIME, @EndDate DATETIME)
RETURNS VARCHAR(4000) 

AS  
 
BEGIN 
	DECLARE		@temp_return as VARCHAR(4000);

	SELECT		@temp_return = COALESCE(@temp_return + ', ', '') +
				CAST(ISNULL(b.Description,'') AS varchar(50))
	FROM		Benefits..GroupEnrollment ge (nolock)
	JOIN		Benefits..Benefit b (nolock)
					on	ge.BenefitID = b.BenefitID
					and	b.Deleted = 0
	WHERE		ge.GroupID = @GroupID
	and			ge.Deleted = 0
	and			(DATEDIFF(DAY, ge.EffectiveDate, @EndDate) >= 0) 
	and			(	ge.TerminationDate IS NULL
				or	(DATEDIFF(DAY, @BeginDate, ge.TerminationDate) >= 0)
				) 
	GROUP BY	b.Description;

    IF (@temp_return IS NULL) 
        SET @temp_return = ''

	RETURN	(@temp_return)
END;
GO
