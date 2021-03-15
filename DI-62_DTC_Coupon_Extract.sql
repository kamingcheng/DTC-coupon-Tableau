/* Clean up data import for Coupon group */
/* This is read from "G:\My Drive\SQL\Coupons\CouponGroups.csv" -- Ka Ming Cheng obtained this lookup from Alexander Schoep.  */
Drop Table if Exists #CouponGroups
SELECT 
CouponGroup
,case when couponDescription = '"Customer care, Playba"' then 'Customer care, Playba'
	  when couponDescription = 	'"Customer issue, speak"' then 'Customer issue, speak'
	  else couponDescription end as couponDescription
into #CouponGroups
from Reporting_Scratch.dbo.CouponGroups

--SELECT * from Reporting_Scratch.dbo.CouponGroups order by CouponGroup, couponDescription
/* Extract records from Sales Invoiced Line Item (SLIC) */
IF OBJECT_ID('tempdb..#SLIC_temp1') is not null
drop table #SLIC_temp1

DECLARE @THISWEEK int
SET @THISWEEK = (select fiscalweekid from dwm.reporting.vw_dim_date where istoday = 1)

DECLARE @StartYear int
Set @StartYear = (SELECT distinct fiscalyearId from DWM.reporting.DimDate with (nolock) where DayID = (SELECT DateFromParts(Year(GetDate())-2,Month(GetDate()),Day(GetDate()))))   -- 2 fiscal years prior.  For example, if current FY is 2021, then this statement will start the clco in FY 2019.

