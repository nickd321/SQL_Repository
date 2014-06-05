CREATE TABLE [incentives].[IncentiveDB_Recalc_Log]
(
[LogID] [int] NOT NULL IDENTITY(1, 1),
[HealthPlanID] [int] NOT NULL,
[GroupID] [int] NOT NULL,
[MemberID] [int] NOT NULL,
[ChangeDate] [datetime] NOT NULL,
[Change] [varchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Recalculated] [bit] NOT NULL,
[RecalculatedMessage] [varchar] (8000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RecalculatedDate] [datetime] NULL,
[RecalculatedBy] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AddDate] [datetime] NOT NULL,
[AddedBy] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DA_Notes] [varchar] (8000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [incentives].[IncentiveDB_Recalc_Log] ADD CONSTRAINT [PK__Incentiv__5E5499A815FA39EE] PRIMARY KEY CLUSTERED  ([LogID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_nc_Incentiv_MemberID] ON [incentives].[IncentiveDB_Recalc_Log] ([MemberID]) ON [PRIMARY]
GO
