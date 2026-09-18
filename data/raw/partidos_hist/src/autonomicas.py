# -*- coding: utf-8 -*-
"""Candidatos de las formaciones estudiadas en las ELECCIONES AUTONOMICAS.

El Ministerio no publica microdatos autonomicos, asi que se trabaja sobre los
boletines de proclamacion de candidaturas ya descargados por los trabajos
anteriores:

  1979-2012  autonomicas_scrape/docs_pre2015  (327 documentos, 19 comunidades)
  2015-2026  autonomicas_scrape/docs          (los mapeados en docmap.CAND_DOCS)

Dos lectores distintos porque la maquetacion no tiene nada que ver:
  - los boletines antiguos van a varias columnas y sin numerar de forma fiable
    (se usa parse_old, el lector que ya se valido para PP en 2000-2012);
  - los modernos llevan "Candidatura num." (se usa parse_candnum via build_all).

Control: bajo listas cerradas una candidatura presenta tantos titulares como
escanos tiene la circunscripcion. Cada lista se marca como reconciliada o no.
"""
import os, re, sys, csv, glob, collections

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.path.insert(0, os.path.join('autonomicas_scrape', 'src'))

from reglas import clasificar, norm                       # noqa: E402
import parse_old as PO                                    # noqa: E402
from build_all import run_parser, canon_prov              # noqa: E402
from docmap import CAND_DOCS, CUTS                        # noqa: E402
from seats_table import seats                             # noqa: E402


def _referencia_pp():
    """(camara, eleccion, circunscripcion) -> titulares del PP.

    Las listas del PP de 2000-2012 ya se extrajeron y se truncaron a la
    longitud legal en el trabajo anterior, asi que sirven de segunda referencia
    de escanos alli donde la tabla estatica no llega.
    """
    import csv as _csv
    ref = collections.Counter()
    for fn in ('autonomicas_scrape/out_pre2015/pp_autonomicas_2000_2012.csv',
               'candidatos_pp_vox_autonomicas_2015_2026.csv'):
        if not os.path.exists(fn):
            continue
        for r in _csv.DictReader(open(fn, encoding='utf-8')):
            if str(r.get('is_titular', '')).upper() not in ('TRUE', '1'):
                continue
            if r.get('abbreviation') not in (None, '', 'PP'):
                continue
            ref[(r['chamber'], r['election'], r['province'])] += 1
    return ref


REF_PP = _referencia_pp()

# Correcciones a la tabla estatica de escanos, comprobadas en el propio
# boletin: la lista del PP de ese documento mide exactamente ese numero.
OVERRIDE_LOCAL = {
    ('madrid', 'autonomous_1999_06'): {'Madrid': 102},   # PP lee 102 en el mismo boletin
}

# Ninguna circunscripcion autonomica supera los escanos de su comunidad: sirve
# de tope para detectar lecturas desbocadas (el lector se come la candidatura
# siguiente y sigue leyendo hasta el final del documento).
def _tope(region):
    from seats_table import BASE
    d = BASE.get(region) or {}
    return max(d.values()) if d else 140

# Murcia imprime "CIRCUNSCRIPCION N.o" y el numero cae a menudo en la linea
# siguiente, asi que la deteccion generica se queda con el nombre de la region.
RE_CIRC_NUM = re.compile(r'CIRCUNSCRIPCI[OÓ]N\s*N\.?[ºo°]?\s*(\d)?', re.I)
ORDINALES = {'1': 'Primera', '2': 'Segunda', '3': 'Tercera', '4': 'Cuarta', '5': 'Quinta'}


# El detector generico busca el nombre de la provincia en cualquier linea, y
# se confunde cuando un candidato se apellida como ella ("Sra. Lorena Jurado i
# Tarragona" en un boletin que era entero de Lleida). El rotulo explicito de la
# cabecera manda sobre cualquier coincidencia suelta.
RE_CIRC_EXPL = re.compile(
    r"(?:CIRCUNSCRIPCI[OÓ]N|CIRCUMSCRIPCI[OÓ])\s*(?:ELECTORAL)?\s*:?\s*"
    r"([A-ZÁÉÍÓÚÑÜ][\wÁÉÍÓÚÑÜáéíóúñü .'-]{2,28})"
    r"|JUNTA ELECTORAL PROVINCIAL(?:\s+DE)?\s+([A-ZÁÉÍÓÚÑÜ][\wÁÉÍÓÚÑÜáéíóúñü .'-]{2,28})", re.I)


