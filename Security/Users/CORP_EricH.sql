IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'CORP\EricH')
CREATE LOGIN [CORP\EricH] FROM WINDOWS
GO
CREATE USER [CORP\EricH] FOR LOGIN [CORP\EricH]
GO