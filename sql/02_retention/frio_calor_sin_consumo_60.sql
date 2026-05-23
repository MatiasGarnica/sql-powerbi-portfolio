/* =============================================================================
   frio_calor_sin_consumo_60.sql
   -----------------------------------------------------------------------------
   Módulo:        02 · Retención de clientes
   Objetivo:      Workflow analítico de seguimiento de clientes con equipo de
                  Frío/Calor (F/C) instalado que llevan 60+ días sin consumo.
                  Para cada uno determina QUÉ pasó en el mes analizado:
                  recompró, le retiraron el equipo, hubo un cambio de equipo,
                  está marcado como fugado, fue corrección interna, o sigue
                  sin consumo.

   Impacto:       Reemplaza un proceso manual de Excel de ~4 horas mensuales
                  que cruzaba 6 reportes distintos. Hoy corre en <5 segundos
                  y alimenta el dashboard de retención de F/C.

   Lógica de eventos:
                  ┌─────┬──────────────┬─────────────────────────────────┐
                  │ Cód │ Origen       │ Significado                     │
                  ├─────┼──────────────┼─────────────────────────────────┤
                  │ E2  │ Pedidos      │ Volvió a comprar                │
                  │ E1  │ Mov.Equipos  │ Retiro técnico estándar         │
                  │ E3  │ Mov.Equipos  │ Retiro por fuga (Reparto 146)   │
                  │ E4  │ Mov.Equipos  │ Corrección interna (Reparto 147)│
                  │ EC  │ Mov.Equipos  │ Cambio (IdRecambio NOT NULL)    │
                  │ E5  │ (default)    │ Sigue sin consumo               │
                  └─────┴──────────────┴─────────────────────────────────┘

   Patrón ListaClientes:
                  En producción, Power BI exporta la cohort de "60+ días sin
                  consumo" como lista de NroCta y se pega como VALUES.
                  En esta demo, autogeneramos esa lista detectando los clientes
                  con equipo F/C activo sin pedidos en los 60 días previos a
                  la ventana de análisis.

   Salida:        Una fila por cliente con:
                  - Datos de contacto (Nombre, Direcc, Telefn)
                  - TipoEvento (E1-E5/EC) priorizado
                  - EstadoFinal (descripción human-readable)
                  - FechaEvento, IdReparto
                  - FlagConflicto: 1 si tuvo múltiples eventos distintos
                  - AccionesMes: string con TODOS los eventos ordenados

   Técnicas SQL:  UNION ALL de fuentes heterogéneas, CASE state machine,
                  STUFF + FOR XML PATH para string aggregation (patrón
                  pre-SQL Server 2017, compatible con versiones legacy),
                  ROW_NUMBER para priorización, COALESCE para defaults,
                  EXISTS correlacionado para auto-generar la cohort.

   Performance:   ~100-500 clientes en la cohort · <5 segundos
============================================================================= */

DECLARE @Mes   date = '2026-04-01';                           -- mes a analizar
DECLARE @Desde date = DATEFROMPARTS(YEAR(@Mes), MONTH(@Mes), 1);
DECLARE @Hasta date = DATEADD(MONTH, 1, @Desde);              -- límite exclusivo


;WITH ListaClientes AS (
    /* En PRODUCCIÓN esta CTE recibe una lista hardcoded de NroCta vía
       VALUES, exportada desde Power BI con la cohort "60+ días sin consumo":
       
           SELECT NroCta FROM (VALUES (392081), (149469), ...) V(NroCta)
       
       En la DEMO autogeneramos esa misma cohort: clientes con equipo F/C
       activo (sin Fecha_Baja) instalado hace más de 90 días, que NO tienen
       pedidos en los 60 días previos al @Desde. */
    SELECT DISTINCT CS.IdCliente AS NroCta
    FROM [H2O_JUMI_DEMO].[dbo].ClientesServicios CS WITH (NOLOCK)
    WHERE CS.Fecha_Baja IS NULL
      AND CS.Fecha_Desde <= DATEADD(DAY, -90, @Desde)
      AND NOT EXISTS (
          SELECT 1
          FROM [H2O_JUMI_DEMO].[dbo].Pedidos P
          WHERE P.idCliente     = CS.IdCliente
            AND P.Fecha_Pedido >= DATEADD(DAY, -60, @Desde)
            AND P.Fecha_Pedido <  @Desde
      )
),

