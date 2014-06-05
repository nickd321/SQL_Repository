CREATE TABLE [providence].[Spouse_MidYearAdd_List]
(
[MemberID] [int] NULL,
[EligMemberID] [varchar] (30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EligMemberSuffix] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FirstName] [varchar] (80) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastName] [varchar] (80) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MiddleInitial] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[RelationshipID] [int] NULL,
[Birthdate] [datetime] NULL,
[EE_AltID1] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[FileDate] [datetime] NULL,
[AddDate] [datetime] NULL
) ON [PRIMARY]
GO
