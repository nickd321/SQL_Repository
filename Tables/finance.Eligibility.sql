CREATE TABLE [finance].[Eligibility]
(
[ClientName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[PlanSponsorName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ClientType] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Relationship] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FullDate] [datetime] NULL,
[EligibleCount] [int] NULL,
[PlanID] [int] NULL,
[GroupNumber] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
