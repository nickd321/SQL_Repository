IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'CORP\BlairG')
CREATE LOGIN [CORP\BlairG] FROM WINDOWS
GO
CREATE USER [CORP\BLAIRG] FOR LOGIN [CORP\BlairG]
GO