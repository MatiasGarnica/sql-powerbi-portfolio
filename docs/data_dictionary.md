# Data dictionary

Reference documentation for the 21 tables in the `H2O_JUMI_DEMO` schema.
Field-level detail with business meaning and example values.

> Conventions used below: **PK** = primary key. **FK** = foreign key.
> Types reflect the synthetic loader; the production source may differ in
> nullability and precision.

---

## Catalogs

### `CondPAGO` — Payment conditions
| Column | Type | Meaning |
|---|---|---|
| Codigo | INT, PK | 1=Contado, 2=CtaCte 30d, 3=CtaCte 60d, 4=CtaCte 90d |
| Descrp | CHAR(30) | Human-readable label |
| DiasCR | INT | Credit days (0 = cash) |

### `TiposCli` — Customer types
| Column | Type | Meaning |
|---|---|---|
| Codigo | VARCHAR(6), PK | `HOG`, `EMP`, `GAS`, `INS`, `GCT` |
| Descrp | VARCHAR(50) | Hogar, Empresa, Gastronomía, Institucional, Grandes Cuentas |
| IdListaPrecio | VARCHAR(6) | Price list assignment |

### `Categorias` — Customer segmentation
| Column | Type | Meaning |
|---|---|---|
| Categoria | VARCHAR(6), PK | `CAT-A` (Premium), `CAT-B` (Standard), `CAT-C` (Basic), `CAT-D` (Migrated) |
| Descripcion | VARCHAR(60) | Label |

### `ClientesAtrLis` — Attribute lookup values
| Column | Type | Meaning |
|---|---|---|
| AtrNro | INT | Which `Clientes.AtribN` this row describes (typically 5) |
| AtrCod | VARCHAR(50) | Code stored in `Clientes.AtribN` |
| AtrDes | VARCHAR(250) | Human-readable description |

### `CteVtas` — Sales document types
| Column | Type | Meaning |
|---|---|---|
| Codigo | VARCHAR(6), PK | `FACA`, `NCA`, `RECA`, `DI`, etc. |
| Descrp | CHAR(30) | FACTURA A / NOTA DE CREDITO / RECIBO / etc. |
| DebHab | CHAR(1) | `D` = debit movement, `H` = credit movement |

### `CptTes` — Treasury concepts (payment methods)
| Column | Type | Meaning |
|---|---|---|
| Codigo | CHAR(3), PK | `EFE`, `CHQ`, `TRF`, `DIG`, `TRJ`, `RET`, `CCB`, `CPA` |
| Descrp | CHAR(30) | Payment method label |
| DebHab | CHAR(1) | Movement direction |

### `Productos` — SKU catalog
| Column | Type | Meaning |
|---|---|---|
| idProducto | VARCHAR(6), PK | `E` (20L), `EM` (12L), `F` (10L), `FM` (5L), `m` (Soda), `AC` (Dispenser rent), etc. |
| Descripcion | VARCHAR(50) | Long name |
| Abreviatura | VARCHAR(10) | Short name for reports |
| Litros | NUMERIC(10,2) | Volume per unit (0 for services) |
| cantidad_x_bulto | INT | Units per bulk package |

---

## Routing

### `Rutas` — Delivery route definitions
| Column | Type | Meaning |
|---|---|---|
| Codigo | VARCHAR(6), PK | `R0001`, `R0002`, etc. |
| Descrp | CHAR(30) | Route label |
| Vnddor | INT, FK → `repartos.Codigo` | Assigned vendor |
| DiaRep | CHAR(10) | Day of week visited |

### `repartos` — Vendors, supervisors, technicians, special flags
| Column | Type | Meaning |
|---|---|---|
| Codigo | INT, PK | Integer route/vendor ID |
| Descrp | CHAR(100) | Name or label |
| CodSup | INT, FK → `repartos.Codigo` | Supervisor (self-referential) |
| Sucursal | VARCHAR(10) | Branch |

**Special route ranges:**
- `1–122`, `251–281`, `155–176`, `401–434`, `460–481`: active vendors
- `201–208`: regional supervisors (self-referencing `CodSup`)
- `146`: customers flagged as "fugados" (escaped without paying)
- `147`: internal accounting corrections
- `148–149`: bajas por deuda / voluntarias
- `179, 181, 186, 197, 198`: field technicians (no sales)
- `200`: incobrables (uncollectible)
- `440, 441`: warehouse routes

