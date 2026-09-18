# =============================================================================
# People listed by the satellite organisations of the Spanish radical right
#
# The retrieval itself is the Python pipeline in organizaciones/, called from R
# through {reticulate}, so that the whole thing runs from the .qmd:
#
#   01_urls.py      catalogue of every archived URL of each domain (CDX API)
#   02_capturas.py  captures of the pages that list people, collapsed by
#                   digest so that only real content changes are kept
#   03_extraer.py   download each capture and read the people off it
#   05_hazteoir.py  HazteOir, whose site has lived on four different hosts
#   06_citizengo.py CitizenGO
#
# Reading the people off the page is the part that cannot be replaced by a
# selector: these sites use four different layouts (an individual profile with
# the name in the URL, alternating name/role lines, the name repeated between
# the role and the biography, and "Name, Role" on a single line).
#
# The date on every row is the date of the CAPTURE, not of the appointment:
# the person was listed on that page on that day, which is not necessarily
# when they took office.
# =============================================================================

library(reticulate)
library(tidyverse)

# requests/bs4/lxml, resolved into an ephemeral environment by reticulate
py_require(c("requests", "beautifulsoup4", "lxml"))

ORG_DIR <- "organizaciones"

# The scripts are numbered, so their names are not valid Python identifiers and
# cannot be imported: they are executed instead. They locate their own folder
# through __file__, which py_run_file does not set on its own.
run_python_script <- function(file) {
  path <- normalizePath(file.path(ORG_DIR, file), winslash = "/")
  py_run_string(sprintf("__file__ = '%s'", path))
  py_run_file(path)
  invisible(NULL)
}

# Each phase writes its result to organizaciones/out/ and the captures are
# cached in organizaciones/snapshots/, so a second run costs nothing and a run
# interrupted by the Archive's rate limit resumes where it stopped.
retrieve_if_missing <- function(file, script) {
  if (!file.exists(file.path(ORG_DIR, "out", file))) run_python_script(script)
}

retrieve_if_missing("urls.csv",                "01_urls.py")
retrieve_if_missing("capturas.csv",            "02_capturas.py")
retrieve_if_missing("personas.csv",            "03_extraer.py")
retrieve_if_missing("personas_hazteoir.csv",   "05_hazteoir.py")
retrieve_if_missing("personas_citizengo.csv",  "06_citizengo.py")

# --- back into R -------------------------------------------------------------
# What survives the Python filter and is still not a person: the universities
# and newspapers that appear inside the biographies, the buttons of the page
# itself ("Leer bio", "Ver organigrama"), a couple of bare job titles, and the
# organisations' own names. Roughly 8% of the raw output.
NOT_A_PERSON <- str_c(
  "UNIVERSIT|SCIENCES PO|COLLEGE|SCHOOL|INSTITUT|GEORGETOWN|SORBONNE|",
  "DIGEST|OBJECTIVE|TELEVISION|NEWSLETTER|GACETA|ANTHROPOLOGY|GOURMET|",
  "IP ADDRESS|SOBRE NOSOTROS|^LEER |^VER |^FISCAL |MANAGER|FUNDADOR|",
  "ISSEP|DISENSO|CITIZENGO|HAZTEOIR|DENAES|SUMA CULTURAL|RECONSTRUIR")

satellite_people <- c("personas.csv", "personas_hazteoir.csv", "personas_citizengo.csv") |>
  map(\(f) read_csv(file.path(ORG_DIR, "out", f), col_types = cols(.default = "c"))) |>
  list_rbind() |>
  filter(!str_detect(str_to_upper(stringi::stri_trans_general(nombre, "Latin-ASCII")),
                     NOT_A_PERSON)) |>
  transmute(
    organisation = organizacion,
    section      = organo,
    person       = nombre,
    role         = replace_na(cargo, ""),   # a post, but also often a profession
    role_family  = familia_cargo,
    capture_date = ymd(fecha_captura),
    url, wayback_url = url_wayback, pattern = patron)

# one row per person and organisation, with the span over which they are listed
satellite_summary <- satellite_people |>
  summarise(.by = c(organisation, person),
            sections   = str_c(sort(unique(section)), collapse = " | "),
            roles      = str_c(sort(unique(role[role != ""])), collapse = " | "),
            first_seen = min(capture_date),
            last_seen  = max(capture_date),
            n_captures = n()) |>
  arrange(organisation, person)

# the point of the whole thing: who sits in more than one of these bodies
satellite_overlap <- satellite_summary |>
  summarise(.by = person,
            organisations   = str_c(sort(unique(organisation)), collapse = " | "),
            n_organisations = n_distinct(organisation)) |>
  filter(n_organisations > 1) |>
  arrange(desc(n_organisations), person)

satellite_summary |> count(organisation, name = "people")
satellite_overlap
