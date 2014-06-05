IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'CORP\HLS_Reports_User')
CREATE LOGIN [CORP\HLS_Reports_User] FROM WINDOWS
GO
CREATE USER [CORP\HLS_Reports_User] FOR LOGIN [CORP\HLS_Reports_User]
GO
