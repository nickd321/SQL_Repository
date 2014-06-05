CREATE TABLE [ctca].[Incentives_ReportLog]
(
[ReportLogID] [int] NOT NULL IDENTITY(1, 1),
[MemberID] [int] NOT NULL,
[MemberActivityItemID] [int] NULL,
[MemberAnswerID] [int] NULL,
[ActivityItemID] [int] NOT NULL,
[ActivityCode] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ActivityCodeDate] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Activity] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ActivityDate] [datetime] NOT NULL,
[ActivityCreditDate] [datetime] NULL,
[ActivityModifiedDate] [datetime] NULL,
[RecordEffectiveBeginDate] [datetime] NULL,
[RecordEffectiveEndDate] [datetime] NULL,
[PointsReported] [int] NULL,
[QuestionText] [varchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TimePeriodName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ReportDate] [datetime] NOT NULL,
[AddedDate] [datetime] NOT NULL,
[AddedBy] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ModifiedDate] [datetime] NULL,
[ModifiedBy] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [varchar] (8000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Rerun] [bit] NOT NULL,
[ReferenceName] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [ctca].[Incentives_ReportLog] ADD CONSTRAINT [PK_ReportLogID] PRIMARY KEY CLUSTERED  ([ReportLogID]) ON [PRIMARY]
GO
