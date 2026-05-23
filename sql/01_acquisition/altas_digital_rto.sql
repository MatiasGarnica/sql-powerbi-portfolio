/* =============================================================================
   altas_digital_rto.sql
   -----------------------------------------------------------------------------
   Módulo:        01 · Adquisición de clientes
   Objetivo:      Reporte unificado de altas de los últimos 3 meses, clasificadas
                  por canal de adquisición (DIGITAL vs RTO) y por tipo de promo
                  aplicada en la primera compra.

   Modelo de negocio:
                  - Canal RTO (Ruta Tradicional Operativa): el cliente entra
                    por la red de vendedores físicos. En la base real son las
                    categorías 1, 16, 18, 3, 57. En esta demo: CAT-A y CAT-B.
                  - Canal DIGITAL: el cliente se registra por la web/app.
                    En la base real son TODAS las categorías excepto las RTO
                    y un conjunto de excluidas (cuentas internas, etc).
                    En esta demo: CAT-C y CAT-D.
                  - Estado: combina clientes Activos (Clientes) con Bajas
                    (ClientesBaja) mediante UNION ALL. Permite a Marketing
                    medir altas brutas y a Comercial medir churn temprano.
                  - TipoPromo: clasifica la primera compra entre NORMAL,
                    SIN CARGO, 2x1/BONIF o SIN COMPRA (alta sin primer pedido).

   Salida:        Una fila por cliente con: ruta, estado, canal, primer pedido,
                  monto total del primer pedido y clasificación de promo.

   Técnicas SQL:  UNION ALL de 4 bloques (Activo×Digital, Baja×Digital,
                  Activo×RTO, Baja×RTO), CTE de FirstPedido con ROW_NUMBER,
                  agregación condicional para clasificación de promo,
                  LEFT JOIN para incluir altas sin primera compra.

   Performance:   ~2-5 seg sobre el dataset sintético
============================================================================= */

DECLARE @Desde date = DATEFROMPARTS(YEAR(DATEADD(MONTH, -3, GETDATE())),
                                     MONTH(DATEADD(MONTH, -3, GETDATE())), 1);
DECLARE @Hasta date = GETDATE();

-- Lista de rutas operativas a EXCLUIR (no son vendedores reales: técnicos,
-- almacenes, flags operativos como "fugados" o "incobrables")
-- En producción la lista real es mucho más larga; acá conservamos las
-- categorías que existen en el dataset sintético.
-- @RutasExcluidas: 146 (Fugados), 147 (Corrección Interna), 148 (Bajas por Deuda),
--                  149 (Bajas Voluntarias), 179, 181, 186, 197, 198 (Técnicos),
--                  200 (Incobrables), 440, 441 (Almacenes)


