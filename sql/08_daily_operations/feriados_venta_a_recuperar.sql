/* =============================================================================
   feriados_venta_a_recuperar.sql
   -----------------------------------------------------------------------------
   Módulo:        08 · Operaciones diarias
   Objetivo:      Cuantificar el monto de venta perdida por ruta cuando un
                  feriado interrumpe el reparto normal, para alimentar el
                  plan de recupero de la siguiente jornada.

   El problema:   Las rutas tienen días fijos de visita (DiaRep). Cuando un
                  feriado cae en martes, todas las rutas que reparten ese día
                  pierden su jornada de venta. Comercial necesita saber, por
                  cada ruta, cuánto facturaba "un martes promedio" para
                  reasignar bidones y priorizar el día siguiente.

   Insight clave:  El promedio "típico" NO es el de cualquier día — es el
                  del MISMO día de la semana. Una ruta de lunes vende muy
                  distinto a una de viernes. El cálculo correcto compara
                  manzanas con manzanas: martes feriado vs martes promedio.

   Consolidación de 2 reportes:
                  Este script reemplaza el flujo histórico en 2 queries
                  separadas (una para promedio semanal a 2 meses, otra para
                  el día específico). Acá hacemos todo en una pasada con
                  filtros condicionales en agregación.

   Parámetros:    @FeriadoFecha — la fecha del feriado a analizar
                  @VentanaMeses — meses hacia atrás para el promedio

   Salida:        Una fila por ruta:
                  - PromedioDiaSemana → lo que normalmente vende ese día
                  - VtaFeriado        → lo que efectivamente vendió ese día
                  - ARecuperar        → diferencia (venta perdida)
                  - PctRecupero       → ratio de impacto

   Técnicas SQL:  Agregación condicional con CASE WHEN, DATEPART para
                  alineación de día-de-semana, JOIN multi-CTE,
                  NULLIF para protección de división.
   
   Performance:   ~120 rutas activas · <1 seg
============================================================================= */

-- =============================================================================
-- PARÁMETROS
-- =============================================================================
DECLARE @FeriadoFecha  DATE = '2026-05-01';                       -- 1° de Mayo (Día del Trabajador)
DECLARE @VentanaMeses  INT  = 2;                                  -- lookback para el promedio
DECLARE @VentanaDesde  DATE = DATEADD(MONTH, -@VentanaMeses, @FeriadoFecha);
DECLARE @DiaSemana     INT  = DATEPART(WEEKDAY, @FeriadoFecha);   -- 1=domingo, 2=lunes, etc.


;WITH BaseDiaria AS (
    /* Venta diaria agregada por (Fecha, Ruta) durante la ventana de lookback,
       hasta el día anterior al feriado (no incluye el feriado).
       Solo cuenta productos con litros (excluye servicios) y precio > 0
       (excluye promos de cortesía que no representan venta real). */
    SELECT
        CAST(P.Fecha_Pedido AS date)                          AS Fecha,
        DATEPART(WEEKDAY, P.Fecha_Pedido)                     AS DiaSemana,
        P.idVendedor                                          AS Ruta,
        SUM(PP.Cantidad)                                      AS Cantidad,
        SUM(PP.Cantidad * 1.0 / NULLIF(PR.cantidad_x_bulto, 0)) AS Bultos,
        SUM(PP.Cantidad * PR.Litros)                          AS Litros,
        SUM(CASE WHEN PP.Precio > 0 
                 THEN PP.Cantidad * PP.Precio 
                 ELSE 0 END)                                  AS Consumo
    FROM       [H2O_JUMI_DEMO].[dbo].Pedidos             P  WITH (NOLOCK)
    INNER JOIN [H2O_JUMI_DEMO].[dbo].PEDIDOS_PRODUCTOS   PP WITH (NOLOCK) ON P.IDPEDIDO    = PP.IDPEDIDO
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].Productos           PR WITH (NOLOCK) ON PP.idProducto = PR.idProducto
    WHERE P.Fecha_Pedido >= @VentanaDesde
      AND P.Fecha_Pedido <  DATEADD(DAY, 1, @FeriadoFecha)     -- incluye el feriado
      AND P.idCliente   <> 0
      AND PR.Litros     <> 0
    GROUP BY 
        CAST(P.Fecha_Pedido AS date),
        DATEPART(WEEKDAY, P.Fecha_Pedido),
        P.idVendedor
),

PromedioDiaSemana AS (
    /* Promedio de venta por ruta SOLO para el mismo día de la semana
       que el feriado. Ej: si el feriado fue martes, promediamos los
       martes anteriores. Esto evita comparar lunes (alto) con martes 
       (bajo) y desvirtuar la métrica. */
    SELECT
        Ruta,
        COUNT(*)                                              AS DiasIncluidos,
        AVG(Cantidad)                                         AS PromCantidad,
        AVG(Bultos)                                           AS PromBultos,
        AVG(Litros)                                           AS PromLitros,
        AVG(Consumo)                                          AS PromConsumo
    FROM BaseDiaria
    WHERE DiaSemana = @DiaSemana                                -- solo el mismo día de semana
      AND Fecha    <> @FeriadoFecha                             -- excluye el feriado del promedio
    GROUP BY Ruta
),

VtaFeriado AS (
    /* Venta efectiva del día feriado. Si la ruta no salió a repartir,
       no figurará acá → quedará como NULL en el LEFT JOIN final. */
    SELECT
        Ruta,
        Cantidad   AS FeriadoCantidad,
        Bultos     AS FeriadoBultos,
        Litros     AS FeriadoLitros,
        Consumo    AS FeriadoConsumo
    FROM BaseDiaria
    WHERE Fecha = @FeriadoFecha
)


-- =============================================================================
-- SALIDA: comparación lado a lado + cálculo de recupero
-- =============================================================================
SELECT
    P.Ruta,
    P.DiasIncluidos                                           AS DiasBaseProm,
    -- Métricas promedio del día-tipo
    CAST(P.PromConsumo AS DECIMAL(12, 2))                     AS PromedioConsumo,
    CAST(P.PromLitros  AS DECIMAL(12, 2))                     AS PromedioLitros,
    -- Métricas del día feriado (NULL si la ruta no salió)
    ISNULL(F.FeriadoConsumo, 0)                               AS VtaFeriadoConsumo,
    ISNULL(F.FeriadoLitros,  0)                               AS VtaFeriadoLitros,
    -- Cálculo de recupero
    CAST(P.PromConsumo - ISNULL(F.FeriadoConsumo, 0) 
         AS DECIMAL(12, 2))                                   AS ARecuperarConsumo,
    -- Ratio de recupero: % del promedio que faltó facturar
    CAST(100.0 * (P.PromConsumo - ISNULL(F.FeriadoConsumo, 0)) 
         / NULLIF(P.PromConsumo, 0) AS DECIMAL(5, 1))         AS PctRecupero
FROM      PromedioDiaSemana P
LEFT JOIN VtaFeriado        F ON F.Ruta = P.Ruta
WHERE P.DiasIncluidos >= 4                                     -- al menos 4 muestras para promedio confiable
ORDER BY ARecuperarConsumo DESC;                               -- rutas más impactadas primero
