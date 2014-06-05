SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO

CREATE FUNCTION [temp].[ufn_National_Award_Eligibility](@GroupID INT, @BeginDate DATETIME, @EndDate DATETIME)
RETURNS VARCHAR(1000) 

AS  
 
BEGIN 
	DECLARE		@temp_return as VARCHAR(1000);

	SELECT		@temp_return = COALESCE(@temp_return + ', ', '') +
				CAST(ISNULL(bav.AttributeValue,'') AS varchar(10))
	FROM		Benefits..GroupEnrollment ge (nolock)
	JOIN		Benefits..Benefit b (nolock)
					on	ge.BenefitID = b.BenefitID
					and	b.Deleted = 0
	JOIN		Benefits..BenefitAttributeValue bav (nolock) 
					on	b.BenefitID = bav.BenefitID
					and	bav.BenefitAttributeID = 32
	WHERE		ge.GroupID = @GroupID
	and			ge.Deleted = 0
	and			(DATEDIFF(DAY, ge.EffectiveDate, @EndDate) >= 0) 
	and			(	ge.TerminationDate IS NULL
				or	(DATEDIFF(DAY, @BeginDate, ge.TerminationDate) >= 0)
				) 
	GROUP BY	bav.AttributeValue;

    IF (@temp_return IS NULL) 
        SET @temp_return = 'No'

	RETURN	(@temp_return)
END;



GO
