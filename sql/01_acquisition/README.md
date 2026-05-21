# 01 · Customer acquisition

Queries focused on identifying genuinely new customers — those who not only
registered but converted into a paying relationship within a defined window —
and tracking the channel and promotion type that drove their first purchase.

## Why this matters

Marketing campaigns and sales incentives are evaluated against *concretadas*
(realized acquisitions), not raw registrations. A customer who signs up but
never places a paid order is not yet a customer — they are a lead. Conflating
the two inflates funnel metrics and misallocates promo budget.

## Business definitions used here

| Term | Meaning |
|---|---|
| **Alta** | Customer registration date (`Clientes.FecAlt`) |
| **Concretada** | First paid order placed within 60 days of registration |
| **Primera compra** | First order in `Pedidos` for the customer, regardless of price |
| **Promo 2x1** | Normally-priced product delivered at price 0 on first order |
| **Sin Cargo** | Native zero-price product (e.g., `EMSC` — initial bottle deposit) |
| **Digital** | Customer registered through the online channel (`Atrib6 = 'DIG'`) |

## Queries in this module

| File | Purpose | Output grain |
|---|---|---|
| `altas_concretadas.sql` | Monthly count of realized acquisitions, split Hogar vs Gastronomy | Month × Segment |
| `primera_compra_estado.sql` | Per-customer first-order detail with promo classification | Customer × first order |
| `altas_digital_rto.sql` | Digital-channel acquisitions by delivery route | Route × Month |
| `recompra_mensual.sql` | Did the new customer come back? Second-order tracking | Customer × Month |

## Key techniques demonstrated

- **`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`** to identify the first
  order per customer in a single pass
- **Multi-CTE composition** to layer business rules without subquery nesting
- **`CASE WHEN ... THEN ...`** for promo classification with fallthrough logic
- **`OUTER APPLY`** to attach the first-line product without losing customers
  with no orders yet
- **Date arithmetic** with `DATEFROMPARTS()` and `EOMONTH()` for month windows

## How to run

All queries assume the `H2O_JUMI_DEMO` database created by
[`../../data/load_to_sqlserver.sql`](../../data/load_to_sqlserver.sql).

```sql
USE H2O_JUMI_DEMO;
GO

-- Then open and execute any .sql file in this folder
```

## Sample output

Running `altas_concretadas.sql` against the synthetic dataset returns the
monthly Gastronomy acquisition trend:

```
Mes      Gastronomy  Hogar  Total
2025-06         25     142    167
2025-07         24     138    162
2025-08         27     145    172
...
```

Avg days from registration to first paid order (Gastronomy): **12.9**
