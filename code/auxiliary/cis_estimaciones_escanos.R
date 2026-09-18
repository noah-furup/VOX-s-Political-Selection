# ============================================================
# ESTIMACIONES DE ESCAÑOS DEL CIS EN LAS PREELECTORALES
#
# Descarga el PDF de "Estimación de voto" de cada estudio
# preelectoral del CIS (ver cis_preelectorales_vox.csv) y extrae
# la estimación de escaños (horquilla y, si existe, el valor más
# probable) de cada partido en cada circunscripción publicada.
#
# Los PDFs no tienen una estructura común, así que en lugar de
# leer el texto plano (que desordena las columnas) se usan las
# coordenadas de cada palabra (pdftools::pdf_data) para
# reconstruir filas y columnas. Hay dos formatos:
#   - "ancho": generales, una fila por provincia y una columna
#     por partido ("Estimación de escaños por provincias").
#   - "bloques": resto, una tabla por circunscripción con una
#     fila por partido y una columna de escaños/concejales.
#
# Salidas:
#   - cis_estimaciones_escanos.csv : todos los partidos
#   - cis_estimaciones_vox.csv     : solo VOX (0 si el CIS
#     publicó estimación en esa circunscripción sin incluir a VOX)
# ============================================================

library(tidyverse)
library(pdftools)
library(stringi)

dir_pdf <- "cis_estimaciones_pdf"
dir.create(dir_pdf, showWarnings = FALSE)

# 1. Estudios y PDFs de estimación ----------------------------------------
# ccaa = comunidad por defecto del estudio (NA en generales, europeas y
# macroencuestas con varias comunidades)
estudios <- tribble(
  ~estudio, ~eleccion,                 ~ccaa_estudio,            ~ruta,
  3022,     "europeas_2014_05",        NA,                       "1555786/3022_Estimacionpdf.pdf",
  3053,     "autonomicas_2015_03",     "Andalucía",              "1555936/3053_Estimacionpdf.pdf",
  3060,     "municipales_2015_05",     "Cataluña",               "1555971/3060_Estimacionpdf.pdf",
  3061,     "municipales_2015_05",     "Andalucía",              "1555976/3061_Estimacionpdf.pdf",
  3062,     "municipales_2015_05",     "País Vasco",             "1555981/3062_Estimacionpdf.pdf",
  3063,     "municipales_2015_05",     "Galicia",                "1555986/3063_Estimacionpdf.pdf",
  3064,     "autonomicas_2015_05",     "Aragón",                 "1555991/3064_Estimacionpdf.pdf",
  3065,     "autonomicas_2015_05",     "Comunidad de Madrid",    "1555996/3065_Estimacionpdf.pdf",
  3066,     "autonomicas_2015_05",     "Comunitat Valenciana",   "1556001/3066_Estimacionpdf.pdf",
  3067,     "autonomicas_2015_05",     "Principado de Asturias", "1556006/3067_Estimacionpdf.pdf",
  3068,     "autonomicas_2015_05",     "Illes Balears",          "1556011/3068_Estimacionpdf.pdf",
  3069,     "autonomicas_2015_05",     "Canarias",               "1556016/3069_Estimacionpdf.pdf",
  3070,     "autonomicas_2015_05",     "Cantabria",              "1556021/3070_Estimacionpdf.pdf",
  3071,     "autonomicas_2015_05",     "Castilla-La Mancha",     "1556026/3071_Estimacionpdf.pdf",
  3072,     "autonomicas_2015_05",     "Castilla y León",        "1556031/3072_Estimacionpdf.pdf",
  3073,     "autonomicas_2015_05",     "Extremadura",            "1556036/3073_Estimacionpdf.pdf",
  3074,     "autonomicas_2015_05",     "Región de Murcia",       "1556041/3074_Estimacionpdf.pdf",
  3075,     "autonomicas_2015_05",     "Navarra",                "1556046/3075_Estimacionpdf.pdf",
  3076,     "autonomicas_2015_05",     "La Rioja",               "1556051/3076_Estimacionpdf.pdf",
  3077,     "autonomicas_2015_05",     "Ceuta",                  "1556056/3077_Estimacionpdf.pdf",
  3078,     "autonomicas_2015_05",     "Melilla",                "1556061/3078_Estimacionpdf.pdf",
  3117,     "generales_2015_12",       NA,                       "1556226/3117_Estimacionpdf.pdf",
  3141,     "generales_2016_06",       NA,                       "1556341/3141_Estimacionpdf.pdf",
  3152,     "autonomicas_2016_09",     "País Vasco",             "1556396/3152_Estimacionpdf.pdf",
  3153,     "autonomicas_2016_09",     "Galicia",                "1556401/3153_Estimacionpdf.pdf",
  3230,     "autonomicas_2018_12",     "Andalucía",              "1556796/3230_Estimacionpdf.pdf",
  3242,     "generales_2019_04",       NA,                       "1556851/3242_Estimacionpdf.pdf",
  3244,     "autonomicas_2019_04",     "Comunitat Valenciana",   "1556861/3244_Estimacionpdf.pdf",
  3245,     "autonomicas_2019_05",     NA,                       "1556866/3245_EstimacionEAMpdf.pdf",
  3245,     "europeas_2019_05",        NA,                       "1556866/3245_EstimacionEPEpdf.pdf",
  3263,     "generales_2019_11",       NA,                       "1557011/3263_Estimacion.pdf",
  3286,     "autonomicas_2020_07",     "País Vasco",             "1557131/3286_Estimacion.pdf",
  3287,     "autonomicas_2020_07",     "Galicia",                "1557136/3287_estimacionpdf.pdf",
  3306,     "autonomicas_2021_02",     "Cataluña",               "1557216/3306_Estimacion.pdf",
  3317,     "autonomicas_2021_05",     "Comunidad de Madrid",    "1557271/3317_Estimacionpdf.pdf",
  3348,     "autonomicas_2022_02",     "Castilla y León",        "1557426/3348_Estimacionpdf.pdf",
  3365,     "autonomicas_2022_06",     "Andalucía",              "1557516/3365_Estimacionpdf.pdf",
  3402,     "autonomicas_2023_05",     NA,                       "1544721/3402_EstimacionEAMpdf.pdf",
  3411,     "generales_2023_07",       NA,                       "1557956/3411_Estimacionpdf.pdf",
  3437,     "autonomicas_2024_02",     "Galicia",                "1559046/3437_Estimacion.pdf",
  3448,     "autonomicas_2024_04",     "País Vasco",             "1559601/3448_Estimacion.pdf",
  3453,     "autonomicas_2024_05",     "Cataluña",               "1559686/3453_Estimacion.pdf",
  3458,     "europeas_2024_06",        NA,                       "1559696/3458_Estimacion.pdf",
  3538,     "autonomicas_2025_12",     "Extremadura",            "13697506/3538_Estimacion.pdf",
  3543,     "autonomicas_2026_02",     "Aragón",                 "13730886/3543_Estimacion.pdf",
  3545,     "autonomicas_2026_03",     "Castilla y León",        "13765729/3545_Estimacion-CyL.pdf",
  3558,     "autonomicas_2026_05",     "Andalucía",              "13957047/3558_Estimacion.pdf"
) |>
  mutate(
    municipio = case_match(estudio,
                           3060 ~ "Barcelona", 3061 ~ "Sevilla",
                           3062 ~ "Vitoria-Gasteiz", 3063 ~ "Santiago de Compostela",
                           .default = NA_character_),
    url     = paste0("https://www.cis.es/documents/20117/", ruta),
    archivo = file.path(dir_pdf, basename(ruta))
  )

