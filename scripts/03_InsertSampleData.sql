/*
================================================================================
 File        : 03_InsertSampleData.sql
 Purpose     : Generate realistic volume data so that indexing/optimization
               problems actually manifest (small tables never show real
               performance issues). Produces:
                 - 50 Categories
                 - 5,000 Products
                 - 100,000 Customers
                 - 500,000 Orders
                 - ~1,500,000 OrderDetails
 Author      : Shubham Lashkar
 Note        : Uses set-based generation (no cursors/loops) for speed.
================================================================================
*/

USE OrderManagementDB;
GO

SET NOCOUNT ON;

-- ============================================================================
-- Categories
-- ============================================================================
INSERT INTO dbo.Categories (CategoryName, ParentCategoryID)
VALUES
('Electronics', NULL), ('Mobiles', 1), ('Laptops', 1), ('Accessories', 1),
('Home & Kitchen', NULL), ('Furniture', 5), ('Appliances', 5),
('Fashion', NULL), ('Men', 8), ('Women', 8), ('Kids', 8),
('Books', NULL), ('Fiction', 12), ('Non-Fiction', 12),
('Sports', NULL), ('Fitness Equipment', 15), ('Outdoor', 15);
GO

-- ============================================================================
-- Products (5,000 rows) — using a numbers/tally table for set-based generation
-- ============================================================================
;WITH Tally AS
(
    SELECT TOP (5000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Products (ProductName, CategoryID, UnitPrice, StockQuantity, IsDiscontinued)
SELECT
    'Product-' + CAST(n AS VARCHAR(10)),
    (n % 17) + 1,
    CAST(((n * 37) % 50000) + 100 AS DECIMAL(10,2)) / 100,
    (n * 13) % 500,
    CASE WHEN n % 47 = 0 THEN 1 ELSE 0 END
FROM Tally;
GO

-- ============================================================================
-- Customers (100,000 rows)
-- ============================================================================
;WITH Tally AS
(
    SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Customers (FirstName, LastName, Email, Phone, City, State, CreatedDate)
SELECT
    'FirstName' + CAST(n AS VARCHAR(10)),
    'LastName' + CAST(n AS VARCHAR(10)),
    'customer' + CAST(n AS VARCHAR(10)) + '@example.com',
    '9' + RIGHT('000000000' + CAST(n AS VARCHAR(10)), 9),
    CASE (n % 6)
        WHEN 0 THEN 'Mumbai' WHEN 1 THEN 'Pune' WHEN 2 THEN 'Thane'
        WHEN 3 THEN 'Navi Mumbai' WHEN 4 THEN 'Nashik' ELSE 'Nagpur'
    END,
    'Maharashtra',
    DATEADD(DAY, -(n % 1500), SYSUTCDATETIME())
FROM Tally;
GO

-- ============================================================================
-- Orders (500,000 rows) — skewed date distribution (recent dates more common)
-- to mimic real-world query patterns ("last 30 days" reporting)
-- ============================================================================
;WITH Tally AS
(
    SELECT TOP (500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c
)
INSERT INTO dbo.Orders (CustomerID, OrderDate, OrderStatus, ShippingCity, TotalAmount)
SELECT
    ((n * 7) % 100000) + 1,
    DATEADD(MINUTE, -(n % 700000), SYSUTCDATETIME()),
    CASE (n % 10)
        WHEN 0 THEN 'Cancelled' WHEN 1 THEN 'Pending'
        WHEN 2 THEN 'Shipped' ELSE 'Delivered'
    END,
    CASE (n % 6)
        WHEN 0 THEN 'Mumbai' WHEN 1 THEN 'Pune' WHEN 2 THEN 'Thane'
        WHEN 3 THEN 'Navi Mumbai' WHEN 4 THEN 'Nashik' ELSE 'Nagpur'
    END,
    0  -- TotalAmount computed after OrderDetails are inserted
FROM Tally;
GO

-- ============================================================================
-- OrderDetails (~1.5M rows, 2-4 lines per order)
-- ============================================================================
;WITH Tally AS
(
    SELECT TOP (1500000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b CROSS JOIN sys.all_objects c
)
INSERT INTO dbo.OrderDetails (OrderID, ProductID, Quantity, UnitPrice, Discount)
SELECT
    ((n * 3) % 500000) + 1,
    ((n * 11) % 5000) + 1,
    (n % 5) + 1,
    CAST(((n * 23) % 50000) + 100 AS DECIMAL(10,2)) / 100,
    CASE WHEN n % 20 = 0 THEN 0.10 ELSE 0 END
FROM Tally;
GO

-- ============================================================================
-- Backfill Orders.TotalAmount from OrderDetails (also doubles as a
-- "why batch updates matter" example for 04/05 scripts)
-- ============================================================================
;WITH OrderTotals AS
(
    SELECT OrderID, SUM(Quantity * UnitPrice * (1 - Discount)) AS ComputedTotal
    FROM dbo.OrderDetails
    GROUP BY OrderID
)
UPDATE o
SET o.TotalAmount = ot.ComputedTotal
FROM dbo.Orders o
INNER JOIN OrderTotals ot ON ot.OrderID = o.OrderID;
GO

PRINT 'Sample data generated: Categories, Products, Customers, Orders, OrderDetails.';
GO
