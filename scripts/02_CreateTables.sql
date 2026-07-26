/*
================================================================================
 File        : 02_CreateTables.sql
 Purpose     : Schema for OrderManagementDB — a realistic OLTP schema large
               enough to demonstrate genuine indexing/optimization problems.
 Author      : Shubham Lashkar
================================================================================
*/

USE OrderManagementDB;
GO

-- ============================================================================
-- Customers
-- ============================================================================
CREATE TABLE dbo.Customers
(
    CustomerID      INT IDENTITY(1,1) NOT NULL,
    FirstName       NVARCHAR(50)  NOT NULL,
    LastName        NVARCHAR(50)  NOT NULL,
    Email           NVARCHAR(100) NOT NULL,
    Phone           NVARCHAR(20)  NULL,
    City            NVARCHAR(50)  NOT NULL,
    State           NVARCHAR(50)  NOT NULL,
    Country         NVARCHAR(50)  NOT NULL DEFAULT 'India',
    CreatedDate     DATETIME2     NOT NULL DEFAULT SYSUTCDATETIME(),
    IsActive        BIT           NOT NULL DEFAULT 1,
    CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (CustomerID)
);
GO

CREATE UNIQUE INDEX UQ_Customers_Email ON dbo.Customers(Email);
GO

-- ============================================================================
-- Categories
-- ============================================================================
CREATE TABLE dbo.Categories
(
    CategoryID      INT IDENTITY(1,1) NOT NULL,
    CategoryName    NVARCHAR(100) NOT NULL,
    ParentCategoryID INT NULL,
    CONSTRAINT PK_Categories PRIMARY KEY CLUSTERED (CategoryID),
    CONSTRAINT FK_Categories_Parent FOREIGN KEY (ParentCategoryID)
        REFERENCES dbo.Categories(CategoryID)
);
GO

-- ============================================================================
-- Products
-- ============================================================================
CREATE TABLE dbo.Products
(
    ProductID       INT IDENTITY(1,1) NOT NULL,
    ProductName     NVARCHAR(150) NOT NULL,
    CategoryID      INT NOT NULL,
    UnitPrice       DECIMAL(10,2) NOT NULL,
    StockQuantity   INT NOT NULL DEFAULT 0,
    IsDiscontinued  BIT NOT NULL DEFAULT 0,
    CreatedDate     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Products PRIMARY KEY CLUSTERED (ProductID),
    CONSTRAINT FK_Products_Category FOREIGN KEY (CategoryID)
        REFERENCES dbo.Categories(CategoryID),
    CONSTRAINT CK_Products_UnitPrice CHECK (UnitPrice >= 0)
);
GO

-- ============================================================================
-- Orders  (partition-friendly: OrderDate drives most reporting queries)
-- ============================================================================
CREATE TABLE dbo.Orders
(
    OrderID         INT IDENTITY(1,1) NOT NULL,
    CustomerID      INT NOT NULL,
    OrderDate       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    OrderStatus     NVARCHAR(20) NOT NULL DEFAULT 'Pending', -- Pending/Shipped/Delivered/Cancelled
    ShippingCity    NVARCHAR(50) NULL,
    TotalAmount     DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID),
    CONSTRAINT FK_Orders_Customer FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers(CustomerID),
    CONSTRAINT CK_Orders_Status CHECK (OrderStatus IN ('Pending','Shipped','Delivered','Cancelled'))
);
GO

-- ============================================================================
-- OrderDetails (the classic "hot" table for performance-tuning demos)
-- ============================================================================
CREATE TABLE dbo.OrderDetails
(
    OrderDetailID   INT IDENTITY(1,1) NOT NULL,
    OrderID         INT NOT NULL,
    ProductID       INT NOT NULL,
    Quantity        INT NOT NULL,
    UnitPrice       DECIMAL(10,2) NOT NULL,
    Discount        DECIMAL(4,2) NOT NULL DEFAULT 0,
    CONSTRAINT PK_OrderDetails PRIMARY KEY CLUSTERED (OrderDetailID),
    CONSTRAINT FK_OrderDetails_Order FOREIGN KEY (OrderID)
        REFERENCES dbo.Orders(OrderID),
    CONSTRAINT FK_OrderDetails_Product FOREIGN KEY (ProductID)
        REFERENCES dbo.Products(ProductID),
    CONSTRAINT CK_OrderDetails_Quantity CHECK (Quantity > 0)
);
GO

-- ============================================================================
-- OrderAuditLog — used later for trigger / monitoring demos
-- ============================================================================
CREATE TABLE dbo.OrderAuditLog
(
    AuditID         INT IDENTITY(1,1) NOT NULL,
    OrderID         INT NOT NULL,
    ChangedColumn   NVARCHAR(50) NOT NULL,
    OldValue        NVARCHAR(200) NULL,
    NewValue        NVARCHAR(200) NULL,
    ChangedDate     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_OrderAuditLog PRIMARY KEY CLUSTERED (AuditID)
);
GO

PRINT 'All tables created successfully.';
GO