# Los estudios 3275 y 3276 (Galicia y País Vasco, abril 2020) no publicaron
# estimación de voto porque las elecciones se suspendieron.

walk2(estudios$url, estudios$archivo, \(url, archivo) {
  if (!file.exists(archivo)) {
    download.file(url, archivo, mode = "wb", quiet = TRUE, method = "libcurl",
                  headers = c("User-Agent" = "Mozilla/5.0"))
  }
})

# 2. Diccionarios ----------------------------------------------------------
normalizar <- function(x) {
  x |> stri_trans_general("Latin-ASCII") |> str_to_upper() |> str_squish()
}

# patron sobre texto normalizado (mayúsculas, sin tildes)
provincias <- tribble(
  ~provincia,               ~patron,                ~ccaa,                    ~solo_generales,
  "Almería",                "ALMERIA",              "Andalucía",              FALSE,
  "Cádiz",                  "CADIZ",                "Andalucía",              FALSE,
  "Córdoba",                "CORDOBA",              "Andalucía",              FALSE,
  "Granada",                "GRANADA",              "Andalucía",              FALSE,
  "Huelva",                 "HUELVA",               "Andalucía",              FALSE,
  "Jaén",                   "JAEN",                 "Andalucía",              FALSE,
  "Málaga",                 "MALAGA",               "Andalucía",              FALSE,
  "Sevilla",                "SEVILLA",              "Andalucía",              FALSE,
  "Huesca",                 "HUESCA",               "Aragón",                 FALSE,
  "Teruel",                 "TERUEL",               "Aragón",                 FALSE,
  "Zaragoza",               "ZARAGOZA",             "Aragón",                 FALSE,
  "Asturias",               "ASTURIAS",             "Principado de Asturias", FALSE,
  "Baleares",               "BALEARS|BALEARES",     "Illes Balears",          TRUE,
  "Las Palmas",             "PALMAS",               "Canarias",               TRUE,
  "Santa Cruz de Tenerife", "TENERIFE",             "Canarias",               TRUE,
  "Cantabria",              "CANTABRIA",            "Cantabria",              FALSE,
  "Ávila",                  "AVILA",                "Castilla y León",        FALSE,
  "Burgos",                 "BURGOS",               "Castilla y León",        FALSE,
  "León",                   "LEON",                 "Castilla y León",        FALSE,
  "Palencia",               "PALENCIA",             "Castilla y León",        FALSE,
  "Salamanca",              "SALAMANCA",            "Castilla y León",        FALSE,
  "Segovia",                "SEGOVIA",              "Castilla y León",        FALSE,
  "Soria",                  "SORIA",                "Castilla y León",        FALSE,
  "Valladolid",             "VALLADOLID",           "Castilla y León",        FALSE,
  "Zamora",                 "ZAMORA",               "Castilla y León",        FALSE,
  "Albacete",               "ALBACETE",             "Castilla-La Mancha",     FALSE,
  "Ciudad Real",            "CIUDAD REAL|C\\. REAL", "Castilla-La Mancha",    FALSE,
  "Cuenca",                 "CUENCA",               "Castilla-La Mancha",     FALSE,
  "Guadalajara",            "GUADALAJARA",          "Castilla-La Mancha",     FALSE,
  "Toledo",                 "TOLEDO",               "Castilla-La Mancha",     FALSE,
  "Barcelona",              "BARCELONA",            "Cataluña",               FALSE,
  "Girona",                 "GIRONA|GERONA",        "Cataluña",               FALSE,
  "Lleida",                 "LLEIDA|LERIDA",        "Cataluña",               FALSE,
  "Tarragona",              "TARRAGONA",            "Cataluña",               FALSE,
  "Ceuta",                  "CEUTA",                "Ceuta",                  FALSE,
  "Melilla",                "MELILLA",              "Melilla",                FALSE,
  "Alicante",               "ALICANTE|ALACANT",     "Comunitat Valenciana",   FALSE,
  "Castellón",              "CASTELLON|CASTELLO",   "Comunitat Valenciana",   FALSE,
  "Valencia",               "VALENCIA",             "Comunitat Valenciana",   FALSE,
  "Badajoz",                "BADAJOZ",              "Extremadura",            FALSE,
  "Cáceres",                "CACERES",              "Extremadura",            FALSE,
  "A Coruña",               "CORUNA",               "Galicia",                FALSE,
  "Lugo",                   "LUGO",                 "Galicia",                FALSE,
  "Ourense",                "OURENSE|ORENSE",       "Galicia",                FALSE,
  "Pontevedra",             "PONTEVEDRA",           "Galicia",                FALSE,
  "La Rioja",               "RIOJA",                "La Rioja",               FALSE,
  "Madrid",                 "MADRID",               "Comunidad de Madrid",    FALSE,
  "Murcia",                 "MURCIA",               "Región de Murcia",       FALSE,
  "Navarra",                "NAVARRA",              "Navarra",                FALSE,
  "Álava",                  "ALAVA|ARABA",          "País Vasco",             FALSE,
  "Guipúzcoa",              "GIPUZKOA|GUIPUZCOA",   "País Vasco",             FALSE,
  "Vizcaya",                "BIZKAIA|VIZCAYA",      "País Vasco",             FALSE
) |>
  mutate(regex = paste0("\\b(", patron, ")\\b"))