;WITH UnicoCliente AS (

    -- ─────────────────────────────────────────────────────────────────────────
    -- BLOQUE 1 · ACTIVOS · Canal DIGITAL
    -- ─────────────────────────────────────────────────────────────────────────
    SELECT 
        R.Vnddor                              AS RUTA,
        CONVERT(varchar(10), C.FecAlt, 103)   AS FECALT,
        CAST(NULL AS date)                    AS FecBaj,
        C.NroCta,
        'Activo'                              AS Estado,
        'Digital'                             AS Categoria,
        C.Nombre,
        C.Direcc,
        C.Telefn,
        CA.Descripcion,
        ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS RowNum
    FROM       [H2O_JUMI_DEMO].[dbo].Clientes        C  WITH (NOLOCK)
    LEFT JOIN  [H2O_JUMI_DEMO].[dbo].ClientesRutas   CR WITH (NOLOCK) ON C.NroCta    = CR.Cliente_Ruteo
    LEFT JOIN  [H2O_JUMI_DEMO].[dbo].Rutas           R  WITH (NOLOCK) ON CR.CdRuta   = R.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Categorias      CA WITH (NOLOCK) ON C.Categoria = CA.Categoria
    WHERE C.NroCta <> 0
      AND R.Vnddor NOT IN (146, 147, 148, 149, 179, 181, 186, 197, 198, 200, 440, 441)
      AND C.Categoria IN ('CAT-C', 'CAT-D')                   -- canal Digital en demo
      AND C.Direcc NOT LIKE '%AV. CENTRAL 1234%'              -- excluye depósito
      AND C.FecAlt >= @Desde

    UNION ALL

    -- ─────────────────────────────────────────────────────────────────────────
    -- BLOQUE 2 · BAJAS · Canal DIGITAL
    -- ─────────────────────────────────────────────────────────────────────────
    SELECT 
        R.Vnddor                              AS RUTA,
        CONVERT(varchar(10), C.FecAlt, 103)   AS FECALT,
        CAST(C.FecBaj AS date)                AS FecBaj,
        C.NroCta,
        'Baja'                                AS Estado,
        'Digital'                             AS Categoria,
        C.Nombre,
        C.Direcc,
        C.Telefn,
        CA.Descripcion,
        ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS RowNum
    FROM       [H2O_JUMI_DEMO].[dbo].ClientesBaja    C  WITH (NOLOCK)
    LEFT JOIN  [H2O_JUMI_DEMO].[dbo].Rutas           R  WITH (NOLOCK) ON C.CdRuta    = R.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Categorias      CA WITH (NOLOCK) ON C.Categoria = CA.Categoria
    WHERE C.NroCta <> 0
      AND R.Vnddor NOT IN (146, 147, 148, 149, 179, 181, 186, 197, 198, 200, 440, 441)
      AND C.Categoria IN ('CAT-C', 'CAT-D')
      AND C.Direcc NOT LIKE '%AV. CENTRAL 1234%'
      AND C.FecAlt >= @Desde

    UNION ALL

    -- ─────────────────────────────────────────────────────────────────────────
    -- BLOQUE 3 · ACTIVOS · Canal RTO (Reparto Tradicional)
    -- ─────────────────────────────────────────────────────────────────────────
    SELECT 
        R.Vnddor                              AS RUTA,
        CONVERT(varchar(10), C.FecAlt, 103)   AS FECALT,
        CAST(NULL AS date)                    AS FecBaj,
        C.NroCta,
        'Activo'                              AS Estado,
        'RTO'                                 AS Categoria,
        C.Nombre,
        C.Direcc,
        C.Telefn,
        CA.Descripcion,
        ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS RowNum
    FROM       [H2O_JUMI_DEMO].[dbo].Clientes        C  WITH (NOLOCK)
    LEFT JOIN  [H2O_JUMI_DEMO].[dbo].ClientesRutas   CR WITH (NOLOCK) ON C.NroCta    = CR.Cliente_Ruteo
    LEFT JOIN  [H2O_JUMI_DEMO].[dbo].Rutas           R  WITH (NOLOCK) ON CR.CdRuta   = R.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Categorias      CA WITH (NOLOCK) ON C.Categoria = CA.Categoria
    WHERE C.NroCta <> 0
      AND R.Vnddor NOT IN (146, 147, 148, 149, 179, 181, 186, 197, 198, 200, 440, 441)
      AND C.Categoria IN ('CAT-A', 'CAT-B')                   -- canal RTO en demo
      AND C.Direcc NOT LIKE '%AV. CENTRAL 1234%'
      AND C.FecAlt >= @Desde

    UNION ALL

    -- ─────────────────────────────────────────────────────────────────────────
    -- BLOQUE 4 · BAJAS · Canal RTO
    -- ─────────────────────────────────────────────────────────────────────────
    SELECT 
        R.Vnddor                              AS RUTA,
        CONVERT(varchar(10), C.FecAlt, 103)   AS FECALT,
        CAST(C.FecBaj AS date)                AS FecBaj,
        C.NroCta,
        'Baja'                                AS Estado,
        'RTO'                                 AS Categoria,
        C.Nombre,
        C.Direcc,
        C.Telefn,
        CA.Descripcion,
        ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS RowNum
    FROM       [H2O_JUMI_DEMO].[dbo].ClientesBaja    C  WITH (NOLOCK)
    LEFT JOIN  [H2O_JUMI_DEMO].[dbo].Rutas           R  WITH (NOLOCK) ON C.CdRuta    = R.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Categorias      CA WITH (NOLOCK) ON C.Categoria = CA.Categoria
    WHERE C.NroCta <> 0
      AND R.Vnddor NOT IN (146, 147, 148, 149, 179, 181, 186, 197, 198, 200, 440, 441)
      AND C.Categoria IN ('CAT-A', 'CAT-B')
      AND C.Direcc NOT LIKE '%AV. CENTRAL 1234%'
      AND C.FecAlt >= @Desde
),

