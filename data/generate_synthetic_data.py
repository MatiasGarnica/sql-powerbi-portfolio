"""
generate_synthetic_data.py
==========================
Generador de datos sintéticos para la base H2O_JUMI (distribuidora de agua).
Crea 21 archivos CSV con integridad referencial, simulando ~24 meses de
operación con ~15.000 clientes y ~500.000 pedidos.

Uso:
    pip install faker pandas numpy
    python generate_synthetic_data.py

Salida:
    ./data/csv/*.csv
"""

import random
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
SEED                  = 42
N_CLIENTES_ACTIVOS    = 14_000
N_CLIENTES_BAJA       = 1_000
PCT_HOGAR             = 0.78
PCT_GASTRO            = 0.12
PCT_EMPRESA           = 0.10
PCT_CTACTE            = 0.22
PCT_FC                = 0.18
PCT_MADRES_HIJAS      = 0.04
PCT_BARRIO_CERRADO    = 0.06
MESES_HISTORIA        = 24
PROM_PED_MES_HOGAR    = 1.1
PROM_PED_MES_EMPRESA  = 3.8
PROM_PED_MES_GASTRO   = 2.5

OUTPUT_DIR = Path('./data/csv')
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

random.seed(SEED); np.random.seed(SEED); Faker.seed(SEED)
fake = Faker('es_AR')

HOY           = datetime(2026, 5, 19)
FECHA_INICIO  = HOY - timedelta(days=30 * MESES_HISTORIA)

print(f"Generando datos sintéticos H2O_JUMI · seed={SEED}")
print(f"Ventana: {FECHA_INICIO.date()} → {HOY.date()}")
print("─" * 60)

# ============================================================================
# 1) CATÁLOGOS
# ============================================================================
print("[1/7] Catálogos…")

condpago = pd.DataFrame([
    (1, 'CONTADO',          0, 1, '01'),
    (2, 'CTA CTE 30 DIAS', 30, 1, '02'),
    (3, 'CTA CTE 60 DIAS', 60, 2, '03'),
    (4, 'CTA CTE 90 DIAS', 90, 3, '04'),
], columns=['Codigo','Descrp','DiasCR','Cuotas','CodAlt'])

tiposcli = pd.DataFrame([
    ('HOG','HOGAR',          'LP01'),
    ('EMP','EMPRESA',        'LP02'),
    ('GAS','GASTRONOMIA',    'LP03'),
    ('INS','INSTITUCIONAL',  'LP04'),
    ('GCT','GRANDES CUENTAS','LP05'),
], columns=['Codigo','Descrp','IdListaPrecio'])

categorias = pd.DataFrame([
    ('CAT-A','PREMIUM'),
    ('CAT-B','ESTANDAR'),
    ('CAT-C','BASICO'),
    ('CAT-D','MIGRADO'),
], columns=['Categoria','Descripcion'])

clientesatrlis = pd.DataFrame([
    (5,'CORP',  'Corporativo'),
    (5,'PYME',  'Pyme'),
    (5,'INDIV', 'Individual'),
    (5,'GASTRO','Gastronomico'),
], columns=['AtrNro','AtrCod','AtrDes'])

ctevtas = pd.DataFrame([
    ('FACA',  'FACTURA A',                    'D'),
    ('FACB',  'FACTURA B',                    'D'),
    ('FACSUC','FAC SUC',                      'D'),
    ('NCA',   'NOTA DE CREDITO A',            'H'),
    ('NCB',   'NOTA DE CREDITO B',            'H'),
    ('RECA',  'RECIBO A',                     'H'),
    ('RECB',  'RECIBO B',                     'H'),
    ('DI',    'DEBITO INTERNO',               'D'),
    ('CI',    'CREDITO INTERNO',              'H'),
    ('APL',   'APLICACION DE CUENTA CORRIENTE','D'),
], columns=['Codigo','Descrp','DebHab'])

cpttes = pd.DataFrame([
    ('EFE','EFECTIVO',        'D'),
    ('CHQ','CHEQUE',          'D'),
    ('TRF','TRANSFERENCIA',   'D'),
    ('DIG','PAGO DIGITAL',    'D'),
    ('TRJ','TARJETA',         'D'),
    ('RET','RETENCIONES',     'D'),
    ('CCB','COMPENSACION B',  'H'),
    ('CPA','COMPENSACION A',  'H'),
], columns=['Codigo','Descrp','DebHab'])

