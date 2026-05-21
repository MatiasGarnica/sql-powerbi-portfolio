/* ============================================================================
   load_to_sqlserver.sql
   ============================================================================
   Crea la base H2O_JUMI_DEMO, define las 21 tablas y carga los CSV sintéticos.

   USO:
   1) Ajustar @csv_path con la ruta donde están los CSV (¡acceso del servicio
      SQL Server, NO de tu usuario Windows!). Para localhost típico:
        @csv_path = N'C:\h2o_jumi_demo\data\csv\'
   2) Ejecutar todo el script en SSMS conectado al server donde quieras la DB.
   3) Verificar al final el SELECT COUNT(*) de cada tabla.

   Nota: BULK INSERT requiere permisos ADMINISTER BULK OPERATIONS.
============================================================================ */

USE master;
GO

IF DB_ID('H2O_JUMI_DEMO') IS NOT NULL
BEGIN
    ALTER DATABASE H2O_JUMI_DEMO SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE H2O_JUMI_DEMO;
END
GO

CREATE DATABASE H2O_JUMI_DEMO;
GO

USE H2O_JUMI_DEMO;
GO

-- ============================================================================
-- DECLARACIÓN DE RUTA (ajustar según entorno)
-- ============================================================================
DECLARE @csv_path NVARCHAR(500) = N'C:\h2o_jumi_demo\data\csv\';
DECLARE @sql NVARCHAR(MAX);

-- ============================================================================
-- 1) CATÁLOGOS
-- ============================================================================

CREATE TABLE CondPAGO (
    Codigo  INT          NOT NULL PRIMARY KEY,
    Descrp  CHAR(30),
    DiasCR  INT,
    Cuotas  INT,
    CodAlt  VARCHAR(15)
);

CREATE TABLE TiposCli (
    Codigo         VARCHAR(6)  NOT NULL PRIMARY KEY,
    Descrp         VARCHAR(50),
    IdListaPrecio  VARCHAR(6)
);

CREATE TABLE Categorias (
    Categoria   VARCHAR(6)  NOT NULL PRIMARY KEY,
    Descripcion VARCHAR(60)
);

CREATE TABLE ClientesAtrLis (
    AtrNro INT,
    AtrCod VARCHAR(50),
    AtrDes VARCHAR(250)
);

CREATE TABLE CteVtas (
    Codigo  VARCHAR(6)  NOT NULL PRIMARY KEY,
    Descrp  CHAR(30),
    DebHab  CHAR(1)
);

CREATE TABLE CptTes (
    Codigo  CHAR(3)  NOT NULL PRIMARY KEY,
    Descrp  CHAR(30),
    DebHab  CHAR(1)
);

CREATE TABLE Productos (
    idProducto       VARCHAR(6)  NOT NULL PRIMARY KEY,
    Descripcion      VARCHAR(50),
    Abreviatura      VARCHAR(10),
    Litros           NUMERIC(10,2),
    Unidad           VARCHAR(6),
    Orden            INT,
    cantidad_x_bulto INT
);

-- ============================================================================
-- 2) RUTAS Y REPARTOS
-- ============================================================================

CREATE TABLE Rutas (
    Codigo     VARCHAR(6)  NOT NULL PRIMARY KEY,
    Descrp     CHAR(30),
    Vnddor     INT,
    DiaRep     CHAR(10),
    Frecuencia INT,
    Orden      INT
);

CREATE TABLE repartos (
    Codigo   INT  NOT NULL PRIMARY KEY,
    Descrp   CHAR(100),
    PctCom   DECIMAL(10,2),
    CodSup   INT,
    NroCta   NUMERIC(15,0),
    Sucursal VARCHAR(10)
);

-- ============================================================================
-- 3) CLIENTES Y CLIENTESBAJA
-- ============================================================================

