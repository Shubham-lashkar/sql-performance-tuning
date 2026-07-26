/*
================================================================================
 File        : 10_PerformanceMonitoring.sql
 Purpose     : Ongoing health-check queries for ops/DBA use — blocking,
               statistics staleness, TempDB pressure, buffer pool usage,
               and top resource-consuming queries.
 Author      : Shubham Lashkar
================================================================================
*/

USE OrderManagementDB;
GO

-- ============================================================================
-- 1) Active blocking chains right now
-- ============================================================================
SELECT
    blocking.session_id       AS BlockingSessionID,
    blocked.session_id        AS BlockedSessionID,
    blocked.wait_type,
    blocked.wait_time / 1000.0 AS WaitTimeSeconds,
    st.text                   AS BlockedQueryText
FROM sys.dm_exec_requests blocked
INNER JOIN sys.dm_exec_sessions blocking ON blocking.session_id = blocked.blocking_session_id
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) st
WHERE blocked.blocking_session_id != 0;
GO

-- ============================================================================
-- 2) Statistics staleness — outdated stats are a top cause of bad plans
-- ============================================================================
SELECT
    OBJECT_NAME(s.object_id)   AS TableName,
    s.name                     AS StatsName,
    sp.last_updated,
    sp.rows,
    sp.rows_sampled,
    sp.modification_counter    AS RowsModifiedSinceUpdate
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
  AND sp.modification_counter > 0
ORDER BY sp.modification_counter DESC;
GO

-- ============================================================================
-- 3) TempDB contention check (PFS/GAM/SGAM page latch contention symptoms)
-- ============================================================================
SELECT
    session_id, wait_type, wait_duration_ms, resource_description
FROM sys.dm_os_waiting_tasks
WHERE wait_type LIKE 'PAGELATCH%';
GO

-- ============================================================================
-- 4) Buffer pool usage by table — what's actually cached in memory
-- ============================================================================
SELECT TOP 20
    OBJECT_NAME(p.object_id)        AS TableName,
    COUNT(*) * 8 / 1024             AS CachedSizeMB
FROM sys.dm_os_buffer_descriptors b
INNER JOIN sys.allocation_units au ON au.allocation_unit_id = b.allocation_unit_id
INNER JOIN sys.partitions p ON p.partition_id = au.container_id
WHERE b.database_id = DB_ID()
GROUP BY p.object_id
ORDER BY CachedSizeMB DESC;
GO

-- ============================================================================
-- 5) Top 10 most expensive queries by total logical reads (I/O pressure)
-- ============================================================================
SELECT TOP 10
    qs.execution_count,
    qs.total_logical_reads,
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    SUBSTRING(st.text, 1, 200) AS query_snippet
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_logical_reads DESC;
GO

-- ============================================================================
-- 6) Database file I/O stats — identify hot files needing separation
-- ============================================================================
SELECT
    DB_NAME(vfs.database_id)       AS DatabaseName,
    mf.name                        AS LogicalFileName,
    mf.type_desc,
    vfs.num_of_reads, vfs.num_of_writes,
    vfs.io_stall_read_ms, vfs.io_stall_write_ms
FROM sys.dm_io_virtual_file_stats(DB_ID(), NULL) vfs
INNER JOIN sys.master_files mf
    ON mf.database_id = vfs.database_id AND mf.file_id = vfs.file_id
ORDER BY (vfs.io_stall_read_ms + vfs.io_stall_write_ms) DESC;
GO

-- ============================================================================
-- 7) Simple health-check summary — good candidate for a scheduled SQL Agent
--    job that writes results to a monitoring table for trending over time
-- ============================================================================
SELECT
    (SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id != 0) AS ActiveBlockedSessions,
    (SELECT COUNT(*) FROM sys.dm_os_waiting_tasks WHERE wait_type LIKE 'PAGELATCH%') AS TempDBContentionWaits,
    (SELECT AVG(avg_fragmentation_in_percent)
       FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED')
       WHERE page_count > 100) AS AvgIndexFragmentationPct,
    GETUTCDATE() AS CheckedAt;
GO
