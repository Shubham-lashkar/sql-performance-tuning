/*
================================================================================
 File        : 06_ExecutionPlanAnalysis.sql
 Purpose     : Techniques and DMV queries for reading and diagnosing
               execution plans — beyond just "Include Actual Execution Plan".
 Author      : Shubham Lashkar
================================================================================
*/

USE OrderManagementDB;
GO

-- ============================================================================
-- 1) Capture actual execution plan for a query (run with "Include Actual
--    Execution Plan" ON in SSMS, or via SET STATISTICS XML)
-- ============================================================================
SET STATISTICS XML ON;

SELECT o.OrderID, o.OrderDate, c.FirstName, c.LastName, SUM(od.Quantity * od.UnitPrice) AS LineTotal
FROM dbo.Orders o
INNER JOIN dbo.Customers c ON c.CustomerID = o.CustomerID
INNER JOIN dbo.OrderDetails od ON od.OrderID = o.OrderID
WHERE o.OrderDate >= DATEADD(DAY, -30, SYSUTCDATETIME())
GROUP BY o.OrderID, o.OrderDate, c.FirstName, c.LastName;

SET STATISTICS XML OFF;
GO
-- What to look for in the plan:
--   - Thick arrows = high row counts flowing between operators (I/O hotspot)
--   - Yellow warning triangle on operators = implicit conversion / missing stats
--   - "Estimated" vs "Actual" row count mismatch > 10x = stale statistics
--   - Key Lookup next to an Index Seek = missing covering index
--   - Hash Match on small tables = missing index causing suboptimal join strategy

-- ============================================================================
-- 2) Find queries with the biggest estimate-vs-actual mismatch (cached plans)
-- ============================================================================
SELECT TOP 20
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    qs.total_elapsed_time / qs.execution_count  AS avg_elapsed_time_micro,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) ELSE qs.statement_end_offset END
          - qs.statement_start_offset)/2) + 1) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY avg_logical_reads DESC;
GO

-- ============================================================================
-- 3) Top CPU-consuming queries currently cached
-- ============================================================================
SELECT TOP 20
    qs.total_worker_time / qs.execution_count AS avg_cpu_time,
    qs.execution_count,
    qs.total_elapsed_time,
    st.text AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY avg_cpu_time DESC;
GO

-- ============================================================================
-- 4) Detect implicit conversions in cached plans (a frequent silent killer)
-- ============================================================================
SELECT
    st.text AS query_text,
    qp.query_plan
FROM sys.dm_exec_cached_plans cp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qp
WHERE CAST(qp.query_plan AS NVARCHAR(MAX)) LIKE '%CONVERT_IMPLICIT%';
GO

-- ============================================================================
-- 5) Wait statistics — what is SQL Server actually waiting on right now?
-- ============================================================================
SELECT TOP 15
    wait_type,
    wait_time_ms,
    waiting_tasks_count,
    wait_time_ms / NULLIF(waiting_tasks_count, 0) AS avg_wait_ms
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN
    ('CLR_SEMAPHORE','LAZYWRITER_SLEEP','RESOURCE_QUEUE','SLEEP_TASK',
     'SLEEP_SYSTEMTASK','SQLTRACE_BUFFER_FLUSH','WAITFOR','BROKER_TASK_STOP')
ORDER BY wait_time_ms DESC;
-- PAGEIOLATCH_*  -> disk I/O bottleneck (consider faster storage / more RAM for buffer pool)
-- CXPACKET/CXCONSUMER -> parallelism; check MAXDOP / Cost Threshold for Parallelism
-- LCK_M_*        -> blocking; investigate long transactions
GO

-- ============================================================================
-- 6) Currently running queries + blocking chain
-- ============================================================================
SELECT
    r.session_id, r.status, r.blocking_session_id, r.wait_type, r.wait_time,
    r.cpu_time, r.logical_reads, r.total_elapsed_time,
    st.text AS query_text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.session_id != @@SPID
ORDER BY r.total_elapsed_time DESC;
GO
