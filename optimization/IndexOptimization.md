# Index Optimization

How to decide whether an index is helping, hurting, or missing — not just how to create one.

## Finding missing indexes
SQL Server tracks predicates it couldn't seek efficiently:
```sql
SELECT mid.statement, migs.avg_user_impact, migs.user_seeks + migs.user_scans AS TimesUsedIfCreated
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig ON mig.index_handle = mid.index_handle
JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
ORDER BY migs.avg_user_impact DESC;
```
(`scripts/04_CreateIndexes.sql`)

**Caveat:** these are suggestions based on the plan cache since the last restart, not guarantees. Validate impact before creating — an index that "would help" a rarely-run query isn't worth its write overhead.

## Finding unused indexes
Every index has a write cost on `INSERT`/`UPDATE`/`DELETE`. An index with zero seeks/scans/lookups but nonzero updates is pure overhead:
```sql
SELECT OBJECT_NAME(s.object_id), i.name, s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE s.user_seeks = 0 AND s.user_scans = 0 AND s.user_lookups = 0 AND s.user_updates > 0;
```

## Fragmentation
```sql
SELECT OBJECT_NAME(ips.object_id), i.name, ips.avg_fragmentation_in_percent,
    CASE WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
         WHEN ips.avg_fragmentation_in_percent BETWEEN 5 AND 30 THEN 'REORGANIZE'
         ELSE 'OK' END AS RecommendedAction
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON i.object_id = ips.object_id AND i.index_id = ips.index_id
WHERE ips.page_count > 100;
```
- **> 30% fragmented** → `ALTER INDEX ... REBUILD` (rewrites the index entirely; can run `ONLINE` on Enterprise edition)
- **5–30% fragmented** → `ALTER INDEX ... REORGANIZE` (lighter-weight, always online)
- **< 5%** → not worth the maintenance cost

## Decision checklist before adding an index
1. Does an existing index already cover this predicate with a compatible column order?
2. Is the column selective enough to avoid a scan-equivalent seek?
3. Is the read frequency high enough to justify the write overhead?
4. Would a covering `INCLUDE` avoid a Key Lookup for an existing index instead of creating a brand-new one?

## Related scripts
- `scripts/04_CreateIndexes.sql`
- `scripts/10_PerformanceMonitoring.sql`
