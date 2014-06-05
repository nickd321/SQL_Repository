CREATE TABLE [temp].[UT_Orders_Product_Lookup]
(
[ProductCategory] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ProductName] [varchar] (150) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[ProductSKU] [varchar] (8) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ProductAbbreviation] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[Weight] [numeric] (5, 2) NULL
) ON [PRIMARY]
GO
