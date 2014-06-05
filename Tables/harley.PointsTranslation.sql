CREATE TABLE [harley].[PointsTranslation]
(
[PointsTranslationID] [int] NOT NULL IDENTITY(1, 1),
[PointsClassCode] [int] NOT NULL,
[MinPointsValue] [int] NOT NULL,
[MaxPointsValue] [int] NOT NULL,
[Deleted] [bit] NOT NULL
) ON [PRIMARY]
GO
