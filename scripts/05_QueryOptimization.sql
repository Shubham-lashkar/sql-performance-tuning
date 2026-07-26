/*
================================================================================
 File        : 05_QueryOptimization.sql
 Purpose     : Common anti-patterns paired with their optimized rewrite —
               each pair is directly comparable via execution plan / IO stats.
 Author      : Shubham Lashkar
================================================================================
*/

USE OrderManagementDB;
GO
SET STATISTICS IO ON;

-- ============================================================================
-- 1) SARGability: function-wrapped column kills index usage
-- ============================================================================
-- BAD: YEAR(OrderDate) forces a scan — index on OrderDate cannot be seeked
SELECT COUNT(*) FROM dbo.Orders WHERE YEAR(OrderDate) = 2026;

-- GOOD: range predicate stays SARGable
SELECT COUNT(*) FROM dbo.Orders
WHERE OrderDate >= '2026-01-01' AND OrderDate < '2027-01-01';
GO

-- ============================================================================
-- 2) Leading wildcard LIKE defeats index seeks
-- ============================================================================
-- BAD
SELECT CustomerID, FirstName, LastName FROM dbo.Customers
WHERE LastName LIKE '%son';

-- GOOD (if the business requirement allows prefix search)
SELECT CustomerID, FirstName, LastName FROM dbo.Customers
WHERE LastName LIKE 'John%';
-- For true substring search at scale, use Full-Text Search instead of LIKE '%x%'
GO

-- ============================================================================
-- 3) SELECT * vs explicit columns (I/O + covering index eligibility)
-- ============================================================================
-- BAD: pulls all columns, prevents narrow covering indexes from helping
SELECT * FROM dbo.Orders WHERE CustomerID = 4521;

-- GOOD
SELECT OrderID, OrderDate, OrderStatus, TotalAmount
FROM dbo.Orders WHERE CustomerID = 4521;
GO

-- ============================================================================
-- 4) NOT IN / NOT EXISTS with NULLs, and correlated subquery cost
-- ============================================================================
-- BAD: NOT IN silently returns zero rows if the subquery has any NULL
SELECT CustomerID, FirstName FROM dbo.Customers c
WHERE c.CustomerID NOT IN (SELECT CustomerID FROM dbo.Orders);

-- GOOD: NOT EXISTS is NULL-safe and typically optimizes better
SELECT c.CustomerID, c.FirstName FROM dbo.Customers c
WHERE NOT EXISTS (SELECT 1 FROM dbo.Orders o WHERE o.CustomerID = c.CustomerID);
GO

-- ============================================================================
-- 5) Implicit conversion — mismatched data types silently disable index seeks
-- ============================================================================
-- BAD: Email is NVARCHAR, comparing against a VARCHAR literal can force a scan
--      in mixed-collation or implicit-conversion scenarios
SELECT CustomerID FROM dbo.Customers WHERE Email = CAST('customer100@example.com' AS VARCHAR(100));

-- GOOD: match the column's native type
SELECT CustomerID FROM dbo.Customers WHERE Email = N'customer100@example.com';
GO

-- ============================================================================
-- 6) Avoid row-by-row processing (cursor) for set-based work
-- ============================================================================
-- BAD (illustrative — do not run against 500K rows without intent):
/*
DECLARE @OrderID INT;
DECLARE cur CURSOR FOR SELECT OrderID FROM dbo.Orders WHERE OrderStatus = 'Pending';
OPEN cur;
FETCH NEXT FROM cur INTO @OrderID;
WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE dbo.Orders SET OrderStatus = 'Shipped' WHERE OrderID = @OrderID;
    FETCH NEXT FROM cur INTO @OrderID;
END
CLOSE cur; DEALLOCATE cur;
*/

-- GOOD: set-based, single UPDATE, one plan, minimal log churn
-- UPDATE dbo.Orders SET OrderStatus = 'Shipped' WHERE OrderStatus = 'Pending';
GO

-- ============================================================================
-- 7) JOIN vs correlated subquery for aggregation
-- ============================================================================
-- BAD: correlated subquery re-executes per row of Customers
SELECT c.CustomerID, c.FirstName,
       (SELECT SUM(o.TotalAmount) FROM dbo.Orders o WHERE o.CustomerID = c.CustomerID) AS LifetimeValue
FROM dbo.Customers c;

-- GOOD: single-pass aggregation join
SELECT c.CustomerID, c.FirstName, SUM(o.TotalAmount) AS LifetimeValue
FROM dbo.Customers c
LEFT JOIN dbo.Orders o ON o.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.FirstName;
GO

-- ============================================================================
-- 8) Pagination: OFFSET/FETCH cost grows with page depth — keyset pagination
--    is the scalable pattern for deep pages
-- ============================================================================
-- OK for shallow pages, degrades on deep pages (must scan+discard all prior rows)
SELECT OrderID, OrderDate, TotalAmount
FROM dbo.Orders
ORDER BY OrderDate DESC
OFFSET 50000 ROWS FETCH NEXT 50 ROWS ONLY;

-- BETTER at scale: keyset (seek) pagination using the last seen OrderDate/OrderID
-- SELECT TOP (50) OrderID, OrderDate, TotalAmount
-- FROM dbo.Orders
-- WHERE OrderDate < @LastSeenOrderDate
--    OR (OrderDate = @LastSeenOrderDate AND OrderID < @LastSeenOrderID)
-- ORDER BY OrderDate DESC, OrderID DESC;
GO

SET STATISTICS IO OFF;
GO
