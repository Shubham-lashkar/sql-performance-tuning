# Query Optimization

General principles applied throughout `scripts/05_SlowQueries.sql` → `scripts/06_OptimizedQueries.sql`.

## 1. SARGability
A predicate is "SARGable" (Search ARGument-able) when SQL Server can use an index seek to evaluate it. Wrapping a column in a function (`YEAR(OrderDate)`, `CONVERT(...)`, `ISNULL(Column, x)`) breaks this — the optimizer must evaluate the function per row, forcing a scan.

**Fix:** rewrite as a range predicate that leaves the column bare — `OrderDate >= '2026-01-01' AND OrderDate < '2027-01-01'` instead of `YEAR(OrderDate) = 2026`.

## 2. Avoid leading wildcards
`LIKE '%son'` cannot use a standard B-tree index (SQL Server can't seek to "somewhere in the middle" of a string). `LIKE 'John%'` can. For genuine substring search at scale, use Full-Text Search instead of `LIKE '%x%'`.

## 3. Select only needed columns
`SELECT *` prevents narrow covering indexes from satisfying the query and increases I/O and network payload for no benefit.

## 4. NOT EXISTS over NOT IN
`NOT IN` against a subquery that can return `NULL` silently produces zero rows for the entire query — a correctness bug, not just a performance one. `NOT EXISTS` is NULL-safe and typically optimizes to an anti-join, which is also cheaper.

## 5. Set-based over row-by-row (RBAR)
Correlated subqueries and cursors execute once per outer row. A `JOIN` + `GROUP BY` lets the optimizer process the whole set in one pass.

## 6. Pagination at scale
`OFFSET`/`FETCH` still has to scan and discard every row before the offset — cost grows linearly with page depth. Keyset (seek) pagination carries the last-seen key forward and always performs a bounded seek, regardless of page depth.

## Related scripts
- `scripts/05_SlowQueries.sql`
- `scripts/06_OptimizedQueries.sql`
