/* =============================================================================
   recompra_mensual.sql
   -----------------------------------------------------------------------------
   Módulo:        01 · Adquisición de clientes
   Objetivo:      Detecta la PRIMERA y la SEGUNDA compra histórica de cada
                  cliente para medir la retención temprana del canal.

                  Una alta sin segunda compra es un "lead disfrazado de
                  cliente": entró por una promo pero no volvió. Este reporte
                  permite cuantificar ese leak en la operación.

   Cómo se usa en Producción:
                  - Power BI calcula la métrica "Días a la 2da compra"
                    sobre este resultado y la grafica como cohort por mes
                    de alta.
                  - Comercial usa la lista de clientes con primera compra
                    pero sin segunda (LEFT JOIN devuelve NULL) para llamar
                    a recompra antes del día 30.

   Filtros típicos en producción:
                  - Listado de NroCta provisto por Power BI (cohort específico)
                  - Solo clientes con FecAlt en los últimos 3 meses
                  Acá omitimos esos filtros para demostrar la lógica sobre
                  todo el universo del dataset sintético.

   Salida:        Una fila por cliente con datos de su 1ra y 2da compra
                  (NULL en la 2da si todavía no recompró).

   Técnicas SQL:  ROW_NUMBER() para sequencing, CTE multi-nivel,
                  patrón de auto-rejoinable (PrimeraCompra + SegundaCompra
                  apuntan al mismo CTE filtrando por rn), LEFT JOIN para
                  preservar la cohort completa.
   
   Performance:   ~14k clientes activos sobre 424k pedidos · ~3 seg
============================================================================= */

;WITH UnicoCliente AS (
    /* Cliente + dimensiones. ROW_NUMBER() deduplica el JOIN con ClientesRutas
       en caso de múltiples rutas asignadas (toma la más reciente). */
    SELECT 
        C.NroCta,
        C.Nombre,
        C.Direcc,
        C.FecAlt,
        R.Vnddor,
        TC.Descrp        AS TipCli,
        CP.Descrp        AS CndPag,
        CAT.Descripcion  AS Categoria,
        ATR.AtrDes,
        ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS RowNum
    FROM       [H2O_JUMI_DEMO].[dbo].Clientes        C   WITH (NOLOCK)
    INNER JOIN [H2O_JUMI_DEMO].[dbo].ClientesRutas   CR  WITH (NOLOCK) ON C.NroCta    = CR.Cliente_Ruteo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Rutas           R   WITH (NOLOCK) ON CR.CdRuta   = R.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].CondPAGO        CP  WITH (NOLOCK) ON C.CndPag    = CP.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].TiposCli        TC  WITH (NOLOCK) ON C.TipCli    = TC.Codigo
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].Categorias      CAT WITH (NOLOCK) ON C.Categoria = CAT.Categoria
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].ClientesAtrLis  ATR WITH (NOLOCK) ON C.Atrib5    = ATR.AtrCod
    WHERE 
        C.NroCta <> 0
        AND C.Direcc <> 'AV. CENTRAL 1234'                          -- excluye depósito
        AND C.FecAlt > DATEFROMPARTS(YEAR(DATEADD(MONTH, -3, GETDATE())), 
                                     MONTH(DATEADD(MONTH, -3, GETDATE())), 1)
        /* En producción este bloque tiene una lista de NroCta provista por
           Power BI (cohort específico):
           AND C.NroCta IN (1209624, 1210674, 1210676, ...)
           Lo omitimos en la demo para que aplique a toda la base sintética. */
),

LineasConCargo AS (
    /* Todas las líneas históricas con cargo (precio > 0) sobre productos
       con litros > 0 — es decir, ventas reales de agua/soda, no servicios. */
    SELECT 
        P.idCliente,
        P.IDPEDIDO,
        CAST(P.Fecha_Pedido AS date) AS Fecha_Pedido,
        PP.Cantidad,
        PP.Precio
    FROM       [H2O_JUMI_DEMO].[dbo].Pedidos             P   WITH (NOLOCK)
    INNER JOIN [H2O_JUMI_DEMO].[dbo].PEDIDOS_PRODUCTOS   PP  WITH (NOLOCK) ON P.IDPEDIDO    = PP.IDPEDIDO
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].Productos           PR  WITH (NOLOCK) ON PP.idProducto = PR.idProducto
    WHERE PR.Litros > 0
      AND PP.Precio > 0
),

ComprasAgregadas AS (
    /* Una fila = una compra (un pedido). El importe es la suma de sus líneas. */
    SELECT
        L.idCliente,
        L.IDPEDIDO,
        L.Fecha_Pedido,
        SUM(L.Cantidad * L.Precio) AS ImportePedido
    FROM LineasConCargo L
    GROUP BY L.idCliente, L.IDPEDIDO, L.Fecha_Pedido
),

ComprasRankeadas AS (
    /* Ranking cronológico de compras por cliente. rn=1 es la primera,
       rn=2 es la segunda, etc. */
    SELECT
        C.*,
        ROW_NUMBER() OVER (PARTITION BY C.idCliente 
                           ORDER BY C.Fecha_Pedido, C.IDPEDIDO) AS rn
    FROM ComprasAgregadas C
),

PrimeraCompra AS (
    /* Primera compra: rn = 1 */
    SELECT 
        idCliente, 
        Fecha_Pedido  AS FechaPrimeraCompra, 
        ImportePedido AS ImportePrimeraCompra
    FROM ComprasRankeadas
    WHERE rn = 1
),

SegundaCompra AS (
    /* Segunda compra: rn = 2. NO todos los clientes tienen una.
       LEFT JOIN en el SELECT final preserva los que no recompraron. */
    SELECT 
        idCliente, 
        Fecha_Pedido  AS FechaSegundaCompra, 
        ImportePedido AS ImporteSegundaCompra
    FROM ComprasRankeadas
    WHERE rn = 2
)

SELECT
    UC.NroCta,
    UC.Nombre,
    UC.Direcc        AS Direccion,
    UC.FecAlt,
    UC.Vnddor        AS RUTA,
    UC.TipCli,
    UC.Categoria,
    UC.AtrDes        AS Atributo,
    UC.CndPag,

    PC.FechaPrimeraCompra,
    PC.ImportePrimeraCompra,

    SC.FechaSegundaCompra,        -- NULL si todavía no recompró
    SC.ImporteSegundaCompra,      -- NULL si todavía no recompró

    -- Métrica derivada útil para Power BI: días entre 1ra y 2da compra
    DATEDIFF(DAY, PC.FechaPrimeraCompra, SC.FechaSegundaCompra) AS DiasEntreCompras

FROM       UnicoCliente   UC
LEFT JOIN  PrimeraCompra  PC ON PC.idCliente = UC.NroCta
LEFT JOIN  SegundaCompra  SC ON SC.idCliente = UC.NroCta
WHERE UC.RowNum = 1
ORDER BY UC.NroCta;
