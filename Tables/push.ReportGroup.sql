CREATE TABLE [push].[ReportGroup]
(
[ReportGroupID] [int] NOT NULL IDENTITY(1, 1),
[ReportID] [int] NOT NULL,
[GroupID] [int] NOT NULL,
[Deleted] [bit] NOT NULL CONSTRAINT [DF__ReportGro__Delet__2CFD9AD7] DEFAULT ((0))
) ON [PRIMARY]
GO
ALTER TABLE [push].[ReportGroup] ADD CONSTRAINT [PK__ReportGr__D202A7FF2A212E2C] PRIMARY KEY CLUSTERED  ([ReportGroupID]) ON [PRIMARY]
GO
ALTER TABLE [push].[ReportGroup] ADD CONSTRAINT [FK__ReportGro__Repor__2C09769E] FOREIGN KEY ([ReportID]) REFERENCES [push].[Report] ([ReportID])
GO