CREATE TABLE Clientes (
    NroCta                          NUMERIC(15,0) NOT NULL PRIMARY KEY,
    Nombre                          VARCHAR(255),
    Direcc                          VARCHAR(255),
    Idlocalidad                     INT,
    Locali                          VARCHAR(255),
    NomPai                          CHAR(20),
    NroSub                          NUMERIC(10,0),
    Categoria                       VARCHAR(6),
    Telefn                          VARCHAR(MAX),
    EMails                          VARCHAR(255),
    CndIva                          CHAR(1),
    NrCUIT                          CHAR(13),
    ZonaVT                          CHAR(3),
    CndPag                          INT,
    IdListaPrecio                   VARCHAR(6),
    TipCli                          VARCHAR(6),
    Requiere_Comprobante            INT,
    Sucursal_Comprobante            VARCHAR(6),
    Periodo_Facturacion             CHAR(1),
    Certificado_Recepcion           INT,
    Tipo_Factura                    INT,
    Tipo_Cobranza                   INT,
    Cobrador                        INT,
    FecAlt                          DATETIME,
    FecMod                          DATETIME,
    NombreFiscal                    VARCHAR(255),
    DomicilioFiscal                 VARCHAR(255),
    LocalidadFiscal                 VARCHAR(255),
    CodAlt                          VARCHAR(15),
    Transf_Status                   VARCHAR(1),
    IdProvincia                     NUMERIC(10,0),
    suma_fiado_reparto              INT,
    InscIB                          CHAR(1),
    Porc_IIBB                       NUMERIC(10,2),
    Pcia_IIBB                       INT,
    Situacion_IIBB                  VARCHAR(6),
    Nro_IIBB                        VARCHAR(15),
    Latitud                         VARCHAR(255),
    Longitud                        VARCHAR(255),
    Usuario                         VARCHAR(50),
    TeMovil                         VARCHAR(MAX),
    IdImpuestoMunicipal             INT,
    BaseCalculoImpuestoMunicipal    VARCHAR(1),
    TasaImpuestoMunicipal           NUMERIC(10,2),
    fecha_nacimiento                DATETIME,
    Usuario_mod                     VARCHAR(50),
    GENERA_FACTURA_ELECTRONICA      INT,
    saldo                           DECIMAL(18,2),
    Atrib0 VARCHAR(50), Atrib1 VARCHAR(50), Atrib2 VARCHAR(50),
    Atrib3 VARCHAR(50), Atrib4 VARCHAR(50), Atrib5 VARCHAR(50),
    Atrib6 VARCHAR(50), Atrib7 VARCHAR(50), Atrib8 VARCHAR(50), Atrib9 VARCHAR(50),
    Latitud2                        FLOAT,
    Longitud2                       FLOAT,
    RG5329MotivoExencion            VARCHAR(50),
    RG5329PorcentajeExencion        NUMERIC(10,2),
    RG5329ExencionDesde             DATETIME,
    RG5329ExencionHasta             DATETIME
);

CREATE TABLE ClientesBaja (
    IdClienteBaja        NUMERIC(15,0) NOT NULL PRIMARY KEY,
    NroCta               NUMERIC(15,0) NOT NULL,
    Nombre               VARCHAR(255),
    Direcc               VARCHAR(255),
    Locali               VARCHAR(255),
    NomPai               CHAR(20),
    Telefn               CHAR(70),
    EMails               VARCHAR(255),
    CndIva               CHAR(1),
    NrCUIT               CHAR(13),
    ZonaVT               CHAR(3),
    CndPag               INT,
    IdListaPrecio        VARCHAR(6),
    TipCli               CHAR(3),
    Categoria            VARCHAR(6),
    NroSub               NUMERIC(10,0),
    IdMotivo             VARCHAR(6),
    CdRuta               VARCHAR(6),
    Orden                INT,
    FecAlt               DATETIME,
    FecBaj               DATETIME,
    Usuario              VARCHAR(20),
    Requiere_Comprobante INT,
    Sucursal_Comprobante VARCHAR(6),
    Periodo_Facturacion  CHAR(1),
    Certificado_Recepcion INT,
    Tipo_Factura         INT,
    Tipo_Cobranza        INT,
    NombreFiscal         VARCHAR(255),
    DomicilioFiscal      VARCHAR(255),
    LocalidadFiscal      VARCHAR(255),
    CodAlt               VARCHAR(15),
    IdProvincia          NUMERIC(10,0),
    InscIB               CHAR(1),
    Porc_IIBB            NUMERIC(10,2),
    Situacion_IIBB       VARCHAR(6),
    Nro_IIBB             VARCHAR(15),
    Pcia_IIBB            INT,
    TeMovil              VARCHAR(255),
    IdImpuestoMunicipal  INT,
    BaseCalculoImpuestoMunicipal VARCHAR(1),
    TasaImpuestoMunicipal NUMERIC(10,2),
    IDLOCALIDAD          INT,
    FECHA_NACIMIENTO     DATETIME,
    GENERA_FACTURA_ELECTRONICA INT,
    Atrib0 VARCHAR(50), Atrib1 VARCHAR(50), Atrib2 VARCHAR(50),
    Atrib3 VARCHAR(50), Atrib4 VARCHAR(50), Atrib5 VARCHAR(50),
    Atrib6 VARCHAR(50), Atrib7 VARCHAR(50), Atrib8 VARCHAR(50), Atrib9 VARCHAR(50)
);

