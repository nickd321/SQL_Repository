IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'CORP\GregN')
CREATE LOGIN [CORP\GregN] FROM WINDOWS
GO
CREATE USER [CORP\GregN] FOR LOGIN [CORP\GregN]
GO