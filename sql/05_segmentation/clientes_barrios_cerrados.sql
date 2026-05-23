/* =============================================================================
   clientes_barrios_cerrados.sql
   -----------------------------------------------------------------------------
   Módulo:        05 · Segmentación geográfica
   Objetivo:      Identifica clientes que viven en barrios cerrados / countries
                  parseando la columna `Direcc` con pattern matching (LIKE),
                  y calcula su consumo histórico por mes.

   Por qué importa:
                  Los countries son el segmento más rentable del canal Hogar:
                  alta densidad geográfica (1 ruta cubre el barrio entero),
                  pagos puntuales (cuotas de expensas), tickets más altos
                  (consumo familiar más alto). Identificarlos es prerequisito
                  para promociones zonales (descuentos por barrio, días de
                  reparto exclusivos, productos premium).

   El desafío:    No hay una tabla "Barrios" en el sistema. La única señal es
                  la dirección textual escrita por el call center. El convention
                  es escribir "{calle} {número} - {NOMBRE BARRIO}" o
                  "{calle} {número}, {NOMBRE BARRIO}".

   Aproximación:  CASE WHEN con ~80 LIKE patterns (en producción).
                  En esta demo: ~13 barrios para no inflar el código.
                  El mismo lista en el WHERE garantiza que solo se procesen
                  esos clientes (filtro temprano = mejor performance que
                  evaluar el CASE sobre toda la tabla Clientes).

   Salida:        Una fila por (cliente, barrio, año, mes) con consumo en
                  litros, cantidad de unidades, bultos y monto facturado.

   Técnicas SQL:  Pattern matching con LIKE, CASE WHEN dimensional,
                  doble filtrado (WHERE + CASE), JOIN multi-tabla para
                  agregar dimensiones de cliente al hecho de consumo.

   Performance:   Filtro early en WHERE → escaneo de Clientes mucho menor
                  que evaluar el CASE sobre el dataset completo.
============================================================================= */

