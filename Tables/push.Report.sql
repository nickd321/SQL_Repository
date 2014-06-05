CREATE TABLE [push].[Report]
(
[ReportID] [int] NOT NULL IDENTITY(1, 1),
[ReportName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EffectiveBeginDate] [datetime] NOT NULL,
[EffectiveEndDate] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [push].[Report] ADD CONSTRAINT [PK__Report__D5BD48E526509D48] PRIMARY KEY CLUSTERED  ([ReportID]) ON [PRIMARY]
GO