productos = pd.DataFrame([
    ('E',    'BIDON 20L',           'B20',   20.0, 'UN', 1,  None),
    ('EM',   'BIDON 12L',           'B12',   12.0, 'UN', 1,  None),
    ('F',    'BIDON 10L',           'B10',   10.0, 'UN', 1,  None),
    ('FM',   'BIDON 5L',            'B05',    5.0, 'UN', 1,  None),
    ('EMSC', 'BIDON 12L SIN CARGO', 'B12SC', 12.0, 'UN', 1,  None),
    ('m',    'SODA 600ML',          'SOD',    0.6, 'UN', 12, None),
    ('SX',   'PACK SODA X12',       'SODX12', 7.2, 'PK', 12, 12),
    ('AC',   'ALQUILER DISPENSER',  'ALQ',    0.0, 'UN', 1,  None),
    ('IN',   'INSTALACION',         'INS',    0.0, 'UN', 1,  None),
    ('RT',   'RETIRO',              'RET',    0.0, 'UN', 1,  None),
    ('VS',   'VASO DESCARTABLE',    'VAS',    0.0, 'PK', 100,None),
], columns=['idProducto','Descripcion','Abreviatura','Litros','Unidad','Orden','cantidad_x_bulto'])

for df, name in [(condpago,'CondPAGO'),(tiposcli,'TiposCli'),(categorias,'Categorias'),
                 (clientesatrlis,'ClientesAtrLis'),(ctevtas,'CteVtas'),(cpttes,'CptTes'),
                 (productos,'Productos')]:
    df.to_csv(OUTPUT_DIR / f'{name}.csv', index=False)

print(f"   ✓ 7 catálogos guardados")

# ============================================================================
# 2) RUTAS y REPARTOS
# ============================================================================
print("[2/7] Rutas y repartos (jerarquía comercial)…")

SUPERVISORES = [
    (201,'SUPERVISOR ZONA NORTE'),
    (202,'SUPERVISOR ZONA SUR'),
    (203,'SUPERVISOR ZONA ESTE'),
    (204,'SUPERVISOR ZONA OESTE'),
    (205,'SUPERVISOR GASTRONOMIA'),
    (206,'SUPERVISOR INSTITUCIONAL'),
    (207,'SUPERVISOR GRANDES CUENTAS'),
    (208,'SUPERVISOR LA PLATA'),
]

repartos_rows = []
rutas_rows    = []

for cod, descr in SUPERVISORES:
    repartos_rows.append((cod, descr, 0.0, cod, None, '01'))

def crear_rango(rango, supervisor, tipo='VND'):
    for c in rango:
        descr = f"{tipo} {c:04d}"
        repartos_rows.append((c, descr, 5.0, supervisor, None, '01'))
        codigo_ruta = f"R{c:04d}"
        dia_rep = random.choice(['LUNES','MARTES','MIERCOLES','JUEVES','VIERNES','SABADO'])
        rutas_rows.append((codigo_ruta, f"RUTA {c:04d}", c, dia_rep, 7, c))

crear_rango(range(1, 50),    201)
crear_rango(range(50, 100),  202)
crear_rango(range(100, 123), 203)
crear_rango(range(251, 282), 204)
crear_rango(range(401, 435), 208)
crear_rango(range(155, 177), 205)
crear_rango(range(460, 482), 206)

ESPECIALES = [
    (146,'FUGADOS',           201),
    (147,'CORRECCION INTERNA',201),
    (148,'BAJAS POR DEUDA',   201),
    (149,'BAJAS VOLUNTARIAS', 201),
    (179,'TECNICO 01',        201),
    (181,'TECNICO 02',        202),
    (186,'TECNICO 03',        203),
    (197,'TECNICO 04',        204),
    (198,'TECNICO 05',        205),
    (440,'ALMACEN CENTRAL',   207),
    (441,'ALMACEN SUR',       207),
    (200,'INCOBRABLES',       207),
]
for cod, descr, sup in ESPECIALES:
    repartos_rows.append((cod, descr, 0.0, sup, None, '01'))

repartos = pd.DataFrame(repartos_rows,
    columns=['Codigo','Descrp','PctCom','CodSup','NroCta','Sucursal'])
rutas = pd.DataFrame(rutas_rows,
    columns=['Codigo','Descrp','Vnddor','DiaRep','Frecuencia','Orden'])

VENDEDORES_ACTIVOS = sorted(rutas['Vnddor'].tolist())
VENDEDORES_GASTRO  = list(range(155, 177))
VENDEDORES_EMPRESA = list(range(460, 482))
RUTAS_CODES        = rutas['Codigo'].tolist()

