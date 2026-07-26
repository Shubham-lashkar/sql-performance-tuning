# Standard Views vs Indexed (Materialized) Views

## Standard view — logic reuse, zero storage cost
```sql
CREATE VIEW dbo.vw_CustomerOrderSummary AS
SELECT c.CustomerID, ..., SUM(o.TotalAmount) AS LifetimeValue
FROM dbo.Customers c LEFT JOIN dbo.Orders o ON o.CustomerID = c.CustomerID
GROUP BY ...;
```
(`scripts/08_Views.sql`)

A standard view is just stored SQL text — it re-executes the underlying query every time it's referenced. Use it to encapsulate and reuse complex logic; it provides **no** performance benefit on its own (and can hide an expensive query behind a simple-looking name, which is worth watching for).

## Indexed view — genuine materialization
```sql
CREATE VIEW dbo.vw_DailySalesSummary WITH SCHEMABINDING AS
SELECT CAST(o.OrderDate AS DATE) AS SalesDate, o.OrderStatus,
       SUM(o.TotalAmount) AS TotalSales, COUNT_BIG(*) AS OrderCount
FROM dbo.Orders o
GROUP BY CAST(o.OrderDate AS DATE), o.OrderStatus;

CREATE UNIQUE CLUSTERED INDEX IX_vw_DailySalesSummary
ON dbo.vw_DailySalesSummary (SalesDate, OrderStatus);
```
The `CREATE UNIQUE CLUSTERED INDEX` is what actually materializes the aggregated result on disk — this is SQL Server's equivalent of a materialized view. Once indexed, querying the view reads pre-aggregated data instead of re-scanning and re-grouping `Orders` every time.

### Requirements
- `WITH SCHEMABINDING` — locks the underlying table schema so it can't change under the view
- Only deterministic aggregates are allowed
- `COUNT_BIG(*)` is required alongside `SUM`/other aggregates for an indexed view
- No outer joins, subqueries, or several other constructs allowed in the view definition

### The trade-off
Every `INSERT`/`UPDATE`/`DELETE` on `Orders` now also has to maintain this index — write cost goes up. This is worth it only when the view is read far more often than the base table is written to, which is exactly the profile of a "daily sales dashboard" query.

## Decision rule used in this repo
- Reused logic, read frequency similar to base table → **standard view**
- Heavy aggregation, read-far-more-than-write reporting pattern → **indexed view**

## Related scripts
- `scripts/08_Views.sql` (renumbered to `09_Views.sql` in the final tree)
