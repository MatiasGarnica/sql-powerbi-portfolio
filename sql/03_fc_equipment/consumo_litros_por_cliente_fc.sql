/* =============================================================================
   consumo_litros_por_cliente_fc.sql
   -----------------------------------------------------------------------------
   Módulo:        03 · Productividad de equipos F/C
   Objetivo:      Para cada cliente con equipo de Frío/Calor instalado al
                  corte, calcula el consumo de litros (volumen físico) en
                  una ventana temporal definida.

                  Es el insumo principal del KPI de "productividad por
                  equipo": litros/mes que efectivamente se mueven por cada
                  dispenser instalado.

   Cómo se usa:   - Power BI lo grafica como ratio Litros/Equipo por mes
                  - Permite detectar clientes con equipo subutilizado
                    (candidatos a retiro para reasignar el equipo)
                  - Sirve como denominador de la métrica de eficiencia
                    de la flota instalada

   Lógica de "equipo vigente al corte":
                  Un equipo se considera vigente en @FechaCorte si cumple:
                    a) Fecha_Baja > @FechaCorte   AND  Fecha_Desde < @FechaCorte
                       (el equipo estaba activo durante el corte)
                    b) Fecha_Baja IS NULL         AND  Fecha_Desde < @FechaCorte
                       (el equipo sigue activo y se instaló antes del corte)

   Salida:        Una fila por cliente:
                  - NroCta
                  - Q_FC: cantidad de equipos F/C distintos
                  - ConsumoLitros: litros facturados en la ventana
                  - LitrosPorEquipo: ratio derivado (productividad real)

   Técnicas SQL:  CTE con HAVING para filtrar agregaciones, lógica de
                  vigencia temporal con OR, JOIN con tabla de productos
                  para acceder a la columna Litros (factor de conversión
                  unidades → volumen).

   Performance:   ~2.500 clientes con F/C sobre 935K líneas · <2 seg
============================================================================= */

-- =============================================================================
-- PARÁMETROS
-- =============================================================================
DECLARE @FechaCorte   date = '2026-05-01';   -- foto de equipos vigentes a esta fecha
DECLARE @ConsumoDesde date = '2026-04-01';   -- inicio ventana de consumo (inclusive)
DECLARE @ConsumoHasta date = '2026-05-01';   -- fin ventana de consumo (exclusive)


;WITH ClientesFC AS (
    /* Clientes con al menos 1 equipo F/C vigente al @FechaCorte.
       La doble condición OR cubre dos escenarios:
         - Equipo activo durante el corte (Baja posterior al corte)
         - Equipo sigue activo hoy (Baja IS NULL) */
    SELECT 
        CS.IdCliente,
        COUNT(DISTINCT CS.Nro_Serie) AS Q_FC
    FROM [H2O_JUMI_DEMO].[dbo].ClientesServicios CS WITH (NOLOCK)
    WHERE (CS.Fecha_Baja  >  @FechaCorte AND CS.Fecha_Desde < @FechaCorte)
       OR (CS.Fecha_Baja  IS NULL        AND CS.Fecha_Desde < @FechaCorte)
    GROUP BY CS.IdCliente
    HAVING COUNT(DISTINCT CS.Nro_Serie) > 0
)

SELECT 
    CFC.IdCliente                                   AS NroCta,
    CFC.Q_FC,
    SUM(PP.Cantidad * PR.Litros)                    AS ConsumoLitros,
    -- Métrica derivada útil para Power BI: productividad real por equipo
    CAST(SUM(PP.Cantidad * PR.Litros) * 1.0 
         / NULLIF(CFC.Q_FC, 0) AS DECIMAL(12, 2))   AS LitrosPorEquipo
FROM       ClientesFC                                CFC
INNER JOIN [H2O_JUMI_DEMO].[dbo].Pedidos             P  WITH (NOLOCK) ON P.idCliente    = CFC.IdCliente
INNER JOIN [H2O_JUMI_DEMO].[dbo].PEDIDOS_PRODUCTOS   PP WITH (NOLOCK) ON PP.IDPEDIDO    = P.IDPEDIDO
LEFT  JOIN [H2O_JUMI_DEMO].[dbo].Productos           PR WITH (NOLOCK) ON PP.idProducto = PR.idProducto
WHERE P.Fecha_Pedido >= @ConsumoDesde
  AND P.Fecha_Pedido <  @ConsumoHasta
  AND PR.Litros > 0                                  -- excluye servicios, instalaciones
GROUP BY CFC.IdCliente, CFC.Q_FC
ORDER BY ConsumoLitros DESC;                         -- top consumidores primero
