# -*- coding: utf-8 -*-
"""Excel final con los candidatos de las formaciones solicitadas."""
import csv, os, collections, datetime
import pandas as pd

OUT = 'partidos_hist/out'
SAL = 'CANDIDATOS_PARTIDOS_HISTORICOS.xlsx'

cand = pd.read_csv(f'{OUT}/candidatos.csv', dtype=str).fillna('')
cob = pd.read_csv(f'{OUT}/cobertura.csv', dtype=str).fillna('')

cand['anyo'] = cand['anyo'].astype(int)
cand['posicion'] = pd.to_numeric(cand['posicion'], errors='coerce')

# --- 01 candidatos ---------------------------------------------------------
det = cand.rename(columns={
    'partido': 'Partido', 'tipo_candidatura': 'Tipo de candidatura', 'nivel': 'Nivel',
    'eleccion': 'Eleccion', 'anyo': 'Anyo', 'mes': 'Mes', 'provincia': 'Provincia',
    'municipio': 'Municipio', 'posicion': 'Posicion en la lista', 'candidato': 'Candidato',
    'sexo': 'Sexo', 'es_titular': 'Es titular', 'electo': 'Electo',
    'sigla_impresa': 'Sigla impresa', 'nombre_impreso': 'Nombre impreso',
    'fuente': 'Fuente'})[
    ['Partido', 'Tipo de candidatura', 'Nivel', 'Eleccion', 'Anyo', 'Mes', 'Provincia',
     'Municipio', 'Posicion en la lista', 'Candidato', 'Sexo', 'Es titular', 'Electo',
     'Sigla impresa', 'Nombre impreso', 'Fuente']]

# --- 02 resumen por partido -----------------------------------------------
res = (cand.assign(electo=(cand['electo'] == 'TRUE').astype(int))
       .groupby(['partido', 'nivel'], as_index=False)
       .agg(candidatos=('candidato', 'size'), electos=('electo', 'sum'),
            primera=('anyo', 'min'), ultima=('anyo', 'max'),
            convocatorias=('eleccion', 'nunique')))
res.columns = ['Partido', 'Nivel', 'Candidatos', 'Electos', 'Primer anyo', 'Ultimo anyo',
               'N. de convocatorias']

# --- 03 por convocatoria ---------------------------------------------------
porconv = (cand.assign(electo=(cand['electo'] == 'TRUE').astype(int))
           .groupby(['partido', 'nivel', 'eleccion', 'anyo', 'tipo_candidatura'], as_index=False)
           .agg(candidatos=('candidato', 'size'), electos=('electo', 'sum'),
                municipios=('municipio', lambda s: s[s != ''].nunique()),
                provincias=('provincia', 'nunique')))
porconv.columns = ['Partido', 'Nivel', 'Eleccion', 'Anyo', 'Tipo de candidatura',
                   'Candidatos', 'Electos', 'Municipios', 'Provincias']

# --- 04 etiquetas incluidas (auditoria del filtro) -------------------------
etiq = (cand.groupby(['partido', 'tipo_candidatura', 'nombre_impreso', 'sigla_impresa'],
                     as_index=False)
        .agg(filas=('candidato', 'size'), anyos=('anyo', lambda s: ', '.join(map(str, sorted(set(s)))))))
etiq.columns = ['Partido', 'Tipo de candidatura', 'Nombre impreso en el boletin',
                'Sigla impresa', 'Filas', 'Anyos']

# --- 05 cobertura de la fuente --------------------------------------------
COBERTURA = pd.DataFrame({
 'Nivel': ['Congreso', 'Congreso', 'Senado', 'Parlamento Europeo',
           'Municipales', 'Municipales', 'Municipales',
           'Cabildos insulares', 'Autonomicas'],
 'Periodo': ['1977, 1979, 1982, 1986 y 2000', '1989-1996 y 2004-2023', '1977-2023',
             '1987-2024', '1979 y 1983', '1987-1999', '2003-2023',
             '1987-2023 (salvo 1999)', 'todas'],
 'Que hay': ['SOLO los 350 diputados electos', 'listas completas', 'listas completas',
             'listas completas', 'NADA: el fichero de candidatos esta vacio',
             'solo unos 70 municipios (las capitales)', 'listas completas',
             'listas completas', 'NADA'],
 'Consecuencia': [
   'De esas convocatorias solo consta quien salio elegido; no hay listas de candidatos.',
   'Sin restricciones.', 'Sin restricciones.', 'Sin restricciones.',
   'Las municipales de 1979 y 1983 no se pueden reconstruir con esta fuente.',
   'Una formacion que solo se presentara en municipios pequenos no aparecera.',
   'Sin restricciones.', 'En 1999 el fichero esta vacio.',
   'El Ministerio no publica microdatos. Se han leido los boletines de proclamacion (hojas 06 y 07): 1979-2012 y 2015-2026. De los 327 documentos antiguos, 120 son PDF escaneados sin capa de texto (sobre todo 1979-1995) y no se pueden leer sin OCR.']})

