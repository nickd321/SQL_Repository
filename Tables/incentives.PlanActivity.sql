CREATE TABLE [incentives].[PlanActivity]
(
[PlanActivityID] [int] NOT NULL IDENTITY(1, 1),
[HealthPlanID] [int] NOT NULL,
[GroupID] [int] NOT NULL,
[ClientID] [int] NOT NULL,
[ClientIncentivePlanID] [int] NOT NULL,
[PlanLevel] [int] NOT NULL,
[ActivityItemID] [int] NOT NULL,
[ParentActivityItemID] [int] NULL,
[ActivityItemOperator] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ActivityItemCode] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ActivityID] [int] NULL,
[ActivityName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ActivityDescription] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AI_OrderBy] [int] NULL,
[AI_Name] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AI_Instruction] [varchar] (1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AI_Start] [datetime] NULL,
[AI_End] [datetime] NULL,
[AI_NumDaysToComplete] [int] NULL,
[AI_IsRequired] [bit] NULL,
[AI_IsRequiredStep] [bit] NULL,
[AI_IsActionItem] [bit] NULL,
[AI_IsHidden] [bit] NULL,
[UnitID] [int] NULL,
[UnitName] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AIC_ActivityValue] [int] NULL,
[AIC_CompareValue] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AIC_CompareOperator] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AIL_MaxValue] [int] NULL,
[AIL_TimePeriod] [int] NULL,
[TimePeriodName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AIB_Pregnant] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AIB_Smoking] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AIB_Fasting] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AIB_ExamTypeCode] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Expired] [bit] NOT NULL,
[RecordHash] [varbinary] (100) NOT NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE TRIGGER [incentives].[trgr_PlanActivity_RecordHash] 
   ON  [incentives].[PlanActivity] 
   AFTER UPDATE
AS 
BEGIN

	SET NOCOUNT ON;

	UPDATE pa
	SET pa.RecordHash = upd.RecordHash
	FROM
		incentives.PlanActivity pa
	JOIN
		(
		SELECT
			PlanActivityID,
			HASHBYTES(
					'SHA1',
					(
					CAST(PlanLevel AS VARCHAR(10)) + '|' +
					CAST(ActivityItemID AS VARCHAR(10)) + '|' +
					ISNULL(CAST(ParentActivityItemID AS VARCHAR(10)),'') + '|' +
					ISNULL(ActivityItemOperator,'') + '|' +
					ISNULL(ActivityItemCode,'') + '|' +
					ISNULL(CAST(ActivityID AS VARCHAR(10)),'') + '|' +
					ISNULL(ActivityName,'') + '|' +
					ISNULL(ActivityDescription,'') + '|' +
					ISNULL(CAST(AI_OrderBy AS VARCHAR(10)),'') + '|' +
					ISNULL(AI_Name,'') + '|' +
					ISNULL(AI_Instruction,'') + '|' +
					ISNULL(CAST(CAST(AI_Start AS FLOAT) AS VARCHAR(30)),'') + '|' +
					ISNULL(CAST(CAST(AI_End AS FLOAT) AS VARCHAR(30)),'') + '|' +
					ISNULL(CAST(AI_NumDaysToComplete AS VARCHAR(10)),'') + '|' +
					ISNULL(CAST(AI_IsRequired AS VARCHAR(1)),'') + '|' +
					ISNULL(CAST(AI_IsRequiredStep AS VARCHAR(1)),'') + '|' +
					ISNULL(CAST(AI_IsActionItem AS VARCHAR(1)),'') + '|' +
					ISNULL(CAST(AI_IsHidden AS VARCHAR(1)),'') + '|' +
					ISNULL(CAST(UnitID AS VARCHAR(10)),'') + '|' +
					ISNULL(UnitName,'') + '|' +
					ISNULL(CAST(AIC_ActivityValue AS VARCHAR(10)),'') + '|' +
					ISNULL(AIC_CompareValue,'') + '|' +
					ISNULL(AIC_CompareOperator,'') + '|' +
					ISNULL(CAST(AIL_MaxValue AS VARCHAR(10)),'') + '|' +
					ISNULL(CAST(AIL_TimePeriod AS VARCHAR(10)),'') + '|' +
					ISNULL(TimePeriodName,'') + '|' +
					ISNULL(AIB_Pregnant,'') + '|' +
					ISNULL(AIB_Smoking,'') + '|' +
					ISNULL(AIB_Fasting,'') + '|' +
					ISNULL(AIB_ExamTypeCode,'')
					)) AS RecordHash
		FROM
			INSERTED
		) upd
		ON	(pa.PlanActivityID = upd.PlanActivityID)
END


GO
ALTER TABLE [incentives].[PlanActivity] ADD CONSTRAINT [PK_PlanActivity] PRIMARY KEY CLUSTERED  ([PlanActivityID]) ON [PRIMARY]
GO