repartos.to_csv(OUTPUT_DIR / 'repartos.csv', index=False)
rutas.to_csv(OUTPUT_DIR / 'Rutas.csv', index=False)
print(f"   ✓ {len(SUPERVISORES)} supervisores, {len(VENDEDORES_ACTIVOS)} vendedores, {len(ESPECIALES)} especiales")

# ============================================================================
# 3) CLIENTES + CLIENTES_BAJA
# ============================================================================
print("[3/7] Clientes (15.000 cuentas)…")

BARRIOS_CERRADOS = [
    'NORDELTA','BAHIA GRANDE','BAHIA SAN MARCO','EL TRIGAL','LOS LAGOS',
    'PILAR DEL ESTE','CAMPOS DE ECHEVERRIA','SAN AGUSTIN','SANTA CATALINA',
    'BARRIO ABRIL','ALTOS DE GOLF','LOS CARDALES','AYRES DEL PILAR'
]
LOCALIDADES = ['BUENOS AIRES','PILAR','TIGRE','SAN ISIDRO','LA PLATA','QUILMES',
               'BERAZATEGUI','LOMAS DE ZAMORA','MORON','SAN MIGUEL','ESCOBAR',
               'CAMPANA','ZARATE','LANUS','AVELLANEDA']

total_clientes = N_CLIENTES_ACTIVOS + N_CLIENTES_BAJA
nrocta_inicial = 1001

tipos_cli = np.random.choice(['HOG','GAS','EMP','INS','GCT'],
                              size=total_clientes,
                              p=[0.78, 0.11, 0.09, 0.01, 0.01])
cnd_pag_choice = np.random.choice([1,2,3,4], size=total_clientes,
                                   p=[1-PCT_CTACTE, 0.10, 0.08, 0.04])
dias_atras = np.random.randint(30, 365*5, size=total_clientes)
fec_alt = [HOY - timedelta(days=int(d)) for d in dias_atras]

print("   · Pre-generando pool de nombres y direcciones…")
POOL_NOMBRES_HOG = [fake.name() for _ in range(3000)]
POOL_NOMBRES_EMP = [fake.company().upper() for _ in range(2000)]
POOL_DIRECCIONES = [fake.street_address().upper() for _ in range(5000)]

clientes_rows = []
for i in range(total_clientes):
    nrocta = nrocta_inicial + i
    tipo   = tipos_cli[i]

    if tipo in ('EMP','GAS','INS','GCT'):
        nombre = random.choice(POOL_NOMBRES_EMP)
    else:
        nombre = random.choice(POOL_NOMBRES_HOG).upper()

    r = random.random()
    if r < PCT_BARRIO_CERRADO:
        direcc = f"{random.choice(POOL_DIRECCIONES).split(',')[0]}, {random.choice(BARRIOS_CERRADOS)}"
    elif r < PCT_BARRIO_CERRADO + 0.005:
        direcc = 'AV. CENTRAL 1234'
    else:
        direcc = random.choice(POOL_DIRECCIONES)

    localidad = random.choice(LOCALIDADES)
    telefono  = f"011-{random.randint(4000,9999)}-{random.randint(1000,9999)}"
    email     = f"cliente{nrocta}@email-demo.com"
    nrcuit    = f"{random.randint(20,30)}-{random.randint(10000000,40000000)}-{random.randint(0,9)}"

    atrib1     = '1' if tipo == 'HOG' else '0'
    atrib5_cod = {'HOG':'INDIV','GAS':'GASTRO','EMP':'PYME','INS':'CORP','GCT':'CORP'}[tipo]
    categoria  = random.choice(['CAT-A','CAT-B','CAT-C','CAT-D'])

    clientes_rows.append((
        nrocta, nombre, direcc, random.randint(1,200), localidad, 'ARGENTINA',
        0, categoria, telefono, email, 'I', nrcuit, '   ',
        int(cnd_pag_choice[i]), 'LP01', tipo, 0, '', 'M', 0, 1, 0, 0,
        fec_alt[i], fec_alt[i], nombre, direcc, localidad, '', 'S', 1, 100,
        'I', 0.0, 1, 'EX', '', '-34.5', '-58.4', 'sistema_carga', '', 0, '', 0.0,
        None, 'sistema_mod', 1, 0.0,
        '', atrib1, '', '', '', atrib5_cod, '', '', '', '',
        -34.5, -58.4, '', 0.0, None, None
    ))