-- ============================================================================
-- 4) RELACIONES
-- ============================================================================

CREATE TABLE ClientesRutas (
    CdRuta        VARCHAR(6),
    OrdRut        INT,
    Tipo          CHAR(1),
    Cliente_Ruteo NUMERIC(15,0),
    Estado        NUMERIC(1,0)
);

CREATE TABLE Clientes_Ctas_Madres_e_Hijas (
    IdCliente NUMERIC(15,0) NOT NULL,
    Cta_Madre NUMERIC(15,0)
);

CREATE TABLE ClientesServicios (
    IdCliente            NUMERIC(15,0) NOT NULL,
    IdServicio           INT           NOT NULL,
    NrItem               INT           NOT NULL,
    IdEquipo             NUMERIC(15,0),
    Marca                VARCHAR(30),
    Modelo               VARCHAR(30),
    Nro_Serie            VARCHAR(30),
    Porcentaje_Descuento NUMERIC(5,2),
    Contrato             VARCHAR(20),
    NroOrdenAlta         VARCHAR(20),
    NroOrdenBaja         VARCHAR(20),
    Fecha_Desde          DATETIME,
    Fecha_Hasta          DATETIME,
    Fecha_Alta           DATETIME,
    Fecha_Modificacion   DATETIME,
    Fecha_Baja           DATETIME,
    IdProducto           VARCHAR(10),
    Sector               VARCHAR(20)
);

CREATE TABLE Movimientos_Equipos (
    IdMovimiento     NUMERIC(15,0) NOT NULL PRIMARY KEY,
    Fecha            DATETIME,
    IdReparto        INT,
    IdCliente        NUMERIC(15,0),
    IdClienteNuevo   INT,
    Nro_Serie        VARCHAR(20),
    IdProducto       VARCHAR(6),
    Tipo_Movimiento  CHAR(1),
    Anulado          SMALLINT,
    Equipo_Asignado  NUMERIC(15,0),
    IdRecambio       NUMERIC(15,0),
    Usuario          VARCHAR(50)
);

-- ============================================================================
-- 5) HECHOS TRANSACCIONALES
-- ============================================================================

CREATE TABLE Pedidos (
    idPedido        DECIMAL(15,0) NOT NULL PRIMARY KEY,
    idVendedor      INT,
    Fecha_Pedido    DATETIME,
    idCliente       DECIMAL(15,0),
    Factura         CHAR(1),
    Nro_Comprobante VARCHAR(15),
    CodForExp       VARCHAR(6),
    NroForExp       INT,
    Status          VARCHAR(2),
    IDCLIENTENUEVO  NUMERIC(15,0)
);

CREATE TABLE Pedidos_Productos (
    idPedido         DECIMAL(15,0) NOT NULL,
    idProducto       VARCHAR(6)    NOT NULL,
    Tipo             CHAR(1)       NOT NULL,
    Cantidad         DECIMAL(10,2) NOT NULL,
    Precio           DECIMAL(15,2) NOT NULL,
    TIPOBONIFICACION VARCHAR(1)    NOT NULL
);

