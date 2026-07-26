# Composite Index

## What it is
An index built on **more than one column**. Column order determines which query patterns the index can serve efficiently — this is the single most misunderstood part of indexing.

## Where it's used in this repo
```sql
CREATE NONCLUSTERED INDEX IX_OrderDetails_ProductID_OrderID
ON dbo.OrderDetails (ProductID, OrderID)
INCLUDE (Quantity, UnitPrice);
```
(`scripts/04_CreateIndexes.sql`)

## The leftmost-prefix rule
A composite index on `(ProductID, OrderID)` can efficiently serve:
- `WHERE ProductID = X` ✅ (leading column)
- `WHERE ProductID = X AND OrderID = Y` ✅ (both columns, in order)

It **cannot** efficiently serve:
- `WHERE OrderID = Y` alone ❌ — `OrderID` is not the leading column, so SQL Server falls back to a scan

## Column order decision rule used here
Put the **more selective / more frequently filtered-alone** column first. `ProductID` is filtered alone far more often (e.g. "show all orders containing this product") than `OrderID` is filtered alone (orders are usually looked up by `OrderID` directly via the primary key, not through `OrderDetails`).

## Anti-pattern to avoid
```sql
-- BAD: low-selectivity / rarely-filtered-alone column leads
CREATE INDEX IX_Bad ON dbo.OrderDetails (Discount, ProductID);
```
`Discount` has very few distinct values and is rarely the sole filter — this index is close to useless for the actual query patterns in this application.

## Related scripts
- `scripts/04_CreateIndexes.sql`
