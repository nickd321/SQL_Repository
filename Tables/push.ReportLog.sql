CREATE TABLE [push].[ReportLog]
(
[ReportLogID] [int] NOT NULL IDENTITY(1, 1),
[ReportID] [int] NOT NULL,
[LogStatus] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LogDetail] [varchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [push].[ReportLog] ADD CONSTRAINT [CK__ReportLog__LogSt__32B6742D] CHECK (([LogStatus]='E' OR [LogStatus]='W' OR [LogStatus]='S'))
GO
ALTER TABLE [push].[ReportLog] ADD CONSTRAINT [PK__ReportLo__F189033D2FDA0782] PRIMARY KEY CLUSTERED  ([ReportLogID]) ON [PRIMARY]
GO
ALTER TABLE [push].[ReportLog] ADD CONSTRAINT [FK__ReportLog__Repor__31C24FF4] FOREIGN KEY ([ReportID]) REFERENCES [push].[Report] ([ReportID])
GO