cols_clientes = [
    'NroCta','Nombre','Direcc','Idlocalidad','Locali','NomPai','NroSub','Categoria',
    'Telefn','EMails','CndIva','NrCUIT','ZonaVT','CndPag','IdListaPrecio','TipCli',
    'Requiere_Comprobante','Sucursal_Comprobante','Periodo_Facturacion',
    'Certificado_Recepcion','Tipo_Factura','Tipo_Cobranza','Cobrador','FecAlt','FecMod',
    'NombreFiscal','DomicilioFiscal','LocalidadFiscal','CodAlt','Transf_Status',
    'IdProvincia','suma_fiado_reparto','InscIB','Porc_IIBB','Pcia_IIBB','Situacion_IIBB',
    'Nro_IIBB','Latitud','Longitud','Usuario','TeMovil','IdImpuestoMunicipal',
    'BaseCalculoImpuestoMunicipal','TasaImpuestoMunicipal','fecha_nacimiento',
    'Usuario_mod','GENERA_FACTURA_ELECTRONICA','saldo',
    'Atrib0','Atrib1','Atrib2','Atrib3','Atrib4','Atrib5','Atrib6','Atrib7','Atrib8','Atrib9',
    'Latitud2','Longitud2','RG5329MotivoExencion','RG5329PorcentajeExencion',
    'RG5329ExencionDesde','RG5329ExencionHasta'
]
df_clientes_full = pd.DataFrame(clientes_rows, columns=cols_clientes)
df_clientes      = df_clientes_full.iloc[:N_CLIENTES_ACTIVOS].copy()
df_clientes_baja = df_clientes_full.iloc[N_CLIENTES_ACTIVOS:].copy()

# Bajas: agregar FecBaj
fec_baj_list = []
for fa in df_clientes_baja['FecAlt']:
    dias_disp = (HOY - fa).days - 1
    dias_baja = random.randint(30, max(31, min(720, dias_disp)))
    fec_baj_list.append(fa + timedelta(days=dias_baja))
df_clientes_baja['FecBaj'] = fec_baj_list

df_clientes_baja['IdClienteBaja'] = range(1, len(df_clientes_baja) + 1)
df_clientes_baja['IdMotivo']      = np.random.choice(['M01','M02','M03','M04'], size=len(df_clientes_baja))
df_clientes_baja['CdRuta']        = np.random.choice(RUTAS_CODES, size=len(df_clientes_baja))
df_clientes_baja['Orden']         = np.random.randint(1, 999, size=len(df_clientes_baja))
df_clientes_baja['Usuario']       = 'sistema_baja'

cols_baja = [
    'IdClienteBaja','NroCta','Nombre','Direcc','Locali','NomPai','Telefn','EMails',
    'CndIva','NrCUIT','ZonaVT','CndPag','IdListaPrecio','TipCli','Categoria','NroSub',
    'IdMotivo','CdRuta','Orden','FecAlt','FecBaj','Usuario','Requiere_Comprobante',
    'Sucursal_Comprobante','Periodo_Facturacion','Certificado_Recepcion','Tipo_Factura',
    'Tipo_Cobranza','NombreFiscal','DomicilioFiscal','LocalidadFiscal','CodAlt',
    'IdProvincia','InscIB','Porc_IIBB','Situacion_IIBB','Nro_IIBB','Pcia_IIBB','TeMovil',
    'IdImpuestoMunicipal','BaseCalculoImpuestoMunicipal','TasaImpuestoMunicipal',
    'IDLOCALIDAD','FECHA_NACIMIENTO','GENERA_FACTURA_ELECTRONICA',
    'Atrib0','Atrib1','Atrib2','Atrib3','Atrib4','Atrib5','Atrib6','Atrib7','Atrib8','Atrib9'
]
df_clientes_baja_out = df_clientes_baja.rename(columns={'Idlocalidad':'IDLOCALIDAD',
                                                         'fecha_nacimiento':'FECHA_NACIMIENTO'})[cols_baja]

df_clientes.to_csv(OUTPUT_DIR / 'Clientes.csv', index=False)
df_clientes_baja_out.to_csv(OUTPUT_DIR / 'ClientesBaja.csv', index=False)

CLIENTES_ACTIVOS_IDS = df_clientes['NroCta'].tolist()
TIPOS_POR_CLIENTE    = dict(zip(df_clientes['NroCta'], df_clientes['TipCli']))
CND_PAG_POR_CLIENTE  = dict(zip(df_clientes['NroCta'], df_clientes['CndPag']))
FECALT_POR_CLIENTE   = dict(zip(df_clientes['NroCta'], df_clientes['FecAlt']))

print(f"   ✓ {len(df_clientes):,} activos · {len(df_clientes_baja):,} bajas")

