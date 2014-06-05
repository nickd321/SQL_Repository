IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'CORP\nickd')
CREATE LOGIN [CORP\nickd] FROM WINDOWS
GO
CREATE USER [CORP\nickd] FOR LOGIN [CORP\nickd]
GO
