/*
================================================================================
 File        : 09_Functions.sql
 Purpose     : Scalar vs inline table-valued functions — with a working
               demonstration of why scalar UDFs hurt performance at scale
               and how to fix it.
 Author      : Shubham Lashkar
================================================================================
*/

USE OrderManagementDB;
GO

-- ============================================================================
-- 1) ANTI-PATTERN: Scalar UDF called per-row (row-by-row execution — RBAR)
--    Prior to SQL Server 2019's scalar UDF inlining, this runs once PER ROW
--    and cannot be parallelized. Even with inlining, simple cases are better
--    written as inline TVFs or computed inline.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_GetOrderDiscountAmount_Scalar (@OrderID INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @DiscountAmount DECIMAL(12,2);

    SELECT @DiscountAmount = SUM(Quantity * UnitPrice * Discount)
    FROM dbo.OrderDetails
    WHERE OrderID = @OrderID;

    RETURN ISNULL(@DiscountAmount, 0);
END
GO

-- Usage that becomes an RBAR performance problem across many rows:
-- SELECT OrderID, dbo.fn_GetOrderDiscountAmount_Scalar(OrderID) FROM dbo.Orders;

-- ============================================================================
-- 2) BETTER: Inline Table-Valued Function (ITVF) — optimizer expands this
--    like a parameterized view / joins normally, no per-row execution
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_GetOrderDiscountAmount_ITVF (@OrderID INT)
RETURNS TABLE
AS
RETURN
(
    SELECT SUM(Quantity * UnitPrice * Discount) AS DiscountAmount
    FROM dbo.OrderDetails
    WHERE OrderID = @OrderID
);
GO

-- Usage — behaves like a join, fully optimizable:
-- SELECT o.OrderID, d.DiscountAmount
-- FROM dbo.Orders o
-- CROSS APPLY dbo.fn_GetOrderDiscountAmount_ITVF(o.OrderID) d;

-- ============================================================================
-- 3) BEST for set-based reporting: skip the function entirely, aggregate
--    directly (fastest option when logic doesn't need to be reused elsewhere)
-- ============================================================================
-- SELECT o.OrderID, SUM(od.Quantity * od.UnitPrice * od.Discount) AS DiscountAmount
-- FROM dbo.Orders o
-- INNER JOIN dbo.OrderDetails od ON od.OrderID = o.OrderID
-- GROUP BY o.OrderID;

-- ============================================================================
-- 4) Multi-statement TVF (MSTVF) — use sparingly; the optimizer estimates a
--    fixed row count for these (historically 1 or 100 depending on version),
--    which can cause bad plan choices in joins. Prefer ITVF where possible.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_GetActiveCustomersByCity (@City NVARCHAR(50))
RETURNS @Result TABLE
(
    CustomerID INT,
    CustomerName NVARCHAR(101)
)
AS
BEGIN
    INSERT INTO @Result
    SELECT CustomerID, FirstName + ' ' + LastName
    FROM dbo.Customers
    WHERE City = @City AND IsActive = 1;

    RETURN;
END
GO