# ============================================================================
# 4) RELACIONES CLIENTES (Rutas, Madres-Hijas, FC)
# ============================================================================
print("[4/7] Relaciones cliente-ruta, cuentas madre-hija, equipos F/C…")

RUTAS_HOGAR_OESTE = [r for r in RUTAS_CODES if int(r[1:]) < 250 or 251 <= int(r[1:]) < 282]
RUTAS_GASTRO     = [r for r in RUTAS_CODES if int(r[1:]) in VENDEDORES_GASTRO]
RUTAS_EMPRESA    = [r for r in RUTAS_CODES if int(r[1:]) in VENDEDORES_EMPRESA]
RUTAS_LA_PLATA   = [r for r in RUTAS_CODES if 401 <= int(r[1:]) < 435]

def asignar_ruta(tipo):
    if tipo == 'GAS':
        return random.choice(RUTAS_GASTRO)
    if tipo in ('EMP','INS','GCT'):
        return random.choice(RUTAS_EMPRESA)
    return random.choice(RUTAS_HOGAR_OESTE + RUTAS_LA_PLATA)

clientes_rutas_rows = []
for nrocta, tipo in TIPOS_POR_CLIENTE.items():
    cd_ruta = asignar_ruta(tipo)
    clientes_rutas_rows.append((cd_ruta, random.randint(1,999), 'V', nrocta, 1))

for nrocta in df_clientes_baja['NroCta'].tolist():
    cd_ruta = random.choice(RUTAS_CODES)
    clientes_rutas_rows.append((cd_ruta, random.randint(1,999), 'V', nrocta, 0))

clientes_rutas = pd.DataFrame(clientes_rutas_rows,
    columns=['CdRuta','OrdRut','Tipo','Cliente_Ruteo','Estado'])
clientes_rutas.to_csv(OUTPUT_DIR / 'ClientesRutas.csv', index=False)

empresas_y_gastro = [c for c,t in TIPOS_POR_CLIENTE.items() if t in ('EMP','GAS','INS','GCT')]
random.shuffle(empresas_y_gastro)
n_madres = int(len(empresas_y_gastro) * PCT_MADRES_HIJAS)
madres = empresas_y_gastro[:n_madres]
hijas  = empresas_y_gastro[n_madres:n_madres*4]

cmh_rows = []
for i, hija in enumerate(hijas):
    madre = madres[i % len(madres)]
    if hija != madre:
        cmh_rows.append((hija, madre))
cmh = pd.DataFrame(cmh_rows, columns=['IdCliente','Cta_Madre'])
cmh.to_csv(OUTPUT_DIR / 'Clientes_Ctas_Madres_e_Hijas.csv', index=False)

clientes_con_fc = random.sample(CLIENTES_ACTIVOS_IDS, int(len(CLIENTES_ACTIVOS_IDS) * PCT_FC))
MODELOS_FC = ['DISP-COLD-A','DISP-COLD-B','DISP-CC-100','DISP-CC-200','DISP-PREMIUM']

cs_rows = []
for i, cli in enumerate(clientes_con_fc):
    fec_desde = FECALT_POR_CLIENTE[cli] + timedelta(days=random.randint(30, 365))
    if fec_desde > HOY:
        fec_desde = HOY - timedelta(days=random.randint(30, 365))
    fec_baja = fec_desde + timedelta(days=random.randint(180, 1500)) if random.random() < 0.10 else None
    if fec_baja and fec_baja > HOY:
        fec_baja = None
    cs_rows.append((
        cli, 1, 1, 1000 + i, 'COLD-TECH', random.choice(MODELOS_FC),
        f"SN-{10000+i:06d}", 0.0, '', '', '',
        fec_desde, None, fec_desde, None, fec_baja, 'AC', 'OFICINA'
    ))
cs = pd.DataFrame(cs_rows, columns=[
    'IdCliente','IdServicio','NrItem','IdEquipo','Marca','Modelo','Nro_Serie',
    'Porcentaje_Descuento','Contrato','NroOrdenAlta','NroOrdenBaja',
    'Fecha_Desde','Fecha_Hasta','Fecha_Alta','Fecha_Modificacion','Fecha_Baja',
    'IdProducto','Sector'
])
cs.to_csv(OUTPUT_DIR / 'ClientesServicios.csv', index=False)

