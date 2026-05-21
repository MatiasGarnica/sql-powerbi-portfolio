# Synthetic data layer

This folder contains the reproducible synthetic dataset used by every SQL query
in this repository. **No real company data lives here or anywhere else in the repo.**

## Files

| File | Purpose |
|---|---|
| `generate_synthetic_data.py` | Python generator. Creates 21 CSV files (~115 MB) in `data/csv/`. |
| `load_to_sqlserver.sql` | Creates `H2O_JUMI_DEMO` database, all 21 tables, bulk-loads CSVs. |
| `csv/` *(gitignored)* | Generated CSVs — not committed, regenerate locally. |

## Setup (5–10 minutes)

### 1 · Generate CSVs

Requires Python 3.10+ on Windows, macOS, or Linux.

```bash
pip install faker pandas numpy
python generate_synthetic_data.py
```

Output goes to `./data/csv/` — 21 files, ~115 MB, ~5 minutes on a modern laptop.

### 2 · Load into SQL Server

Requires SQL Server 2017+ (Express or higher) and SSMS.

1. Copy the `data/csv/` folder to a path readable by the SQL Server service.
   On Windows, a typical safe choice: `C:\h2o_jumi_demo\data\csv\`
2. Give read permission on that folder to `NT Service\MSSQLSERVER`
   (or `NETWORK SERVICE` depending on your instance).
3. Open `load_to_sqlserver.sql` in SSMS, verify the `@csv_path` variable points to
   your folder, then execute (F5).

The script creates the `H2O_JUMI_DEMO` database, defines the 21 tables, and
bulk-loads every CSV. Total time: 1–2 minutes.

### 3 · Verify

The script prints a row count per table at the end. Expected ballpark:

| Table | Approximate rows |
|---|---:|
| `Pedidos_Productos` | 935,000 |
| `Movimientos_Caja` | 570,000 |
| `Pedidos` | 425,000 |
| `MovTes` | 325,000 |
| `CtaCteVT` | 155,000 |
| `ClientesRutas` | 15,000 |
| `Clientes` | 14,000 |
| Others | < 5,000 |

## Anonymization mapping

Every PII or identifying field is replaced with a synthetic equivalent:

| Original field | Replacement strategy |
|---|---|
| `Clientes.Nombre` | `Faker('es_AR').name()` for individuals, `.company()` for businesses |
| `Clientes.Direcc` | `Faker('es_AR').street_address()` with occasional gated-community suffix |
| `Clientes.NrCUIT` | Format-valid Argentine CUIT with random digits |
| `Clientes.Telefn` / `EMails` | Random patterns, never real contact |
| `repartos.Descrp` | `"Supervisor Zona Norte/Sur/..."`, `"VND 0042"` |
| `ClientesServicios.Marca` | Generic `"COLD-TECH"` instead of real equipment brand |
| `Movimientos_Caja_Ajustes.Usuario` | `"JOB_FC"`, `"JOB_NC"`, `"JOB_AJUSTE"` |
| `MovTes.CodCpt` | Generic codes (`EFE`, `TRF`, `DIG`, `CHQ`) instead of provider names |

Routes, vendor codes, and product IDs preserve their **original numeric values**
so the queries that filter on specific codes (e.g., `WHERE idVendedor NOT IN (146, 147, ...)`)
work without modification.

## Configuration

Top-level constants in `generate_synthetic_data.py` control dataset size:

```python
SEED                = 42        # change to get a different dataset
N_CLIENTES_ACTIVOS  = 14_000
N_CLIENTES_BAJA     = 1_000
MESES_HISTORIA      = 24
PCT_FC              = 0.18      # % of customers with cold/hot equipment
PCT_BARRIO_CERRADO  = 0.06      # % in gated communities
```

## Schema reference

The dataset reproduces the schema of a real water-distribution operations
database with the following entity groups (see [`../docs/data_dictionary.md`](../docs/data_dictionary.md)
for full column-level reference):

- **Catalogs:** `CondPAGO`, `TiposCli`, `Categorias`, `ClientesAtrLis`, `CteVtas`, `CptTes`, `Productos`
- **Routing:** `Rutas`, `repartos`, `ClientesRutas`
- **Customers:** `Clientes`, `ClientesBaja`, `Clientes_Ctas_Madres_e_Hijas`
- **Equipment:** `ClientesServicios`, `Movimientos_Equipos`
- **Transactions:** `Pedidos`, `Pedidos_Productos`, `Movimientos_Caja`, `Movimientos_Caja_Ajustes`, `CtaCteVT`, `MovTes`
