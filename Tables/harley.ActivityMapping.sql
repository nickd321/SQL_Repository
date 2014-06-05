CREATE TABLE [harley].[ActivityMapping]
(
[ActivityMappingID] [int] NOT NULL IDENTITY(1, 1),
[ClassCode] [int] NOT NULL,
[EmployeePHABio] [bit] NOT NULL,
[SpousePHABio] [bit] NOT NULL,
[Deleted] [bit] NOT NULL
) ON [PRIMARY]
GO