def circ_explicita(lineas, region):
    """Circunscripcion declarada en la cabecera del documento, si la hay."""
    from parse_old import CONSTITUENCIES
    validas = CONSTITUENCIES.get(region) or {}
    for l in lineas[:400]:
        m = RE_CIRC_EXPL.search(l)
        if not m:
            continue
        bruto = (m.group(1) or m.group(2) or '').strip(' .:,')
        for v in validas:
            if PO.sa(v) == PO.sa(bruto) or PO.sa(bruto).startswith(PO.sa(v)):
                return v
    return None


def circ_numerada(ls, i):
    """Busca hacia atras la circunscripcion numerada mas cercana."""
    for j in range(i, max(-1, i - 400), -1):
        m = RE_CIRC_NUM.search(ls[j])
        if not m:
            continue
        num = m.group(1)
        if not num:                       # el numero va en la linea siguiente
            for k in range(j + 1, min(len(ls), j + 3)):
                mm = re.match(r'^\s*(\d)\s*$', ls[k])
                if mm:
                    num = mm.group(1); break
        if num in ORDINALES:
            return ORDINALES[num]
    return None

TXT_VIEJO = 'autonomicas_scrape/txt_pre2015'
TXT_NUEVO = 'autonomicas_scrape/txt/'
OUT = 'partidos_hist/out'

MESES = {'ene': '01', 'feb': '02', 'mar': '03', 'abr': '04', 'may': '05', 'jun': '06',
         'jul': '07', 'ago': '08', 'sep': '09', 'oct': '10', 'nov': '11', 'dic': '12'}
CAMARA = {
 'andalucia': 'Parlamento de Andalucía', 'aragon': 'Cortes de Aragón',
 'asturias': 'Junta General del Principado de Asturias',
 'baleares': 'Parlament de les Illes Balears', 'canarias': 'Parlamento de Canarias',
 'cantabria': 'Parlamento de Cantabria', 'castilla-lamancha': 'Cortes de Castilla-La Mancha',
 'castillayleon': 'Cortes de Castilla y León', 'catalunya': 'Parlament de Catalunya',
 'ceuta': 'Asamblea de Ceuta', 'extremadura': 'Asamblea de Extremadura',
 'galicia': 'Parlamento de Galicia', 'madrid': 'Asamblea de Madrid',
 'melilla': 'Asamblea de Melilla', 'murcia': 'Asamblea Regional de Murcia',
 'navarra': 'Parlamento de Navarra', 'paisvasco': 'Parlamento Vasco',
 'rioja': 'Parlamento de La Rioja', 'valencia': 'Corts Valencianes',
}
REGION_ES = {k: v for k, v in {
 'andalucia': 'Andalucia', 'aragon': 'Aragon', 'asturias': 'Asturias',
 'baleares': 'Illes Balears', 'canarias': 'Canarias', 'cantabria': 'Cantabria',
 'castilla-lamancha': 'Castilla-La Mancha', 'castillayleon': 'Castilla y Leon',
 'catalunya': 'Cataluna', 'ceuta': 'Ceuta', 'extremadura': 'Extremadura',
 'galicia': 'Galicia', 'madrid': 'Madrid', 'melilla': 'Melilla', 'murcia': 'Murcia',
 'navarra': 'Navarra', 'paisvasco': 'Pais Vasco', 'rioja': 'La Rioja',
 'valencia': 'Comunidad Valenciana'}.items()}

# numeracion o vinetas que preceden al rotulo del partido en los boletines
RE_PREFIJO = re.compile(r'^\s*[\d]{0,3}\s*[.\-)•·]?\s*')
RE_SIGLA_FIN = re.compile(r'\s*\(([^()]{1,40})\)\s*$')
RE_ANOTACION = re.compile(
    r'\s*\((?:independiente|indep\.?|no afiliad[oa]|s\.?p\.?|sin filiaci[oó]n)\)\s*$', re.I)


