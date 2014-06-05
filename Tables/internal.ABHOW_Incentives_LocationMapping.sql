CREATE TABLE [internal].[ABHOW_Incentives_LocationMapping]
(
[LocationMappingID] [int] NOT NULL IDENTITY(1, 1),
[LocationCode] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LocationName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Deleted] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [internal].[ABHOW_Incentives_LocationMapping] ADD CONSTRAINT [PK_LocationMappingID] PRIMARY KEY CLUSTERED  ([LocationMappingID]) ON [PRIMARY]
GO
