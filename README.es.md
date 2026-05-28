# SQL · Power BI portfolio — Analytics de distribución de agua

Portfolio end-to-end de Business Intelligence construido sobre un dataset
operativo realista modelado a partir de una empresa regional de distribución
de agua. Demuestra T-SQL de calidad productiva, modelado en Power BI,
medidas DAX y el razonamiento analítico detrás de cada reporte — no solo
el código.

![Tablero destacado — Cobranzas por Región](powerbi/screenshots/01_cobranzas_kpis.png)

[![SQL Server](https://img.shields.io/badge/SQL_Server-2017+-CC2927?logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/en-us/sql-server)
[![T-SQL](https://img.shields.io/badge/T--SQL-Avanzado-336791?logo=postgresql&logoColor=white)](https://learn.microsoft.com/en-us/sql/t-sql/language-reference)
[![Power BI](https://img.shields.io/badge/Power_BI-Desktop-F2C811?logo=powerbi&logoColor=black)](https://powerbi.microsoft.com/)
[![DAX](https://img.shields.io/badge/DAX-Medidas-F2C811?logo=powerbi&logoColor=black)](powerbi/measures.dax)
[![Licencia](https://img.shields.io/badge/licencia-MIT-blue.svg)](LICENSE)

> 🇬🇧 [Read in English](README.md)

---

## Sobre este proyecto

Este repositorio documenta mi trabajo como Analista Senior de Datos en una
operación regional de distribución de agua: la infraestructura de BI que
diseño y mantengo en producción — 14.000 clientes activos en 7 regiones,
24 meses de historia de pedidos, ~500.000 transacciones, y una flota de
dispensers de agua fría/calor trackeada individualmente.

**Qué es real vs. demo:**

- Las **queries SQL, medidas DAX y código Power Query M** son ejemplos
  funcionales adaptados de producción. Están anonimizados (nombres de
  tablas, columnas, reglas de negocio, códigos lookup) y corren contra
  el dataset sintético incluido en [`data/`](data/).
- Los **screenshots de los dashboards** son de los reportes de producción,
  con toda información confidencial (nombres de clientes, de supervisores,
  marcas, montos absolutos) redactada por blureo.
- Un **generador de dataset sintético** (con asistencia de IA, incluido
  para reproducibilidad) permite a cualquiera clonar el repo y ejecutar
  todas las queries localmente — sin necesidad de credenciales o datos
  productivos.

---

## Qué hay adentro

| Capa | Contenido | Archivos |
|---|---|---|
| **Datos sintéticos** | Generador reproducible + bulk loader de 21 tablas | [`data/`](data/) |
| **Queries SQL** | 11 queries de calidad productiva en 8 módulos | [`sql/`](sql/) |
| **Power BI** | 7 dashboards (11 páginas), medidas DAX, código M | [`powerbi/`](powerbi/) |
| **Documentación** | Diccionario de datos, guías de técnicas | [`docs/`](docs/) |

---

## Módulos SQL — todos completos

| # | Módulo | Query estrella | Técnicas |
|---|---|---|---|
| 01 | [Adquisición](sql/01_acquisition/) | `altas_digital_rto.sql` | `ROW_NUMBER`, `UNION ALL` de 4 bloques, clasificación de promos |
| 02 | [Retención](sql/02_retention/) | `frio_calor_sin_consumo_60.sql` | State machine, `STUFF`+`FOR XML PATH`, priorización |
| 03 | [Equipos F/C](sql/03_fc_equipment/) | `consumo_litros_por_cliente_fc.sql` | Lógica de vigencia temporal, ratios derivados |
| 04 | [Riesgo Financiero](sql/04_financial_risk/) | `deuda_gastro_por_ruta.sql` | `UNION ALL` multi-fuente, separación contable |
| 05 | [Segmentación](sql/05_segmentation/) | `clientes_barrios_cerrados.sql` | Pattern matching con `LIKE`, optimización con WHERE early |
| 06 | [Performance Comercial](sql/06_sales_performance/) | `venta_mensual_por_comercial.sql` | SQL dinámico, doble `PIVOT`, temp tables con índices |
| 07 | [Cobranzas](sql/07_collections/) | `cobranzas_mensuales_por_ruta.sql` | `OUTER APPLY`, parsing con `REVERSE`+`PATINDEX` |
| 08 | [Operaciones Diarias](sql/08_daily_operations/) | `feriados_venta_a_recuperar.sql` | Alineación por día de semana, KPI consolidado |

---

## Dashboards destacados

### Workflow de retención de equipos F/C

Un reporte de workflow diario que reemplaza ~4 horas de trabajo manual en
Excel con una query SQL de menos de 5 segundos. Para cada cliente con
60+ días sin consumo, clasifica qué pasó este mes: volvió a comprar,
le retiramos el equipo, sigue sin consumo, o quedó marcado como fugado.

![F/C Sin Consumo](powerbi/screenshots/04_frio_calor_sin_consumo.png)

→ [SQL fuente](sql/02_retention/frio_calor_sin_consumo_60.sql) · [Documentación del dashboard](powerbi/README.md#2--fc-equipment-retention-workflow)

### Venta a recuperar por feriados

Cuando un feriado interrumpe un día de reparto, este reporte cuantifica
el monto de venta a recuperar el día hábil siguiente — por ruta,
comparando lo efectivamente vendido el feriado contra el promedio
semanal del mismo día de la semana.

![Venta a Recuperar](powerbi/screenshots/06_feriados_venta_recuperar.png)

→ [SQL fuente](sql/08_daily_operations/feriados_venta_a_recuperar.sql) · [Documentación del dashboard](powerbi/README.md#4--holiday-sales-recovery)

### Altas de clientes por canal

Diferencia las altas "vanity" (alta de registración alta, sin consumo
posterior) de las altas reales (consumo sostenido) por ruta, semana,
canal (Digital / Tradicional) y tipo de promo.

![Altas RTO Digital](powerbi/screenshots/07_altas_rto_digital.png)

→ [SQL fuente](sql/01_acquisition/altas_digital_rto.sql) · [Documentación del dashboard](powerbi/README.md#5--customer-acquisitions--rto--digital-2-pages)

---

## Stack técnico

```
Origen        →  SQL Server 2017+
Modelado      →  Star schema · 21 tablas (catálogos, ruteo, clientes, equipos, transacciones)
ETL           →  Power Query M (parametrizado)
Medidas       →  DAX (CALCULATE, FILTER, ALL, ADDCOLUMNS, TOPN, VAR/RETURN)
Visualización →  Power BI Desktop + Service
```

---

## Estructura del repositorio

```
sql-powerbi-portfolio/
├── data/                         Dataset sintético reproducible
│   ├── generate_synthetic_data.py   ← Generador (Python)
│   ├── load_to_sqlserver.sql        ← Bulk loader (T-SQL)
│   └── README.md                    ← Instrucciones de setup
├── sql/                          11 queries en 8 módulos
│   ├── 01_acquisition/
│   ├── 02_retention/
│   ├── 03_fc_equipment/
│   ├── 04_financial_risk/
│   ├── 05_segmentation/
│   ├── 06_sales_performance/
│   ├── 07_collections/
│   └── 08_daily_operations/
├── powerbi/                      Dashboards, medidas, screenshots
│   ├── README.md                    ← Catálogo de 7 dashboards
│   ├── measures.dax                 ← 14 medidas DAX
│   └── screenshots/                 ← 11 PNGs anonimizados
├── docs/                         Referencia del modelo
│   └── data_dictionary.md           ← Las 21 tablas documentadas
├── README.md                     ← Espejo en inglés
├── README.es.md                  ← Este archivo
└── LICENSE                       ← MIT
```

---

## Inicio rápido

```bash
git clone https://github.com/MatiasGarnica/sql-powerbi-portfolio.git
cd sql-powerbi-portfolio/data
pip install faker pandas numpy
python generate_synthetic_data.py
```

Después cargás en SQL Server con [`data/load_to_sqlserver.sql`](data/load_to_sqlserver.sql).
Instrucciones detalladas en [`data/README.md`](data/README.md).

---

## Autor

**Matías Garnica** — BI Analyst
[LinkedIn](https://www.linkedin.com/in/garnicamatias) · [Email](mailto:garnicamatias@outlook.es)

---

## Licencia

[MIT](LICENSE) — usá el código que quieras como referencia para tu propio portfolio.
