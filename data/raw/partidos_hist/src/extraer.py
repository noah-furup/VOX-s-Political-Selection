# -*- coding: utf-8 -*-
"""Candidatos de Plataforma per Catalunya, Fuerza Nueva y Comunion
Tradicionalista Carlista en todos los niveles que publica el Ministerio del
Interior: Congreso, Senado, europeas, municipales y cabildos.

Fuente: los microdatos oficiales replicados en infoelectoral/files. Cada
convocatoria trae un fichero 03 (candidaturas) y uno 04 (candidatos); se cruzan
por el codigo de candidatura.

El Ministerio NO publica las autonomicas: ese nivel queda fuera y se documenta
como hueco, no se rellena por otra via.
"""
import os, re, csv, glob, json, sys, unicodedata, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from reglas import clasificar

BASE = 'infoelectoral/files'
OUT = 'partidos_hist/out'
NIVELES = {'congreso': 'Congreso', 'senado': 'Senado', 'europeas': 'Parlamento Europeo',
           'municipales': 'Municipales', 'cabildos': 'Cabildos insulares'}


def sa(s):
    return ''.join(c for c in unicodedata.normalize('NFD', str(s))
                   if unicodedata.category(c) != 'Mn').upper()


def norm(s):
    return re.sub(r'\s+', ' ', sa(s)).strip(' .-')


# ---------------------------------------------------------------------------
# Clasificacion de candidaturas
#
# `propia`      = la formacion concurre con su propio nombre
# `coalicion`   = concurre coaligada o dentro de una candidatura conjunta
# `sucesora`    = organizacion posterior fundada por la misma direccion
#
# Se separan para que se puedan incluir o excluir del analisis; NO se mezclan.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
PROV = {
 '01':'Álava','02':'Albacete','03':'Alicante','04':'Almería','05':'Ávila','06':'Badajoz',
 '07':'Illes Balears','08':'Barcelona','09':'Burgos','10':'Cáceres','11':'Cádiz',
 '12':'Castellón','13':'Ciudad Real','14':'Córdoba','15':'A Coruña','16':'Cuenca',
 '17':'Girona','18':'Granada','19':'Guadalajara','20':'Gipuzkoa','21':'Huelva',
 '22':'Huesca','23':'Jaén','24':'León','25':'Lleida','26':'La Rioja','27':'Lugo',
 '28':'Madrid','29':'Málaga','30':'Murcia','31':'Navarra','32':'Ourense','33':'Asturias',
 '34':'Palencia','35':'Las Palmas','36':'Pontevedra','37':'Salamanca',
 '38':'Santa Cruz de Tenerife','39':'Cantabria','40':'Segovia','41':'Sevilla','42':'Soria',
 '43':'Tarragona','44':'Teruel','45':'Toledo','46':'Valencia','47':'Valladolid',
 '48':'Bizkaia','49':'Zamora','50':'Zaragoza','51':'Ceuta','52':'Melilla',
 '99':'Circunscripción única / no aplica',
}


def leer_03(path):
    """codigo de candidatura -> (sigla, nombre)"""
    d = {}
    for l in open(path, encoding='latin-1'):
        if len(l) < 70:
            continue
        d[l[8:14]] = (l[14:64].strip(), l[64:214].strip())
    return d


def municipios(carpeta):
    """(provincia, municipio) -> nombre, del fichero 05.

    La carpeta TOTA solo trae la version corta del fichero 05 (las capitales),
    asi que se leen tambien las carpetas hermanas MUNI/MESA de esa convocatoria,
    donde esta el listado completo de municipios.
    """
    d = {}
    hermanas = glob.glob(re.sub(r'_(TOTA|MUNI|MESA)$', '_*', carpeta))
    for f in sorted(x for h in hermanas for x in glob.glob(os.path.join(h, '05*.DAT'))):
        for l in open(f, encoding='latin-1'):
            if len(l) < 120:
                continue
            d[(l[11:13], l[13:16])] = re.sub(r'\s+', ' ', l[18:118]).strip()
    return d