me_rows = []
for i, row in cs.iterrows():
    me_rows.append((
        len(me_rows) + 1, row['Fecha_Desde'], random.choice([179,181,186,197,198]),
        row['IdCliente'], None, row['Nro_Serie'], 'AC', 'I', 0, None, None, 'tecnico_demo'
    ))
    if row['Fecha_Baja'] is not None:
        me_rows.append((
            len(me_rows) + 1, row['Fecha_Baja'], random.choice([179,181,186,197,198]),
            row['IdCliente'], None, row['Nro_Serie'], 'AC', 'R', 0, None, None, 'tecnico_demo'
        ))
me = pd.DataFrame(me_rows, columns=[
    'IdMovimiento','Fecha','IdReparto','IdCliente','IdClienteNuevo','Nro_Serie',
    'IdProducto','Tipo_Movimiento','Anulado','Equipo_Asignado','IdRecambio','Usuario'
])
me.to_csv(OUTPUT_DIR / 'Movimientos_Equipos.csv', index=False)

print(f"   ✓ {len(clientes_rutas):,} relaciones · {len(cmh):,} madre-hija · {len(cs):,} equipos F/C")

# ============================================================================
# 5) PEDIDOS y PEDIDOS_PRODUCTOS
# ============================================================================
print("[5/7] Pedidos y líneas (tarda ~3 minutos)…")

prom_por_tipo = {'HOG':PROM_PED_MES_HOGAR,'GAS':PROM_PED_MES_GASTRO,
                 'EMP':PROM_PED_MES_EMPRESA,'INS':PROM_PED_MES_EMPRESA,
                 'GCT':PROM_PED_MES_EMPRESA * 1.5}

ruta_por_cliente = (clientes_rutas[clientes_rutas['Estado']==1]
                    .drop_duplicates('Cliente_Ruteo')
                    .set_index('Cliente_Ruteo')['CdRuta'])
vendedor_por_ruta = rutas.set_index('Codigo')['Vnddor'].to_dict()

PROD_AGUA   = ['E','EM','F','FM','EMSC']
PROD_SODA   = ['m','SX']
PROD_PRECIOS = {
    'E': 4500, 'EM': 3200, 'F': 2800, 'FM': 1600, 'EMSC': 0,
    'm': 1200, 'SX': 13000, 'AC': 8000, 'IN': 5000, 'RT': 0, 'VS': 2200
}

pedidos_rows = []
pp_rows = []
idpedido = 100_001

for nrocta in CLIENTES_ACTIVOS_IDS:
    tipo    = TIPOS_POR_CLIENTE[nrocta]
    fec_alt = FECALT_POR_CLIENTE[nrocta]
    inicio  = max(fec_alt, FECHA_INICIO)
    meses_activos = max(1, int((HOY - inicio).days / 30))
    lambda_ = prom_por_tipo[tipo] * meses_activos
    n_ped = np.random.poisson(lambda_)
    if n_ped == 0:
        continue
    cd_ruta = ruta_por_cliente.get(nrocta)
    if pd.isna(cd_ruta) or cd_ruta is None:
        continue
    idvend = vendedor_por_ruta.get(cd_ruta)
    duracion = (HOY - inicio).days
    if duracion <= 0:
        continue
    fechas_offset = sorted(random.sample(range(duracion), min(n_ped, duracion)))
    fechas = [inicio + timedelta(days=d) for d in fechas_offset]

    es_primera_compra = True
    for fp in fechas:
        idv = idvend if random.random() > 0.03 else random.choice([146,147,148,149,200])
        pedidos_rows.append((idpedido, idv, fp, nrocta, 'N', f"{idpedido:08d}", '', 0, 'PR', 0))

        n_lineas = {'HOG': np.random.choice([1,2], p=[0.7,0.3]),
                    'GAS': np.random.choice([2,3,4], p=[0.4,0.4,0.2]),
                    'EMP': np.random.choice([2,3,4], p=[0.3,0.5,0.2]),
                    'INS': np.random.choice([2,3], p=[0.5,0.5]),
                    'GCT': np.random.choice([3,4,5], p=[0.4,0.4,0.2])}[tipo]
        productos_orden = random.sample(PROD_AGUA, min(n_lineas, len(PROD_AGUA)))
        if random.random() < 0.18:
            productos_orden.append(random.choice(PROD_SODA))

        for prod in productos_orden:
            cant = max(1, int(np.random.normal(3, 2)))
            precio = PROD_PRECIOS[prod]
            if es_primera_compra and prod in PROD_AGUA and random.random() < 0.25:
                precio = 0
            tipo_bonif = '0' if precio > 0 else 'P'
            pp_rows.append((idpedido, prod, 'V', cant, precio, tipo_bonif))

        es_primera_compra = False
        idpedido += 1