ccaas <- tribble(
  ~ccaa,                    ~patron,                                ~provincia_unica,
  "Andalucía",              "ANDALUCIA",                            NA,
  "Aragón",                 "ARAGON",                               NA,
  "Principado de Asturias", "ASTURIAS",                             "Asturias",
  "Illes Balears",          "BALEARS|BALEARES",                     NA,
  "Canarias",               "CANARIAS",                             NA,
  "Cantabria",              "CANTABRIA",                            "Cantabria",
  "Castilla y León",        "CASTILLA Y LEON",                      NA,
  "Castilla-La Mancha",     "CASTILLA-LA MANCHA|CASTILLA LA MANCHA", NA,
  "Cataluña",               "CATALUNA|CATALUNYA",                   NA,
  "Comunitat Valenciana",   "VALENCIANA",                           NA,
  "Extremadura",            "EXTREMADURA",                          NA,
  "Galicia",                "GALICIA",                              NA,
  "Comunidad de Madrid",    "MADRID",                               "Madrid",
  "Región de Murcia",       "MURCIA",                               "Murcia",
  "Navarra",                "NAVARRA",                              "Navarra",
  "País Vasco",             "PAIS VASCO|EUSKADI",                   NA,
  "La Rioja",               "RIOJA",                                "La Rioja",
  "Ceuta",                  "CEUTA",                                "Ceuta",
  "Melilla",                "MELILLA",                              "Melilla"
) |>
  mutate(regex = paste0("\\b(", patron, ")\\b"))

