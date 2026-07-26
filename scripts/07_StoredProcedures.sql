/*
================================================================================
 File        : 07_StoredProcedures.sql
 Purpose     : Tuned stored procedures demonstrating parameter sniffing
               mitigation, batching, and proper error handling.
 Author      : Shubham Lashkar
================================================================================
*/

USE OrderManagementDB;
GO

-- ============================================================================
-- 1) usp_GetCustomerOrders — pairs with the covering index from 04
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetCustomerOrders
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderID, OrderDate, OrderStatus, TotalAmount
    FROM dbo.Orders
    WHERE CustomerID = @CustomerID
    ORDER BY OrderDate DESC;
END
GO

-- ============================================================================
-- 2) usp_GetOrdersByDateRange — demonstrates parameter sniffing mitigation
--    via OPTION (RECOMPILE) for a proc whose row count varies wildly by input
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_GetOrdersByDateRange
    @StartDate DATETIME2,
    @EndDate   DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderID, CustomerID, OrderDate, OrderStatus, TotalAmount
    FROM dbo.Orders
    WHERE OrderDate >= @StartDate AND OrderDate < @EndDate
    OPTION (RECOMPILE);  -- generates an optimal plan per call instead of reusing
                          -- a plan cached for a very different date range size
END
GO

-- ============================================================================
-- 3) usp_PlaceOrder — transactional insert with proper error handling and
--    explicit isolation, avoiding lock escalation on hot tables
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_PlaceOrder
    @CustomerID INT,
    @ProductID  INT,
    @Quantity   INT,
    @NewOrderID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- ensures automatic rollback on any error

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @UnitPrice DECIMAL(10,2);
        SELECT @UnitPrice = UnitPrice FROM dbo.Products WHERE ProductID = @ProductID;

        IF @UnitPrice IS NULL
        BEGIN
            THROW 50001, 'Invalid ProductID.', 1;
        END

        INSERT INTO dbo.Orders (CustomerID, OrderDate, OrderStatus, TotalAmount)
        VALUES (@CustomerID, SYSUTCDATETIME(), 'Pending', @UnitPrice * @Quantity);

        SET @NewOrderID = SCOPE_IDENTITY();

        INSERT INTO dbo.OrderDetails (OrderID, ProductID, Quantity, UnitPrice, Discount)
        VALUES (@NewOrderID, @ProductID, @Quantity, @UnitPrice, 0);

        UPDATE dbo.Products
        SET StockQuantity = StockQuantity - @Quantity
        WHERE ProductID = @ProductID AND StockQuantity >= @Quantity;

        IF @@ROWCOUNT = 0
        BEGIN
            THROW 50002, 'Insufficient stock for requested quantity.', 1;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

        THROW;  -- re-raise original error with correct line number/procedure context
    END CATCH
END
GO

-- ============================================================================
-- 4) usp_BulkUpdateOrderStatus — batched updates to avoid long-running
--    transactions / lock escalation on large tables
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_BulkUpdateOrderStatus
    @FromStatus NVARCHAR(20),
    @ToStatus   NVARCHAR(20),
    @BatchSize  INT = 5000
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @RowsAffected INT = 1;

    WHILE @RowsAffected > 0
    BEGIN
        UPDATE TOP (@BatchSize) dbo.Orders
        SET OrderStatus = @ToStatus
        WHERE OrderStatus = @FromStatus;

        SET @RowsAffected = @@ROWCOUNT;

        -- brief pause to let other transactions through on a busy system
        IF @RowsAffected > 0 WAITFOR DELAY '00:00:00.100';
    END
END
GO
