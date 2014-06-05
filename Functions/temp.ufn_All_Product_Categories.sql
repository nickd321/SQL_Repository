SET QUOTED_IDENTIFIER OFF
GO
SET ANSI_NULLS OFF
GO

CREATE FUNCTION [temp].[ufn_All_Product_Categories](@ProductID INT)
RETURNS VARCHAR(1000) 

AS  
 
BEGIN 
	DECLARE		@temp_return as VARCHAR(1000);

	SELECT		@temp_return = ConcatenatedCategories
	FROM		DA_Reports.temp.vwProduct_ConcatenatedCategories
	WHERE		ProductID = @ProductID;

    IF (@temp_return IS NULL) 
        SET @temp_return = ''

	RETURN	(@temp_return)
END;
GO