pedidos = pd.DataFrame(pedidos_rows, columns=[
    'idPedido','idVendedor','Fecha_Pedido','idCliente','Factura','Nro_Comprobante',
    'CodForExp','NroForExp','Status','IDCLIENTENUEVO'
])
pedidos_productos = pd.DataFrame(pp_rows, columns=[
    'idPedido','idProducto','Tipo','Cantidad','Precio','TIPOBONIFICACION'
])
pedidos.to_csv(OUTPUT_DIR / 'Pedidos.csv', index=False)
pedidos_productos.to_csv(OUTPUT_DIR / 'Pedidos_Productos.csv', index=False)
print(f"   ✓ {len(pedidos):,} pedidos · {len(pedidos_productos):,} líneas")

# ============================================================================
# 6) MOVIMIENTOS_CAJA / MOVIMIENTOS_CAJA_AJUSTES
# ============================================================================
print("[6/7] Movimientos de caja…")

mc_rows = []
mca_rows = []
idmov = 1
idaj = 1
clientes_contado = set(c for c,p in CND_PAG_POR_CLIENTE.items() if p == 1)

pedidos_totales = (pedidos_productos.assign(total=lambda x: x['Cantidad']*x['Precio'])
                   .groupby('idPedido')['total'].sum().to_dict())

for _, ped in pedidos.iterrows():
    if ped['idCliente'] not in clientes_contado:
        continue
    importe = pedidos_totales.get(ped['idPedido'], 0)
    if importe <= 0:
        continue
    mc_rows.append((idmov, ped['idVendedor'], ped['idPedido'], ped['idCliente'],
                    ped['Fecha_Pedido'], 'Su Compra', importe, None, '', None, '', None))
    idmov += 1
    if random.random() < 0.85:
        fec_pago = ped['Fecha_Pedido'] + timedelta(days=random.randint(0, 3))
        mc_rows.append((idmov, ped['idVendedor'], ped['idPedido'], ped['idCliente'],
                        fec_pago, 'Su Pago', -importe, None, f"R{idmov:06d}", None, '', None))
        idmov += 1

for cli in clientes_con_fc:
    if cli not in clientes_contado:
        continue
    cs_cliente = cs[cs['IdCliente']==cli]
    if cs_cliente.empty:
        continue
    fec_inicio_fc = cs_cliente.iloc[0]['Fecha_Desde']
    fec_fin_fc    = cs_cliente.iloc[0]['Fecha_Baja'] or HOY
    if fec_inicio_fc < FECHA_INICIO:
        fec_inicio_fc = FECHA_INICIO
    cursor = datetime(fec_inicio_fc.year, fec_inicio_fc.month, 1)
    while cursor < min(fec_fin_fc, HOY):
        importe_fc = random.choice([8000, 12000, 15000, 18000])
        fecha_mov = cursor + timedelta(days=random.randint(1,28))
        mca_rows.append((idaj, 200, cli, fecha_mov, 'Alquiler F/C', importe_fc,
                         'JOB_FC', '', None, None, idaj, None))
        idaj += 1
        if random.random() < 0.08:
            mca_rows.append((idaj, 200, cli, fecha_mov + timedelta(days=2),
                             'NC F/C', -importe_fc * 0.3, 'JOB_NC', '', None, None, idaj, None))
            idaj += 1
        cursor = (cursor.replace(day=1) + timedelta(days=32)).replace(day=1)

for _ in range(2000):
    cli = random.choice(CLIENTES_ACTIVOS_IDS)
    fec = FECHA_INICIO + timedelta(days=random.randint(0, (HOY-FECHA_INICIO).days))
    imp = random.choice([1000, -1000, 5000, -5000, 10000, -10000])
    mca_rows.append((idaj, random.choice(VENDEDORES_ACTIVOS), cli, fec, 'Ajuste manual',
                     imp, 'JOB_AJUSTE', '', None, None, idaj, None))
    idaj += 1

mc = pd.DataFrame(mc_rows, columns=[
    'IdMovimiento','IdReparto','IdPedido','IdCliente','Fecha','Descripcion','Importe',
    'IDCLIENTENUEVO','Nro_Recibo','IdMotivo','id_pago','id_gateway_pago'
])
mca = pd.DataFrame(mca_rows, columns=[
    'idAjuste','idReparto','idCliente','Fecha','Descripcion','Importe',
    'Usuario','codmov','nromov','IDTIPOAJUSTE','IdAjuste_Nuevo','idfactura'
])
mc.to_csv(OUTPUT_DIR / 'Movimientos_Caja.csv', index=False)
mca.to_csv(OUTPUT_DIR / 'Movimientos_Caja_Ajustes.csv', index=False)
print(f"   ✓ {len(mc):,} mov caja · {len(mca):,} ajustes")

