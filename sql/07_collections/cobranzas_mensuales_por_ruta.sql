/* =============================================================================
   cobranzas_mensuales_por_ruta.sql
   -----------------------------------------------------------------------------
   Módulo:        07 · Cobranzas
   Objetivo:      Reporte mensual de cobranzas (últimos 5 meses) abierto por
                  ruta × método de pago × período. Alimenta el dashboard de
                  composición de cobranzas (Efectivo vs Resto, % Digital,
                  % Cheques, % Transferencia, % Retenciones).

   Cómo se usa:   Cobranzas y Finanzas usan este reporte para:
                  - Monitorear el % de cobro en efectivo por región (cash-rich
                    vs digital, importante para flujo de caja)
                  - Detectar caídas de un método específico (ej: si Mercado
                    Pago cae, hay problema técnico con el integrador)
                  - Atribución correcta del ingreso al vendedor que cobró
                    (la "ruta" del cobro NO siempre es la del cliente)

   Truco del oficio — extracción de ruta de Refern:
                  En el sistema de gestión, los movimientos en Efectivo se
                  imputan al "casino" (caja general) y la ruta queda
                  embebida en la columna Refern como sufijo numérico, ej:
                       "CIERRE DIARIO RUTA 0042"  →  ruta 42
                       "RENDICION COBRANZA 0157"  →  ruta 157
                  Para extraerla usamos un combo REVERSE + PATINDEX que
                  toma todos los dígitos al final del string.
                  Para los métodos no-efectivo (TRF, DIG, CHQ, RET) la ruta
                  proviene directamente del cliente (NroCta → Rutas).

   Salida:        Una fila por (RUTA, Mes, CodCpt) con el importe total.
                  Se excluyen CodCpt internos (transferencias entre cajas).

   Técnicas SQL:  CTE multi-nivel, OUTER APPLY para enriquecimiento por fila,
                  parsing de strings con REVERSE + LEFT + PATINDEX,
                  TRY_CONVERT para protección contra texto no-numérico,
                  CASE WHEN dimensional para selección de fuente de ruta,
                  agregación por dimensión calculada.

   Performance:   ~325k movimientos × 5 meses · ~6 seg
============================================================================= */

SET NOCOUNT ON;

;WITH UnicoCliente AS (
    /* Universo de clientes filtrado a las rutas comerciales activas.
       En producción la lista tiene ~300 códigos (cubre 6 regiones).
       Acá usamos un subset representativo del dataset sintético. */
    SELECT 
        C.NroCta,
        C.Nombre,
        R.Vnddor                 AS RUTA,
        C.Direcc                 AS Direccion,
        C.FecAlt,
        CONVERT(INT, 0)          AS FecBaj,
        TC.Descrp                AS TipCli,
        'RTO'                    AS Gestion,
        CP.Descrp                AS MediodePago,
        ATR.AtrDes               AS Atributo,
        ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS RowNum
    FROM       [H2O_JUMI_DEMO].[dbo].Clientes        C   WITH (NOLOCK)
    INNER JOIN [H2O_JUMI_DEMO].[dbo].ClientesRutas   CR  WITH (NOLOCK) ON C.NroCta    = CR.Cliente_Ruteo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Rutas           R   WITH (NOLOCK) ON CR.CdRuta   = R.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].CondPAGO        CP  WITH (NOLOCK) ON C.CndPag    = CP.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].TiposCli        TC  WITH (NOLOCK) ON C.TipCli    = TC.Codigo
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].ClientesAtrLis  ATR WITH (NOLOCK) ON C.Atrib5    = ATR.AtrCod
    WHERE R.Vnddor IN (
        -- Norte
        1, 2, 3, 5, 8, 9, 11, 13, 14, 16, 17, 18, 25, 35, 50, 71, 90,
        -- Este
        4, 6, 12, 15, 19, 28, 36, 55, 70, 83, 99, 110, 119,
        -- Sur
        10, 20, 30, 40, 60, 74, 84, 96, 105, 116,
        -- Plata
        251, 260, 265, 270, 275, 281, 460, 475, 481,
        -- Norte 2
        401, 410, 415, 420, 425, 430, 434,
        -- Gastronomía
        155, 157, 158, 159, 160, 163, 164, 172, 173, 176, 242
    )
),

