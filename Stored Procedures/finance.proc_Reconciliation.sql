SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [finance].[proc_Reconciliation] AS

BEGIN

	DECLARE @BeginDate DATETIME
	DECLARE @EndDate DATETIME

	SELECT TOP 1
		@BeginDate = DATEADD(MM,DATEDIFF(MM,0,CAST(OrderDate AS DATETIME)),0),
		@EndDate = DATEADD(MM,DATEDIFF(MM,0,CAST(OrderDate AS DATETIME)) + 1,0)
	FROM
		finance.stg_Reconciliation

	--Provide the sheet names for the following result sets
	SELECT
		SheetName
	FROM
		(
		SELECT
			1 AS SortOrder,
			'Not in Online Store' AS SheetName
		UNION
		SELECT
			2 AS SortOrder,
			'Only in Online Store' AS SheetName
		UNION
		SELECT
			3 AS SortOrder,
			'Order Adjustments' AS SheetName
		) s
	ORDER BY
		SortOrder

	--Not in Online Store
	SELECT
		[Ordernumber],
		[OrderDate],
		[ShipDate],
		[Invoicenumber],
		[CustomerKey],
		[CustomerName],
		[BP Customer],
		[Client Name],
		[BPAADD_0],
		[Salespersonname],
		[Documenttotal],
		[InvoiceDate],
		[CustCategory],
		[CustCategoryDesc],
		[CustomerPO],
		[ZHMS_0]
	FROM
		DA_Reports.finance.stg_Reconciliation r
	LEFT JOIN
		HealthyStore.dbo.HS_Order o
		ON	(r.[ZHMS_0] = CAST(o.OrderID AS VARCHAR))
		AND	(o.CreateDate >= @BeginDate)
		AND	(o.CreateDate < @EndDate)
	WHERE
		o.OrderID IS NULL


	--Only in Online Store
	SELECT     
		cust.SiteMemberID AS MemberID,
		grp.HealthPlanName AS HealthPlan,
		grp.GroupName AS [Group],
		mem.FirstName + ' ' + mem.LastName AS CustomerName,
		ISNULL(prod.ProductName,'') AS ProductName,
		CONVERT(VARCHAR(10),ord.CreateDate,101) AS OrderDate,
		ord.OrderID AS OrderNumber,
		CONVERT(VARCHAR(10),ord.ShippedDate,101) AS ShippedDate,
		prodopt.Name AS ProductOptionName,
		prodopt.SKU AS SKU,
		ord.GrandTotal AS Amount,
		ordtxt.OrderTransactionTypeText AS TransactionType,
		cctxt.CreditCardTransactionTypeText AS CreditCardTransactionType,
		CONVERT(VARCHAR(10),ordtx.TransactionDate,101) AS TransactionDate,
		cctx.PnRef AS TransactionID,
		ordtx.Amount AS TransactionAmount,
		store.Name AS Store
	FROM		
		HealthyStore.dbo.HS_Order ord
	JOIN
		HealthyStore.dbo.HS_OrderItem ordit
		ON	(ord.OrderID = ordit.OrderID)
		AND	(ord.Deleted = 0)
	JOIN
		HealthyStore.dbo.HS_ProductOption prodopt
		ON	(ordit.ProductOptionID = prodopt.ProductOptionID)
	JOIN
		HealthyStore.dbo.HS_Product prod
		ON	(prodopt.ProductID = prod.ProductID)
	JOIN
		HealthyStore.dbo.HS_Customer cust
		ON	(ord.CustomerID = cust.CustomerID)
		AND	(cust.Deleted = 0)
	JOIN
		Healthystore.dbo.HS_OrderTransaction ordtx
		ON	(ord.OrderID = ordtx.OrderID)
	JOIN
		Healthystore.dbo.HS_OrderTransactionType ordtxt
		ON	(ordtx.OrderTransactionTypeID = ordtxt.OrderTransactionTypeID)
		AND	(ordtxt.OrderTransactiontypeID = 1) --Credit Card
	JOIN
		Healthystore.dbo.HS_Store store
		ON	(ord.StoreID = store.StoreID)
	JOIN	
		Healthystore.dbo.HS_CreditCardTransaction cctx
		ON	(ordtx.OrderTransactionID = cctx.OrderTransactionID)
	JOIN
		Healthystore.dbo.HS_CreditCardTransactionType cctxt
		ON	(cctx.CreditCardTransactionTypeID = cctxt.CreditCardTransactionTypeID)
		AND	(cctxt.CreditCardTransactionTypeID IN (2,3)) --Delayed Caption,Sale
	JOIN
		DA_Production.prod.Member mem
		ON	(cust.SiteMemberID = mem.MemberID)
	JOIN
		DA_Production.prod.HealthPlanGroup grp
		ON	(mem.GroupID = grp.GroupID)
	LEFT JOIN 
		DA_Reports.finance.stg_Reconciliation stage
		ON	(CAST(ord.OrderID AS CHAR) = stage.ZHMS_0)
		AND	(stage.OrderDate BETWEEN @BeginDate AND @EndDate)
	WHERE
		ord.Createdate BETWEEN @BeginDate AND @EndDate AND
		ord.OrderStatusID <> 6 AND --Cancelled
		stage.OrderNumber IS NULL
	GROUP BY
		cust.SiteMemberID,
		grp.GroupName,
		grp.HealthPlanName,
		mem.FirstName + ' ' + mem.LastName,
		ISNULL(prod.ProductName,''),
		CONVERT(varchar(10),ord.CreateDate,101),
		CONVERT(varchar(10),ord.ShippedDate,101),
		ord.OrderID,
		prodopt.SKU,
		prodopt.Name,
		ordtxt.OrderTransactionTypeText,
		CONVERT(varchar(10),ordtx.TransactionDate,101),
		ord.GrandTotal,
		ordtx.Amount,
		cctxt.CreditCardTransactionTypeText,
		cctx.PnRef,
		store.Name
	ORDER BY 
		grp.GroupName,
		grp.HealthPlanName


	--Order Adjustments
	SELECT DISTINCT
		CAST(cust.SiteMemberID AS NVARCHAR) AS MemberID,
		CAST(mem.LastName AS NVARCHAR) AS LastName,
		CAST(mem.FirstName AS NVARCHAR) AS FirstName,
		CAST(grp.HealthPlanName AS NVARCHAR) AS HealthPlan,
		CAST(grp.GroupName AS NVARCHAR) AS [Group],
		CONVERT(NCHAR(10),ordtx.TransactionDate,101) AS TransactionDate,
		ordtx.OrderID AS OrderID,
		ordtx.OrderTransactionTypeID AS OrderTransactionTypeID,
		CAST(ordtxt.OrderTransactionTypeText AS NVARCHAR) AS OrderTransactionTypeText,
		ordtx.Amount AS Amount,
		ord.OrderStatusID AS OrderStatusID,
		CAST(ordtxs.OrderStatusText AS NVARCHAR) AS OrderStatusText,
		CAST(ISNULL(ord.Comments,'') AS NVARCHAR) AS Comments
	FROM    
		DA_Production.prod.HealthPlanGroup grp
	JOIN
		DA_Production.prod.Member mem
		ON	(mem.GroupID = grp.GroupID)
	JOIN
		HealthyStore.dbo.HS_Customer cust	
		ON	(cust.SiteMemberID = mem.MemberID)
		AND	(cust.Deleted = 0)
	JOIN
		HealthyStore.dbo.HS_Order ord
		ON	(ord.CustomerID = cust.CustomerID)
		AND	(ord.Deleted = 0)
	JOIN
		HealthyStore.dbo.HS_OrderTransaction ordtx
		ON	(ord.OrderID = ordtx.OrderID)
		AND	(ordtx.OrderTransactionTypeID = 2) --Adjustment
		AND	(ordtx.Amount < 0) --Credit
		AND	(ordtx.TransactionDate BETWEEN @BeginDate AND @EndDate)
	JOIN
		Healthystore.dbo.HS_OrderTransactionType ordtxt  
		ON	(ordtx.OrderTransactionTypeID = ordtxt.OrderTransactionTypeID)
	JOIN
		Healthystore.dbo.HS_OrderStatus ordtxs
		ON	(ord.OrderStatusID = ordtxs.OrderStatusID)
	ORDER BY
		CAST(cust.SiteMemberID AS NVARCHAR)

END
GO