# Última coincidencia (la más cercana a la tabla) de un diccionario
ultima_coincidencia <- function(lineas, dicc, campo) {
  hits <- map_dfr(seq_along(lineas), \(i) {
    pos <- map_int(dicc$regex, \(r) {
      m <- str_locate_all(lineas[i], r)[[1]]
      if (nrow(m)) max(m[, 1]) else NA_integer_
    })
    tibble(linea = i, pos = pos, valor = dicc[[campo]])
  }) |> filter(!is.na(pos))
  if (!nrow(hits)) return(NA_character_)
  hits |> arrange(desc(linea), desc(pos)) |> slice(1) |> pull(valor)
}

# 3. Utilidades de tokens --------------------------------------------------
limpiar_guiones <- function(x) {
  str_replace_all(x, "[‐-―−�]", "-")
}

es_pct    <- function(t) str_detect(t, "\\d,\\d|^±")
# "3-4", "(3-4)", "3", "-" y la notación de 2016 "3(-1)" (el último escaño
# puede pasar a otro partido)
es_escano <- function(t) {
  str_detect(t, "^\\(?\\d{1,3}(-\\d{1,3})?\\)?$|^-{1,2}$|^\\d{1,3}\\([+-]\\d\\)$")
}

parsear_escanos <- function(t) {
  m <- str_match(t, "^(\\d+)\\(([+-])(\\d)\\)$")
  if (!is.na(m[, 1])) {
    base <- as.integer(m[, 2]); otro <- base + as.integer(paste0(m[, 3], m[, 4]))
    return(c(min(base, otro), max(base, otro)))
  }
  t <- str_remove_all(t, "[()]")
  if (str_detect(t, "^-{1,2}$")) return(c(0L, 0L))
  m <- str_match(t, "^(\\d+)(?:-(\\d+))?$")
  a <- as.integer(m[, 2]); b <- coalesce(as.integer(m[, 3]), a)
  c(min(a, b), max(a, b))
}

leer_palabras <- function(archivo) {
  pdf_data(archivo) |>
    imap_dfr(\(d, i) mutate(d, pagina = i)) |>
    mutate(text = limpiar_guiones(text), xc = x + width / 2, yc = y + height / 2)
}

agrupar_lineas <- function(d, tol = 3) {
  d |> arrange(yc, x) |> mutate(linea = cumsum(c(TRUE, diff(yc) > tol)))
}

# Une "24" "–" "26" o "(36" "-" "38)" en un solo token "24-26"
unir_rangos <- function(l) {
  l <- arrange(l, x)
  if (nrow(l) < 2) return(l)
  out <- l[1, ]
  for (i in 2:nrow(l)) {
    cur <- out[nrow(out), ]; nxt <- l[i, ]
    hueco <- nxt$x - (cur$x + cur$width)
    rango_completo <- function(s) str_detect(s, "\\d-\\(?\\d")
    unir <- hueco < 12 && !rango_completo(cur$text) && !rango_completo(nxt$text) && (
      # "24" + "-"   o   "24" + "-26"
      (str_detect(cur$text, "\\d$") && str_detect(nxt$text, "^-(\\d|\\)?$)")) ||
      # "24-" + "26"
      (str_detect(cur$text, "\\d-$") && str_detect(nxt$text, "^\\(?\\d"))
    )
    if (unir) {
      out[nrow(out), "text"]  <- paste0(cur$text, nxt$text)
      out[nrow(out), "width"] <- nxt$x + nxt$width - cur$x
      out[nrow(out), "xc"]    <- cur$x + (nxt$x + nxt$width - cur$x) / 2
    } else {
      out <- bind_rows(out, nxt)
    }
  }
  out
}

preparar_pagina <- function(d, tol = 3) {
  d |>
    agrupar_lineas(tol) |>
    group_by(linea) |> group_modify(\(l, k) unir_rangos(l)) |> ungroup() |>
    mutate(tipo = case_when(es_pct(text) ~ "pct", es_escano(text) ~ "esc", TRUE ~ "txt"))
}

limpiar_partido <- function(x) {
  x |> str_remove("\\s*\\(\\d\\)$") |> str_remove("\\*+$") |> str_remove("-$") |>
    str_replace_all("- ", "-") |> str_squish()
}

# 4. Formato ancho (generales: provincias x partidos) ------------------------
es_pagina_ancha <- function(d) {
  any(str_detect(d$text, "^(PROVINCIA|Provincia)$")) &&
    sum(es_escano(limpiar_guiones(d$text))) >= 40
}

