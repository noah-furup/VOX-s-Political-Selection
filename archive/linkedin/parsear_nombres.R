# =============================================================================
# Extraer los nombres de personas de páginas de resultados de LinkedIn
# copiadas a mano.
#
# CÓMO USARLO
#   1. Abre cada página de resultados en el navegador (páginas 2 a 10).
#   2. En cada una: Ctrl+A, Ctrl+C.
#   3. Pega en un fichero de texto dentro de linkedin/paginas/,
#      uno por página:  pagina_02.txt, pagina_03.txt, ... pagina_10.txt
#   4. Ejecuta este script.
#
# Sale linkedin/nombres_linkedin.csv con el nombre, la página de origen y la
# línea siguiente del bloque (que suele ser el titular profesional).
#
# El acceso lo haces tú en tu propia sesión: el script no se conecta a
# LinkedIn ni automatiza nada contra el sitio.
# =============================================================================

library(stringr)
library(dplyr)
library(readr)

DIR_PAGINAS <- "linkedin/paginas"
SALIDA      <- "linkedin/nombres_linkedin.csv"

# --- vocabulario de interfaz: nada de esto es un nombre de persona ----------
RUIDO <- str_c(collapse = "|", c(
  "grado de contacto", "Conectar", "Seguir", "Mensaje", "Ver perfil",
  "Ver p.gina", "Guardar", "Siguiente", "Anterior", "Resultados",
  "Personas", "Empresas", "Empleos", "Grupos", "Escuelas", "Publicaciones",
  "Filtros", "Ubicaciones", "Contactos", "Idioma", "Buscar", "Inicio",
  "Mi red", "Notificaciones", "Yo\\b", "LinkedIn", "Foto de",
  "conexi.n en com.n", "conexiones en com.n", "Miembro de LinkedIn",
  "Estado actual", "Ha estudiado", "Trabaja en", "Premium",
  "Ampliar", "Cerrar", "M.s opciones", "Acerca de", "Accesibilidad",
  "Pol.tica de privacidad", "Condiciones", "Publicidad", "Copyright"
))

# marca de grado de contacto: "• 1.º", "· 2.º", "3er", "2do"...
RE_GRADO <- "^[•·\\*\\-\\s]*(1|2|3)\\s*(º|°|er|do|.{0,3})\\s*$"

# un nombre español: 2-5 palabras capitalizadas, admitiendo partículas
PARTICULAS <- c("de", "del", "la", "las", "los", "y", "e", "da", "do", "van", "von", "i")
RE_PALABRA <- "[A-ZÁÉÍÓÚÑÜ][a-záéíóúñü'’-]+"

es_nombre <- function(x) {
  x <- str_squish(x)
  if (is.na(x) || nchar(x) < 5 || nchar(x) > 60) return(FALSE)
  if (str_detect(x, RUIDO)) return(FALSE)
  if (str_detect(x, "[0-9@/\\\\|•·#]")) return(FALSE)
  if (str_detect(x, ",")) return(FALSE)          # "Madrid, España" no es un nombre
  pal <- str_split(x, "\\s+")[[1]]
  if (length(pal) < 2 || length(pal) > 5) return(FALSE)
  # cada palabra: partícula en minúscula, o palabra capitalizada
  ok <- vapply(pal, function(p) {
    tolower(p) %in% PARTICULAS || str_detect(p, str_c("^", RE_PALABRA, "$"))
  }, logical(1))
  # al menos dos palabras "de verdad" (no partículas)
  sum(!tolower(pal) %in% PARTICULAS) >= 2 && all(ok)
}

# --- lectura ---------------------------------------------------------------
ficheros <- list.files(DIR_PAGINAS, pattern = "\\.txt$", full.names = TRUE)
if (length(ficheros) == 0) {
  stop("No hay ficheros en ", DIR_PAGINAS,
       ". Pega ahí el texto de cada página como pagina_02.txt, pagina_03.txt, ...")
}

extraer_de_fichero <- function(ruta) {
  lineas <- read_lines(ruta) |> str_squish()
  lineas <- lineas[lineas != ""]
  # LinkedIn repite el nombre (una vez como enlace, otra para lectores de
  # pantalla): quitamos la repetición inmediata
  lineas <- lineas[c(TRUE, lineas[-1] != lineas[-length(lineas)])]

  candidatos <- which(vapply(lineas, es_nombre, logical(1)))
  if (length(candidatos) == 0) return(tibble())

  # Señal fuerte: un nombre de resultado lleva el grado de contacto
  # ("• 2.º") en alguna de las dos líneas siguientes.
  con_grado <- vapply(candidatos, function(i) {
    sig <- lineas[seq(i + 1, min(i + 2, length(lineas)))]
    any(str_detect(sig, RE_GRADO))
  }, logical(1))

  # Si la señal aparece, nos fiamos solo de ella; si el formato copiado no la
  # trae, caemos a la heurística general y avisamos.
  idx <- if (any(con_grado)) candidatos[con_grado] else candidatos
  fiabilidad <- if (any(con_grado)) "grado de contacto" else "solo heuristica"

  tibble(
    nombre   = lineas[idx],
    contexto = lineas[pmin(idx + 1, length(lineas))],
    pagina   = str_extract(basename(ruta), "\\d+"),
    fuente   = basename(ruta),
    criterio = fiabilidad
  )
}

res <- bind_rows(lapply(ficheros, extraer_de_fichero))

if (nrow(res) == 0) {
  stop("No se ha reconocido ningún nombre. Pega aquí las primeras 30 líneas ",
       "de una de las páginas y ajusto los patrones.")
}

# el mismo perfil puede salir en varias páginas
res <- res |>
  mutate(clave = str_to_lower(str_squish(nombre))) |>
  group_by(clave) |>
  slice(1) |>
  ungroup() |>
  select(-clave) |>
  arrange(pagina, nombre)

dir.create(dirname(SALIDA), showWarnings = FALSE, recursive = TRUE)
write_csv(res, SALIDA)

# --- control ---------------------------------------------------------------
cat("ficheros leidos :", length(ficheros), "\n")
cat("nombres unicos  :", nrow(res), "\n")
cat("por pagina      :\n"); print(table(res$pagina))
cat("criterio        :\n"); print(table(res$criterio))
cat("\nPrimeros 15 (revisalos antes de dar el fichero por bueno):\n")
print(head(res[, c("nombre", "contexto")], 15), n = 15)
cat("\n-> ", SALIDA, "\n")
