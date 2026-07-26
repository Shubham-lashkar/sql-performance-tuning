# Clustered Index

## What it is
The clustered index determines the **physical storage order** of table data. A table can have only one clustered index because data rows can only be sorted one way on disk.

## Where it's used in this repo
Every table's primary key in `scripts/02_CreateTables.sql` is defined `PRIMARY KEY CLUSTERED` — e.g.:

```sql
CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderID)
```

## Why OrderID (identity column) as the clustering key
- **Ever-increasing values** → new rows are always appended at the end of the B-tree, avoiding page splits from random inserts
- **Narrow key** (4-byte INT) → every non-clustered index stores this key as its row locator, so a wide clustering key bloats *every* index on the table
- **Uniqueness** guaranteed by IDENTITY, satisfying the clustered index requirement without extra overhead

## Common mistake
Clustering on a naturally volatile or wide column (e.g. a GUID or a large VARCHAR name field) causes:
- Random-order inserts → frequent page splits → fragmentation
- Every non-clustered index carries the wide key → larger indexes, more I/O

## Related scripts
- `scripts/02_CreateTables.sql` — clustered PK definitions
- `scripts/04_CreateIndexes.sql` — fragmentation check query (`sys.dm_db_index_physical_stats`)