def clasificar_linea(linea, anyo):
    """Como `clasificar`, pero sobre una linea suelta de boletin.

    El rotulo puede arrastrar VARIOS parentesis: "UNION DEL PUEBLO NAVARRO
    (UPN) (R-1)" lleva la sigla y el numero de orden en la papeleta. Se quitan
    todos y se prueban como sigla.
    """
    l = RE_PREFIJO.sub('', linea.strip())
    siglas = []
    while True:
        m = RE_SIGLA_FIN.search(l)
        if not m:
            break
        siglas.append(m.group(1))
        l = l[:m.start()].rstrip()
    for sg in (siglas or ['']):
        cl = clasificar(l, sg, anyo)
        if cl:
            return cl
    cl = clasificar(l, '', anyo)
    if cl:
        return cl
    # El boletin a veces pega delante texto de una fe de erratas
    # ("8, donde dice MEN- UNION DEL PUEBLO NAVARRO"): se prueban los sufijos,
    # exigiendo que el nombre del partido ocupe el final exacto de la linea.
    palabras = l.split()
    for k in range(1, min(len(palabras), 8)):
        cl = clasificar(' '.join(palabras[k:]), siglas[0] if siglas else '', anyo)
        if cl:
            return cl
    return []


RE_ENTRADA = re.compile(r"^\s*(\d{1,3})\s*[.\-)ºo]\s*(.{6,70})$")


def es_cabecera(linea):
    """Linea que rotula una candidatura (no un candidato).

    Se exige que NO empiece por numero, que sea corta y que vaya en
    mayusculas: asi no se confunde con un apellido que contenga "Union" o
    "Popular".
    """
    st = linea.strip()
    if not st or len(st) > 80 or RE_ENTRADA.match(st):
        return False
    letras = [c for c in st if c.isalpha()]
    if not letras or sum(1 for c in letras if c.isupper()) / len(letras) < 0.7:
        return False
    return bool(PO.PARTY_WORDS.search(PO.sa(st)) or re.match(r'CANDIDATURA', PO.sa(st)))


def completar_lista(ls, i, tit, necesita, ventana=1500):
    """Busca las posiciones que faltan de una lista corta.

    Cuando el lector se detiene antes de tiempo, los candidatos que faltan
    suelen seguir mas adelante en el documento (otra columna, otra pagina).
    Se buscan por su numero de orden dentro de una ventana a partir del rotulo,
    y solo se aceptan si la entrada tiene pinta de nombre de persona.
    """
    if not necesita or len(tit) >= necesita:
        return tit
    tengo = {p for p, _ in tit}
    faltan = [n for n in range(1, necesita + 1) if n not in tengo]
    nuevos = {}
    for l in ls[i + 1:i + 1 + ventana]:
        st = l.strip()
        # La busqueda se detiene en la cabecera de la candidatura siguiente:
        # sin este limite se rescatan candidatos de OTRO partido y la lista
        # queda contaminada.
        if es_cabecera(st):
            break
        m = RE_ENTRADA.match(st)
        if not m:
            continue
        n = int(m.group(1))
        if n not in faltan or n in nuevos:
            continue
        nom = PO.clean_name(m.group(2))
        if len(nom) < 8 or PO.NOISE.search(nom) or PO.PARTY_WORDS.search(PO.sa(nom)):
            continue
        nuevos[n] = nom
    if not nuevos:
        return tit
    return sorted(tit + [(n, v) for n, v in nuevos.items()], key=lambda x: x[0])


