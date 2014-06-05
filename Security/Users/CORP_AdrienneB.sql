IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'CORP\AdrienneB')
CREATE LOGIN [CORP\AdrienneB] FROM WINDOWS
GO
CREATE USER [CORP\AdrienneB] FOR LOGIN [CORP\AdrienneB]
GO