BaseClientes AS (
    /* Unifica clientes Activos + Bajas (UNION ALL) y filtra rutas operativas
       que no son comerciales (técnicos, almacenes, flags). */
    SELECT C.NroCta, C.Nombre, C.Direcc, C.Telefn
    FROM       [H2O_JUMI_DEMO].[dbo].Clientes        C
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].ClientesRutas   CR WITH (NOLOCK) ON C.NroCta = CR.Cliente_Ruteo
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].Rutas           R  WITH (NOLOCK) ON CR.CdRuta = R.Codigo
    INNER JOIN ListaClientes                         LC                ON LC.NroCta = C.NroCta
    WHERE R.Vnddor NOT IN (146, 147, 148, 149, 179, 181, 186, 197, 198, 200, 440, 441)

    UNION ALL

    SELECT C.NroCta, C.Nombre, C.Direcc, C.Telefn
    FROM       [H2O_JUMI_DEMO].[dbo].ClientesBaja    C
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].Rutas           R  WITH (NOLOCK) ON C.CdRuta = R.Codigo
    INNER JOIN ListaClientes                         LC                ON LC.NroCta = C.NroCta
    WHERE R.Vnddor NOT IN (146, 147, 148, 149, 179, 181, 186, 197, 198, 200, 440, 441)
),

UnicoCliente AS (
    /* Deduplicación post-UNION (un cliente puede aparecer en ambas bases si
       hubo idas y vueltas en su historia comercial). */
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY NroCta ORDER BY NroCta DESC) AS RowNum
    FROM BaseClientes
),


-- ════════════════════════════════════════════════════════════════════════════
-- DETECCIÓN DE EVENTOS DENTRO DEL MES ANALIZADO
-- ════════════════════════════════════════════════════════════════════════════

EventosCompras AS (
    /* E2: el cliente volvió a comprar. Origen: tabla Pedidos. */
    SELECT
        E.idCliente                       AS Cliente,
        CONVERT(date, E.Fecha_Pedido)     AS FechaEvento,
        E.idVendedor                      AS IdReparto,
        'E2'                              AS TipoEvento,
        'VOLVIÓ A COMPRAR'                AS EstadoDesc
    FROM       [H2O_JUMI_DEMO].[dbo].Pedidos E WITH (NOLOCK)
    INNER JOIN UnicoCliente               UC ON UC.NroCta = E.idCliente AND UC.RowNum = 1
    WHERE E.Fecha_Pedido >= @Desde
      AND E.Fecha_Pedido <  @Hasta
),

EventosRetiros AS (
    /* E1/E3/E4: retiro de equipo (Tipo_Movimiento = 'R', sin IdRecambio).
       El "tipo de retiro" depende del reparto que lo ejecutó:
         - 146 → FUGADO (cliente que dejó de pagar y desapareció)
         - 147 → CORRECCIÓN INTERNA (ajuste contable, no comercial)
         - cualquier otro → retiro técnico estándar */
    SELECT
        ME.IdCliente                                AS Cliente,
        CONVERT(date, ME.Fecha)                     AS FechaEvento,
        ME.IdReparto                                AS IdReparto,
        TipoEvento  = CASE ME.IdReparto
                        WHEN 146 THEN 'E3'
                        WHEN 147 THEN 'E4'
                        ELSE          'E1'
                      END,
        EstadoDesc  = CASE ME.IdReparto
                        WHEN 146 THEN 'FUGADO'
                        WHEN 147 THEN 'CORRECCIÓN INTERNA'
                        ELSE          'RTO/SUPER/TÉCNICO'
                      END
    FROM       [H2O_JUMI_DEMO].[dbo].Movimientos_Equipos ME
    INNER JOIN UnicoCliente                              UC ON UC.NroCta = ME.IdCliente AND UC.RowNum = 1
    WHERE ME.Tipo_Movimiento     = 'R'              -- retiro de equipo
      AND ME.IdProducto          = 'AC'             -- código de dispenser F/C (en prod: 'U')
      AND CONVERT(date, ME.Fecha) >= @Desde
      AND CONVERT(date, ME.Fecha) <  @Hasta
      AND ISNULL(ME.Anulado, 0) = 0
      AND ME.IdRecambio IS NULL                     -- retiro puro, no cambio
),