parsear_ancha <- function(d) {
  h <- d |> filter(str_detect(text, "^(PROVINCIA|Provincia)$")) |> slice(1)
  x_prov <- h$x; y_h <- h$yc

  cabecera <- d |>
    filter(yc >= y_h - 30, yc <= y_h + 9, x > x_prov + 25,
           !es_escano(text), !es_pct(text))
  total_y <- d |> filter(str_detect(text, "^Total$"), yc > y_h) |> pull(yc)
  total_y <- if (length(total_y)) min(total_y) else Inf

  # filas: solo las líneas cuya etiqueta es una provincia (tolerancia 5 para
  # unir filas en las que el nombre y las cifras están ligeramente desplazados)
  cuerpo <- d |>
    filter(yc > y_h + 4, yc < total_y - 4, x >= x_prov - 15) |>
    preparar_pagina(tol = 5) |>
    group_by(linea) |>
    filter(!is.na(ultima_coincidencia(normalizar(paste(text[tipo == "txt"], collapse = " ")),
                                      provincias, "provincia"))) |>
    ungroup()

  valores <- cuerpo |> filter(tipo == "esc")
  # columnas a partir de los propios valores (incluida la fila de totales,
  # que tiene valor en todas las columnas)
  fila_total <- d |> filter(abs(yc - total_y) < 4) |> preparar_pagina() |> filter(tipo == "esc")
  cols <- bind_rows(valores, fila_total) |> arrange(xc) |>
    mutate(col = cumsum(c(TRUE, diff(xc) > 8))) |>
    group_by(col) |> summarise(xc_col = median(xc), .groups = "drop")
  nombres <- cabecera |>
    mutate(col = map_int(xc, \(z) cols$col[which.min(abs(cols$xc_col - z))])) |>
    arrange(col, y, x) |>
    group_by(col) |>
    summarise(partido = paste(text, collapse = " ") |>
                str_replace_all("- (?=\\p{Ll})", "") |>
                str_replace_all("- ", "-") |>
                str_squish(),
              .groups = "drop")

  filas <- cuerpo |>
    group_by(linea) |>
    summarise(
      etiqueta = paste(text[tipo == "txt"], collapse = " "),
      .groups = "drop"
    ) |>
    filter(etiqueta != "")

  valores |>
    mutate(col = map_int(xc, \(z) cols$col[which.min(abs(cols$xc_col - z))])) |>
    left_join(filas, by = "linea") |>
    left_join(nombres, by = "col") |>
    filter(!is.na(etiqueta)) |>
    transmute(titulo = etiqueta, partido, valor = text)
}