def leer_04(path, codigos, muni):
    """Filas de candidatos cuyo codigo de candidatura este en `codigos`."""
    out = []
    for l in open(path, encoding='latin-1'):
        if len(l) < 60:
            continue
        cod = l[15:21]
        if cod not in codigos:
            continue
        prov, mun = l[9:11], l[12:15]
        pos = l[21:24].strip()
        tipo = l[24:25]
        # hasta 2000 el nombre va en un solo campo; despues, partido en tres
        sexo_raw = l[100:101] if len(l) > 100 else ' '
        partido_en_tres = sexo_raw in ('M', 'F', 'V', 'H')
        if partido_en_tres:
            nombre = ' '.join(x for x in (l[25:50].strip(), l[50:75].strip(), l[75:100].strip()) if x)
            sexo = {'M': 'Hombre', 'V': 'Hombre', 'H': 'Hombre', 'F': 'Mujer'}.get(sexo_raw, '')
        else:
            nombre = re.sub(r'\s+', ' ', l[25:100]).strip()
            sexo = ''
        elegido = l[119:120] if len(l) > 119 else ''
        out.append(dict(
            provincia=PROV.get(prov, prov), cod_provincia=prov,
            municipio=muni.get((prov, mun), '') if mun not in ('999', '') else '',
            cod_municipio=mun if mun != '999' else '',
            posicion=int(pos) if pos.isdigit() else None,
            candidato=re.sub(r'\s+', ' ', nombre).strip(),
            sexo=sexo,
            es_titular=(tipo == 'T'),
            electo={'S': 'TRUE', 'N': 'FALSE'}.get(elegido, ''),
            cod_candidatura=cod))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    # una carpeta por (nivel, convocatoria): TOTA trae los mismos 03/04 que MUNI/MESA
    carpetas = {}
    for niv in NIVELES:
        for c in sorted(glob.glob(f'{BASE}/{niv}/*')):
            b = os.path.basename(c)
            m = re.match(r'(\d{2})(\d{4})(\d{2})_(\w+)', b)
            if not m:
                continue
            clave = (niv, m.group(2), m.group(3))
            if clave not in carpetas or m.group(4) == 'TOTA':
                carpetas[clave] = c

    filas, cobertura = [], []
    for (niv, anyo, mes), carp in sorted(carpetas.items()):
        f03 = glob.glob(os.path.join(carp, '03*.DAT'))
        f04 = glob.glob(os.path.join(carp, '04*.DAT'))
        if not f03 or not f04:
            cobertura.append(dict(nivel=NIVELES[niv], anyo=anyo, mes=mes,
                                  estado='sin fichero de candidatos', n=0))
            continue
        cands = leer_03(f03[0])
        objetivo = {}
        for cod, (sig, nom) in cands.items():
            cl = clasificar(nom, sig, anyo)
            if cl:
                objetivo[cod] = (cl, sig, nom)
        if not objetivo:
            cobertura.append(dict(nivel=NIVELES[niv], anyo=anyo, mes=mes,
                                  estado='ninguna de las tres se presento', n=0))
            continue
        muni = municipios(carp) if niv in ('municipales', 'cabildos') else {}
        n = 0
        for r in leer_04(f04[0], set(objetivo), muni):
            cl, sig, nom = objetivo[r['cod_candidatura']]
            # una candidatura conjunta pertenece a varias formaciones: se emite
            # una fila por formacion, marcada como coalicion
            for partido, tipo in cl:
                f = dict(r, partido=partido, tipo_candidatura=tipo,
                         sigla_impresa=sig, nombre_impreso=nom,
                         nivel=NIVELES[niv], anyo=int(anyo), mes=mes,
                         eleccion=f'{niv}_{anyo}_{mes}',
                         fuente=f'Ministerio del Interior, microdatos {os.path.basename(carp)}')
                filas.append(f); n += 1
        cobertura.append(dict(nivel=NIVELES[niv], anyo=anyo, mes=mes,
                              estado='con candidatos', n=n))

    campos = ['partido', 'tipo_candidatura', 'nivel', 'eleccion', 'anyo', 'mes',
              'provincia', 'municipio', 'posicion', 'candidato', 'sexo',
              'es_titular', 'electo', 'sigla_impresa', 'nombre_impreso',
              'cod_provincia', 'cod_municipio', 'cod_candidatura', 'fuente']
    with open(f'{OUT}/candidatos.csv', 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=campos, extrasaction='ignore')
        w.writeheader()
        for r in sorted(filas, key=lambda x: (x['partido'], x['anyo'], x['nivel'],
                                              str(x['provincia']), str(x['municipio']),
                                              not x['es_titular'], x['posicion'] or 0)):
            w.writerow(r)
    with open(f'{OUT}/cobertura.csv', 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(cobertura[0].keys()))
        w.writeheader(); w.writerows(cobertura)

    print('filas:', len(filas))
    c = collections.Counter((r['partido'], r['tipo_candidatura']) for r in filas)
    for k in sorted(c):
        print(f'  {k[0]:36s} {k[1]:10s} {c[k]:5d}')
    print()
    print('por partido y nivel:')
    c2 = collections.Counter((r['partido'], r['nivel']) for r in filas)
    for k in sorted(c2):
        print(f'  {k[0]:36s} {k[1]:20s} {c2[k]:5d}')


if __name__ == '__main__':
    main()