# ============================================================================
# 7) CtaCteVT y MovTes
# ============================================================================
print("[7/7] CtaCteVT y MovTes…")

clientes_ctacte = set(c for c,p in CND_PAG_POR_CLIENTE.items() if p in (2,3,4))

ccvt_rows = []
nromov = 1
for _, ped in pedidos.iterrows():
    if ped['idCliente'] not in clientes_ctacte:
        continue
    importe = pedidos_totales.get(ped['idPedido'], 0)
    if importe <= 0:
        continue
    ccvt_rows.append(('FACA', nromov, 1, 'FACA', ped['Fecha_Pedido'],
                      str(ped['idCliente']), '0', '', 0, ped['Fecha_Pedido']+timedelta(days=30),
                      importe, f"FAC-{nromov:08d}", ped['idPedido']))
    if random.random() < 0.75:
        fec_rec = ped['Fecha_Pedido'] + timedelta(days=random.randint(5, 60))
        if fec_rec < HOY:
            ccvt_rows.append(('RECA', nromov, 1, 'RECA', fec_rec, str(ped['idCliente']),
                              '0', 'FACA', nromov, None, -importe, f"REC-{nromov:08d}", None))
    if random.random() < 0.05:
        ccvt_rows.append(('NCA', nromov, 1, 'NCA', ped['Fecha_Pedido']+timedelta(days=5),
                          str(ped['idCliente']), '0', 'FACA', nromov, None,
                          -importe*0.2, f"NC-{nromov:08d}", None))
    nromov += 1

ccvt = pd.DataFrame(ccvt_rows, columns=[
    'CodMov','NroMov','NrItem','CteOri','FchMov','NroCta','NroSub','CodApl','NroApl',
    'FchVnc','Import','Refern','idfactura'
])
ccvt.to_csv(OUTPUT_DIR / 'CtaCteVT.csv', index=False)

movtes_rows = []
nromov_tes = 1
for _, mov in mc[mc['Descripcion']=='Su Pago'].iterrows():
    cpt = np.random.choice(['EFE','TRF','DIG','TRJ','CHQ'], p=[0.42,0.10,0.30,0.10,0.08])
    movtes_rows.append((
        'RECC', nromov_tes, 1, mov['Fecha'], 'C', str(int(mov['IdCliente'])),
        f"REC{int(mov['IdReparto']):04d}{nromov_tes}", cpt,
        '001', '001', random.randint(1,9999), str(random.randint(10000000,99999999)),
        f"CC{random.randint(10000,99999)}", '', None, '01', abs(mov['Importe']), 'D', '01', None
    ))
    nromov_tes += 1
for _, mov in ccvt[ccvt['CodMov']=='RECA'].iterrows():
    cpt = np.random.choice(['TRF','CHQ','DIG'], p=[0.55,0.30,0.15])
    movtes_rows.append((
        'RECC', nromov_tes, 1, mov['FchMov'], 'C', mov['NroCta'],
        f"REC-{nromov_tes}", cpt,
        '001', '001', random.randint(1,9999), str(random.randint(10000000,99999999)),
        f"CC{random.randint(10000,99999)}", '', None, '01', abs(mov['Import']), 'D', '01', None
    ))
    nromov_tes += 1

movtes = pd.DataFrame(movtes_rows, columns=[
    'CodMov','NroMov','NrItem','FchMov','TipCta','NroCta','Refern','CodCpt',
    'NroBco','Sucurs','CPBcos','Cheque','Cuenta','Titular','FchVnc','CtaCte',
    'Import','DebHab','CodAsi','NroAsi'
])
movtes.to_csv(OUTPUT_DIR / 'MovTes.csv', index=False)
print(f"   ✓ {len(ccvt):,} mov cta cte · {len(movtes):,} mov tesorería")

# ============================================================================
# RESUMEN
# ============================================================================
print("─" * 60)
archivos = sorted(OUTPUT_DIR.glob('*.csv'))
total_mb = sum(f.stat().st_size for f in archivos) / (1024*1024)
print(f"✅ {len(archivos)} archivos · {total_mb:,.1f} MB totales")
print(f"📁 {OUTPUT_DIR.resolve()}")
print()
for f in archivos:
    n_rows = sum(1 for _ in open(f)) - 1
    print(f"   {f.name:<45} {n_rows:>10,} filas")
