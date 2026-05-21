# SQL & Power BI Portfolio — Water Distribution Analytics

> End-to-end BI ecosystem for a water and soda distribution company in Argentina.
> 14,000+ active customers, 500,000 orders per year, 8 supervised regions.
> SQL Server queries that automated manual reporting workflows, Power BI dashboards
> with custom DAX measures — all reproducible on synthetic data with zero exposure
> of real company information.

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019+-CC2927?logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/en-us/sql-server)
[![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-F2C811?logo=powerbi&logoColor=black)](https://powerbi.microsoft.com)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white)](https://www.python.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

🌐 **[Spanish version → README.es.md](README.es.md)**

---

## Business context

I work as a BI Analyst at a water and soda distribution company in Buenos Aires
metropolitan area. The operation includes:

- **14,000+ active customers** across 4 segments: Home, Gastronomy, Corporate, Institutional
- **230+ delivery vendors** organized in 8 supervised regions
- **Two billing models**: Cash (immediate payment on delivery) and Credit Account (30/60/90 days)
- **Cold/Hot dispenser equipment** installed in 18% of customer premises (rental model)

This repository contains my BI work for the past 1-3 years: SQL queries that
automated previously manual reporting tasks, Power BI dashboards used by
operations and finance teams, and the dimensional logic behind acquisition,
retention, financial risk, and operational performance KPIs.

## Tech stack

| Layer | Technology | Used for |
|---|---|---|
| Database | SQL Server (T-SQL) | CTEs, window functions, `OUTER APPLY`, dynamic SQL with `sp_executesql`, pivots |
| Reporting | Power BI Desktop | M (Power Query) transformations, DAX measures, drill-through, bookmarks |
| Synthetic data | Python (Faker, pandas, numpy) | Reproducible dataset for public sharing |

## Data privacy

Real company data is **never** published in this repository. The codebase ships
a Python generator that produces 21 referentially-consistent tables with the
exact same schema as production, populated with synthetic data:

| | Real (private) | Synthetic (public) |
|---|---|---|
| Customer names | Real persons and companies | Faker (es-AR) |
| Addresses | Real | Random Argentine-style |
| CUIT (tax IDs) | Real | Format-valid but fictitious |
| Supervisor names | Real people | "Supervisor Zona Norte/Sur/..." |
| Equipment brands | Real brand names | Generic labels |
| Internal user codes | Real (`JOB 499`, etc.) | Generic (`JOB_FC`, `JOB_NC`) |
| Payment methods | Real provider names | Generic codes (`EFE`, `TRF`, `DIG`) |

See [`data/README.md`](data/README.md) for the full anonymization mapping and
setup instructions.

## Repository structure

```
sql-powerbi-portfolio/
├── data/                     Synthetic data generator and SQL Server loader
├── sql/                      Production queries grouped by business module
│   ├── 01_acquisition/       New customer activation, first-purchase analysis
│   ├── 02_retention/         60-day inactivity workflow, win-back detection
│   ├── 03_fc_equipment/      Dispenser productivity and consumption metrics
│   ├── 04_financial_risk/    Debt analysis by route and customer segment
│   ├── 05_segmentation/      Gated communities, household vs corporate parsing
│   ├── 06_sales_performance/ Monthly sales by vendor, 24-month historical pivot
│   ├── 07_collections/       Treasury movements, debt aging, payment methods
│   └── 08_daily_operations/  Holiday sales recovery, daily comparison
├── powerbi/                  Power BI Project files, DAX measures, screenshots
└── docs/                     Data dictionary, ERD, business glossary
```

## Analytical modules

### 1 · Customer acquisition
Identifies new customers who effectively converted (first paid order within
60 days of registration). Distinguishes promo channels: 2x1, free trial,
referral, digital. Output feeds weekly acquisition KPI reports.

**Techniques:** `ROW_NUMBER()` over customer-fact joins, multi-condition CASE
for promo classification, OUTER APPLY for first-line product lookup.

### 2 · Customer retention
Detects customers with 60+ days of no consumption, then enriches each case
with the *reason* (repurchased, equipment retrieved, churned, internal correction)
by reading subsequent transactional events. Replaced a 4-hour manual Excel
process with a 15-second query.

**Techniques:** complex CASE state machine, `LEAD()`/`LAG()` for event sequencing,
multi-CTE composition.

### 3 · F/C equipment productivity
Tracks installed dispenser base, monthly consumption per machine model, and
installation/retirement movements. Used for monthly inventory reconciliation.

**Techniques:** `OUTER APPLY` for last-event-per-equipment, NULL-aware joins,
calendar table joins.

### 4 · Financial risk
Per-route debt aging combining cash payment delays and credit account balances.
Flags large-account exposure and identifies routes with collection efficiency
below thresholds.

**Techniques:** `UNION ALL` of two transactional sources, correlated subqueries,
debt-aging window functions.

### 5 · Customer segmentation
Geographic parsing to identify customers in gated communities (using LIKE on
`Direcc` field), household vs corporate classification (via attribute fields),
gastronomy targeting.

**Techniques:** layered CASE, pattern matching, attribute table joins.

### 6 · Sales performance
Pivoted monthly sales by vendor and product over rolling 24-month windows,
with dynamic column generation via `sp_executesql`. Powers the executive
dashboard.

**Techniques:** dynamic SQL, `PIVOT` operator, conditional aggregation.

### 7 · Collections
Monthly treasury reporting by region, payment method breakdown (cash, transfer,
digital, check, retention), debt aging.

**Techniques:** multi-source consolidation, payment-method dimensional joins,
running-balance calculations.

### 8 · Daily operations
Holiday sales recovery analysis (comparing same-day-of-previous-week sales to
estimate route-level recovery rate), daily vs same-day-last-week deltas.

**Techniques:** date arithmetic, vendor-day grain, recovery rate calculation.

## Quick start

```bash
# 1. Clone
git clone https://github.com/<your-user>/sql-powerbi-portfolio.git
cd sql-powerbi-portfolio

# 2. Generate synthetic data
pip install faker pandas numpy
cd data
python generate_synthetic_data.py

# 3. Load into SQL Server (requires SSMS)
# Edit @csv_path in load_to_sqlserver.sql, then execute in SSMS

# 4. Run any query
# Open any .sql file under sql/, queries point to [H2O_JUMI_DEMO].[dbo].[...]
```

Full instructions in [`data/README.md`](data/README.md).

## Sample insights from the synthetic dataset

| Metric | Value |
|---|---|
| Average days from registration to first paid order (Gastronomy) | 12.9 |
| Monthly Gastronomy acquisitions (concretadas) | 25-30 |
| Customers with F/C equipment | 18% |
| First-order promo rate | 25% |
| Cash vs Credit ratio | 78/22 |

## Author

**Matías** — BI Analyst, Buenos Aires, Argentina

- 💼 [LinkedIn](https://linkedin.com/in/your-handle)
- 📧 [Email](mailto:your-email@example.com)
- 🌐 [Portfolio](https://your-website.com)

## License

MIT — see [LICENSE](LICENSE).

---

*This portfolio uses synthetic data exclusively. No real customer, vendor, employee,
or financial information from any actual company is included or referenced.*