# 5. Formato por bloques (una tabla por circunscripción) --------------------
parsear_bloques <- function(d) {
  d <- preparar_pagina(d)
  # filas de datos: líneas con porcentajes, o líneas "etiqueta + escaños"
  # (tablas provinciales que solo publican la horquilla de escaños)
  anclas <- d |>
    group_by(linea) |>
    filter(any(tipo == "pct") |
             (any(tipo == "esc") && any(tipo == "txt") && sum(tipo == "txt") <= 4 &&
                max(x[tipo == "txt"]) < min(x[tipo == "esc"]))) |>
    summarise(yc = mean(yc), .groups = "drop") |>
    arrange(yc) |>
    mutate(fila = cumsum(c(TRUE, diff(yc) > 9))) |>
    group_by(fila) |> summarise(yc = mean(yc), .groups = "drop") |>
    mutate(bloque = cumsum(c(TRUE, diff(yc) > 45)))
  if (!nrow(anclas)) return(tibble())

  map_dfr(unique(anclas$bloque), \(b) {
    a <- filter(anclas, bloque == b)
    techo <- if (b == 1) 0 else max(filter(anclas, bloque == b - 1)$yc) + 10
    zona  <- d |> filter(yc > techo, yc < min(a$yc) - 5)

    cab <- zona |> filter(str_detect(text, regex("^(esca|concejal)", ignore_case = TRUE)))
    if (!nrow(cab)) return(tibble())
    cab <- cab |>
      mutate(clase = map2_chr(xc, yc, \(cx, cy) {
        vec <- zona |> filter(abs(xc - cx) < 40, abs(yc - cy) < 30) |> pull(text) |>
          paste(collapse = " ")
        case_when(str_detect(vec, regex("obtenid", ignore_case = TRUE)) ~ "obtenidos",
                  str_detect(vec, regex("probab", ignore_case = TRUE)) ~ "mas_probable",
                  TRUE ~ "horquilla")
      })) |>
      filter(clase != "obtenidos")
    if (!nrow(cab)) return(tibble())

    # palabras del bloque asignadas a la fila más cercana
    cuerpo <- d |>
      filter(yc >= min(a$yc) - 16, yc <= max(a$yc) + 16) |>
      mutate(fila = map_int(yc, \(z) a$fila[which.min(abs(a$yc - z))]),
             dist = map2_dbl(yc, fila, \(z, f) abs(a$yc[a$fila == f] - z))) |>
      filter(dist <= 16)
    num_x <- cuerpo$x[cuerpo$tipo %in% c("pct", "esc") & cuerpo$x > min(cuerpo$x) + 40]
    lim_etiqueta <- min(c(cuerpo$x[cuerpo$tipo == "pct"], num_x)) - 3

    # etiquetas en varias líneas: se unen las líneas que continúan la anterior
    # (empiezan en minúscula o paréntesis, o la anterior acaba en guion o
    # preposición) y el grupo se asigna a la fila más cercana a su centro
    etiquetas <- d |>
      filter(tipo == "txt", x < lim_etiqueta,
             yc >= min(a$yc) - 16, yc <= max(a$yc) + 16) |>
      group_by(linea) |>
      summarise(t = paste(text[order(x)], collapse = " "), yc = mean(yc), .groups = "drop") |>
      arrange(yc) |>
      mutate(con_datos = linea %in% d$linea[d$tipo %in% c("pct", "esc") & d$x > lim_etiqueta],
             sigue = str_detect(t, "^[a-zà-ú(“\"]") |
               str_detect(lag(t, default = ""), "(-|\\b(de|la|del|el|per|dels|y|i|en))$") |
               (!con_datos &
                  str_count(lag(t, default = ""), "\\(") > str_count(lag(t, default = ""), "\\)")),
             sigue = sigue & (yc - lag(yc, default = -Inf)) < 20,
             grupo = cumsum(!sigue)) |>
      group_by(grupo) |>
      summarise(partido = paste(t, collapse = " "), yc = mean(yc), .groups = "drop") |>
      mutate(fila = map_int(yc, \(z) a$fila[which.min(abs(a$yc - z))]),
             dist = map2_dbl(yc, fila, \(z, f) abs(a$yc[a$fila == f] - z))) |>
      filter(dist <= 16) |>
      group_by(fila) |>
      summarise(partido = paste(partido, collapse = " "), .groups = "drop")

    # centro real de cada columna de escaños a partir de los valores
    esc <- cuerpo |> filter(tipo == "esc", x > lim_etiqueta)
    cols <- cab |>
      mutate(xc_col = map_dbl(xc, \(cx) {
        cerca <- esc$xc[abs(esc$xc - cx) < 45]
        if (length(cerca)) median(cerca) else NA_real_
      })) |>
      filter(!is.na(xc_col)) |>
      distinct(clase, .keep_all = TRUE)
    if (!nrow(cols)) return(tibble())

    valores <- map_dfr(seq_len(nrow(cols)), \(i) {
      esc |>
        mutate(dist = abs(xc - cols$xc_col[i])) |>
        filter(dist < 20) |>
        group_by(fila) |> slice_min(dist, n = 1, with_ties = FALSE) |> ungroup() |>
        transmute(fila, clase = cols$clase[i], valor = text)
    })
    if (!nrow(valores)) return(tibble())

    lineas_zona <- zona |>
      group_by(linea) |>
      summarise(t = paste(text[order(x)], collapse = " "), y = min(y), .groups = "drop") |>
      arrange(y) |> pull(t)

    valores |>
      pivot_wider(names_from = clase, values_from = valor) |>
      left_join(etiquetas, by = "fila") |>
      mutate(zona = list(lineas_zona))
  })
}

# 6. Clasificar la circunscripción de cada bloque ---------------------------
clasificar_bloque <- function(lineas, eleccion, ccaa_estudio, municipio) {
  z <- normalizar(lineas)
  tipo_eleccion <- str_extract(eleccion, "^[a-z]+")

  if (!is.na(municipio)) {
    return(tibble(ambito = "municipio", ccaa = ccaa_estudio, provincia = NA_character_,
                  circunscripcion = municipio, eleccion = eleccion))
  }

  # municipio: "MADRID MUNICIPIO. N=1.180" o "BARCELONA (CIUDAD)"
  mun <- str_match(z, "^(.*?)\\s*(MUNICIPIO\\b|\\(CIUDAD\\))")[, 2]
  mun <- mun[!is.na(mun)]
  if (length(mun)) {
    nombre <- str_to_title(str_remove(tail(mun, 1), "^.*\\. "))
    return(tibble(ambito = "municipio", ccaa = ccaa_estudio, provincia = NA_character_,
                  circunscripcion = nombre,
                  eleccion = str_replace(eleccion, "^[a-z]+", "municipales")))
  }

  z_sin_ccaa <- str_remove_all(z, "CASTILLA Y LEON")
  dicc_prov <- if (tipo_eleccion == "generales") provincias else filter(provincias, !solo_generales)
  prov <- ultima_coincidencia(z_sin_ccaa, dicc_prov, "provincia")
  ccaa <- ultima_coincidencia(z, ccaas, "ccaa")
  if (is.na(ccaa)) ccaa <- ccaa_estudio

  # en autonómicas, un nombre de provincia que coincide con el de su
  # comunidad uniprovincial se trata como total de la comunidad
  if (!is.na(prov) && !is.na(ccaa)) {
    unica <- ccaas$provincia_unica[ccaas$ccaa == ccaa]
    if (!is.na(unica) && unica == prov) prov <- NA
  }

  if (!is.na(prov)) {
    return(tibble(ambito = "provincia", ccaa = provincias$ccaa[provincias$provincia == prov],
                  provincia = prov, circunscripcion = prov, eleccion = eleccion))
  }
  if (tipo_eleccion %in% c("generales", "europeas") && is.na(ccaa_estudio) &&
      !str_detect(paste(z, collapse = " "), "COMUNIDAD AUTONOMA|MUNICIPIO")) {
    return(tibble(ambito = "nacional", ccaa = NA_character_, provincia = NA_character_,
                  circunscripcion = "España", eleccion = eleccion))
  }
  unica <- ccaas$provincia_unica[match(ccaa, ccaas$ccaa)]
  tibble(ambito = "comunidad", ccaa = ccaa, provincia = unica,
         circunscripcion = ccaa, eleccion = eleccion)
}

