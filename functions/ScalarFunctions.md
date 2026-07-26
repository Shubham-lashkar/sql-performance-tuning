# Scalar Functions vs Inline Table-Valued Functions

## The problem: Scalar UDFs and row-by-row execution (RBAR)
```sql
CREATE FUNCTION dbo.fn_GetOrderDiscountAmount_Scalar (@OrderID INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @DiscountAmount DECIMAL(12,2);
    SELECT @DiscountAmount = SUM(...) FROM dbo.OrderDetails WHERE OrderID = @OrderID;
    RETURN ISNULL(@DiscountAmount, 0);
END
```
(`scripts/09_Functions.sql`)

Called once per row in a `SELECT`, this function executes **once per row** rather than as part of a single set-based plan. Prior to SQL Server 2019, this also blocks parallelism entirely for the whole query. Even with 2019+'s scalar UDF inlining, not every function qualifies for inlining (e.g. functions with `TRY...CATCH`, table variables, or certain system functions don't inline).

## The fix: Inline Table-Valued Function (ITVF)
```sql
CREATE FUNCTION dbo.fn_GetOrderDiscountAmount_ITVF (@OrderID INT)
RETURNS TABLE
AS
RETURN (SELECT SUM(...) AS DiscountAmount FROM dbo.OrderDetails WHERE OrderID = @OrderID);
```
An ITVF is really just a parameterized view — the optimizer expands its definition inline into the calling query's plan and optimizes the whole thing as one set-based operation. Used via `CROSS APPLY`, it behaves like a join, not a per-row function call.

## Multi-statement TVF caution
`fn_GetActiveCustomersByCity` uses a multi-statement TVF (`RETURNS @Result TABLE ... BEGIN ... END`). Unlike an ITVF, the optimizer cannot see inside the function body — it estimates a fixed row count for the result (historically a flat guess), which can lead to bad join plans when this function's output is joined against other tables. Prefer ITVFs whenever the logic can be expressed as a single `RETURN (SELECT ...)`.

## Rule of thumb used in this repo
1. Can the logic be inlined directly into the calling query? Do that — no function needed.
2. Does it need to be reused across many queries? Use an ITVF.
3. Only use a multi-statement TVF or scalar function when the logic genuinely requires procedural steps that can't be expressed as a single set-based `SELECT`.

## Related scripts
- `scripts/09_Functions.sql` (renumbered to `08_Functions.sql` in the final tree)
