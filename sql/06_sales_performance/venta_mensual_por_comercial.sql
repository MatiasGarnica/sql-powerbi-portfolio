/* =============================================================================
   venta_mensual_por_comercial.sql
   -----------------------------------------------------------------------------
   Módulo:        06 · Performance de ventas
   Objetivo:      Reporte pivotado de venta de los últimos 24 meses, con
                  dos métricas por mes (cantidad de litros + facturación $)
                  al nivel grain Cliente × Ruta × Producto.

   Estructura de salida:
                  | NroCta | Nombre | Ruta | Producto | ... 
                  | 2024-06 CANT | 2024-06 FACT | 2024-07 CANT | 2024-07 FACT | ...
                  | 2026-05 CANT | 2026-05 FACT |

   Cómo se usa:   Alimenta el dashboard ejecutivo de Performance Comercial.
                  Permite ver evolución de cada cliente a lo largo de 2 años
                  en una sola fila → comparable mes a mes, identificación de
                  caídas/crecimientos, segmentación por estacionalidad.

   Patrón arquitectónico clave — "Inversión de flujo":
                  El reflejo natural sería: arrancar de Clientes y JOIN a
                  Pedidos. Acá invertimos: arrancamos de Pedidos
                  (#VENTAS) y derivamos el universo de Clientes con venta
                  real (#CLIENTES_ACTIVOS). Beneficios:
                    - Universo acotado (solo clientes con actividad real)
                    - Evita subquery costosa de filtrado
                    - Mejor cardinalidad en los JOINs subsiguientes
                    - Cardinalidad estimada por el optimizador es más precisa

   Técnicas SQL:  CTE recursivo (calendario de meses), temp tables con
                  índices, dynamic SQL con sp_executesql, doble PIVOT (
                  cantidades + facturación), generación dinámica de
                  columnas via STUFF + FOR XML PATH, ISNULL para celdas
                  faltantes, inversión de flujo para performance.

   Performance:   ~14k clientes × ~10 productos × 24 meses = ~3.4M celdas
                  en el resultado pivotado · ~15 seg en SQL Server Express
============================================================================= */

SET NOCOUNT ON;

-- =============================================================================
-- VENTANA: últimos 24 meses cerrados
-- =============================================================================
DECLARE @Hasta DATE = EOMONTH(GETDATE(), -1);                   -- último día del mes anterior
DECLARE @Desde DATE = DATEFROMPARTS(
                        YEAR (DATEADD(MONTH, -23, @Hasta)),
                        MONTH(DATEADD(MONTH, -23, @Hasta)), 1);  -- primer día, 23 meses atrás


-- =============================================================================
-- 1) CALENDARIO de 24 meses (CTE recursivo materializado en temp)
-- =============================================================================
;WITH Cal AS (
    SELECT DATEFROMPARTS(YEAR(@Desde), MONTH(@Desde), 1) AS Mes
    UNION ALL
    SELECT DATEADD(MONTH, 1, Mes) 
    FROM Cal 
    WHERE DATEADD(MONTH, 1, Mes) <= @Hasta
)
SELECT Mes INTO #Cal FROM Cal OPTION (MAXRECURSION 0);


-- =============================================================================
-- 2) VENDEDORES habilitados: tabla en memoria, mucho más eficiente que IN gigante
-- =============================================================================
-- En producción la lista contiene ~260 códigos de vendedores comerciales activos.
-- Acá usamos un subset representativo que cubre los rangos del dataset sintético:
--   1-122    → Hogar/Empresa core
--   155-176  → Gastronomía
--   242      → Gastro La Plata
--   251-281  → Región Plata
--   401-434  → Región Norte
-- (Excluidos: 146-149 operativos, 179-198 técnicos, 200 incobrables, 440-441 almacenes)
CREATE TABLE #Vendedores (IdVendedor INT PRIMARY KEY);
INSERT INTO #Vendedores (IdVendedor)
SELECT v FROM (VALUES
    (1),(2),(3),(4),(5),(10),(15),(20),(25),(30),(40),(50),(60),(70),(80),(90),(100),(110),(120),
    (155),(157),(158),(159),(160),(163),(164),(165),(170),(172),(173),(174),(175),(176),(242),
    (251),(260),(265),(270),(275),(281),
    (401),(410),(415),(420),(425),(430),(434),(460),(475),(481)
) v(v);


-- =============================================================================
-- 3) HECHO PRIMARIO: ventas agregadas por Cliente × Ruta × Producto × Mes
-- =============================================================================
SELECT
    P.idCliente                                                  AS NroCta,
    P.idVendedor                                                 AS Ruta,
    PP.idProducto,
    PR.Abreviatura,
    DATEFROMPARTS(YEAR(P.Fecha_Pedido), MONTH(P.Fecha_Pedido),1) AS Mes,
    SUM(PP.Cantidad * PR.Litros)                                 AS Cantidad,         -- litros
    SUM(PP.Cantidad * PP.Precio)                                 AS Facturacion       -- $