# --- 06/07 autonomicas -----------------------------------------------------
auto = pd.read_csv(f'{OUT}/autonomicas.csv', dtype=str).fillna('')
auto['anyo'] = auto['anyo'].astype(int)
auto['Calidad'] = auto['reconciliacion'].apply(
    lambda x: 'verificada (la lista tiene tantos titulares como escanos)' if x == 'reconciliada'
    else ('no verificada: sin escanos de referencia' if x.startswith('sin escanos')
          else ('lista bien formada (boletin moderno)' if x == ''
                else 'NO CUADRA con los escanos: revisar')))
autod = auto.rename(columns={
    'partido': 'Partido', 'tipo_candidatura': 'Tipo de candidatura', 'comunidad': 'Comunidad',
    'camara': 'Camara', 'eleccion': 'Eleccion', 'anyo': 'Anyo',
    'circunscripcion': 'Circunscripcion', 'posicion': 'Posicion en la lista',
    'candidato': 'Candidato', 'es_titular': 'Es titular', 'rotulo': 'Rotulo en el boletin',
    'reconciliacion': 'Detalle del control', 'fuente': 'Documento de origen'})[
    ['Partido', 'Tipo de candidatura', 'Comunidad', 'Camara', 'Eleccion', 'Anyo',
     'Circunscripcion', 'Posicion en la lista', 'Candidato', 'Es titular',
     'Calidad', 'Detalle del control', 'Rotulo en el boletin', 'Documento de origen']]

autores = (auto.groupby(['partido', 'comunidad', 'anyo', 'Calidad'], as_index=False)
           .agg(filas=('candidato', 'size')))
autores.columns = ['Partido', 'Comunidad', 'Anyo', 'Calidad', 'Filas']

hoy = datetime.date.today().isoformat()
METODO = pd.DataFrame({'Apartado': [
  'Objeto', 'Fuente', 'Como se cruza', 'Niveles', 'Tipo de candidatura',
  'Que NO incluye', 'Homonimos descartados', 'Sexo', 'Electo',
  'Doble conteo', 'Ficheros', 'Fecha'],
 'Detalle': [
  'Candidatos de las formaciones solicitadas en todas las elecciones cuyos microdatos publica el Ministerio del Interior.',
  'Microdatos oficiales del Ministerio del Interior (replica de infoelectoral). Fichero 03 = candidaturas, fichero 04 = candidatos.',
  'Por codigo de candidatura entre los ficheros 03 y 04 de cada convocatoria. Se verifico que el cruce es completo (137 de 137 codigos en el Congreso de 2004).',
  'Congreso, Senado, Parlamento Europeo, municipales y cabildos insulares.',
  '"propia" = la formacion concurre con su nombre; "coalicion" = dentro de una candidatura conjunta o lista local que la incorpora; "sucesora" = organizacion posterior de la misma direccion. Se separan para poder incluirlas o excluirlas; NO se mezclan.',
  'Elecciones autonomicas: el Ministerio no las publica (ver hoja de cobertura).',
  'Se excluyen formaciones de nombre parecido pero distintas: Partido Carlista (EKA) frente a Comunion Tradicionalista Carlista; Partit per Catalunya frente a Plataforma per Catalunya; las decenas de "Grupo Independiente de..." locales que comparten las siglas GIL; PACMA y Partido Democratico Espanol frente a PADE.',
  'Tal y como lo codifica el Ministerio. Antes de 2000 el fichero no trae ese campo, asi que queda vacio.',
  'Del propio fichero de candidatos (campo "elegido").',
  'Una candidatura conjunta pertenece a todas las formaciones que la integran, asi que sus candidatos se repiten en una fila por formacion, marcada como "coalicion". Para contar sin duplicar, filtre por Tipo de candidatura = propia.',
  'Carpeta partidos_hist: reglas.py (que candidatura es de quien), extraer.py, excel.py y los CSV intermedios.',
  hoy]})

with pd.ExcelWriter(SAL, engine='openpyxl') as xl:
    METODO.to_excel(xl, sheet_name='00 Metodologia', index=False)
    det.to_excel(xl, sheet_name='01 Candidatos', index=False)
    res.to_excel(xl, sheet_name='02 Resumen por partido', index=False)
    porconv.to_excel(xl, sheet_name='03 Por convocatoria', index=False)
    etiq.to_excel(xl, sheet_name='04 Etiquetas incluidas', index=False)
    COBERTURA.to_excel(xl, sheet_name='05 Cobertura de la fuente', index=False)
    autod.to_excel(xl, sheet_name='06 Autonomicas', index=False)
    autores.to_excel(xl, sheet_name='07 Autonomicas control', index=False)
    for h in xl.book.worksheets:
        h.freeze_panes = 'A2'
        for col in h.columns:
            letra = col[0].column_letter
            ancho = max((len(str(c.value)) for c in col[:300] if c.value), default=10)
            h.column_dimensions[letra].width = min(max(ancho + 2, 12), 58)

print('->', SAL)
print(f'  01 Candidatos          : {len(det)}')
print(f'  02 Resumen por partido : {len(res)}')
print(f'  03 Por convocatoria    : {len(porconv)}')
print(f'  04 Etiquetas incluidas : {len(etiq)}')
print(f'  06 Autonomicas         : {len(autod)}')
print()
print(res.groupby('Partido')[['Candidatos', 'Electos']].sum().to_string())
