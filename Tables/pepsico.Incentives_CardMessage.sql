CREATE TABLE [pepsico].[Incentives_CardMessage]
(
[CardMessageID] [int] NOT NULL IDENTITY(1, 1),
[ProgramName] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MessageCode] [int] NOT NULL,
[RuleDescription] [varchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Deleted] [bit] NOT NULL
) ON [PRIMARY]
GO
