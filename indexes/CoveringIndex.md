# Covering Index

## What it is
A non-clustered index that includes **every column** a query needs — either as key columns (for seeking/sorting) or as `INCLUDE` columns (for retrieval only). Because the index alone can satisfy the entire query, SQL Server never needs a Key Lookup back to the clustered index.

## Where it's used in this repo
```sql
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID_Covering
ON dbo.Orders (CustomerID, OrderDate DESC)
INCLUDE (OrderStatus, TotalAmount);
```
(`scripts/04_CreateIndexes.sql`)

## Why this exact column layout
| Clause | Column(s) | Reason |
|---|---|---|
| Key (equality) | `CustomerID` | The `WHERE` filter column |
| Key (sort) | `OrderDate DESC` | Matches `ORDER BY OrderDate DESC` — avoids a separate Sort operator |
| INCLUDE | `OrderStatus`, `TotalAmount` | Needed in `SELECT` but not for seeking/sorting — cheaper to store at the leaf level than as key columns |

## Measured impact
Query: "recent orders for a customer" (`scripts/05_SlowQueries.sql` #6 → `scripts/06_OptimizedQueries.sql` #6)

| | Before (no covering index) | After (covering index) |
|---|---|---|
| Operator | Index Seek + Key Lookup + Sort | Index Seek only |
| Logical reads | High (1 lookup per row) | Minimal |
| Sort operator | Present | Eliminated (index pre-sorted) |

## Trade-off
Covering indexes are wider than single-column indexes, so they cost more to store and maintain on every `INSERT`/`UPDATE`/`DELETE`. Use them for high-frequency, performance-critical query patterns — not for every possible column combination.

## Related scripts
- `scripts/04_CreateIndexes.sql`
- `execution-plans/BeforeOptimization.md` / `AfterOptimization.md`