def listas_en_doc(lineas, region, anyo, el=None):
    """Toda lista de una formacion estudiada en el documento.

    Es `parse_old.lists_in_doc` con el patron de partido cambiado: en vez de
    buscar al PP, se busca cualquiera de las formaciones del estudio.
    """
    # Algunos boletines anotan "(Independiente)" detras del nombre y eso rompe
    # la deteccion de entrada numerada, cortando la lista en seco (UPN en
    # Navarra se quedaba en 3 de 50 candidatos por esto).
    lineas = [RE_ANOTACION.sub('', x) for x in lineas]
    ls = PO.drop_furniture(lineas)
    # drop_furniture borra las lineas que se repiten mucho, y en Murcia eso se
    # lleva por delante los rotulos "CIRCUNSCRIPCION N.o". Para localizar la
    # circunscripcion se recorre el texto SIN limpiar, avanzando en paralelo.
    circ_cruda, puntero = {}, 0
    for i_l, l_l in enumerate(ls):
        while puntero < len(lineas) and lineas[puntero].strip() != l_l.strip():
            puntero += 1
        circ_cruda[i_l] = puntero
        puntero += 1
    circ_doc = circ_explicita(lineas, region)
    out, vistos = [], set()
    for i, l in enumerate(ls):
        if len(l.strip()) > 80 or len(l.split()) > 12:
            continue
        if PO.NOISE.search(l):
            continue
        cl = clasificar_linea(l, anyo)
        if not cl:
            continue
        circ = (circ_doc or PO.constituency_near(ls, i, region)
                or PO.doc_constituency(ls, region))
        necesita = (OVERRIDE_LOCAL.get((region, el)) or {}).get(circ)
        if necesita is None:
            try:
                necesita = seats(region, el, circ) if (circ and el) else None
            except Exception:
                necesita = None
        if necesita is None:
            # (a) circunscripciones numeradas (Murcia, Asturias en algunos anhos)
            cn = circ_numerada(lineas, circ_cruda.get(i, 0)) or circ_numerada(ls, i)
            if cn:
                try:
                    n2 = seats(region, el, cn)
                except Exception:
                    n2 = None
                if n2:
                    circ, necesita = cn, n2
        if necesita is None and circ:
            # (b) segunda referencia: los titulares del PP en esa misma
            #     circunscripcion, ya validados en el trabajo anterior
            necesita = REF_PP.get((CAMARA.get(region, region), el, circ)) or None
        # Estas listas se imprimen a varias columnas: con un salto corto el
        # lector se queda a medias y con uno largo se cuela en la candidatura
        # siguiente. Se prueban varias densidades y gana la primera que alcanza
        # la longitud legal de la lista (misma tactica que build_lists.py).
        tit, sup, lector = [], [], ''
        tope = _tope(region)

        def probar(t, sp, nombre):
            """Con escanos conocidos gana la lectura que los alcanza. Sin
            referencia NO se coge la mas larga: una lectura desbocada se lleva
            cientos de nombres de otras candidaturas. Se prefiere la mas corta
            que sea plausible."""
            nonlocal tit, sup, lector
            if necesita:
                if len(t) >= necesita and (not tit or len(tit) < necesita):
                    tit, sup, lector = t[:necesita], sp, nombre
                    return True
                if len(t) > len(tit) and len(tit) < necesita:
                    tit, sup, lector = t, sp, nombre
                return False
            # sin referencia: descartamos lo que excede el tamano de la mayor
            # circunscripcion de la comunidad y nos quedamos con la primera
            # lectura plausible, que viene del salto mas corto
            if len(t) > tope:
                return False
            if not tit and len(t) >= 3:
                tit, sup, lector = t, sp, nombre
            return False

        # (a) lista numerada, probando varias densidades de salto: con un salto
        #     corto el lector se queda a medias entre columnas y con uno largo
        #     se cuela en la candidatura siguiente
        for salto in (60, 150, 400, 1200, 4000):
            t, sp = PO.harvest_run(ls, i, max_jump=salto)
            if probar(t, sp, f'numerada/{salto}'):
                break
        # (b) lista sin numerar, con cada nombre precedido de D./Dna.
        if not (necesita and len(tit) >= necesita):
            try:
                th, sh = PO.harvest_honorific(ls, i, max_lines=600)
                probar(th, sh, 'honorificos')
            except Exception:
                pass
        # (c) lista sin numerar ni tratamiento
        if not (necesita and len(tit) >= necesita):
            try:
                tu, su = PO.harvest_unnumbered({'lines': ls[i + 1:i + 600], 'idx': 0,
                                                'all_lines': ls, 'head': l})
                probar(tu, su, 'sin numerar')
            except Exception:
                pass
        # ultimo recurso: rescatar las posiciones que falten
        if necesita and len(tit) < necesita:
            tit = completar_lista(ls, i, tit, necesita)
        if len(tit) < 3:
            continue
        firma = (tuple(n for _, n in tit[:3]), len(tit))
        if firma in vistos:
            continue
        vistos.add(firma)
        out.append({'formaciones': cl, 'rotulo': l.strip(), 'circunscripcion': circ,
                    'titulares': tit, 'suplentes': sup, 'lector': lector,
                    'escanos': necesita})
    return out


