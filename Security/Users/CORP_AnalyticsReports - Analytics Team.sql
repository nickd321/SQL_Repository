IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'CORP\AnalyticsReports - Analytics Team')
CREATE LOGIN [CORP\AnalyticsReports - Analytics Team] FROM WINDOWS
GO
CREATE USER [CORP\AnalyticsReports - Analytics Team] FOR LOGIN [CORP\AnalyticsReports - Analytics Team]
GO