# 7. Procesar todos los PDFs -----------------------------------------------
procesar_estudio <- function(estudio, eleccion, ccaa_estudio, municipio, archivo) {
  palabras <- leer_palabras(archivo)
  map_dfr(unique(palabras$pagina), \(p) {
    d <- filter(palabras, pagina == p)
    if (es_pagina_ancha(d)) {
      parsear_ancha(d) |>
        mutate(
          partido = limpiar_partido(partido),
          total_circ = str_detect(normalizar(partido), "^(TOTAL|ESCANOS)"),
          prov = map_chr(titulo, \(t) ultima_coincidencia(normalizar(t), provincias, "provincia"))
        ) |>
        group_by(prov) |>
        mutate(escanos_circunscripcion = suppressWarnings(as.integer(valor[total_circ][1]))) |>
        ungroup() |>
        filter(!total_circ) |>
        transmute(estudio, pagina = p, formato = "ancho",
                  ambito = "provincia", ccaa = provincias$ccaa[match(prov, provincias$provincia)],
                  provincia = prov, circunscripcion = prov, eleccion,
                  partido, horquilla = valor, mas_probable = NA_character_,
                  escanos_circunscripcion, etiqueta_pdf = titulo)
    } else {
      bl <- parsear_bloques(d)
      if (!nrow(bl)) return(tibble())
      if (!"mas_probable" %in% names(bl)) bl$mas_probable <- NA_character_
      if (!"horquilla" %in% names(bl)) bl$horquilla <- bl$mas_probable
      bl |>
        mutate(info = map(zona, \(z) clasificar_bloque(z, eleccion, ccaa_estudio, municipio))) |>
        unnest(info) |>
        transmute(estudio, pagina = p, formato = "bloques", ambito, ccaa, provincia,
                  circunscripcion, eleccion, partido = limpiar_partido(partido),
                  horquilla, mas_probable, escanos_circunscripcion = NA_integer_,
                  etiqueta_pdf = map_chr(zona, \(z) paste(tail(z, 3), collapse = " | ")))
    }
  })
}

estimaciones_raw <- estudios |>
  pmap_dfr(\(estudio, eleccion, ccaa_estudio, municipio, archivo, ...) {
    message("Estudio ", estudio, " (", basename(archivo), ")")
    procesar_estudio(estudio, eleccion, ccaa_estudio, municipio, archivo)
  })

estimaciones <- estimaciones_raw |>
  filter(!is.na(partido), partido != "") |>
  mutate(
    rango = map(coalesce(horquilla, mas_probable), parsear_escanos),
    escanos_min = map_int(rango, 1),
    escanos_max = map_int(rango, 2),
    escanos_mas_probable = map_int(mas_probable, \(t) if (is.na(t)) NA_integer_ else parsear_escanos(t)[1])
  ) |>
  select(estudio, eleccion, ambito, ccaa, provincia, circunscripcion, partido,
         escanos_min, escanos_max, escanos_mas_probable, escanos_circunscripcion,
         texto_pdf = horquilla, pagina, formato, etiqueta_pdf)

write_csv(estimaciones, "cis_estimaciones_escanos.csv")

# 8. Tabla de VOX ------------------------------------------------------------
# Reglas:
#   - Elecciones anteriores a 2018: 0 escaños en todas las circunscripciones.
#   - Generales, autonómicas y europeas desde 2018: estimación del CIS (0 si
#     el CIS publicó estimación en esa circunscripción sin escaños para VOX).
#   - Municipales desde 2018: concejales de VOX electos en ese municipio en
#     las municipales anteriores (0 si no obtuvo ninguno o no se presentó).
anio_de <- function(eleccion) as.integer(str_extract(eleccion, "\\d{4}"))

es_vox <- function(partido) str_detect(partido, regex("^vox$", ignore_case = TRUE))

