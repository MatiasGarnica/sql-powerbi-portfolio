/* =============================================================================
   primera_compra_estado.sql
   -----------------------------------------------------------------------------
   Módulo:        01 · Adquisición de clientes
   Objetivo:      Para cada cliente, identifica los productos de su PRIMERA
                  compra histórica y clasifica si esa compra fue:
                    - NORMAL       → todas las líneas con cargo
                    - SIN CARGO    → producto nativamente sin cargo (ej: EMSC,
                                     primer bidón de cortesía)
                    - 2x1 / BONIF  → al menos una línea a precio 0 dentro de
                                     un pedido con cargo (promo de bonificación)
   
   Uso típico:    Reporte de control de calidad de promociones. Permite a
                  Marketing auditar qué % de altas se concretan vía promo vs
                  precio normal, y a Finanzas dimensionar el costo de bonifs.

   Salida:        Una fila por (cliente, producto) de la primera compra.
                  NroCta · idProducto · Abreviatura · TotalImporteProducto
                  TieneLineaPrecio0 · TipoPromo

   Técnicas SQL:  ROW_NUMBER(), CTE multi-nivel, agregación condicional con CASE.
   Performance:   ~24.000 filas sobre 14k clientes activos · <1 seg
============================================================================= */

;WITH FirstPedido AS (
    /* Numera los pedidos de cada cliente cronológicamente. rn=1 es la 1ra compra. */
    SELECT 
        p.idCliente, 
        p.IDPEDIDO, 
        p.Fecha_Pedido,
        ROW_NUMBER() OVER (
            PARTITION BY p.idCliente
            ORDER BY p.Fecha_Pedido, p.IDPEDIDO
        ) AS rn
    FROM [H2O_JUMI_DEMO].[dbo].Pedidos p WITH (NOLOCK)
),
PrimeraCompraProd AS (
    /* Líneas de la primera compra, solo productos con litros (agua/soda),
       agregadas a nivel cliente × producto. */
    SELECT
        fp.idCliente                                            AS NroCta,
        pp.idProducto,
        pr.Abreviatura,
        SUM(pp.Cantidad * pp.Precio)                            AS TotalImporteProducto,
        MAX(CASE WHEN pp.Precio = 0 THEN 1 ELSE 0 END)          AS TieneLineaPrecio0
    FROM FirstPedido fp
    INNER JOIN [H2O_JUMI_DEMO].[dbo].PEDIDOS_PRODUCTOS pp WITH (NOLOCK)
        ON pp.IDPEDIDO = fp.IDPEDIDO
    INNER JOIN [H2O_JUMI_DEMO].[dbo].Productos pr WITH (NOLOCK)
        ON pr.idProducto = pp.idProducto
    WHERE fp.rn = 1            -- nos quedamos solo con la 1ra compra de cada cliente
      AND pr.Litros > 0        -- excluye servicios, alquileres, vasos descartables
    GROUP BY fp.idCliente, pp.idProducto, pr.Abreviatura
)
SELECT
    NroCta,
    idProducto,
    Abreviatura,
    TotalImporteProducto,
    TieneLineaPrecio0,
    /* Clasificación de la naturaleza promocional de la primera compra:
       - TotalImporteProducto = 0  → producto nativo sin cargo (no es promo)
       - Total > 0 + alguna línea a 0 → promo 2x1 o bonificación parcial
       - Total > 0 sin líneas a 0   → compra normal a precio de lista          */
    CASE
        WHEN TotalImporteProducto = 0                              THEN 'SIN CARGO'
        WHEN TotalImporteProducto > 0 AND TieneLineaPrecio0 = 1    THEN '2x1/BONIF'
        ELSE 'NORMAL'
    END AS TipoPromo
FROM PrimeraCompraProd
ORDER BY NroCta, idProducto;
