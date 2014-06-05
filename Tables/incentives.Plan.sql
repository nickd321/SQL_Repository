CREATE TABLE [incentives].[Plan]
(
[PlanID] [int] NOT NULL IDENTITY(1, 1),
[HealthPlanID] [int] NOT NULL,
[GroupID] [int] NOT NULL,
[ClientID] [int] NOT NULL,
[ClientIncentivePlanID] [int] NOT NULL,
[IncentivePlanID] [int] NOT NULL,
[ActivityPlanID] [int] NOT NULL,
[PlanStart] [datetime] NOT NULL,
[PlanEnd] [datetime] NOT NULL,
[SourceDatabase] [varchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Expired] [bit] NOT NULL,
[RecordHash] [varbinary] (100) NOT NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO



CREATE TRIGGER [incentives].[trgr_Plan_RecordHash] 
   ON  [incentives].[Plan] 
   AFTER UPDATE
AS 
BEGIN

	SET NOCOUNT ON;

	UPDATE pln
	SET pln.RecordHash = upd.RecordHash
	FROM
		incentives.[Plan] pln
	JOIN
		(
		SELECT
			PlanID,
			HASHBYTES(
				'SHA1',
				(
				CAST(IncentivePlanID AS VARCHAR(10)) + '|' +
				CAST(ActivityPlanID AS VARCHAR(10)) + '|' +
				CAST(CAST(PlanStart AS FLOAT) AS VARCHAR(30)) + '|' +
				CAST(CAST(PlanEnd AS FLOAT) AS VARCHAR(30)) + '|' +
				SourceDatabase
				)) AS RecordHash
		FROM
			INSERTED
		) upd
		ON	(pln.PlanID = upd.PlanID)
END


GO
ALTER TABLE [incentives].[Plan] ADD CONSTRAINT [PK_Plan] PRIMARY KEY CLUSTERED  ([PlanID]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_NC_Plan_GroupID_RecordHash] ON [incentives].[Plan] ([GroupID], [RecordHash]) ON [PRIMARY]
GO
