CREATE TABLE [internal].[PepsiCo_LettersOutreach_Log]
(
[LogID] [int] NOT NULL IDENTITY(1, 1),
[MemberID] [int] NOT NULL,
[EligMemberID] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EligMemberSuffix] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FirstName] [varchar] (80) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastName] [varchar] (80) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RelationshipID] [int] NULL,
[Birthdate] [datetime] NULL,
[Address1] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Address2] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[City] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[State] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ZipCode] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS5] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[IsCurrentlyEligible] [bit] NULL,
[IsExpat] [bit] NULL,
[IncentiveActivityCreditDate] [datetime] NOT NULL,
[MemberScreeningID] [int] NOT NULL,
[FileSource] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ScreeningDate] [datetime] NOT NULL,
[MemberStratificationName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[BIOMETRICSCREENING] [bit] NOT NULL,
[BIOMETRICOUTCOMES] [bit] NOT NULL,
[COACHING] [bit] NOT NULL,
[DM] [bit] NOT NULL,
[ReportType] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateReported] [datetime] NULL,
[AddedDate] [datetime] NOT NULL,
[AddedBy] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ModifiedBy] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Notes] [varchar] (8000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Rerun] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [internal].[PepsiCo_LettersOutreach_Log] ADD CONSTRAINT [PK_LogID] PRIMARY KEY CLUSTERED  ([LogID]) ON [PRIMARY]
GO