select
(CASE WHEN s.DocumentType = 4 THEN L.[lineTotal] * cr.averageRate * -1 ELSE L.[lineTotal] * cr.averageRate END) as 'SpotUSD'
,l.lineTotal
,l.quantityInvoice
,l.shipQuantity
,l.quantity
,l.quantityAllocated
,l.unitPrice
,l.originatingUnitPrice
,l.originatingCost
,l.originatingExtendedCost
,l.originatingDiscountAmount
,l.originatingTotalTrdDisc
,l.markdownAmount
,l.markdownIndx
,cr.averageRate
,s.DocumentType
,s.orderNumber
, d_doc.FiscalYearDesc 
, d_doc.FiscalYearID
, d_doc.FiscalQuarterDesc 
, d_doc.FiscalQuarterID
, d_doc.FiscalQuarterShortDesc
, d_doc.FiscalMonthDesc 
, d_doc.FiscalMonthID
, d_doc.FiscalMonthShortDesc
, d_doc.FiscalWeekDesc 
, d_doc.FiscalWeekID
, d_doc.FiscalWeekShortDesc
, d_doc.FiscalWeekNumber 
, d.distributorArea Area
, d.distributorRegion Region
, d.distributorSubRegion SubRegion
, d.distributorChannelName Channel
, d.distributorSubChannelName SubChannel
, sic.couponCode 
, sic.couponDescription
, l.salesIndex 
, l.costOfSalesIndex
, gla.AccountNumber as cost_accountNumber
, gla1.accountNumber as rev_accountNumber
, gla1.segment1, gla1.Segment2, gla1.Segment3
, gla2.accountNumber as rev_accountNumber1, gla2.segment1 as segment1_markdown, gla2.segment2 as segment2_markdown, gla2.segment3 as segment3_markdown
, dps.ProductCategoryGroupName, dps.ProductCategoryName, dps.ProductGroupName, dps.ProductName
into #SLIC_temp1
from dwm.[reporting].[Fact_SalesInvoice] s with(nolock)
left join dwm.reporting.Dim_Dealer DD with(nolock) on DD.dimDealerKey=s.dimDealerKey
left join dwm.[reporting].[Fact_SalesInvoiceLineItem] l  with(nolock) on s.factSalesINvoiceKey = l.factSalesINvoiceKey
LEFT JOIN dwm.[reporting].[Dim_GeoChannel] d with (nolock)  on d.[DimgeochanneldimdealerKey] = s.[dimDealerKey]
left join dwm.[reporting].[Dim_Book] b with (nolock) on l.sourcecode=b.dbname
left join dwm.[reporting].[DimDate] d_doc with (nolock) on s.docDimDatekey = d_doc.dimdatekey
left join dwm.[reporting].[Dim_GLAccount] GLA with (nolock) on l.costOfSalesIndex=GLA.ACTINDX and b.DBname = GLA.DBname
left join dwm.[reporting].[Dim_GLAccount] GLA1 with (nolock) on l.salesIndex=GLA1.ACTINDX and b.DBname = GLA1.DBname
left join dwm.[reporting].[Dim_CurrencyRate] cr with (nolock) on b.bookcurrencyId=cr.currencyId and d_doc.fiscalmonthid=cr.fiscalMonthID
left join dwm.[reporting].[Dim_GLAccount] GLA2 with (nolock) on l.markdownIndx = gla2.actindx and b.DBname = gla2.dbname
left join dwm.[reporting].[Dim_ProductSKU] as DPS with (nolock) on isnull(l.productBundleID, 0)=DPS.productBundleId  and isnull(l.productItemId, 0)=DPS.ProductItemId
left join DWM.reporting.REL_Salesinvoicecoupon sic with (nolock) on l.factSalesInvoiceKey = sic.factSalesInvoiceKey
WHERE d.DistributorChannelname != 'Z-Intercompany'
and d.distributorSubChannelName <> 'Internal'
--and (d.distributorArea IN ('AMERICAS', 'APAC', 'EMEA') or d.distributorArea is NULL)  -- Null added on 2/26/2021
--and dps.ProductCategoryGroupName IN ('AUDIO HW', 'ACCESSORY','MODULES', 'THIRD PARTY', 'BUNDLE', 'COUPON')
/*and 
(
	(s.documentType in (3,4) and s.pstgstus <> 0) -- 5492                                                                                                                                                                                                                                                                                                                                                                                                                       
		or
	(s.documentType = 6    and s.shipmentDimDateKey != -1 and 
		(
		(dd.dealerNumber in ('ELKJO100', 'JOHNL100', 'AMAZO200 ', '') and dd.sourceDB='GPNL' ) or 
		(dd.dealerNumber in ('AMAZO110', 'AMAZO120', 'COSTC100', 'COSTC200') and dd.sourceDB='SBM01' ) 
		)
	)
) 
*/
and s.documentType in (3,4) and s.pstgstus <> 0
and l.componentSequenceNumber = 0
and s.isVoided= 0
/*
and (--Sell In RevCategory)
		GLA.[AccountNumber] LIKE '5200-000-%'
		OR GLA.[AccountNumber] LIKE '5100-000-%'
		OR GLA.[AccountNumber]  like '5400-000-%'
		OR GLA.[AccountNumber]  like '5905-000-%'
	)
and (--Revenue
		GLA1.[AccountNumber] LIKE '4200-000-%'
		OR GLA1.[AccountNumber] LIKE '4400-000-%'
		OR GLA1.[AccountNumber] LIKE '4905-000-%'
		OR GLA1.[AccountNumber] LIKE '4240-000-%'
	)
*/
--and s.DocumentType <> '6'
and d_doc.FiscalYearID >= @StartYear			
and d_doc.FiscalWeekID  <= @THISWEEK ---- Change < to <= to include current week -- 2020-10-29

DROP TABLE IF EXISTS #SLIC_temp2
SELECT 
slic.*
,case when markdownAmount = 0 or markdownAmount is NULL then segment1 else segment1_markdown end as Account
,cg.CouponGroup
into #SLIC_temp2
from #SLIC_Temp1 as slic
left join #CouponGroups as cg on slic.couponDescription = cg.couponDescription
where
	(--Sell In RevCategory)
		cost_AccountNumber LIKE '5200-000-%'
		OR cost_AccountNumber LIKE '5100-000-%'
		OR cost_AccountNumber  like '5400-000-%'
		OR cost_AccountNumber  like '5905-000-%'
	)
