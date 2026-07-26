# Parameter Sniffing

## What it is
When a stored procedure runs for the first time (or after its cached plan is evicted/recompiled), SQL Server builds an execution plan optimized for the **specific parameter values** passed in that first call, then caches and reuses that same plan for all future calls — even with very different parameter values.

## Where it shows up in this repo
`usp_GetOrdersByDateRange` in `scripts/07_StoredProcedures.sql` takes `@StartDate`/`@EndDate`. A call for a 1-day range and a call for a 2-year range return wildly different row counts, but would share the same cached plan without mitigation — the plan optimized for one is often terrible for the other (wrong join type, wrong memory grant, missing parallelism or unnecessary parallelism).

## The fix used here
```sql
OPTION (RECOMPILE)
```
Forces a fresh, parameter-specific plan on every execution. Trade-off: extra CPU cost to compile each time, so this is used only on the procedure where plan variance is severe enough to justify it — not applied blanket-wide.

## Other mitigation options (not used here, but worth knowing)
| Technique | When to use |
|---|---|
| `OPTION (RECOMPILE)` | Plan shape genuinely needs to differ per call; recompile cost is acceptable |
| `OPTIMIZE FOR` a representative value | You know the "typical" call pattern and want to bias toward it |
| Query Store "Force Plan" | You've identified one specific known-good plan and want to pin it |
| Local variables instead of parameters | Deliberately disables sniffing (optimizer uses average density instead) — usually not recommended, hides the real issue |

## Related scripts
- `scripts/07_StoredProcedures.sql`
