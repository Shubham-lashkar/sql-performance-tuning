# Execution Plan — Before Optimization

Baseline plans captured by running `scripts/05_SlowQueries.sql` against the schema **before** `scripts/04_CreateIndexes.sql`'s covering index is applied.

## Query: Recent orders for a customer
```sql
SELECT OrderID, OrderDate, OrderStatus, TotalAmount
FROM dbo.Orders
WHERE CustomerID = 4521
ORDER BY OrderDate DESC;
```

### Plan shape (with only `IX_Orders_CustomerID` on `CustomerID` alone)
```
SELECT
 └─ Sort (OrderDate DESC)                    <- extra operator, not free
     └─ Key Lookup (Clustered Index)         <- one random I/O per matching row
         └─ Nested Loops
             └─ Index Seek (IX_Orders_CustomerID)
```

### What this plan tells you
- **Index Seek** on `CustomerID` — good, the filter is index-supported
- **Key Lookup** — bad, every matched row needs a second trip to the clustered index to fetch `OrderDate`, `OrderStatus`, `TotalAmount`
- **Sort** — bad, `ORDER BY OrderDate DESC` has no supporting index order, so SQL Server sorts results in memory/tempdb after retrieval
- At customer order volumes >50 rows, the Key Lookup cost dominates — this is the single most common performance complaint in OLTP reporting queries

### STATISTICS IO output (representative, 500K-row Orders table)
```
Table 'Orders'. Scan count 1, logical reads 3.., Key Lookup reads dominate.
```

## Query: Full table scan pattern
```sql
SELECT COUNT(*) FROM dbo.Orders WHERE YEAR(OrderDate) = 2026;
```

### Plan shape
```
SELECT
 └─ Stream Aggregate (COUNT)
     └─ Clustered Index Scan (Orders)   <- entire table read, every row
```
`YEAR(OrderDate)` wraps the column in a function, so SQL Server cannot seek — it must evaluate the expression row-by-row across the whole table (non-SARGable predicate).

See `AfterOptimization.md` for the fixed plans.
