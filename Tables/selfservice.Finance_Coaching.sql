CREATE TABLE [selfservice].[Finance_Coaching]
(
[ClientName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PlanSponsor] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[BenefitYear] [int] NULL,
[BenefitMonths] [nvarchar] (63) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[CoachingBenefit] [varchar] (5) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MemberID] [int] NULL,
[Participated] [int] NOT NULL,
[ProgramName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Stratification] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SessionIntensity] [varchar] (16) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[SessionCount] [int] NULL
) ON [PRIMARY]
GO
