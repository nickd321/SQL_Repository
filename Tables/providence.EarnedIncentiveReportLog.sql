CREATE TABLE [providence].[EarnedIncentiveReportLog]
(
[ReportLogID] [int] NOT NULL IDENTITY(1, 1),
[MemberID] [int] NOT NULL,
[EligMemberID] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EligMemberSuffix] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EligMemberID_Suffix] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS1] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS3] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS6] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS8] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS9] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS10] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS1_INT] [int] NULL,
[IncentiveCoverageTier] [int] NULL,
[PremiumLifestyleCreditCode] [int] NULL,
[DateReported] [datetime] NOT NULL,
[ReportedTo] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ReportEndDate] [datetime] NOT NULL,
[AddedDate] [datetime] NOT NULL CONSTRAINT [DF__EarnedInc__Added__7ABC33CD] DEFAULT (getdate()),
[AddedBy] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ModifiedBy] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [varchar] (8000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Deleted] [bit] NOT NULL CONSTRAINT [DF__EarnedInc__Delet__7BB05806] DEFAULT ((0))
) ON [PRIMARY]
GO
ALTER TABLE [providence].[EarnedIncentiveReportLog] ADD CONSTRAINT [PK_ReportLogID] PRIMARY KEY CLUSTERED  ([ReportLogID]) ON [PRIMARY]
GO