base AS (
    /* Núcleo del reporte: cada movimiento de tesorería resuelto con su
       RUTA correspondiente (que NO siempre es la del cliente).
       
       La OUTER APPLY funciona como una "función inline" que devuelve
       dos posibles rutas por cada movimiento; el CASE de arriba elige
       cuál usar según el método de pago. */
    SELECT
        m.*,
        RUTA = CASE 
                  WHEN m.CodCpt = 'EFE' THEN X.RutaEFE       -- efectivo → parseo de Refern
                  ELSE X.RutaDefault                          -- otros → ruta del cliente
               END
    FROM       [H2O_JUMI_DEMO].[dbo].MovTes m WITH (NOLOCK)
    LEFT JOIN  UnicoCliente               C ON C.NroCta = m.NroCta
    OUTER APPLY (
        SELECT
            /* Ruta por defecto: la del cliente al que se le cobró.
               En producción hay un fallback adicional vía REPARTOS.NROCTA
               para movimientos que no joinean directo con Clientes (cuentas
               internas de vendedores). En esta demo simplificamos a la 
               ruta del cliente directamente. */
            RutaDefault = C.RUTA,
            /* Ruta EFE: extracción de los dígitos finales del campo Refern.
               Ej: 'CIERRE DIARIO RUTA 0042' → 42
                   'RENDICION COBRANZA 157'  → 157
               Cómo funciona:
                 1. REVERSE(Refern) invierte el string
                 2. PATINDEX('%[^0-9]%', ...) encuentra la 1ra posición no-numérica
                 3. LEFT(..., posicion-1) extrae todos los dígitos del final invertidos
                 4. REVERSE() vuelve a ponerlos en orden
                 5. TRY_CONVERT protege contra strings sin dígitos al final */
            RutaEFE = TRY_CONVERT(INT,
                REVERSE(
                    LEFT(
                        REVERSE(LTRIM(RTRIM(m.Refern))),
                        PATINDEX('%[^0-9]%', REVERSE(LTRIM(RTRIM(m.Refern))) + 'X') - 1
                    )
                )
            )
    ) X
    WHERE m.FchMov >= DATEADD(MONTH, -5, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1))
      AND m.FchMov <  DATEADD(DAY, 1, CAST(GETDATE() AS date))
      AND (
            (m.CodCpt =  'EFE' AND X.RutaEFE     IS NOT NULL)
         OR (m.CodCpt <> 'EFE' AND X.RutaDefault IS NOT NULL)
          )
)

SELECT
    RUTA,
    Mes         = FORMAT(DATEFROMPARTS(YEAR(FchMov), MONTH(FchMov), 1), 'MM-yy'),
    Descripcion = ISNULL(
                      (SELECT Descrp 
                       FROM [H2O_JUMI_DEMO].[dbo].CptTes 
                       WHERE Codigo = M.CodCpt), 
                      M.CodCpt),
    -- El multiplicador defensivo: si DebHab='D' suma, sino resta. Como abajo
    -- filtramos DebHab='D', el efecto neto es siempre +1. Pero la expresión
    -- protege contra anomalías en la calidad de los datos.
    Total       = SUM(Import * CASE DebHab WHEN 'D' THEN 1 ELSE -1 END)
FROM base M
WHERE CodCpt NOT IN ('CCB', 'CPA')         -- excluye transferencias internas entre cajas
  AND DebHab = 'D'                          -- solo movimientos de débito (ingresos)
GROUP BY 
    RUTA,
    DATEFROMPARTS(YEAR(FchMov), MONTH(FchMov), 1),
    CodCpt
ORDER BY 
    RUTA,
    DATEFROMPARTS(YEAR(FchMov), MONTH(FchMov), 1);