### `ClientesRutas` — Customer-to-route assignment
| Column | Type | Meaning |
|---|---|---|
| CdRuta | VARCHAR(6), FK → `Rutas.Codigo` | Assigned route |
| Cliente_Ruteo | NUMERIC(15,0), FK → `Clientes.NroCta` | Customer |
| Estado | NUMERIC(1,0) | 1 = active, 0 = inactive |

---

## Customers

### `Clientes` — Active customers (64 columns; key ones below)
| Column | Type | Meaning |
|---|---|---|
| NroCta | NUMERIC(15,0), PK | Customer account number |
| Nombre, Direcc, Telefn, EMails, NrCUIT | VARCHAR | PII (anonymized in this repo) |
| CndPag | INT, FK → `CondPAGO.Codigo` | Cash or credit |
| TipCli | VARCHAR(6), FK → `TiposCli.Codigo` | Segment |
| Categoria | VARCHAR(6), FK → `Categorias.Categoria` | Premium/Standard/etc. |
| FecAlt | DATETIME | Registration date |
| Atrib1 | VARCHAR(50) | `1` = Hogar, `0` = non-Hogar |
| Atrib5 | VARCHAR(50), FK → `ClientesAtrLis.AtrCod` | Sub-segment code |

### `ClientesBaja` — Discharged customers
Mirrors `Clientes` plus `FecBaj` (discharge date) and `IdMotivo` (reason code).

### `Clientes_Ctas_Madres_e_Hijas` — Parent-child account hierarchy
| Column | Type | Meaning |
|---|---|---|
| IdCliente | NUMERIC(15,0) | Child account |
| Cta_Madre | NUMERIC(15,0) | Parent account |

Used for multi-location corporate customers where one parent account receives
the consolidated invoice for several physical locations.

---

## Equipment

### `ClientesServicios` — Installed equipment (cold/hot dispensers)
| Column | Type | Meaning |
|---|---|---|
| IdCliente | NUMERIC(15,0), FK → `Clientes.NroCta` | Customer with equipment |
| Marca, Modelo | VARCHAR(30) | Equipment make and model |
| Nro_Serie | VARCHAR(30), PK component | Serial number |
| Fecha_Desde | DATETIME | Installation date |
| Fecha_Baja | DATETIME | Retirement date (NULL = still installed) |

### `Movimientos_Equipos` — Equipment events (install, retrieve, swap)
| Column | Type | Meaning |
|---|---|---|
| IdMovimiento | NUMERIC(15,0), PK | Event ID |
| Tipo_Movimiento | CHAR(1) | `I` = Install, `R` = Retrieve, `C` = Swap |
| Fecha, IdCliente, Nro_Serie | — | Self-explanatory |

---

## Transactions

### `Pedidos` — Sales orders (header)
| Column | Type | Meaning |
|---|---|---|
| idPedido | DECIMAL(15,0), PK | Order ID |
| idCliente | DECIMAL(15,0), FK → `Clientes.NroCta` | Customer |
| idVendedor | INT, FK → `repartos.Codigo` | Vendor who placed the order |
| Fecha_Pedido | DATETIME | Order date |
| Status | VARCHAR(2) | `PR` = processed, others depending on flow |

### `Pedidos_Productos` — Order line items
| Column | Type | Meaning |
|---|---|---|
| idPedido | FK → `Pedidos.idPedido` | Order |
| idProducto | FK → `Productos.idProducto` | Product |
| Cantidad, Precio | DECIMAL | Quantity and unit price |
| TIPOBONIFICACION | VARCHAR(1) | `0` = normal, `P` = sin cargo, `B` = 2x1 promo |

### `Movimientos_Caja` — Cash transactions
Tracks Su Compra / Su Pago pairs for cash customers (CndPag=1). Every cash
sale creates one row; the matching payment creates a second row with negative
`Importe`.

### `Movimientos_Caja_Ajustes` — Cash adjustments (FC equipment, manual corrections)
The `Usuario` column indicates the source: `JOB_FC` (equipment rental billing),
`JOB_NC` (credit note auto-generation), `JOB_AJUSTE` (manual correction).

### `CtaCteVT` — Credit account ledger
Document-level current account movements (factura, recibo, NC) for credit
customers. `CodApl` and `NroApl` link recibos and NCs back to their applied
facturas.

### `MovTes` — Treasury movements
Records how money came in: cash, check, transfer, digital wallet, etc.
The `CodCpt` field links to `CptTes` for the payment method breakdown.
