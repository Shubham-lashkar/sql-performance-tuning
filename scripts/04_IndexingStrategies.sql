/*
================================================================================
 File        : 04_IndexingStrategies.sql
 Purpose     : Demonstrates clustered vs non-clustered, covering, filtered,
               and composite index strategies with measurable before/after
               impact using STATISTICS IO / TIME.
 Author      : Shubham Lashkar
================================================================================
*/

USE OrderManagementDB;
GO

-- ============================================================================
-- 1) BASELINE — measure cost WITHOUT a supporting index
-- ============================================================================
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Common lookup pattern: recent orders for a customer
SELECT OrderID, OrderDate, OrderStatus, TotalAmount
FROM dbo.Orders
WHERE CustomerID = 4521
ORDER BY OrderDate DESC;
-- Expect: Clustered Index Scan on Orders, high logical reads on large table
GO

-- ============================================================================
-- 2) NON-CLUSTERED INDEX on the filter column
-- ============================================================================
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID
ON dbo.Orders (CustomerID);
GO

SELECT OrderID, OrderDate, OrderStatus, TotalAmount
FROM dbo.Orders
WHERE CustomerID = 4521
ORDER BY OrderDate DESC;
-- Better: Index Seek, but still a Key Lookup for OrderDate/OrderStatus/TotalAmount
GO

-- ============================================================================
-- 3) COVERING INDEX — eliminate the Key Lookup entirely
-- ============================================================================
DROP INDEX IX_Orders_CustomerID ON dbo.Orders;
GO

CREATE NONCLUSTERED INDEX IX_Orders_CustomerID_Covering
ON dbo.Orders (CustomerID, OrderDate DESC)
INCLUDE (OrderStatus, TotalAmount);
GO

SELECT OrderID, OrderDate, OrderStatus, TotalAmount
FROM dbo.Orders
WHERE CustomerID = 4521
ORDER BY OrderDate DESC;
-- Best: pure Index Seek, no Key Lookup, no Sort (index already ordered)
GO

-- ============================================================================
-- 4) FILTERED INDEX — for a highly selective, frequently-queried subset
--    (only ~10% of orders are 'Pending', but this is the most-queried status
--    on the ops dashboard)
-- ============================================================================
CREATE NONCLUSTERED INDEX IX_Orders_Pending
ON dbo.Orders (OrderDate)
INCLUDE (CustomerID, TotalAmount)
WHERE OrderStatus = 'Pending';
GO

SELECT OrderID, CustomerID, OrderDate, TotalAmount
FROM dbo.Orders
WHERE OrderStatus = 'Pending'
  AND OrderDate >= DATEADD(DAY, -7, SYSUTCDATETIME());
-- Filtered index is smaller than a full index -> less I/O, faster seeks
GO

-- ============================================================================
-- 5) COMPOSITE INDEX COLUMN ORDER MATTERS
--    Wrong order (Discount first) makes the index useless for ProductID-only lookups
-- ============================================================================
-- Bad: leading column rarely used alone
-- CREATE INDEX IX_Bad ON dbo.OrderDetails (Discount, ProductID);

-- Good: most selective / most-filtered column first
CREATE NONCLUSTERED INDEX IX_OrderDetails_ProductID_OrderID
ON dbo.OrderDetails (ProductID, OrderID)
INCLUDE (Quantity, UnitPrice);
GO

-- ============================================================================
-- 6) Find missing index suggestions from the SQL Server engine itself
-- ============================================================================
SELECT
    mid.statement                                  AS TableName,
    migs.avg_user_impact,
    migs.user_seeks + migs.user_scans              AS TimesUsedIfCreated,
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id) + '_Missing ON '
        + mid.statement
        + ' (' + ISNULL(mid.equality_columns,'')
        + CASE WHEN mid.inequality_columns IS NOT NULL THEN ',' + mid.inequality_columns ELSE '' END + ')'
        + ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS CreateIndexStatement
FROM sys.dm_db_missing_index_details mid
INNER JOIN sys.dm_db_missing_index_groups mig ON mig.index_handle = mid.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
ORDER BY migs.avg_user_impact DESC;
GO

-- ============================================================================
-- 7) Find UNUSED indexes (maintenance overhead with zero read benefit)
-- ============================================================================
SELECT
    OBJECT_NAME(s.object_id)   AS TableName,
    i.name                     AS IndexName,
    s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.dm_db_index_usage_stats s
INNER JOIN sys.indexes i ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE OBJECTPROPERTY(s.object_id,'IsUserTable') = 1
  AND s.user_seeks = 0 AND s.user_scans = 0 AND s.user_lookups = 0
  AND s.user_updates > 0
ORDER BY s.user_updates DESC;
GO

-- ============================================================================
-- 8) Index fragmentation check + rebuild/reorganize decision logic
-- ============================================================================
SELECT
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name                     AS IndexName,
    ips.avg_fragmentation_in_percent,
    ips.page_count,
    CASE
        WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
        WHEN ips.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN 'REORGANIZE'
        ELSE 'OK'
    END AS RecommendedAction
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE ips.page_count > 100
ORDER BY ips.avg_fragmentation_in_percent DESC;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO
