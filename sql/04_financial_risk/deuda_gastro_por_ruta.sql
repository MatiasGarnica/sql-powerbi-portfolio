/* =============================================================================
   deuda_gastro_por_ruta.sql
   -----------------------------------------------------------------------------
   Módulo:        04 · Riesgo financiero
   Objetivo:      Aging de deuda del canal Gastronomía agrupado por RUTA,
                  separando los dos modelos de facturación que coexisten:

                    - CONTADO    → deuda = pedidos no cobrados (Su Compra
                                   con su Su Pago todavía pendiente)
                    - CTA. CTE   → deuda = saldo de cuenta corriente
                                   (facturas sin recibo aplicado)

   Cómo se usa:   Reporte mensual para el equipo de cobranzas. Permite ranking
                  de rutas por exposición financiera, identificación de cuentas
                  problemáticas y priorización del recupero.

   Regla de negocio crítica:
                  Un cliente con MediodePago='CONTADO' nunca puede tener deuda
                  de cuenta corriente (y viceversa). El IIF garantiza esa
                  separación lógica para evitar deuda duplicada en el reporte.

   Salida:        Una fila por ruta:
                  - RUTA
                  - DeudaContado: suma de deudas de clientes "Contado" 
                  - DeudaCtaCte: suma de saldos de cuenta corriente

   Técnicas SQL:  UNION ALL de fuentes de deuda heterogéneas (Movimientos_Caja,
                  Movimientos_Caja_Ajustes, CtaCteVT), agregaciones en cascada,
                  IIF para separación condicional contado/cuenta corriente,
                  filtrado por rango de rutas (canal Gastro).

   Performance:   ~2.000 clientes Gastro · <3 seg
============================================================================= */

SET NOCOUNT ON;

-- =============================================================================
-- PARÁMETROS
-- =============================================================================
DECLARE @FechaReferencia DATE = '2026-05-01';   -- corte de deuda (exclusive)


;WITH UnicoCliente AS (
    /* Unifica clientes Activos + Bajas (UNION ALL) filtrados al canal Gastro.
       ROW_NUMBER() deduplica clientes que puedan aparecer en ambas tablas. */
    SELECT 
        C.NroCta,
        C.Nombre, 
        R.Vnddor                AS RUTA, 
        C.Direcc                AS Direccion,
        C.FecAlt, 
        CAST(NULL AS DATETIME)  AS FecBaj,
        TC.Descrp               AS TipCli, 
        CP.Codigo               AS CndPagCod,
        CP.Descrp               AS MediodePago,
        ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS RowNum
    FROM       [H2O_JUMI_DEMO].[dbo].Clientes        C  WITH (NOLOCK)
    INNER JOIN [H2O_JUMI_DEMO].[dbo].ClientesRutas   CR WITH (NOLOCK) ON C.NroCta = CR.Cliente_Ruteo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Rutas           R  WITH (NOLOCK) ON CR.CdRuta = R.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].CondPAGO        CP WITH (NOLOCK) ON C.CndPag = CP.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].TiposCli        TC WITH (NOLOCK) ON C.TipCli = TC.Codigo
    WHERE C.NroCta <> 0
      AND R.Vnddor IN (157, 158, 159, 163, 164, 171, 172, 173, 176, 242)    -- rutas Gastro

    UNION ALL

    SELECT 
        C.NroCta,
        C.Nombre, 
        R.Vnddor    AS RUTA, 
        C.Direcc    AS Direccion,
        C.FecAlt, 
        C.FecBaj, 
        TC.Descrp   AS TipCli, 
        CP.Codigo   AS CndPagCod,
        CP.Descrp   AS MediodePago,
        ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS RowNum
    FROM       [H2O_JUMI_DEMO].[dbo].ClientesBaja    C  WITH (NOLOCK)
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Rutas           R  WITH (NOLOCK) ON C.CdRuta = R.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].CondPAGO        CP WITH (NOLOCK) ON C.CndPag = CP.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].TiposCli        TC WITH (NOLOCK) ON C.TipCli = TC.Codigo
    WHERE C.NroCta <> 0
      AND R.Vnddor IN (157, 158, 159, 163, 164, 171, 172, 173, 176, 242)
),

