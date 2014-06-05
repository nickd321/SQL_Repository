CREATE TABLE [ctca].[Incentives_ActivityQuestionMapping]
(
[MappingID] [int] NOT NULL IDENTITY(1, 1),
[Activity] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[QuestionText] [varchar] (500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[TimePeriodName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ActivityCode] [varchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Deleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [ctca].[Incentives_ActivityQuestionMapping] ADD CONSTRAINT [PK_MappingID] PRIMARY KEY CLUSTERED  ([MappingID]) ON [PRIMARY]
GO
