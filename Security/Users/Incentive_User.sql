IF NOT EXISTS (SELECT * FROM master.dbo.syslogins WHERE loginname = N'Incentive_User')
CREATE LOGIN [Incentive_User] WITH PASSWORD = 'p@ssw0rd'
GO
CREATE USER [Incentive_User] FOR LOGIN [Incentive_User]
GO