and (--Revenue
		rev_accountNumber LIKE '4200-000-%'
		OR rev_accountNumber LIKE '4400-000-%'
		OR rev_accountNumber LIKE '4905-000-%'
		OR rev_accountNumber LIKE '4240-000-%'
	)
and ProductCategoryGroupName IN ('AUDIO HW', 'ACCESSORY','MODULES', 'THIRD PARTY', 'BUNDLE', 'COUPON')

/* Determine whether a coupon discount is applied to an order */
DROP TABLE IF EXISTS #order_discount_status
SELECT
orderNumber
,case when MarkdownAmount = 0 or MarkdownAmount is Null then 'No discount' else 'Coupon discount' end as discount_status
into #order_discount_status
from 
	(
	SELECT
	OrderNumber
	,sum(markdownAmount) as MarkdownAmount
	from #SLIC_temp2
	group by OrderNumber
	)a

/* Apply coupon discount status back to SLIC */
DROP TABLE IF EXISTS #SLIC
SELECT
slic.*
,ods.discount_status
into #SLIC
from #SLIC_temp2 as slic
left join #order_discount_status as ods on slic.orderNumber = ods.orderNumber




/* Testing Area *****************************/
SELECT count(1) from #SLIC where channel = 'direct'

SELECT
discount_status
,count(distinct OrderNumber)
from #SLIC
where Channel = 'Direct'
and FiscalQuarterID = 202101
group by rollup(discount_status)



DROP TABLE IF EXISTS #order_discount_status
SELECT
orderNumber
,case when MarkdownAmount = 0 or MarkdownAmount is Null then 'No discount' else 'with discount' end as discount_status
into #order_discount_status
from 
	(
	SELECT
	OrderNumber
	,sum(markdownAmount) as MarkdownAmount
	from #SLIC
	group by OrderNumber
	)a





SELECT distinct
CouponGroup
,couponDescription
from #SLIC
order by CouponGroup, couponDescription

SELECT
discount_status
,count(1) as order_count
from
(
SELECT
orderNumber
,case when MarkdownAmount = 0 or MarkdownAmount is Null then 'No discount' else 'with discont' end as discount_status
from 
	(
	SELECT
	OrderNumber
	,sum(markdownAmount) as MarkdownAmount
	from #SLIC
	where Channel = 'Direct'
	and FiscalQuarterID = 202101
	group by OrderNumber
	)a
)b
group by rollup(discount_status)

SELECT
Account
,CASE WHEN couponCode is not null then 'Has Coupon' else 'No coupon' end as Coupon
,sum(quantityInvoice*averageRate*markdownAmount) as markdownAmount_Invoice
,sum(SpotUSd) as SpotUSD
from #SLIC
where FiscalMonthID in (202101,202102,202103)
group by 
Account
,CASE WHEN couponCode is not null then 'Has Coupon' else 'No coupon' end 
order by 
Account
,CASE WHEN couponCode is not null then 'Has Coupon' else 'No coupon' end 

SELECT
Account
,CASE WHEN couponDescription is not null then 'Has Coupon' else 'No coupon' end as Coupon
,sum(quantityInvoice*averageRate*markdownAmount) as markdownAmount_Invoice
,sum(SpotUSd) as SpotUSD
from #SLIC
where FiscalMonthID in (202101,202102,202103)
group by 
Account
,CASE WHEN couponDescription is not null then 'Has Coupon' else 'No coupon' end 
order by 
Account
,CASE WHEN couponDescription is not null then 'Has Coupon' else 'No coupon' end 