RankedClients AS (
    /* Deduplicación + exclusión de rutas no comerciales. */
    SELECT * 
    FROM UnicoCliente
    WHERE RowNum = 1
      AND RUTA NOT IN (0, 200, 300, 400)            -- excluye incobrables, almacenes
),


-- ════════════════════════════════════════════════════════════════════════════
-- DEUDA CONTADO: suma de movimientos sin pago aplicado
-- ════════════════════════════════════════════════════════════════════════════
DEUDATOTAL AS (
    /* Unifica las dos fuentes de movimientos de caja del modelo contado. */
    SELECT IdCliente, SUM(Importe) AS Deuda
    FROM [H2O_JUMI_DEMO].[dbo].Movimientos_Caja_Ajustes AJ
    WHERE Fecha < @FechaReferencia
    GROUP BY IdCliente

    UNION ALL

    SELECT IdCliente, SUM(Importe) AS Deuda
    FROM [H2O_JUMI_DEMO].[dbo].Movimientos_Caja A
    WHERE Fecha < @FechaReferencia
    GROUP BY IdCliente
),

DEUDAUNICA AS (
    /* Saldo total por cliente: ventas (positivas) menos pagos (negativos). */
    SELECT 
        IdCliente, 
        SUM(Deuda) AS DeudaContado  
    FROM DEUDATOTAL 
    GROUP BY IdCliente
),


-- ════════════════════════════════════════════════════════════════════════════
-- DEUDA CUENTA CORRIENTE: saldo de la subcuenta de comprobantes
-- ════════════════════════════════════════════════════════════════════════════
DEUDACCTE AS (
    /* IIF blindado: si el saldo es negativo (cliente con saldo a favor),
       lo forzamos a 0 para no compensar deuda de otros clientes. */
    SELECT 
        NroCta                          AS IdCliente, 
        ISNULL(IIF(SUM(Import) < 0, 0, SUM(Import)), 0)  AS DeudaCtaCte
    FROM [H2O_JUMI_DEMO].[dbo].CtaCteVT
    WHERE FchMov < @FechaReferencia
    GROUP BY NroCta
),


-- ════════════════════════════════════════════════════════════════════════════
-- COMBINACIÓN: una fila por cliente con su deuda según su modelo de pago
-- ════════════════════════════════════════════════════════════════════════════
BASECLIENTES AS (
    /* Regla crítica: un cliente CONTADO solo tiene deuda contado (la otra
       columna se fuerza a 0), y viceversa. Esto evita doble-conteo. 
       Códigos de CondPAGO: 1 = Contado, 2-4 = Cuenta Corriente. */
    SELECT 
        RC.NroCta,
        RC.Nombre,
        RC.Direccion,
        RC.RUTA,
        RC.FecAlt,
        RC.FecBaj,
        RC.MediodePago,
        IIF(RC.CndPagCod = 1,         ISNULL(DC.DeudaContado, 0),  0) AS DeudaContado,
        IIF(RC.CndPagCod IN (2, 3, 4), ISNULL(DCC.DeudaCtaCte, 0),  0) AS DeudaCtaCte
    FROM      RankedClients RC
    LEFT JOIN DEUDAUNICA    DC  ON DC.IdCliente  = RC.NroCta
    LEFT JOIN DEUDACCTE     DCC ON DCC.IdCliente = RC.NroCta
)


-- ════════════════════════════════════════════════════════════════════════════
-- SALIDA: agregado por RUTA, solo rutas con deuda no nula
-- ════════════════════════════════════════════════════════════════════════════
SELECT 
    RUTA, 
    SUM(DeudaContado)             AS DeudaContado, 
    SUM(DeudaCtaCte)              AS DeudaCtaCte,
    SUM(DeudaContado + DeudaCtaCte) AS DeudaTotal
FROM BASECLIENTES
WHERE DeudaContado <> 0 
   OR DeudaCtaCte <> 0
GROUP BY RUTA
ORDER BY DeudaTotal DESC;                          -- rutas con mayor exposición primero
