# Portfolio SQL & Power BI — Analytics de distribuidora de agua

> Ecosistema BI end-to-end para una distribuidora de agua y soda en Argentina.
> 14.000+ clientes activos, 500.000 pedidos al año, 8 regiones supervisadas.
> Queries de SQL Server que automatizaron reportería manual, dashboards de Power BI
> con medidas DAX custom — todo reproducible sobre datos sintéticos, sin exponer
> información real de la empresa.

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019+-CC2927?logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/en-us/sql-server)
[![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-F2C811?logo=powerbi&logoColor=black)](https://powerbi.microsoft.com)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white)](https://www.python.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

🌐 **[English version → README.md](README.md)**

---

## Contexto del negocio

Trabajo como analista de BI en una distribuidora de agua y soda en el AMBA. La
operación incluye:

- **14.000+ clientes activos** en 4 segmentos: Hogar, Gastronomía, Empresa, Institucional
- **230+ vendedores** distribuidos en 8 regiones con supervisor a cargo
- **Dos modelos de facturación**: Contado (pago inmediato) y Cuenta Corriente (30/60/90 días)
- **Equipos de Frío/Calor** instalados en el 18% de los clientes (modelo de alquiler)

Este repositorio contiene el trabajo de BI de los últimos 1-3 años: queries SQL
que automatizaron tareas manuales de reportería, dashboards de Power BI usados por
operaciones y finanzas, y la lógica dimensional detrás de los KPIs de adquisición,
retención, riesgo financiero y performance operativa.

## Stack técnico

| Capa | Tecnología | Uso |
|---|---|---|
| Base de datos | SQL Server (T-SQL) | CTEs, window functions, `OUTER APPLY`, SQL dinámico con `sp_executesql`, pivots |
| Reportería | Power BI Desktop | Transformaciones M (Power Query), medidas DAX, drill-through, bookmarks |
| Datos sintéticos | Python (Faker, pandas, numpy) | Dataset reproducible para uso público |

## Privacidad de datos

En este repositorio **nunca** se publican datos reales de la empresa. El código
incluye un generador en Python que produce 21 tablas con integridad referencial,
con exactamente el mismo esquema de producción pero con datos sintéticos:

| | Real (privado) | Sintético (público) |
|---|---|---|
| Nombres de clientes | Personas y empresas reales | Faker (es-AR) |
| Direcciones | Reales | Estilo argentino aleatorio |
| CUIT | Reales | Formato válido pero ficticios |
| Nombres de supervisores | Personas reales | "Supervisor Zona Norte/Sur/..." |
| Marcas de equipos | Marcas reales | Etiquetas genéricas |
| Códigos de procesos internos | Reales (`JOB 499`, etc.) | Genéricos (`JOB_FC`, `JOB_NC`) |
| Métodos de cobranza | Nombres de proveedores reales | Códigos genéricos (`EFE`, `TRF`, `DIG`) |

Ver [`data/README.md`](data/README.md) para el mapeo completo y setup.

## Estructura del repositorio

```
sql-powerbi-portfolio/
├── data/                     Generador de datos sintéticos y loader de SQL Server
├── sql/                      Queries de producción agrupadas por módulo de negocio
│   ├── 01_acquisition/       Activación de nuevos clientes, primera compra
│   ├── 02_retention/         Workflow de 60 días sin consumo, detección de recompra
│   ├── 03_fc_equipment/      Productividad y consumo de equipos de F/C
│   ├── 04_financial_risk/    Análisis de deuda por ruta y segmento
│   ├── 05_segmentation/      Barrios cerrados, hogar vs empresa
│   ├── 06_sales_performance/ Venta mensual por comercial, pivot histórico 24 meses
│   ├── 07_collections/       Movimientos de tesorería, deuda, métodos de pago
│   └── 08_daily_operations/  Recupero de feriados, comparativa diaria
├── powerbi/                  Archivos del proyecto Power BI, medidas DAX, screenshots
└── docs/                     Diccionario de datos, ERD, glosario de negocio
```

## Módulos analíticos

### 1 · Adquisición de clientes
Identifica clientes nuevos que efectivamente convirtieron (primera compra paga
dentro de los 60 días del alta). Distingue canales: 2x1, prueba gratis, referido,
digital. Alimenta los reportes semanales de KPIs de adquisición.

**Técnicas:** `ROW_NUMBER()` sobre joins cliente-hecho, CASE multi-condición para
clasificación de promos, OUTER APPLY para lookup de primera línea de producto.

### 2 · Retención de clientes
Detecta clientes con 60+ días sin consumo y enriquece cada caso con el *motivo*
(recompró, retiraron el equipo, fugó, corrección interna) leyendo los eventos
transaccionales posteriores. Reemplazó un proceso manual de Excel de 4 horas
con una query de 15 segundos.

**Técnicas:** máquina de estados con CASE complejo, `LEAD()`/`LAG()` para secuencias,
composición multi-CTE.

### 3 · Productividad de equipos F/C
Tracking del parque instalado de dispensers, consumo mensual por modelo, y
movimientos de alta/baja. Se usa para conciliación mensual de inventario.

**Técnicas:** `OUTER APPLY` para último-evento-por-equipo, joins NULL-aware,
joins con tabla calendario.

### 4 · Riesgo financiero
Aging de deuda por ruta combinando atrasos de contado y saldos de cuenta corriente.
Marca exposición de cuentas grandes e identifica rutas con eficiencia de
cobranza bajo umbral.

**Técnicas:** `UNION ALL` de dos fuentes transaccionales, subqueries correlacionadas,
window functions de aging.

### 5 · Segmentación de clientes
Parseo geográfico para identificar clientes en barrios cerrados (vía LIKE sobre
`Direcc`), clasificación hogar vs empresa (vía atributos), targeting de gastronomía.

**Técnicas:** CASE en capas, pattern matching, joins con tablas de atributos.

### 6 · Performance de ventas
Pivot de ventas mensuales por vendedor y producto sobre ventanas móviles de 24 meses,
con generación dinámica de columnas vía `sp_executesql`. Alimenta el dashboard
ejecutivo.

**Técnicas:** SQL dinámico, operador `PIVOT`, agregación condicional.

### 7 · Cobranzas
Reportería mensual de tesorería por región, desglose por método de pago
(efectivo, transferencia, digital, cheque, retención), aging de deuda.

**Técnicas:** consolidación multi-fuente, joins dimensionales con métodos de pago,
cálculos de saldo acumulado.

### 8 · Operación diaria
Análisis de recupero de feriados (compara la venta del mismo día de la semana
anterior para estimar tasa de recupero por ruta), deltas día vs mismo día semana
anterior.

**Técnicas:** aritmética de fechas, grano vendedor-día, cálculo de tasa de recupero.

## Quick start

```bash
# 1. Clonar
git clone https://github.com/MatiasGarnica/sql-powerbi-portfolio.git
cd sql-powerbi-portfolio

# 2. Generar datos sintéticos
pip install faker pandas numpy
cd data
python generate_synthetic_data.py

# 3. Cargar a SQL Server (requiere SSMS)
# Editar @csv_path en load_to_sqlserver.sql, después ejecutar en SSMS

# 4. Correr cualquier query
# Abrí cualquier .sql bajo sql/, las queries apuntan a [H2O_JUMI_DEMO].[dbo].[...]
```

Instrucciones completas en [`data/README.md`](data/README.md).

## Insights del dataset sintético

| Métrica | Valor |
|---|---|
| Días promedio del alta a primera compra paga (Gastronomía) | 12.9 |
| Altas mensuales de Gastronomía concretadas | 25-30 |
| Clientes con equipo F/C | 18% |
| Tasa de promo en primera compra | 25% |
| Ratio Contado vs Cta Cte | 78/22 |

## Autor

**Matías** — Analista de BI, Buenos Aires, Argentina

- 💼 [LinkedIn](https://github.com/MatiasGarnica)
- 📧 [Email](garnicamatias@outlook.es)

## Licencia

MIT — ver [LICENSE](LICENSE).

---

*Este portfolio usa datos sintéticos exclusivamente. No incluye ni referencia
información real de clientes, proveedores, empleados ni datos financieros
de ninguna empresa.*
