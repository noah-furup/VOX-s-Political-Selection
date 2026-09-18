# -*- coding: utf-8 -*-
"""Que candidatura pertenece a que formacion.

Es la pieza delicada del proceso: en los boletines conviven decenas de
formaciones de nombre parecido. Cada regla se escribio despues de mirar el
censo completo de etiquetas (partidos_hist/out/censo_partidos.csv), no de
memoria.

Tipos:
  propia     la formacion concurre con su propio nombre
  coalicion  concurre dentro de una candidatura conjunta
  sucesora   organizacion posterior fundada por la misma direccion
  variante   denominacion historica emparentada, separada para poder excluirla

Una misma candidatura puede pertenecer a VARIAS formaciones (una coalicion
las incorpora a todas): `clasificar` devuelve una lista, no un unico valor.
"""
import re, unicodedata


def norm(s):
    s = ''.join(c for c in unicodedata.normalize('NFD', str(s))
                if unicodedata.category(c) != 'Mn').upper()
    return re.sub(r'\s+', ' ', s).strip(' .-')


# ---------------------------------------------------------------------------
# (formacion, tipo, patron sobre el NOMBRE, anhos admitidos o None)
# ---------------------------------------------------------------------------
_R = [
 # --- Plataforma per Catalunya -------------------------------------------
 ('Plataforma per Catalunya', 'propia',    r'^PLATAFORMA PER CATALUNYA( \(PXC\))?$', None),
 ('Plataforma per Catalunya', 'coalicion', r'^PARTIT AVANCA SALOU - PLATAFORMA PER CATALUNYA$'
                                           r'|^PLATAFORMA PER CATALUNYA&VECINOS DE SANTA COLOMA$', None),

 # --- Fuerza Nueva --------------------------------------------------------
 ('Fuerza Nueva', 'propia',    r'^(ASOCIACION POLITICA )?FUERZA NUEVA$', None),
 ('Fuerza Nueva', 'coalicion', r'^ALIANZA NACIONAL 18 DE JULIO$', None),
 # "Union Nacional" reaparece en 1999-2007 como partido distinto: solo 1979
 ('Fuerza Nueva', 'coalicion', r'^(PARTIDO )?UNION NACIONAL( ESPANOLA)?$'
                               r'|^COALICION UNION NACIONAL$', {'1979'}),
 ('Fuerza Nueva', 'sucesora',  r'^FRENTE NACIONAL$',
                               {'1986', '1987', '1989', '1991', '1993', '1994'}),

 # --- Comunion Tradicionalista Carlista -----------------------------------
 ('Comunion Tradicionalista Carlista', 'propia',    r'^COMUNION TRADICIONALISTA CARLISTA$', None),
 ('Comunion Tradicionalista Carlista', 'coalicion', r'^COMUNIDAD TRADICIONALISTA$'
                                                    r'|^ALIANZA NACIONAL 18 DE JULIO$', None),

 # --- Juntas Espanolas ----------------------------------------------------
 ('Juntas Espanolas', 'propia', r'^JUNTAS ESPANOLAS( JJ\.?EE\.?)?$', None),

 # --- Grupo Independiente Liberal (el de Jesus Gil) -----------------------
 ('Grupo Independiente Liberal', 'propia',
  r'^(AGRUPACION ELECTORAL )?GRUPO INDEPENDIENTE LIBERAL$'
  r'|^GRUPO INDEPENDIENTE LIBERAL DE ANDALUCIA$', None),

 # --- Partido Democrata Espanol (PADE) ------------------------------------
 ('PADE', 'propia',    r'^PARTIDO DEMOCRATA ESPANOL$', None),
 ('PADE', 'coalicion', r'^INDEP\.? POR ALCOBENDAS-PARTIDO DEMOCRATA ESPANOL$'
                       r'|^COALICIO VALENCIANA-PADE$', None),

 # --- Espana 2000 (se fundo como Plataforma Espana 2000) ------------------
 ('Espana 2000', 'propia',    r'^(PLATAFORMA )?ESPANA ?-? ?2000$', None),
 ('Espana 2000', 'coalicion', r'^ESPANA 2000 SOLLANA$', None),

 # --- Movimiento Social Republicano ---------------------------------------
 ('Movimiento Social Republicano', 'propia',    r'^MOVIMI?ENT[O]? SOCIAL REPUBLICA(NO)?$', None),
 ('Movimiento Social Republicano', 'coalicion', r'^MOVIMI?ENT[O]? SOCIAL REPUBLICA(NO)? (PER|DE) .+$'
                                                r'|^FRENTE NACIONAL-MSR$', None),

 # --- Democracia Nacional (fundada en 1995) -------------------------------
 ('Democracia Nacional', 'propia', r'^(CANDIDATURA DE )?DEMOCRACIA NACIONAL$',
  {'1995','1996','1999','2000','2003','2004','2007','2008','2009','2011','2014','2015','2019','2023','2024'}),
 ('Democracia Nacional', 'coalicion', r'^FE DE LAS JONS, ALTERNATIVA ESPANOLA,LA FALANGE, DEMOCRACIA NACIONAL', None),

 # --- Via Democratica -----------------------------------------------------
 ('Via Democratica', 'propia', r'^VIA DEMOCRATICA$', None),

 # --- Falange Espanola de las JONS ----------------------------------------
 # "ESPA.OLA" cubre la enhe rota que dejan algunos ficheros ("ESPA?OLA")
 ('FE de las JONS', 'propia',
  r'^FALANGE ESPA.OLA DE LAS? J\.?O\.?N\.?S\.?$'
  r'|^FALANGE ESPA.OLA +J\.?O\.?N\.?S\.?$', None),
 ('FE de las JONS', 'variante',
  r'^FALANGE ESPA.OLA DE LAS? JONS AUTENTICA$'        # escision "Autentica" de 1977-1979
  r'|^FALANGE ESPA.OLA$', None),                      # "Falange Espanola" a secas (1979, 1983)
 ('FE de las JONS', 'coalicion',
  r'^FE DE LAS JONS, ALTERNATIVA ESPANOLA,LA FALANGE, DEMOCRACIA NACIONAL', None),

 # --- Falange Autentica ---------------------------------------------------
 ('Falange Autentica', 'propia',   r'^FALANGE AUTENTICA$', None),
 ('Falange Autentica', 'variante', r'^FALANGE ESPA.OLA AUTENTICA$', None),

 # --- La Falange ----------------------------------------------------------
 ('La Falange', 'propia',    r'^LA FALANGE$', None),
 ('La Falange', 'variante',  r'^FE/LA FALANGE$|^FALANGE ESPA.OLA/LA FALANGE$', None),
 ('La Falange', 'coalicion', r'^FE DE LAS JONS, ALTERNATIVA ESPANOLA,LA FALANGE, DEMOCRACIA NACIONAL', None),

 # --- ADN (europeas de 1994) ----------------------------------------------
 ('Alternativa Democrata Nacional', 'propia', r'^ALTERNATIVA DEMOCRATA NACIONAL$', None),

 # --- ADN (la coalicion de 2019), como formacion propia -------------------
 ('ADN (coalicion 2019)', 'propia',
  r'^FE DE LAS JONS, ALTERNATIVA ESPANOLA,LA FALANGE, DEMOCRACIA NACIONAL', None),

 # --- Union del Pueblo Navarro --------------------------------------------
 ('Union del Pueblo Navarro', 'propia',
  r'^UNION DEL PUEBLO ?NAVARR[OA]$|^UPN$|^UNION PUEBLO NAVARRO$'
  r'|^UNION DEL PUEBLO NAVARRO-UPN$', None),
 ('Union del Pueblo Navarro', 'coalicion',
  r'^UNION DEL PUEBLO NAVARRO ?-? ?A\.?P\.?-?P\.?D\.?P\.?$'
  r'|^UNION DEL PUEBLO NAVARRO.*PARTIDO POPULAR'
  r'|^UNION DEL PUEBLO NAVARRO EN COALICION CON EL PARTI'
  r'|^UNION DEL PUEBLO NAVARRO EN COALICION CON PARTIDO'
  r'|^NAVARRA SUMA$'
  r'|^COALICION UNION DEL PUEBLO \(UPN\) INDEPENDIENTES DE BURLADA', None),

 # --- Hacer Nacion --------------------------------------------------------
 ('Hacer Nacion', 'propia', r'^HACER NACION$', None),
]
REGLAS = [(p, t, re.compile(rx), a) for p, t, rx, a in _R]

