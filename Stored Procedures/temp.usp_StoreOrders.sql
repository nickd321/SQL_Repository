SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE [temp].[usp_StoreOrders]

@dtBeginDate DATETIME = NULL,
@dtEndDate DATETIME = NULL

AS BEGIN

/***********************************************************************************************
Notes:			XiaohongL 5/10/2012 Modified from usp_Store_Orders created by Ryan 
				to feed the SSRS report "Store Order Daily" in ReportAutomation system
				
				01/04/2012 BlairG
				Added new Connected SKUs to the list to exclude from HealthyStore.dbo.HS_ProductOption
				in the join.
				
				See Request 1648
				
				06/21/2013 BlairG
				Added SKUs
				'850-052','850-166','850-167','850-160-EX','850-161-EX','850-162-EX','850-163-EX','850-164-EX','850-165-EX','850-166-EX','850-167-EX','850-052-EX'
				to the ignore list
***********************************************************************************************/
/***********************************************************************************************
Report Title:	HRMS Product Orders
Requestor:		Todd Northup
Date:			01/14/08
Author:			Ryan Montgomery

Objectives:		-	Provide an Item listing for each product ordered through the HRMS system (this will
					include the following categories: Supplemental Guides, Incentives, 
					Mental Imagery/Mind Body Relaxation, NRT, Program Manuals).  Only items from previous 
					day, unless Monday (include Fri - Sun) or after holiday (include extra days)

				-	Sort order should be by category (in the order above), and then by Product Name

				-	National Reward eligibility is "Yes" if the member is enrolled in a program at the 
					time of the order (per email Carlos - 1/10)

				-	Report needed by 11am each morning

Notes:			-	May need to add exceptions to the National Reward eligibility per Kim Day's list 
					(i.e. Exxon, etc.)

				-	May change National Reward column to flag "Do not ship National Rewards Info" 
					Indicator (per phone Todd Northup - 1/11)

				-	Weight and Product abbreviatiON lookup table will be provided later by Todd's team
					and implemented into the script. (Complete: 1/14/08)

Updates:		-	Carlos' code did not work for the National Award indicator.  I now have it 
					pointing to whether or not the member is currently enrolled, but will need to take
					it one step further to decide if the group does not want it based off Kimberly 
					Day's spreadsheet (20080128 - RM)

				-	Wrote User Defined Functions to allow Contract and Program to show multiple if 
					the group/member is assigned to multiple entities.  Also wrote functiON to determine
					national award eligibility in case the benefits have contradicting values for 
					national award eligibility (i.e. Yes and No assigned to different benefits) (20080211 - RM)

				-	Updated Product AbbreviatiON when null (20080219)

				-	Added Propercase format to name and address

				-	20090224 - Ryan Montgomery
					NOTE:  !!!!! Changed the UniqueRecordID from OrderID to OrderItemID !!!!!

				-	20090325 - Ryan Montgomery
					Previously, I used LastRecordDate as the starting point for the reporting
					duration.  This has been changed to @MostCurrentReportBeginDate;
					
					@MostCurrentReportDueDate variable name was also changed to
					@MostCurrentReportEndDate; 

					Variables @InTrans and @LastReportRunDate were removed as they are no 
					longer needed;  
	
					Removed logic to initially set @LastReportDate; 

					Reorganized variables;

					Removed Commit logic in ProcExit

				-	20090422 - Ryan Montgomery
					Added CategoryID 1502 per Rodney; he uses this for an Enrollment Fee (kind 
					of a non-order).

				-	20091015 - AarON Field
					Added a REPLACE cause in Address1 to remove commas from the Address1 field.
					This was to satisfy a request from ToddN and Processing Services that could
					not handle commas in the address when printing labels.

				-	20100113 - Angelica Mellina
					Add a Quantity Ordered column. 
					(Per email received from Ryan 20101113-11:03 am sbjt "RE: Reports")

				-	20100427	- (Angelica)
					Set up this report to run in the Task Manager

				-	20100503	-	(Angelica)
					Go by the report logs instead of the task manager logs

				-	20100805 - Ryan Montgomery
					Filtered out "Rewards" category per Todd

				-	20100823 - Ryan Montgomery
					Changed the Store filter from Ids to starts with 'HMS'
					Changed Category filter removal from IDs to adding 'Discount Cards' and 
						'Material Requests' on top of existing filters.
					Changed input logs to Distinct records
					Changed Category output to retrieve from a function to limit duplicate records
						Removed output joins to HS_ProductCategory and HS_Category

				-	20100824 - Ryan Montgomery
					Per David, we can now include Material Requests orders in this report.
					Therefore we'll now allow products associated to "Material Requests" and 
					I will discontinue the existing Material Request report.

					Changed the Order By clause to order by SKU per David

				-	20110329 - Ryan Montgomery
					Revised report to fulfill SSRS automation; a second report will be needed
					for the summary data.
					
			    -   20120206 - Tom Rowland
			        Per WO#645: Todd N. asked us to supress any product
			        with SKU '850-144','850-145'.
			        These are actiped replacements done
			        during the 30 day warranty period.
****************************************************************************************************/

