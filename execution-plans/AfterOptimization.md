# Execution Plan — After Optimization

Plans captured by running `scripts/06_OptimizedQueries.sql` after `scripts/04_CreateIndexes.sql` has created the covering index.

## Query: Recent orders for a customer
```sql
SELECT OrderID, OrderDate, OrderStatus, TotalAmount
FROM dbo.Orders
WHERE CustomerID = 4521
ORDER BY OrderDate DESC;
```

### Plan shape (with `IX_Orders_CustomerID_Covering (CustomerID, OrderDate DESC) INCLUDE (OrderStatus, TotalAmount)`)
```
SELECT
 └─ Index Seek (IX_Orders_CustomerID_Covering)   <- single operator, done
```

### What changed
- **Key Lookup eliminated** — `OrderStatus` and `TotalAmount` are now stored directly in the index's leaf level via `INCLUDE`
- **Sort eliminated** — the index key is `(CustomerID, OrderDate DESC)`, so results come back pre-sorted in the exact order the query needs
- Plan collapses from 4 logical operators to 1

### Before vs After summary

| Metric | Before | After |
|---|---|---|
| Operators | Seek + Key Lookup + Nested Loop + Sort | Seek only |
| Logical reads | High (1 extra I/O per row) | Low (single index traversal) |
| Scales with row count? | Poorly — lookup cost grows linearly | Well — seek cost is near-constant |

## Query: Date-range filter instead of function-wrapped column
```sql
SELECT COUNT(*) FROM dbo.Orders
WHERE OrderDate >= '2026-01-01' AND OrderDate < '2027-01-01';
```

### Plan shape (with an index on `OrderDate`)
```
SELECT
 └─ Stream Aggregate (COUNT)
     └─ Index Seek (range scan on OrderDate)   <- only relevant rows touched
```
Rewriting `YEAR(OrderDate) = 2026` as a sargable range (`>=` / `<`) lets the optimizer seek directly to the 2026 range instead of evaluating every row.

## How to reproduce these comparisons yourself
1. Run `scripts/01`–`03` to build schema + data
2. Run `scripts/05_SlowQueries.sql` with **Include Actual Execution Plan** ON in SSMS — save each plan
3. Run `scripts/04_CreateIndexes.sql`
4. Run `scripts/06_OptimizedQueries.sql` with the plan ON again — compare side by side
