# Transaction Handling & Batching

## Where it shows up in this repo
`usp_PlaceOrder` in `scripts/07_StoredProcedures.sql`.

## Key patterns used

### 1. `SET XACT_ABORT ON`
Ensures that **any** runtime error automatically rolls back the entire transaction, rather than leaving it open in an undetermined state. Without this, some errors only abort the current statement, silently leaving a partially-committed, still-open transaction.

### 2. `TRY...CATCH` with `XACT_STATE()` check
```sql
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH
```
`XACT_STATE()` distinguishes between:
- `1` — active, committable transaction
- `-1` — active but **uncommittable** transaction (must be rolled back, cannot commit)
- `0` — no active transaction

Checking before rollback avoids the error "ROLLBACK TRANSACTION request has no corresponding BEGIN TRANSACTION."

### 3. `THROW` (not `RAISERROR`) to re-raise
`THROW` with no arguments inside a `CATCH` block preserves the original error number, message, severity, and line number — better diagnostics than reconstructing the error with `RAISERROR`.

### 4. Batched updates for large tables
`usp_BulkUpdateOrderStatus` uses `UPDATE TOP (@BatchSize)` in a loop instead of one massive `UPDATE`:
```sql
WHILE @RowsAffected > 0
BEGIN
    UPDATE TOP (@BatchSize) dbo.Orders SET OrderStatus = @ToStatus WHERE OrderStatus = @FromStatus;
    SET @RowsAffected = @@ROWCOUNT;
    IF @RowsAffected > 0 WAITFOR DELAY '00:00:00.100';
END
```
**Why:** a single `UPDATE` touching millions of rows holds locks for the entire duration, risking lock escalation to a table lock and blocking other transactions. Small batches with a brief pause between them let other transactions interleave, at the cost of the operation taking longer overall and not being atomic as one unit.

## Related scripts
- `scripts/07_StoredProcedures.sql`
