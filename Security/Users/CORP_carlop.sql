IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'CORP\carlop')
CREATE LOGIN [CORP\carlop] FROM WINDOWS
GO
CREATE USER [CORP\carlop] FOR LOGIN [CORP\carlop]
GO
