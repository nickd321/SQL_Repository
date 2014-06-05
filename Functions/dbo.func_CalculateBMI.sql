SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE FUNCTION [dbo].[func_CalculateBMI]  
(  
    @decWeightLbs		DECIMAL,
	@decHeightFeet		DECIMAL,  
    @decHeightInches	DECIMAL 
) 
RETURNS DECIMAL(38,4)
AS  
BEGIN 

/*
If any of the following scenarios are true, this calculation will return a NULL value
	- Weight is NULL, 0, or non-numeric
	- Height Feet is NULL, 0, or non-numeric
	- Height Inches is non-numeric
*/

	SET @decHeightInches = ISNULL(@decHeightInches,0)

	DECLARE @decBMI		DECIMAL(38,4)
	SET @decBMI = 
		(
		SELECT
			-- BMI Calculation:  ((Weight-lbs / (Height-inches)^2) * 703) --
			CASE 
				-- Do not calculate scenarios --
				WHEN @decWeightLbs IS NULL THEN NULL
				WHEN @decHeightFeet IS NULL THEN NULL 
				WHEN ISNUMERIC(@decWeightLbs) = 0 THEN NULL
				WHEN ISNUMERIC(@decHeightFeet) = 0 THEN NULL
				WHEN ISNUMERIC(@decHeightInches) = 0 THEN NULL
				WHEN @decWeightLbs = 0 THEN NULL
				WHEN @decHeightFeet = 0 THEN NULL

				-- Calculation --
				ELSE
				(
					(
						(	-- Weight --
							@decWeightLbs
						) 

						/

						SQUARE	
						(	-- Height Inches --				
							CASE 
								WHEN ISNUMERIC(@decHeightFeet) = 1 and ISNUMERIC(@decHeightInches) = 1 
									THEN (ROUND(@decHeightFeet,0) * 12) + ROUND(@decHeightInches,0) 
								ELSE NULL
							END									
						)
					)
				
					* 703
				)
			END
		);

	RETURN @decBMI

END  


GO