def bloque_viejo():
    """Filas de 1979-2012."""
    filas, informe = [], []
    for f in sorted(os.listdir(TXT_VIEJO)):
        m = re.match(r'([a-z-]+)_(\d{4})_([a-z]{3})_cand(\d+)\.txt$', f)
        if not m:
            continue
        region, anyo, mes3 = m.group(1), m.group(2), m.group(3)
        mes = MESES.get(mes3, '00')
        el = f'autonomous_{anyo}_{mes}'
        texto = open(os.path.join(TXT_VIEJO, f), encoding='utf-8', errors='replace').read()
        if len(texto) < 500:
            informe.append(dict(fichero=f, estado='texto vacio (PDF escaneado)', n=0))
            continue
        lineas = texto.split('\n')
        try:
            lst = listas_en_doc(lineas, region, anyo, el)
        except Exception as e:
            informe.append(dict(fichero=f, estado=f'error {type(e).__name__}', n=0))
            continue
        # Un mismo boletin puede repetir la cabecera del partido en cada pagina,
        # de modo que una lista sale partida en varios fragmentos. Se unen los
        # que comparten formacion y circunscripcion, se quitan los nombres
        # repetidos y se renumera.
        fus = {}
        for L in lst:
            k = (tuple(sorted(p for p, _ in L['formaciones'])), L['circunscripcion'] or '')
            if k not in fus:
                fus[k] = dict(L, titulares=list(L['titulares']),
                              suplentes=list(L['suplentes']), fragmentos=1)
            else:
                fus[k]['fragmentos'] = fus[k].get('fragmentos', 1) + 1
                fus[k]['titulares'] += L['titulares']
                fus[k]['suplentes'] += L['suplentes']
                fus[k]['lector'] = fus[k].get('lector', '') + '+fusion'
        lst = []
        for L in fus.values():
            # Solo se quitan repetidos cuando la lista venia partida en varios
            # fragmentos. Dentro de una lectura unica la numeracion ya es
            # correlativa, y un boletin puede repetir legitimamente un nombre.
            if L.get('fragmentos', 1) == 1:
                nec = L.get('escanos')
                if nec:
                    L['titulares'] = L['titulares'][:nec]
                lst.append(L)
                continue
            for campo in ('titulares', 'suplentes'):
                vistos_n, limpio = set(), []
                for _, nom in L[campo]:
                    # nombre completo como clave: truncarlo hacia dos candidatos
                    # distintos con el mismo arranque y se perdia uno
                    k = re.sub(r'\W+', '', nom).upper()
                    if k in vistos_n:
                        continue
                    vistos_n.add(k); limpio.append(nom)
                nec = L.get('escanos')
                if campo == 'titulares' and nec:
                    limpio = limpio[:nec]
                L[campo] = [(i + 1, n) for i, n in enumerate(limpio)]
            lst.append(L)

        n = 0
        for L in lst:
            circ = L['circunscripcion'] or ''
            # el numero de escanos ya se resolvio al leer la lista (tabla
            # estatica, correcciones comprobadas o referencia del PP)
            esper = L.get('escanos')
            estado = ('reconciliada' if esper and len(L['titulares']) == esper
                      else (f'NO reconcilia (leidos {len(L["titulares"])}, escanos {esper})'
                            if esper else 'sin escanos de referencia'))
            for partido, tipo in L['formaciones']:
                for pos, nom in L['titulares']:
                    filas.append(dict(partido=partido, tipo_candidatura=tipo,
                                      comunidad=REGION_ES.get(region, region),
                                      camara=CAMARA.get(region, region), eleccion=el,
                                      anyo=int(anyo), circunscripcion=circ,
                                      posicion=pos, candidato=PO.clean_name(nom),
                                      es_titular=True, rotulo=L['rotulo'],
                                      reconciliacion=estado, fuente=f, lector=L.get('lector','')))
                for pos, nom in L['suplentes']:
                    filas.append(dict(partido=partido, tipo_candidatura=tipo,
                                      comunidad=REGION_ES.get(region, region),
                                      camara=CAMARA.get(region, region), eleccion=el,
                                      anyo=int(anyo), circunscripcion=circ,
                                      posicion=pos, candidato=PO.clean_name(nom),
                                      es_titular=False, rotulo=L['rotulo'],
                                      reconciliacion=estado, fuente=f, lector=L.get('lector','')))
                n += len(L['titulares']) + len(L['suplentes'])
        informe.append(dict(fichero=f, estado=f'{len(lst)} listas', n=n))
    return filas, informe


