# Non-Clustered Index

## What it is
A separate B-tree structure that stores a copy of selected columns plus a pointer back to the clustered index key (or RID, for heaps). A table can have many non-clustered indexes.

## Where it's used in this repo
```sql
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID
ON dbo.Orders (CustomerID);
```
(`scripts/04_CreateIndexes.sql`)

## What it fixes
Without this index, filtering `Orders` by `CustomerID` requires a full **Clustered Index Scan** — SQL Server has to read every row in the table to find matches. With the index, it becomes an **Index Seek** — SQL Server jumps directly to the matching rows.

## The Key Lookup problem
A plain non-clustered index on `CustomerID` alone only contains `CustomerID` + the clustering key (`OrderID`). If the query also needs `OrderDate`, `OrderStatus`, `TotalAmount`, SQL Server must perform a **Key Lookup** back into the clustered index for every matching row — expensive at scale.

This is exactly why `IX_Orders_CustomerID` is later dropped and replaced with a covering index (see `CoveringIndex.md`).

## Related scripts
- `scripts/04_CreateIndexes.sql`
- `scripts/05_SlowQueries.sql` (query #6) vs `scripts/06_OptimizedQueries.sql` (query #6)
