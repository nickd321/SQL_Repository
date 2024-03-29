CREATE TABLE [selfservice].[Challenges]
(
[ClientType] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Client] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PlanSponsor] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastName] [varchar] (80) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[FirstName] [varchar] (80) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[Relationship] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[EligMemberID] [varchar] (33) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS1] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS2] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS3] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS4] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS5] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS6] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS7] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS8] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS9] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS10] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS11] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS12] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS13] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS14] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS15] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS16] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS17] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS18] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS19] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS20] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS21] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS22] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS23] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CS24] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AltID1] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AltID2] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Email] [varchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[DOB] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Address] [varchar] (201) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[City] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[State] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[IsCurrentlyEligible] [int] NOT NULL,
[ChallengeName] [varchar] (8000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ChallengeBeginDate] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RegistrationDate] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[CompletionDate] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ChallengeCompleted] [int] NOT NULL
) ON [PRIMARY]
GO
