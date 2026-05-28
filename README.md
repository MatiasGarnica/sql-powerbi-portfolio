# SQL · Power BI portfolio — Water distribution analytics

End-to-end BI portfolio built on a realistic operational dataset modeled
after a regional water-distribution company. Demonstrates production-grade
T-SQL, Power BI modeling, DAX measures, and the analytical thinking behind
each report — not just the code.

![Featured dashboard — Collections by Region](powerbi/screenshots/01_cobranzas_kpis.png)

[![SQL Server](https://img.shields.io/badge/SQL_Server-2017+-CC2927?logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/en-us/sql-server)
[![T-SQL](https://img.shields.io/badge/T--SQL-Advanced-336791?logo=postgresql&logoColor=white)](https://learn.microsoft.com/en-us/sql/t-sql/language-reference)
[![Power BI](https://img.shields.io/badge/Power_BI-Desktop-F2C811?logo=powerbi&logoColor=black)](https://powerbi.microsoft.com/)
[![DAX](https://img.shields.io/badge/DAX-Measures-F2C811?logo=powerbi&logoColor=black)](powerbi/measures.dax)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Made with Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)](data/generate_synthetic_data.py)

> 🇪🇸 [Leer en español](README.es.md)

---

## About this project

This repository reproduces, in a fully synthetic environment, the BI
infrastructure of a regional water-distribution operation: 14,000 active
customers across 7 regions, 24 months of order history, ~500k transactions,
and a fleet of cold/hot water dispensers tracked individually.

Every SQL query was designed against the **real production database** and
then carefully adapted for this synthetic version. Power BI dashboards
target specific operational decisions made daily by Treasury, Operations,
Marketing, and Sales leadership.

**No production data is exposed.** A Python generator builds the full
dataset from scratch (see [`data/`](data/)), making the entire portfolio
reproducible on any SQL Server instance.

---

## What's inside

| Layer | Content | Files |
|---|---|---|
| **Synthetic data** | Reproducible generator + bulk loader for 21 tables | [`data/`](data/) |
| **SQL queries** | 11 production-grade T-SQL queries across 8 modules | [`sql/`](sql/) |
| **Power BI** | 7 dashboards (11 pages), DAX measures, M code | [`powerbi/`](powerbi/) |
| **Documentation** | Data dictionary, technique guides | [`docs/`](docs/) |

---

## SQL modules — all populated

| # | Module | Star query | Techniques |
|---|---|---|---|
| 01 | [Acquisition](sql/01_acquisition/) | `altas_digital_rto.sql` | `ROW_NUMBER`, 4-way `UNION ALL`, promo classification |
| 02 | [Retention](sql/02_retention/) | `frio_calor_sin_consumo_60.sql` | State machine, `STUFF`+`FOR XML PATH`, priority ranking |
| 03 | [F/C Equipment](sql/03_fc_equipment/) | `consumo_litros_por_cliente_fc.sql` | Temporal vigency logic, derived ratios |
| 04 | [Financial Risk](sql/04_financial_risk/) | `deuda_gastro_por_ruta.sql` | Multi-source `UNION ALL`, accounting separation |
| 05 | [Segmentation](sql/05_segmentation/) | `clientes_barrios_cerrados.sql` | Pattern matching with `LIKE`, early-WHERE optimization |
| 06 | [Sales Performance](sql/06_sales_performance/) | `venta_mensual_por_comercial.sql` | Dynamic SQL, double `PIVOT`, temp tables with indexes |
| 07 | [Collections](sql/07_collections/) | `cobranzas_mensuales_por_ruta.sql` | `OUTER APPLY`, `REVERSE`+`PATINDEX` string parsing |
| 08 | [Daily Operations](sql/08_daily_operations/) | `feriados_venta_a_recuperar.sql` | Day-of-week alignment, consolidated KPI calculation |

---

## Featured dashboards

### F/C Equipment Retention Workflow

A daily workflow report replacing ~4 hours of manual Excel work with a
sub-5-second SQL query. For every customer with 60+ days of no consumption,
it classifies what happened this month: came back, equipment retrieved,
went silent, or flagged as a runaway.

![F/C Sin Consumo](powerbi/screenshots/04_frio_calor_sin_consumo.png)

→ [SQL source](sql/02_retention/frio_calor_sin_consumo_60.sql) · [Dashboard documentation](powerbi/README.md#2--fc-equipment-retention-workflow)

### Holiday Sales Recovery

When a holiday interrupts a delivery day, this report quantifies the
revenue gap to close on the next business day — by route, comparing
each route's actual sales on the holiday with its weekly average for
the same weekday.

![Venta a Recuperar](powerbi/screenshots/06_feriados_venta_recuperar.png)

→ [SQL source](sql/08_daily_operations/feriados_venta_a_recuperar.sql) · [Dashboard documentation](powerbi/README.md#4--holiday-sales-recovery)

### Customer Acquisitions by Channel

Distinguishes vanity acquisitions (high signup count, no follow-up
purchase) from true acquisitions (steady consumption) by route, week,
channel (Digital / Traditional) and promo type.

![Altas RTO Digital](powerbi/screenshots/07_altas_rto_digital.png)

→ [SQL source](sql/01_acquisition/altas_digital_rto.sql) · [Dashboard documentation](powerbi/README.md#5--customer-acquisitions--rto--digital-2-pages)

---

## Tech stack

```
Source        →  SQL Server 2017+
Modeling      →  Star schema · 21 tables (catalogs, routing, customers, equipment, transactions)
ETL           →  Power Query M (parameterized)
Measures      →  DAX (CALCULATE, FILTER, ALL, ADDCOLUMNS, TOPN, VAR/RETURN)
Visualization →  Power BI Desktop + Service
Data gen      →  Python 3.10+ (Faker, pandas, numpy)
```

---

## Repository structure

```
sql-powerbi-portfolio/
├── data/                         Reproducible synthetic dataset
│   ├── generate_synthetic_data.py   ← Generator (Python)
│   ├── load_to_sqlserver.sql        ← Bulk loader (T-SQL)
│   └── README.md                    ← Setup instructions
├── sql/                          11 queries across 8 modules
│   ├── 01_acquisition/
│   ├── 02_retention/
│   ├── 03_fc_equipment/
│   ├── 04_financial_risk/
│   ├── 05_segmentation/
│   ├── 06_sales_performance/
│   ├── 07_collections/
│   └── 08_daily_operations/
├── powerbi/                      Dashboards, measures, screenshots
│   ├── README.md                    ← 7 dashboards catalog
│   ├── measures.dax                 ← 14 DAX measures
│   └── screenshots/                 ← 11 anonymized PNGs
├── docs/                         Schema reference
│   └── data_dictionary.md           ← All 21 tables documented
├── README.md                     ← This file
├── README.es.md                  ← Spanish mirror
└── LICENSE                       ← MIT
```

---

## Quick start

```bash
git clone https://github.com/MatiasGarnica/sql-powerbi-portfolio.git
cd sql-powerbi-portfolio/data
pip install faker pandas numpy
python generate_synthetic_data.py
```

Then load into SQL Server with [`data/load_to_sqlserver.sql`](data/load_to_sqlserver.sql).
Detailed instructions in [`data/README.md`](data/README.md).

---

## Author

**Matías Garnica** — BI Analyst
[LinkedIn](https://www.linkedin.com/in/garnicamatias) · [Email](mailto:garnicamatias@outlook.es)

Available for opportunities in Buenos Aires, Argentina or remote.

---

## License

[MIT](LICENSE) — feel free to use any code as reference for your own portfolio.