SELECT
Account
,CASE WHEN couponDescription is not null then 'Has Coupon' else 'No coupon' end as Coupon
,CASE WHEN Channel = 'Direct' then 'Direct' else 'Non-Direct' end as DTC
,sum(quantityInvoice*averageRate*markdownAmount) as markdownAmount_Invoice
,sum(SpotUSd) as SpotUSD
from #SLIC
where FiscalMonthID in (202101,202102,202103)
and Account = 4240
group by 
Account
,CASE WHEN couponDescription is not null then 'Has Coupon' else 'No coupon' end 
,CASE WHEN Channel = 'Direct' then 'Direct' else 'Non-Direct' end
order by 
Account
,CASE WHEN couponDescription is not null then 'Has Coupon' else 'No coupon' end 
,CASE WHEN Channel = 'Direct' then 'Direct' else 'Non-Direct' end

SELECT 
sum(SpotUSD)
from #SLIC
where Channel = 'Direct'
and FiscalQuarterID = 202101
and couponcode = 'EE50-XL4DT24CT6'

SELECT *
from #SLIC where couponCode = 'EE50-XL4DT24CT6'

SELECT
rev_accountNumber1
,sum(quantityInvoice*averageRate*markdownAmount) as markdownAmount_Invoice
,sum(quantityAllocated*averageRate*markdownAmount) as markdownAmount_Allocated
,sum(SpotUSD) as spotUSD
from #SLIC
where FiscalMonthID in (202101,202102,202103)
and channel = 'Direct'
group by rev_accountNumber1 with rollup
order by rev_accountNumber1


SELECT
segment1
,sum(quantityInvoice*averageRate*markdownAmount) as markdownAmount_Invoice
,sum(quantityAllocated*averageRate*markdownAmount) as markdownAmount_Allocated
,sum(SpotUSD) as spotUSD
from #SLIC
where FiscalMonthID in (202101,202102,202103)
--and channel = 'Direct'
group by segment1 with rollup
order by segment1

SELECT top 1000* from #SLIC
SELECT rev_accountNumber1, count(1) from #SLIC group by rev_accountNumber1

SELECT
Account
,sum(quantityInvoice*averageRate*markdownAmount) as markdownAmount_Invoice
,sum(quantityAllocated*averageRate*markdownAmount) as markdownAmount_Allocated
,sum(SpotUSD) as spotUSD
from #SLIC
where FiscalMonthID in (202101,202102,202103)
--and channel = 'Direct'
group by Account with rollup

SELECT
Account, Channel
,sum(quantityInvoice*averageRate*markdownAmount) as markdownAmount_Invoice
,sum(quantityAllocated*averageRate*markdownAmount) as markdownAmount_Allocated
,sum(SpotUSD) as spotUSD
from #SLIC
where FiscalMonthID in (202101,202102,202103)
--and channel = 'Direct'
group by Account, Channel
order by Account, Channel

Select
couponDescription
,count(1)
,sum(markdownAmount) as markdownAmount
,sum(SpotUSD) as SpotUSD
from #SLIC
where Channel = 'Direct'
and couponDescription is not null
group by couponDescription
order by couponDescription 

-- Drop table Reporting_Scratch.dbo.CouponGroups
SELECT * from Reporting_Scratch.dbo.CouponGroups   -- This is read from "G:\My Drive\SQL\Coupons\CouponGroups.csv" -- Ka Ming Cheng obtained this lookup from Alexander Schoep

select count(distinct concat(couponDescription, coupongroup)), count(1) from Reporting_Scratch.dbo.CouponGroups   
select distinct couponDescription, coupongroup from Reporting_Scratch.dbo.CouponGroups


Select
CouponGroup
,sum(markdownAmount) as markdownAmount
,sum(SpotUSD) as SpotUSD
from #SLIC
where 1=1
and Channel = 'Direct'
and FiscalMonthID in (202101,202102, 202103)
group by rollup(CouponGroup) 
order by CouponGroup

Select
sum(markdownAmount) as markdownAmount
,sum(SpotUSD) as SpotUSD
from #SLIC
where FiscalMonthID in (202101,202102, 202103)

SELECT top 100
*
from DWM.ssas.vw_Fact_AcctTrx