FirstPedido AS (
    /* Numera los pedidos de cada cliente cronológicamente. rn=1 es la 1ra compra.
       Solo se consideran pedidos con productos de litros > 0 (agua/soda),
       para excluir movimientos de servicios o instalaciones. */
    SELECT
        P.idCliente,
        P.IDPEDIDO,
        P.Fecha_Pedido,
        ROW_NUMBER() OVER (
            PARTITION BY P.idCliente
            ORDER BY P.Fecha_Pedido, P.IDPEDIDO
        ) AS rn
    FROM       [H2O_JUMI_DEMO].[dbo].Pedidos             P  WITH (NOLOCK)
    INNER JOIN [H2O_JUMI_DEMO].[dbo].PEDIDOS_PRODUCTOS   PP WITH (NOLOCK) ON PP.IDPEDIDO    = P.IDPEDIDO
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Productos           PR WITH (NOLOCK) ON PR.idProducto = PP.idProducto
    WHERE PR.Litros > 0
),

PrimeraCompraTotal AS (
    /* Suma del importe de la primera compra y flag de si tuvo alguna línea
       a precio 0 (necesario para distinguir SIN CARGO de 2x1/BONIF). */
    SELECT
        FP.idCliente                                    AS NroCta,
        FP.IDPEDIDO,
        FP.Fecha_Pedido,
        SUM(PP.Cantidad * PP.Precio)                    AS TotalImportePedido,
        MAX(CASE WHEN PP.Precio = 0 THEN 1 ELSE 0 END)  AS TieneLineaPrecio0
    FROM       FirstPedido FP
    INNER JOIN [H2O_JUMI_DEMO].[dbo].PEDIDOS_PRODUCTOS PP WITH (NOLOCK) ON PP.IDPEDIDO    = FP.IDPEDIDO
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Productos         PR WITH (NOLOCK) ON PR.idProducto = PP.idProducto
    WHERE FP.rn = 1
      AND PR.Litros > 0
    GROUP BY FP.idCliente, FP.IDPEDIDO, FP.Fecha_Pedido
)

SELECT
    UC.RUTA,
    UC.FECALT,
    FECBAJ = CASE WHEN UC.FecBaj IS NULL THEN '0' ELSE CONVERT(varchar(10), UC.FecBaj, 103) END,
    UC.NroCta,
    UC.Estado,
    UC.Categoria,
    UC.Nombre, 
    UC.Direcc, 
    UC.Telefn,
    UC.Descripcion,
    PC.IDPEDIDO                          AS PrimerPedido,
    PC.Fecha_Pedido                      AS FechaPrimerPedido,
    PC.TotalImportePedido,
    PC.TieneLineaPrecio0,
    -- Clasificación final del tipo de promoción aplicada en la primera compra
    TipoPromo = CASE
        WHEN PC.IDPEDIDO            IS NULL              THEN 'SIN COMPRA'   -- alta sin primer pedido
        WHEN PC.TotalImportePedido = 0                   THEN 'SIN CARGO'    -- producto nativo gratis
        WHEN PC.TotalImportePedido > 0 
         AND PC.TieneLineaPrecio0  = 1                   THEN '2x1/BONIF'    -- promo parcial
        ELSE 'NORMAL'                                                         -- compra normal
    END
FROM       UnicoCliente UC
LEFT JOIN  PrimeraCompraTotal PC ON PC.NroCta = UC.NroCta
WHERE UC.RowNum = 1
ORDER BY UC.RUTA, UC.NroCta;
