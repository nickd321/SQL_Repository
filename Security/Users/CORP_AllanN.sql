IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'CORP\AllanN')
CREATE LOGIN [CORP\AllanN] FROM WINDOWS
GO
CREATE USER [CORP\AllanN] FOR LOGIN [CORP\AllanN]
GO