CREATE TABLE Movimientos_Caja (
    IdMovimiento     INT NOT NULL PRIMARY KEY,
    IdReparto        INT,
    IdPedido         DECIMAL(15,0),
    IdCliente        DECIMAL(15,0),
    Fecha            DATETIME,
    Descripcion      VARCHAR(50),
    Importe          DECIMAL(18,2),
    IDCLIENTENUEVO   NUMERIC(15,0),
    Nro_Recibo       VARCHAR(20),
    IdMotivo         INT,
    id_pago          VARCHAR(100),
    id_gateway_pago  INT
);

CREATE TABLE Movimientos_Caja_Ajustes (
    idAjuste        NUMERIC(15,0) NOT NULL PRIMARY KEY,
    idReparto       INT,
    idCliente       NUMERIC(15,0),
    Fecha           DATETIME,
    Descripcion     VARCHAR(50),
    Importe         NUMERIC(18,2),
    Usuario         VARCHAR(50),
    codmov          VARCHAR(6),
    nromov          NUMERIC(15,0),
    IDTIPOAJUSTE    INT,
    IdAjuste_Nuevo  NUMERIC(15,0),
    idfactura       NUMERIC(15,0)
);

CREATE TABLE CtaCteVT (
    CodMov    VARCHAR(6)     NOT NULL,
    NroMov    NUMERIC(15,0)  NOT NULL,
    NrItem    INT            NOT NULL,
    CteOri    VARCHAR(6),
    FchMov    DATETIME,
    NroCta    VARCHAR(10),
    NroSub    VARCHAR(10),
    CodApl    VARCHAR(6),
    NroApl    NUMERIC(15,0),
    FchVnc    DATETIME,
    Import    NUMERIC(18,2),
    Refern    CHAR(50),
    idfactura NUMERIC(15,0)
);

CREATE TABLE MovTes (
    CodMov   VARCHAR(6)    NOT NULL,
    NroMov   NUMERIC(15,0) NOT NULL,
    NrItem   INT           NOT NULL,
    FchMov   DATETIME,
    TipCta   CHAR(1),
    NroCta   VARCHAR(10),
    Refern   CHAR(30),
    CodCpt   CHAR(3),
    NroBco   CHAR(3),
    Sucurs   VARCHAR(10),
    CPBcos   INT,
    Cheque   CHAR(8),
    Cuenta   CHAR(11),
    Titular  CHAR(80),
    FchVnc   DATETIME,
    CtaCte   CHAR(2),
    Import   NUMERIC(18,2),
    DebHab   CHAR(1),
    CodAsi   CHAR(2),
    NroAsi   NUMERIC(15,0)
);

PRINT '✓ Estructura creada (21 tablas)';
GO

-- ============================================================================
-- BULK INSERT (carga de CSVs)
-- ============================================================================
-- IMPORTANTE: cambiá @csv_path a tu ruta real antes de ejecutar.
DECLARE @csv_path NVARCHAR(500) = N'C:\h2o_jumi_demo\data\csv\';
DECLARE @sql NVARCHAR(MAX);

DECLARE @tablas TABLE (nombre NVARCHAR(100), archivo NVARCHAR(100));
INSERT INTO @tablas VALUES
    ('CondPAGO',                    'CondPAGO.csv'),
    ('TiposCli',                    'TiposCli.csv'),
    ('Categorias',                  'Categorias.csv'),
    ('ClientesAtrLis',              'ClientesAtrLis.csv'),
    ('CteVtas',                     'CteVtas.csv'),
    ('CptTes',                      'CptTes.csv'),
    ('Productos',                   'Productos.csv'),
    ('Rutas',                       'Rutas.csv'),
    ('repartos',                    'repartos.csv'),
    ('Clientes',                    'Clientes.csv'),
    ('ClientesBaja',                'ClientesBaja.csv'),
    ('ClientesRutas',               'ClientesRutas.csv'),
    ('Clientes_Ctas_Madres_e_Hijas','Clientes_Ctas_Madres_e_Hijas.csv'),
    ('ClientesServicios',           'ClientesServicios.csv'),
    ('Movimientos_Equipos',         'Movimientos_Equipos.csv'),
    ('Pedidos',                     'Pedidos.csv'),
    ('Pedidos_Productos',           'Pedidos_Productos.csv'),
    ('Movimientos_Caja',            'Movimientos_Caja.csv'),
    ('Movimientos_Caja_Ajustes',    'Movimientos_Caja_Ajustes.csv'),
    ('CtaCteVT',                    'CtaCteVT.csv'),
    ('MovTes',                      'MovTes.csv');

