# Statistics

SQL Server's query optimizer relies on statistics — histograms of column value distribution — to estimate row counts and choose a plan (seek vs scan, join order, join type). Stale or missing statistics are one of the most common causes of a "good" query suddenly getting a bad plan.

## How the optimizer uses them
For `WHERE CustomerID = 4521`, the optimizer checks the statistics on `CustomerID` to estimate how many rows will match, then picks Seek vs Scan and memory grant size based on that estimate. If the real row count differs wildly from the estimate, the chosen plan can be badly wrong (too little memory grant → spill to tempdb; too much → wasted resources).

## Checking staleness
```sql
SELECT OBJECT_NAME(s.object_id) AS TableName, s.name AS StatsName,
    sp.last_updated, sp.rows, sp.modification_counter AS RowsModifiedSinceUpdate
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE sp.modification_counter > 0
ORDER BY sp.modification_counter DESC;
```
(`scripts/10_PerformanceMonitoring.sql`)

## Auto-update behavior
Enabled at the database level in `scripts/01_CreateDatabase.sql`:
```sql
ALTER DATABASE OrderManagementDB SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE OrderManagementDB SET AUTO_UPDATE_STATISTICS_ASYNC ON;
```
- `AUTO_UPDATE_STATISTICS` triggers a refresh once enough rows have changed (roughly 20% + 500 rows, by default, prior to trace-flag/DB-scoped-config changes in newer versions)
- `_ASYNC ON` means the triggering query uses the (slightly) stale stats and doesn't wait for the update — the *next* query benefits. Prevents query-time stalls on large tables, at the cost of one query running on outdated estimates

## Manual refresh
```sql
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;
```
Use `FULLSCAN` after large bulk loads (like `scripts/03_InsertSampleData.sql`) rather than relying on the default sampled scan — sampled statistics can miss skew in large tables.

## Related scripts
- `scripts/01_CreateDatabase.sql`
- `scripts/10_PerformanceMonitoring.sql`