INTO #VENTAS
FROM       [H2O_JUMI_DEMO].[dbo].Pedidos              P  WITH (NOLOCK)
INNER JOIN [H2O_JUMI_DEMO].[dbo].PEDIDOS_PRODUCTOS    PP WITH (NOLOCK) ON PP.IDPEDIDO   = P.IDPEDIDO
INNER JOIN [H2O_JUMI_DEMO].[dbo].Productos            PR WITH (NOLOCK) ON PR.idProducto = PP.idProducto
INNER JOIN #Vendedores                                V              ON V.IdVendedor   = P.idVendedor
WHERE P.Fecha_Pedido BETWEEN @Desde AND @Hasta
  AND PR.Litros <> 0                                                                  -- excluye servicios
  AND PP.Precio  > 0                                                                  -- excluye promos sin cargo
GROUP BY P.idCliente, P.idVendedor, PP.idProducto, PR.Abreviatura,
         DATEFROMPARTS(YEAR(P.Fecha_Pedido), MONTH(P.Fecha_Pedido),1);

CREATE CLUSTERED INDEX IX_Ventas ON #VENTAS(NroCta, idProducto, Mes);


-- =============================================================================
-- 4) UNIVERSO DE CLIENTES con venta real (DISTINCT desde el hecho)
--    Inversión de flujo: derivamos clientes desde la venta, no al revés.
-- =============================================================================
SELECT DISTINCT NroCta
INTO #CLIENTES_ACTIVOS
FROM #VENTAS;

CREATE UNIQUE CLUSTERED INDEX IX_CliAct ON #CLIENTES_ACTIVOS(NroCta);


-- =============================================================================
-- 5) ENRIQUECIMIENTO DE CLIENTES (atributos, deudas, equipos F/C)
--    Solo procesa clientes con venta real → mucho más liviano.
-- =============================================================================
;WITH UnicoCliente AS (
    /* Unifica Activos + Bajas, filtra al universo con venta real. */
    SELECT C.NroCta, C.Nombre, C.Direcc AS Direccion, C.FecAlt,
           CAST(0 AS INT)              AS FecBaj,
           TC.Descrp                   AS TipCli, 
           CP.Codigo                   AS CndPagCod,
           CP.Descrp                   AS MediodePago,
           ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS rn
    FROM       [H2O_JUMI_DEMO].[dbo].Clientes C  WITH (NOLOCK)
    INNER JOIN #CLIENTES_ACTIVOS              CA             ON CA.NroCta = C.NroCta
    INNER JOIN [H2O_JUMI_DEMO].[dbo].CondPAGO CP WITH (NOLOCK) ON C.CndPag = CP.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].TiposCli TC WITH (NOLOCK) ON C.TipCli = TC.Codigo

    UNION ALL

    SELECT C.NroCta, C.Nombre, C.Direcc, C.FecAlt,
           DATEDIFF(DAY, '1900-01-01', C.FecBaj) AS FecBaj,
           TC.Descrp, CP.Codigo, CP.Descrp,
           ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC)
    FROM       [H2O_JUMI_DEMO].[dbo].ClientesBaja C  WITH (NOLOCK)
    INNER JOIN #CLIENTES_ACTIVOS                  CA             ON CA.NroCta = C.NroCta
    INNER JOIN [H2O_JUMI_DEMO].[dbo].CondPAGO     CP WITH (NOLOCK) ON C.CndPag = CP.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].TiposCli     TC WITH (NOLOCK) ON C.TipCli = TC.Codigo
    WHERE C.FecBaj >= @Desde
),
DeudaContadoSrc AS (
    SELECT IdCliente, SUM(Importe) AS D 
    FROM [H2O_JUMI_DEMO].[dbo].Movimientos_Caja_Ajustes WITH (NOLOCK)
    GROUP BY IdCliente
    UNION ALL
    SELECT IdCliente, SUM(Importe) 
    FROM [H2O_JUMI_DEMO].[dbo].Movimientos_Caja WITH (NOLOCK)
    GROUP BY IdCliente
),
DeudaContado AS (
    /* Joineamos con #CLIENTES_ACTIVOS para descartar deudas de clientes
       sin venta en la ventana → reduce el set a procesar. */
    SELECT D.IdCliente, SUM(D.D) AS DeudaContado
    FROM       DeudaContadoSrc D
    INNER JOIN #CLIENTES_ACTIVOS CA ON CA.NroCta = D.IdCliente
    GROUP BY D.IdCliente
),
DeudaCtaCte AS (
    SELECT CC.NroCta AS IdCliente, ISNULL(SUM(CC.Import), 0) AS DeudaCtaCte
    FROM       [H2O_JUMI_DEMO].[dbo].CtaCteVT CC WITH (NOLOCK)
    INNER JOIN #CLIENTES_ACTIVOS              CA            ON CA.NroCta = CC.NroCta
    GROUP BY CC.NroCta
),
FC_ACTIVOS AS (
    SELECT CS.IdCliente AS NroCta, COUNT(DISTINCT CS.Nro_Serie) AS Q_FC
    FROM       [H2O_JUMI_DEMO].[dbo].ClientesServicios CS WITH (NOLOCK)
    INNER JOIN #CLIENTES_ACTIVOS                       CA             ON CA.NroCta = CS.IdCliente
    WHERE CS.Fecha_Baja  IS NULL
      AND CS.Fecha_Desde <= @Hasta
    GROUP BY CS.IdCliente
)
SELECT
    UC.NroCta, UC.Nombre, UC.Direccion, UC.FecAlt, UC.FecBaj,
    UC.MediodePago,
    -- Códigos CondPAGO en demo: 1 = Contado, 2/3/4 = Cuenta Corriente 30/60/90 días
    IIF(UC.CndPagCod  = 1,           IIF(ISNULL(DC.DeudaContado, 0) < 0, 0, ISNULL(DC.DeudaContado, 0)), 0) AS DeudaContado,
    IIF(UC.CndPagCod IN (2, 3, 4),   IIF(ISNULL(DT.DeudaCtaCte,  0) < 0, 0, ISNULL(DT.DeudaCtaCte,  0)), 0) AS DeudaCtaCte,
    UC.TipCli         AS CATEGORIA,
    ISNULL(FC.Q_FC, 0) AS Q_FC