vox_cis <- estimaciones |>
  filter(!str_detect(eleccion, "^municipales")) |>
  group_by(estudio, eleccion, ambito, ccaa, provincia, circunscripcion) |>
  summarise(
    vox_en_tabla             = any(es_vox(partido)),
    escanos_vox_min          = if (vox_en_tabla) escanos_min[es_vox(partido)][1] else 0L,
    escanos_vox_max          = if (vox_en_tabla) escanos_max[es_vox(partido)][1] else 0L,
    escanos_vox_mas_probable = if (vox_en_tabla) escanos_mas_probable[es_vox(partido)][1] else NA_integer_,
    .groups = "drop"
  ) |>
  mutate(
    anterior_2018            = anio_de(eleccion) < 2018,
    escanos_vox_min          = if_else(anterior_2018, 0L, escanos_vox_min),
    escanos_vox_max          = if_else(anterior_2018, 0L, escanos_vox_max),
    escanos_vox_mas_probable = if_else(anterior_2018, 0L, escanos_vox_mas_probable),
    fuente = if_else(anterior_2018, "0 (anterior a 2018)", paste0("CIS estudio ", estudio))
  ) |>
  select(-anterior_2018, -vox_en_tabla)

# Municipales: concejales electos en la convocatoria municipal anterior
municipales <- readxl::read_xlsx("CANDIDATOS_MUNICIPALES.xlsx") |>
  mutate(anio = anio_de(ELECCION),
         ELEGIDO = as.logical(ELEGIDO))

convocatorias_mun <- sort(unique(municipales$anio))

electos_mun <- municipales |>
  group_by(anio_anterior = anio, CCAA, CIRCUNSCRIPCION) |>
  summarise(electos_anteriores = sum(ELEGIDO, na.rm = TRUE), .groups = "drop")

vox_mun <- municipales |>
  distinct(eleccion = ELECCION, anio, ccaa = CCAA, circunscripcion = CIRCUNSCRIPCION) |>
  mutate(anio_anterior = map_int(anio, \(a) {
    previas <- convocatorias_mun[convocatorias_mun < a]
    if (length(previas)) max(previas) else NA_integer_
  })) |>
  left_join(electos_mun, by = c("anio_anterior", "ccaa" = "CCAA", "circunscripcion" = "CIRCUNSCRIPCION")) |>
  mutate(
    escanos = if_else(anio < 2018, 0L, coalesce(electos_anteriores, 0L)),
    estudio = NA_real_, ambito = "municipio", provincia = NA_character_,
    escanos_vox_min = escanos, escanos_vox_max = escanos, escanos_vox_mas_probable = escanos,
    fuente = if_else(anio < 2018, "0 (anterior a 2018)",
                     paste0("electos en municipales ", anio_anterior))
  ) |>
  select(names(vox_cis))

cis_vox <- bind_rows(vox_cis, vox_mun) |>
  arrange(eleccion, ambito, circunscripcion)

write_csv(cis_vox, "cis_estimaciones_vox.csv")

# 9. Controles ---------------------------------------------------------------
# a) Cobertura por estudio
estimaciones |>
  count(estudio, eleccion, ambito, name = "filas") |>
  left_join(cis_vox |> count(estudio, eleccion, ambito, name = "circunscripciones"),
            by = c("estudio", "eleccion", "ambito")) |>
  print(n = Inf)

# b) En las tablas anchas: suma de mínimos <= escaños de la provincia <= suma de máximos
estimaciones |>
  filter(formato == "ancho") |>
  group_by(estudio, provincia) |>
  summarise(suma_min = sum(escanos_min), suma_max = sum(escanos_max),
            escanos = first(escanos_circunscripcion), .groups = "drop") |>
  filter(is.na(escanos) | suma_min > escanos | suma_max < escanos) |>
  print(n = Inf)

# c) Comparación con las estimaciones de VOX recopiladas a mano
#    (solo generales y autonómicas; las municipales ya no usan el CIS)
previas <- bind_rows(
  read_csv("cis_estimaciones_generales.csv", show_col_types = FALSE) |> rename(circunscripcion = provincia),
  read_csv("cis_estimaciones_autonomicas.csv", show_col_types = FALSE)
)
previas |>
  left_join(cis_vox |> filter(ambito != "municipio") |>
              select(eleccion, circunscripcion, escanos_vox_min, escanos_vox_max),
            by = c("eleccion", "circunscripcion"), suffix = c("_previo", "_pdf")) |>
  filter(!is.na(escanos_vox_min_previo),
         is.na(escanos_vox_min_pdf) |
           escanos_vox_min_previo != escanos_vox_min_pdf |
           escanos_vox_max_previo != escanos_vox_max_pdf) |>
  select(eleccion, circunscripcion, starts_with("escanos_vox")) |>
  print(n = Inf, width = Inf)