def bloque_nuevo():
    """Filas de 2015-2026."""
    filas, informe = [], []
    for fn, v, el, rg, prov in CAND_DOCS:
        p = TXT_NUEVO + fn.replace('.pdf', '.txt')
        if not os.path.exists(p):
            continue
        t = open(p, encoding='utf-8').read()
        c = CUTS.get(fn)
        if c and c in t:
            t = t[:t.index(c)]
        try:
            recs = run_parser(v, t, prov)
        except Exception as e:
            informe.append(dict(fichero=fn, estado=f'error {type(e).__name__}', n=0))
            continue
        anyo = el.split('_')[1]
        n = 0
        for r in recs:
            cl = clasificar(r.get('party_name') or '', r.get('abbr') or '', anyo)
            for partido, tipo in cl:
                filas.append(dict(partido=partido, tipo_candidatura=tipo,
                                  comunidad=rg, camara=rg, eleccion=el, anyo=int(anyo),
                                  circunscripcion=canon_prov(r.get('province'), prov),
                                  posicion=r['position'], candidato=r['candidate'],
                                  es_titular=bool(r['is_titular']),
                                  rotulo=(r.get('party_name') or '').strip(),
                                  reconciliacion='', fuente=fn, lector=f'parse_candnum:{v}'))
                n += 1
        if n:
            informe.append(dict(fichero=fn, estado='ok', n=n))
    return filas, informe


def main():
    os.makedirs(OUT, exist_ok=True)
    fv, iv = bloque_viejo()
    fn_, in_ = bloque_nuevo()
    filas = fv + fn_
    campos = ['partido', 'tipo_candidatura', 'comunidad', 'camara', 'eleccion', 'anyo',
              'circunscripcion', 'posicion', 'candidato', 'es_titular', 'rotulo',
              'reconciliacion', 'fuente', 'lector']
    with open(f'{OUT}/autonomicas.csv', 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=campos, extrasaction='ignore')
        w.writeheader()
        for r in sorted(filas, key=lambda x: (x['partido'], x['anyo'], str(x['comunidad']),
                                              str(x['circunscripcion']), not x['es_titular'],
                                              x['posicion'] or 0)):
            w.writerow(r)
    with open(f'{OUT}/autonomicas_informe.csv', 'w', encoding='utf-8-sig', newline='') as f:
        todo = iv + in_
        w = csv.DictWriter(f, fieldnames=list(todo[0].keys()))
        w.writeheader(); w.writerows(todo)

    print('filas autonomicas:', len(filas), f'  (1979-2012: {len(fv)}  2015-2026: {len(fn_)})')
    c = collections.Counter((r['partido'], r['tipo_candidatura']) for r in filas)
    for k in sorted(c):
        print(f'  {k[0]:34s} {k[1]:10s} {c[k]:5d}')
    print()
    rec = collections.Counter(r['reconciliacion'].split(' (')[0] for r in filas)
    print('reconciliacion:', dict(rec))


if __name__ == '__main__':
    main()