EventoCambio AS (
    /* EC: cambio de equipo (Tipo_Movimiento = 'R' CON IdRecambio).
       El cliente no se va; le cambiamos el dispenser. */
    SELECT
        ME.IdCliente                AS Cliente,
        CONVERT(date, ME.Fecha)     AS FechaEvento,
        ME.IdReparto                AS IdReparto,
        'EC'                        AS TipoEvento,
        'CAMBIO'                    AS EstadoDesc
    FROM       [H2O_JUMI_DEMO].[dbo].Movimientos_Equipos ME
    INNER JOIN UnicoCliente                              UC ON UC.NroCta = ME.IdCliente AND UC.RowNum = 1
    WHERE ME.Tipo_Movimiento     = 'R'
      AND ME.IdProducto          = 'AC'
      AND CONVERT(date, ME.Fecha) >= @Desde
      AND CONVERT(date, ME.Fecha) <  @Hasta
      AND ISNULL(ME.Anulado, 0) = 0
      AND ME.IdRecambio IS NOT NULL                 -- diferenciador con E1/E3/E4
),

EventosMes AS (
    /* Consolidación de los 3 tipos de eventos en una sola estructura. */
    SELECT * FROM EventosCompras
    UNION ALL
    SELECT * FROM EventosRetiros
    UNION ALL
    SELECT * FROM EventoCambio
),


-- ════════════════════════════════════════════════════════════════════════════
-- AUDITORÍA: arma string con TODOS los eventos del mes para auditoría
-- ════════════════════════════════════════════════════════════════════════════

Acciones AS (
    /* STUFF + FOR XML PATH es el patrón canónico de string aggregation en
       T-SQL pre-SQL Server 2017. Equivalente a STRING_AGG() en versiones
       modernas. Se mantiene esta forma por compatibilidad con entornos
       corporativos que aún corren SQL Server 2014/2016. */
    SELECT
        E.Cliente,
        CantEventosDistintos = COUNT(DISTINCT E.TipoEvento),
        AccionesMes =
            STUFF((
                SELECT
                    ' | ' + X.TipoEvento + ':' + X.EstadoDesc
                    + ' (' + CONVERT(varchar(10), X.FechaEvento, 103)
                    + CASE WHEN X.IdReparto IS NULL THEN '' 
                           ELSE ' - R' + CONVERT(varchar(20), X.IdReparto) END
                    + ')'
                FROM EventosMes X
                WHERE X.Cliente = E.Cliente
                ORDER BY X.FechaEvento, X.TipoEvento
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 3, '')         -- recorta los 3 caracteres iniciales ' | '
    FROM EventosMes E
    GROUP BY E.Cliente
),


-- ════════════════════════════════════════════════════════════════════════════
-- PRIORIZACIÓN: cuando un cliente tiene múltiples eventos en el mes,
-- elegimos uno como "estado final" según una jerarquía de negocio:
--   E3 (Fugado)        > prioridad máxima — es churn duro
--   E4 (Corrección)    > segundo
--   E1 (Retiro técnico)> tercero
--   EC (Cambio)        > cuarto
--   E2 (Compra)        > último — la compra "tapa" pero queremos ver retiros
-- El FlagConflicto en el SELECT final marca cuando hay más de un evento.
-- ════════════════════════════════════════════════════════════════════════════

EventosRank AS (
    SELECT
        e.*,
        rn = ROW_NUMBER() OVER (
            PARTITION BY e.Cliente
            ORDER BY 
                CASE e.TipoEvento
                    WHEN 'E3' THEN 1
                    WHEN 'E4' THEN 2
                    WHEN 'E1' THEN 3
                    WHEN 'EC' THEN 4
                    WHEN 'E2' THEN 5
                    ELSE 99
                END,
                e.FechaEvento DESC
        )
    FROM EventosMes e
)


-- ════════════════════════════════════════════════════════════════════════════
-- SALIDA FINAL
-- ════════════════════════════════════════════════════════════════════════════

SELECT
    Mes           = FORMAT(@Desde, 'yyyy-MM'),
    UC.NroCta,
    UC.Nombre,
    UC.Direcc,
    UC.Telefn,
    TipoEvento    = COALESCE(ER.TipoEvento, 'E5'),
    EstadoFinal   = COALESCE(ER.EstadoDesc, 'SIGUE SIN CONSUMO'),
    FechaEvento   = ER.FechaEvento,
    IdReparto     = ER.IdReparto,
    FlagConflicto = CASE WHEN ISNULL(A.CantEventosDistintos, 0) > 1 THEN 1 ELSE 0 END,
    AccionesMes   = A.AccionesMes
FROM       UnicoCliente UC
LEFT JOIN  (SELECT * FROM EventosRank WHERE rn = 1) ER ON ER.Cliente = UC.NroCta
LEFT JOIN  Acciones                                  A ON A.Cliente  = UC.NroCta
WHERE UC.RowNum = 1
ORDER BY UC.NroCta;