DECLARE cur CURSOR FOR SELECT nombre, archivo FROM @tablas;
DECLARE @tabla NVARCHAR(100), @archivo NVARCHAR(100);
DECLARE @start DATETIME2, @rowcount BIGINT;

OPEN cur;
FETCH NEXT FROM cur INTO @tabla, @archivo;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @start = SYSDATETIME();
    SET @sql = N'
        BULK INSERT ' + QUOTENAME(@tabla) + N'
        FROM ''' + @csv_path + @archivo + N'''
        WITH (
            FORMAT          = ''CSV'',
            FIRSTROW        = 2,
            FIELDTERMINATOR = '','',
            ROWTERMINATOR   = ''0x0d0a'',
            CODEPAGE        = ''65001'',
            TABLOCK,
            KEEPNULLS
        );';

    BEGIN TRY
        EXEC sp_executesql @sql;
        SET @sql = N'SELECT @cnt = COUNT(*) FROM ' + QUOTENAME(@tabla);
        EXEC sp_executesql @sql, N'@cnt BIGINT OUTPUT', @cnt = @rowcount OUTPUT;
        PRINT '✓ ' + @tabla + ' → ' + CAST(@rowcount AS VARCHAR(20)) + ' filas en '
            + CAST(DATEDIFF(MILLISECOND, @start, SYSDATETIME()) AS VARCHAR(20)) + ' ms';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error en ' + @tabla + ': ' + ERROR_MESSAGE();
    END CATCH;

    FETCH NEXT FROM cur INTO @tabla, @archivo;
END;
CLOSE cur;
DEALLOCATE cur;

GO

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================
SELECT 'Clientes'                AS Tabla, COUNT(*) AS Filas FROM Clientes
UNION ALL SELECT 'ClientesBaja',                COUNT(*) FROM ClientesBaja
UNION ALL SELECT 'ClientesRutas',               COUNT(*) FROM ClientesRutas
UNION ALL SELECT 'ClientesServicios',           COUNT(*) FROM ClientesServicios
UNION ALL SELECT 'Clientes_Ctas_Madres_e_Hijas',COUNT(*) FROM Clientes_Ctas_Madres_e_Hijas
UNION ALL SELECT 'Movimientos_Equipos',         COUNT(*) FROM Movimientos_Equipos
UNION ALL SELECT 'Pedidos',                     COUNT(*) FROM Pedidos
UNION ALL SELECT 'Pedidos_Productos',           COUNT(*) FROM Pedidos_Productos
UNION ALL SELECT 'Movimientos_Caja',            COUNT(*) FROM Movimientos_Caja
UNION ALL SELECT 'Movimientos_Caja_Ajustes',    COUNT(*) FROM Movimientos_Caja_Ajustes
UNION ALL SELECT 'CtaCteVT',                    COUNT(*) FROM CtaCteVT
UNION ALL SELECT 'MovTes',                      COUNT(*) FROM MovTes
UNION ALL SELECT 'Productos',                   COUNT(*) FROM Productos
UNION ALL SELECT 'Rutas',                       COUNT(*) FROM Rutas
UNION ALL SELECT 'repartos',                    COUNT(*) FROM repartos
UNION ALL SELECT 'CondPAGO',                    COUNT(*) FROM CondPAGO
UNION ALL SELECT 'TiposCli',                    COUNT(*) FROM TiposCli
UNION ALL SELECT 'Categorias',                  COUNT(*) FROM Categorias
UNION ALL SELECT 'ClientesAtrLis',              COUNT(*) FROM ClientesAtrLis
UNION ALL SELECT 'CteVtas',                     COUNT(*) FROM CteVtas
UNION ALL SELECT 'CptTes',                      COUNT(*) FROM CptTes
ORDER BY Filas DESC;
