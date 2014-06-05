CREATE TABLE [incentives].[HealthyroadsDB_Recalc_Log]
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
ALTER TABLE [incentives].[HealthyroadsDB_Recalc_Log] ADD CONSTRAINT [PK__Healthyr__5E5499A819CACAD2] PRIMARY KEY CLUSTERED  ([LogID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [ix_nc_Healthyr_MemberID] ON [incentives].[HealthyroadsDB_Recalc_Log] ([MemberID]) ON [PRIMARY]
GO