SET NOCOUNT ON
	
	-- SET DEFAULT DAILY DATES IF NONE ARE PROVIDED (SUPPORT AUTOMATED DAILY REPORT)
	SET @dtEndDate = ISNULL(@dtEndDate, DATEADD(DD,DATEDIFF(DD,0,GETDATE()),0))
	SET @dtBeginDate = ISNULL(@dtBeginDate, @dtEndDate - 1)

	
	-- Pull Data
	SELECT	
		m.MemberID		
		-- Shipping Info --
		,'Name' = ISNULL(temp.ufn_ProperCase((a.FirstName + ' ' + a.LastName)),'')
		,'Address 1' = REPLACE(ISNULL(temp.ufn_ProperCase(a.Street1)COLLATE SQL_Latin1_General_CP1_CI_AS,''),',','')
		,'Address 2' = ISNULL(temp.ufn_ProperCase(a.Street2),'')
		,'City' = ISNULL(temp.ufn_ProperCase(a.City),'')
		,'State' = ISNULL(a.State,'')
		,'Zip Code' = ISNULL(a.ZipCode,'')
		,'Reference' =	
			(
				(
					SELECT	CASE 
								WHEN m.MemberID IS NULL THEN 'Unknown'
								ELSE CAST(m.MemberID as VARCHAR)
							END
				) 
				+ ' - ' 
				+ ISNULL(ut.ProductAbbreviation, 'Email Ryan SKU, Product Abbreviation, & Weight')
			)
		,'Weight (lbs.)' = ut.Weight
		-- Additional Product Info --
		,'ProductCategory' = pc.ProductCategories
		,'SKU' = ISNULL(po.SKU,'')
		,'National Award' = temp.ufn_National_Award_Eligibility(g.GroupID, o.CreateDate, o.CreateDate)
		-- Member's Enrolled Program --
		,'Program' = temp.ufn_All_Member_Programs(m.MemberID, o.CreateDate, o.CreateDate)
		-- Client Info --
		,'Contract' = temp.ufn_All_Group_Contracts(g.GroupID, o.CreateDate, o.CreateDate)
		,'Health Plan Name' = ISNULL(hp.HealthPlanName, '')
		,'Group Name' = ISNULL(g.GroupName, '')
		,'Group Number' = ISNULL(g.GroupNumber, '')
		-- Order/Date Info --
		,'Order Date' = CONVERT(VARCHAR(10), o.CreateDate, 101)
		,'Order ID' = o.OrderID
		,'Quantity Ordered' = oi.Quantity ---Added by Angelica Mellina 20101113
		,p.ProductName
		,'BeginDate' = @dtBeginDate
		,'EndDate' = @dtEndDate - 1
		,'IsNRT_Highlight' = CASE WHEN ISNULL(po.SKU,'') LIKE '705%' THEN 1 ELSE 0 END
	FROM		
		HealthyStore.dbo.HS_Order o (nolock) -- 48105
	JOIN		
		HealthyStore.dbo.HS_OrderAddress oa (nolock) 
		on	
			o.OrderID = oa.OrderID
	JOIN		
		HealthyStore.dbo.HS_Address a (nolock) 
		on	
			oa.AddressID = a.AddressID
		and	
			a.AddressTypeID = 
			(
			CASE 
				WHEN EXISTS 
				(
					SELECT  
						*
					FROM	
						HealthyStore.dbo.HS_OrderAddress oa2 (nolock)
					JOIN	
						HealthyStore.dbo.HS_Address a2 (nolock) 
						on	
							oa2.AddressID = a2.AddressID
						and 
							oa2.OrderID = o.OrderID
						and	
							a2.AddressTypeID = 1
				)
				THEN 1
				ELSE 2
			END
			) -- 48105
	JOIN		
		HealthyStore.dbo.HS_OrderItem oi (nolock) 
		on 
			o.OrderID = oi.OrderID -- 35635
	JOIN		
		HealthyStore.dbo.HS_ProductOption po (nolock) 
		on 
			oi.ProductOptionID = po.ProductOptionID
			and po.SKU not in ('850-052','850-144','850-145','850-160','850-161','850-162','850-163','850-164','850-165','850-166','850-167','850-160-EX','850-161-EX','850-162-EX','850-163-EX','850-164-EX','850-165-EX','850-166-EX','850-167-EX','850-052-EX')
	JOIN		
		HealthyStore.dbo.HS_Product p (nolock) 
		on 
			po.ProductID = p.ProductID
	JOIN		
		(
			SELECT		
				pc.ProductID,
				'ProductCategories' = 
					ISNULL(temp.ufn_All_Product_Categories(pc.ProductID),'')
			FROM		
				Healthystore.dbo.HS_ProductCategory pc (nolock)
			JOIN		
				Healthystore.dbo.HS_Category c (nolock)
				on	
					pc.CategoryID = c.CategoryID
			JOIN		
				Healthystore.dbo.HS_Store s (nolock)
				on	
					c.StoreID = s.StoreID
			WHERE		
				s.[Name] LIKE 'HMS%'
			and			
				LTRIM(RTRIM(c.CategoryName)) <> 'Kits'
			and			
				LTRIM(RTRIM(c.CategoryName)) <> 'Rewards'
			and			
				LTRIM(RTRIM(c.CategoryName)) <> 'Discount Cards'
			GROUP BY	
				pc.ProductID
		) pc 
			on	p.ProductID = pc.ProductID
	JOIN		
		HealthyStore.dbo.HS_Customer cu (nolock) 
		on 
			o.CustomerID = cu.CustomerID
	LEFT JOIN	
		Benefits.dbo.Member m (nolock) 
		on	
			cu.SiteMemberID = m.MemberID 
		and	
			m.Deleted = 0
	LEFT JOIN	
		Benefits.dbo.[Group] g (nolock) 
		on	
			m.GroupID = g.GroupID
		and	
			g.Deleted = 0
	LEFT JOIN	
		Benefits.dbo.HealthPlanAffiliate hpa (nolock) 
		on 
			g.HealthPlanAffiliateID = hpa.HealthPlanAffiliateID
	LEFT JOIN	
		Benefits.dbo.HealthPlan hp (nolock) 
		on 
			hpa.HealthPlanID = hp.HealthPlanID
	LEFT JOIN	
		temp.[UT_Orders_Product_Lookup] ut (nolock) 
		on 
			po.SKU = ut.ProductSKU  -- Lookup table provided by Todd's team, Stored in HRLDW database temporarily
	WHERE			
		o.CreateDate > @dtBeginDate
	and			
		o.CreateDate <= @dtEndDate
	and			
		o.OrderStatusID <> 6
	ORDER BY	
		CASE WHEN ISNULL(po.SKU,'') LIKE '705%' THEN 0 ELSE 1 END
		,ISNULL(po.SKU,'')
		,pc.ProductCategories
		,o.OrderID

	
END
GO
