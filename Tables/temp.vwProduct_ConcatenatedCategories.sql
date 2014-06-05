CREATE TABLE [temp].[vwProduct_ConcatenatedCategories]
(
[ProductID] [int] NOT NULL,
[ConcatenatedCategories] [varchar] (400) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ConcatenatedCategoryPaths] [varchar] (8000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
