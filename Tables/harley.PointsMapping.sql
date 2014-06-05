CREATE TABLE [harley].[PointsMapping]
(
[PointsMappingID] [int] NOT NULL IDENTITY(1, 1),
[ClassCode] [int] NOT NULL,
[EmployeeClassCode] [int] NOT NULL,
[SpouseClassCode] [int] NOT NULL,
[Deleted] [bit] NOT NULL
) ON [PRIMARY]
GO
