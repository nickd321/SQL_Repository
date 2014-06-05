SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE FUNCTION [temp].[ufn_ProperCase] (@text VARCHAR(4000))
RETURNS VARCHAR(4000)
AS

BEGIN
	DECLARE @counter INT, 
	@length INT,
	@char CHAR(1),
	@textnew VARCHAR(4000)

	SET @text = RTRIM(@text)
	SET @text = LOWER(@text)
	SET @length = LEN(@text)
	SET @counter = 1

	IF	@length > 0 
		BEGIN
			SET @text = UPPER(LEFT(@text, 1) ) + RIGHT(@text, @length - 1) 

			WHILE @counter <> @length --+ 1
				BEGIN
					SELECT @char = SUBSTRING(@text, @counter, 1)

					IF @char = SPACE(1) or @char = '_' or @char = ',' or @char = '.' or @char = '\'
					or @char = '/' or @char = '(' or @char = ')'
						BEGIN
							SET @textnew = LEFT(@text, @counter) + UPPER(SUBSTRING(@text, 
							@counter+1, 1)) + RIGHT(@text, (@length - @counter) - 1)
							SET @text = @textnew
						END

					SET @counter = @counter + 1
				END
		END

	RETURN @text
END

GO
