IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'TableauUser')
CREATE LOGIN [TableauUser] WITH PASSWORD = 'p@ssw0rd'
GO
CREATE USER [TableauUser] FOR LOGIN [TableauUser]
GO