INTO #DIMCLIENTE
FROM      UnicoCliente UC
LEFT JOIN DeudaContado DC ON DC.IdCliente = UC.NroCta
LEFT JOIN DeudaCtaCte  DT ON DT.IdCliente = UC.NroCta
LEFT JOIN FC_ACTIVOS   FC ON FC.NroCta    = UC.NroCta
WHERE UC.rn = 1;

CREATE UNIQUE CLUSTERED INDEX IX_DimCli ON #DIMCLIENTE(NroCta);


-- =============================================================================
-- 6) COLUMNAS DINÁMICAS para el PIVOT
--    Generamos dos strings: uno simple para el PIVOT, otro pareado
--    (CANT + FACT por mes) para el SELECT final.
-- =============================================================================

-- @cols → "[2024-06],[2024-07],...,[2026-05]"
DECLARE @cols nvarchar(max) =
    STUFF((
        SELECT ',' + QUOTENAME(CONVERT(varchar(7), Mes, 120))
        FROM #Cal 
        ORDER BY Mes
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 1, '');

-- @cols_pairs → ", ISNULL(pQ.[2024-06],0) AS [2024-06 CANT], ISNULL(pF.[2024-06],0) AS [2024-06 FACT], ..."
DECLARE @cols_pairs nvarchar(max) =
    STUFF((
        SELECT
            ', ISNULL(pQ.' + QUOTENAME(CONVERT(varchar(7), Mes, 120)) + ',0) AS ' 
                           + QUOTENAME(CONVERT(varchar(7), Mes, 120) + ' CANT') +
            ', ISNULL(pF.' + QUOTENAME(CONVERT(varchar(7), Mes, 120)) + ',0) AS ' 
                           + QUOTENAME(CONVERT(varchar(7), Mes, 120) + ' FACT')
        FROM #Cal 
        ORDER BY Mes
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 2, '');


-- =============================================================================
-- 7) DYNAMIC SQL: doble PIVOT (cantidades + facturación) + JOIN final con dim cliente
-- =============================================================================
DECLARE @sql nvarchar(max) = N'
;WITH pQ AS (
    SELECT NroCta, Ruta, idProducto, Abreviatura, ' + @cols + N'
    FROM (
        SELECT NroCta, Ruta, idProducto, Abreviatura,
               CONVERT(varchar(7), Mes, 120) AS Periodo, 
               Cantidad
        FROM #VENTAS
    ) s
    PIVOT (SUM(Cantidad) FOR Periodo IN (' + @cols + N')) pv
),
pF AS (
    SELECT NroCta, Ruta, idProducto, ' + @cols + N'
    FROM (
        SELECT NroCta, Ruta, idProducto,
               CONVERT(varchar(7), Mes, 120) AS Periodo, 
               Facturacion
        FROM #VENTAS
    ) s
    PIVOT (SUM(Facturacion) FOR Periodo IN (' + @cols + N')) pv
)
SELECT
    pQ.NroCta, dc.Nombre, pQ.Ruta, dc.Direccion, dc.FecAlt, dc.FecBaj,
    dc.MediodePago, dc.DeudaContado, dc.DeudaCtaCte, dc.CATEGORIA, dc.Q_FC,
    pQ.idProducto, pQ.Abreviatura' + @cols_pairs + N'
FROM       pQ
LEFT JOIN  pF          ON pF.NroCta = pQ.NroCta AND pF.Ruta = pQ.Ruta AND pF.idProducto = pQ.idProducto
LEFT JOIN  #DIMCLIENTE dc ON dc.NroCta = pQ.NroCta
ORDER BY pQ.NroCta, pQ.Ruta, pQ.idProducto;';

EXEC sp_executesql @sql;


-- =============================================================================
-- 8) CLEANUP
-- =============================================================================
DROP TABLE #Cal, #Vendedores, #VENTAS, #CLIENTES_ACTIVOS, #DIMCLIENTE;
