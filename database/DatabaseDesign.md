# Database Design — OrderManagementDB

## Overview
A realistic OLTP schema modeling an e-commerce order pipeline, sized to actually surface indexing/query problems (100K customers, 5K products, 500K orders, ~1.5M order lines).

## Entities

| Table | Purpose | Row count (sample data) |
|---|---|---|
| `Customers` | Registered customers | 100,000 |
| `Categories` | Product category hierarchy (self-referencing) | 17 |
| `Products` | Catalog items | 5,000 |
| `Orders` | Order header | 500,000 |
| `OrderDetails` | Order line items | ~1,500,000 |
| `OrderAuditLog` | Change tracking for order status changes | grows over time |

## Relationships
- `Customers (1) → (M) Orders` via `CustomerID`
- `Orders (1) → (M) OrderDetails` via `OrderID`
- `Products (1) → (M) OrderDetails` via `ProductID`
- `Categories (1) → (M) Products` via `CategoryID`
- `Categories (1) → (M) Categories` self-referencing via `ParentCategoryID` (category hierarchy)

## Key design decisions
- **Clustered PK on every table** — narrow, ever-increasing `IDENTITY` keys to minimize page splits and keep non-clustered index row-locators small (see `indexes/ClusteredIndex.md`)
- **`READ_COMMITTED_SNAPSHOT ON`** — row versioning reduces reader/writer blocking, appropriate for an OLTP workload with concurrent reads and writes
- **Separate filegroup for indexes (`FG_Indexes`)** — allows I/O separation between data and index files on different physical disks in a real deployment
- **`OrderDate` skewed toward recent dates** in sample data generation — mimics real traffic patterns where "last 30 days" reporting queries are the hot path

## Full schema
See `scripts/02_CreateTables.sql` for the complete DDL with constraints and defaults.

## ERD
See `ERD.png` in this folder (generate via SSMS: right-click database → *Database Diagrams* → *New Database Diagram*, add all tables, export as image).