# Reglas que se resuelven por la SIGLA porque el nombre impreso es generico
REGLAS_SIGLA = [
 ('Union del Pueblo Navarro', 'coalicion', re.compile(r'^AP-PL-UPN$'), None),   # Coalicion Popular 1986
]

# ---------------------------------------------------------------------------
# Formaciones de nombre parecido que NO son ninguna de las anteriores
# ---------------------------------------------------------------------------
EXCLUIR = re.compile(
    r'^PARTIDO CARLISTA'                 # Partido Carlista (EKA), de izquierdas
    r'|^PARTIT PER CATALUNYA'            # distinto de Plataforma per Catalunya
    r'|^AGRUPACION DE ELECTORES CARLISTAS'
    r'|^GRUPO INDEPENDIENTE (DE|LOGROSAN)'   # listas locales que comparten las siglas GIL
    r'|^ALGECIRAS GRUPO INDEPENDIENTE'
    r'|^PARTIDO ANTITAURINO'             # PACMA, nada que ver con PADE
    r'|^PARTIDO DEMOCRATICO ESPANOL'     # PDE, distinto de PADE
    r'|^PARTIDO SEGOVIANO'
    r'|^FALANGE ASTURIANA'               # comparte siglas FA con Falange Autentica
    r'|^FALANGE ESPANOLA INDEPENDIENTE'  # FEI, formacion propia
    r'|^MOVIMIENTO FALANGISTA'           # MFE, formacion propia
    r'|^UNIDAD FALANG'
    r'|^FALANGE ESPANOLA - UNIDAD FALANGISTA'
    r'|^UNIDADE POR NARON'               # comparte siglas UPN
    r'|^UNITS PER NULLES'
    r'|^HACER EL ESCORIAL'               # comparte la palabra "Hacer"
    r'|^NACION ANDALUZA')


def clasificar(nombre, sigla, anyo):
    """-> lista de (formacion, tipo). Vacia si la candidatura no interesa."""
    n, s = norm(nombre), norm(sigla)
    if EXCLUIR.match(n):
        return []
    out = []
    for partido, tipo, rex, anyos in REGLAS:
        if rex.match(n) and (anyos is None or anyo in anyos):
            out.append((partido, tipo))
    for partido, tipo, rex, anyos in REGLAS_SIGLA:
        if rex.match(s) and (anyos is None or anyo in anyos):
            out.append((partido, tipo))
    # una formacion no puede aparecer dos veces para la misma candidatura
    vistos, res = set(), []
    for p, t in out:
        if p in vistos:
            continue
        vistos.add(p); res.append((p, t))
    return res