;WITH UnicoCliente AS (
    /* Detecta barrio cerrado parseando Direcc. La columna `Urbanizacion`
       devuelve NULL para clientes que no caen en ningún match (filtrados
       luego por el WHERE).

       Patrón de matching: '%<NOMBRE>%' — flexible con cualquier separador
       que use el call center (espacio, guion, coma, etc.).

       En producción la lista tiene ~80 entradas. Acá conservamos 13
       representativas que existen en el dataset sintético. */
    SELECT 
        C.NroCta,
        R.Vnddor                AS RUTA,
        C.Direcc,
        C.FecAlt,
        CONVERT(int, 0)         AS FecBaj,
        TC.Descrp               AS TipCli,
        ATR.AtrDes              AS Atributo,
        CASE
            WHEN C.Direcc LIKE '%NORDELTA%'              THEN 'NORDELTA'
            WHEN C.Direcc LIKE '%BAHIA GRANDE%'          THEN 'BAHIA GRANDE'
            WHEN C.Direcc LIKE '%BAHIA SAN MARCO%'       THEN 'BAHIA SAN MARCO'
            WHEN C.Direcc LIKE '%EL TRIGAL%'             THEN 'EL TRIGAL'
            WHEN C.Direcc LIKE '%LOS LAGOS%'             THEN 'LOS LAGOS'
            WHEN C.Direcc LIKE '%PILAR DEL ESTE%'        THEN 'PILAR DEL ESTE'
            WHEN C.Direcc LIKE '%CAMPOS DE ECHEVERRIA%'  THEN 'CAMPOS DE ECHEVERRIA'
            WHEN C.Direcc LIKE '%SAN AGUSTIN%'           THEN 'SAN AGUSTIN'
            WHEN C.Direcc LIKE '%SANTA CATALINA%'        THEN 'SANTA CATALINA'
            WHEN C.Direcc LIKE '%BARRIO ABRIL%'          THEN 'BARRIO ABRIL'
            WHEN C.Direcc LIKE '%ALTOS DE GOLF%'         THEN 'ALTOS DE GOLF'
            WHEN C.Direcc LIKE '%LOS CARDALES%'          THEN 'LOS CARDALES'
            WHEN C.Direcc LIKE '%AYRES DEL PILAR%'       THEN 'AYRES DEL PILAR'
        END                     AS Urbanizacion,
        ROW_NUMBER() OVER (PARTITION BY C.NroCta ORDER BY C.NroCta DESC) AS RowNum
    FROM       [H2O_JUMI_DEMO].[dbo].Clientes        C   WITH (NOLOCK)
    INNER JOIN [H2O_JUMI_DEMO].[dbo].ClientesRutas   CR  WITH (NOLOCK) ON C.NroCta = CR.Cliente_Ruteo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Rutas           R   WITH (NOLOCK) ON CR.CdRuta = R.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].CondPAGO        CP  WITH (NOLOCK) ON C.CndPag = CP.Codigo
    INNER JOIN [H2O_JUMI_DEMO].[dbo].TiposCli        TC  WITH (NOLOCK) ON C.TipCli = TC.Codigo
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].Categorias      CAT WITH (NOLOCK) ON C.Categoria = CAT.Categoria
    LEFT  JOIN [H2O_JUMI_DEMO].[dbo].ClientesAtrLis  ATR WITH (NOLOCK) ON C.Atrib5 = ATR.AtrCod
    /* Filtro early: solo evaluar el CASE sobre clientes que YA matchearon
       algún barrio. Mejora performance vs filtrar después. */
    WHERE 
           C.Direcc LIKE '%NORDELTA%'
        OR C.Direcc LIKE '%BAHIA GRANDE%'
        OR C.Direcc LIKE '%BAHIA SAN MARCO%'
        OR C.Direcc LIKE '%EL TRIGAL%'
        OR C.Direcc LIKE '%LOS LAGOS%'
        OR C.Direcc LIKE '%PILAR DEL ESTE%'
        OR C.Direcc LIKE '%CAMPOS DE ECHEVERRIA%'
        OR C.Direcc LIKE '%SAN AGUSTIN%'
        OR C.Direcc LIKE '%SANTA CATALINA%'
        OR C.Direcc LIKE '%BARRIO ABRIL%'
        OR C.Direcc LIKE '%ALTOS DE GOLF%'
        OR C.Direcc LIKE '%LOS CARDALES%'
        OR C.Direcc LIKE '%AYRES DEL PILAR%'
)

SELECT 
    P.idCliente,
    UC.Urbanizacion,
    UC.Atributo,
    YEAR(P.Fecha_Pedido)                      AS AÑO,
    DATENAME(MONTH, P.Fecha_Pedido)           AS MES,
    SUM(PP.Cantidad * PR.Litros)              AS LITROS,
    SUM(PP.Cantidad)                          AS CANTIDAD,
    SUM(PP.Cantidad * 1.0 
        / NULLIF(PR.cantidad_x_bulto, 0))     AS BULTOS,
    SUM(PP.Cantidad * PP.Precio)              AS CONSUMO_$
FROM       [H2O_JUMI_DEMO].[dbo].Pedidos             P   WITH (NOLOCK)
INNER JOIN UnicoCliente                              UC  ON UC.NroCta    = P.idCliente AND UC.RowNum = 1
INNER JOIN [H2O_JUMI_DEMO].[dbo].PEDIDOS_PRODUCTOS   PP  WITH (NOLOCK) ON PP.IDPEDIDO = P.IDPEDIDO
LEFT  JOIN [H2O_JUMI_DEMO].[dbo].Productos           PR  WITH (NOLOCK) ON PR.idProducto = PP.idProducto
WHERE PR.Litros > 0                                                       -- excluye servicios
GROUP BY 
    P.idCliente,
    UC.Urbanizacion,
    UC.Atributo,
    YEAR(P.Fecha_Pedido),
    DATENAME(MONTH, P.Fecha_Pedido),
    MONTH(P.Fecha_Pedido)
ORDER BY UC.Urbanizacion, P.idCliente, YEAR(P.Fecha_Pedido), MONTH(P.Fecha_Pedido);
