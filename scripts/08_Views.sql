/*
================================================================================
 File        : 08_Views.sql
 Purpose     : Standard and indexed (materialized) views for reporting
               workloads, with guidance on when each is appropriate.
 Author      : Shubham Lashkar
================================================================================
*/

USE OrderManagementDB;
GO

-- ============================================================================
-- 1) vw_CustomerOrderSummary — standard view (logic reuse, no storage cost)
-- ============================================================================
CREATE OR ALTER VIEW dbo.vw_CustomerOrderSummary
AS
SELECT
    c.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    c.City,
    COUNT(o.OrderID)               AS TotalOrders,
    SUM(o.TotalAmount)             AS LifetimeValue,
    MAX(o.OrderDate)               AS LastOrderDate
FROM dbo.Customers c
LEFT JOIN dbo.Orders o ON o.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName, c.City;
GO

-- ============================================================================
-- 2) vw_DailySalesSummary — INDEXED (materialized) view.
--    Use when: read-heavy reporting workload, underlying data changes
--    relatively infrequently, and query needs to avoid re-aggregating
--    millions of rows on every execution.
--    Requirements: WITH SCHEMABINDING, deterministic aggregates only,
--    COUNT_BIG() required alongside SUM for indexed views.
-- ============================================================================
CREATE OR ALTER VIEW dbo.vw_DailySalesSummary
WITH SCHEMABINDING
AS
SELECT
    CAST(o.OrderDate AS DATE) AS SalesDate,
    o.OrderStatus,
    SUM(o.TotalAmount)        AS TotalSales,
    COUNT_BIG(*)               AS OrderCount
FROM dbo.Orders o
GROUP BY CAST(o.OrderDate AS DATE), o.OrderStatus;
GO

-- The unique clustered index is what actually materializes the view on disk
CREATE UNIQUE CLUSTERED INDEX IX_vw_DailySalesSummary
ON dbo.vw_DailySalesSummary (SalesDate, OrderStatus);
GO
-- Trade-off: every INSERT/UPDATE/DELETE on Orders now also maintains this
-- index. Worth it only when read volume on this aggregate far exceeds
-- write volume on Orders — a classic OLTP-vs-reporting tuning decision.

-- ============================================================================
-- 3) vw_TopSellingProducts — reporting view with window functions
-- ============================================================================
CREATE OR ALTER VIEW dbo.vw_TopSellingProducts
AS
SELECT
    p.ProductID,
    p.ProductName,
    p.CategoryID,
    SUM(od.Quantity)                                     AS UnitsSold,
    SUM(od.Quantity * od.UnitPrice * (1 - od.Discount))   AS Revenue,
    RANK() OVER (PARTITION BY p.CategoryID ORDER BY SUM(od.Quantity) DESC) AS RankInCategory
FROM dbo.Products p
INNER JOIN dbo.OrderDetails od ON od.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName, p.CategoryID;
GO
