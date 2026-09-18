# =============================================================================
# People listed on the websites of the satellite organisations of VOX,
# read from the Internet Archive. Pure R, ~2 minutes, writes one CSV.
#
# Two things keep it fast: only the pages that list people are asked for (one
# CDX query per path prefix, collapsed by digest so that only real content
# changes come back), and at most one capture per page and year is downloaded,
# all of them in parallel.
#
# The date is the date of the CAPTURE, not of the appointment: the person was
# listed on that page on that day, not necessarily appointed then.
# =============================================================================

library(tidyverse)
library(httr2)
library(rvest)
library(readxl)

# path prefixes that hold the team, the board, the faculty
pages <- tribble(
  ~organisation, ~prefix,
  "DENAES",      "denaes.es/quienes-somos",
  "Disenso",     "fundaciondisenso.org/nosotros",
  "ISSEP",       "issep.es/nosotros",
  "ISSEP",       "issep.es/profesores",
  "HazteOir",    "hazteoir.org/conocenos",
  "HazteOir",    "www.hazteoir.org/conocenos",
  "CitizenGO",   "citizengo.org/es/conocenos",
  "CitizenGO",   "www.citizengo.org/es/conocenos",
  "CitizenGO",   "citizengo.org/en/about-us",
  "Solidaridad", "sindicatosolidaridad.es/contacto"
)

# --- 1. what the Archive has --------------------------------------------------
captures <- pages |>
  mutate(cdx = map(prefix, \(p)
    request("http://web.archive.org/cdx/search/cdx") |>
      req_url_query(url = p, matchType = "prefix", output = "json",
                    fl = "timestamp,original", collapse = "digest",
                    filter = c("statuscode:200", "mimetype:text/html"),
                    limit = 2000, .multi = "explode") |>
      req_retry(max_tries = 3) |>
      req_perform() |> resp_body_json() |>
      (\(x) tibble(timestamp = map_chr(x[-1], 1), original = map_chr(x[-1], 2)))())) |>
  unnest(cdx) |>
  mutate(date = ymd(str_sub(timestamp, 1, 8)), year = year(date),
         snapshot = str_c("https://web.archive.org/web/", timestamp, "id_/", original)) |>
  # one capture per page and year is enough to follow who is on a board
  slice_max(date, n = 1, by = c(original, year), with_ties = FALSE)

# --- 2. download them in parallel ---------------------------------------------
responses <- captures$snapshot |>
  map(\(u) request(u) |> req_timeout(30) |> req_error(is_error = \(r) FALSE)) |>
  req_perform_parallel(max_active = 5, on_error = "continue", progress = TRUE)

lines <- captures |>
  mutate(html = map_chr(responses, possibly(\(r) resp_body_string(r), NA_character_))) |>
  filter(!is.na(html)) |>
  # only the code is dropped. These sites wrap their content in <header> and
  # <aside>, so removing those takes the board away with the menu; the census
  # test below is what actually separates people from navigation.
  mutate(text = map(html, \(h) {
    page <- read_html(h)
    page |> html_elements("script, style, noscript") |> xml2::xml_remove()
    page |> html_elements("body") |> html_text2() |> str_split_1("\n") |> str_squish()
  }), .keep = "unused") |>
  unnest(text) |>
  filter(text != "")

# --- 3. which of those lines is a person --------------------------------------
PARTICLES <- c("de", "del", "la", "las", "los", "y", "e", "da", "do", "van", "von", "i")

# labels, menus and headlines the capitalisation rule would otherwise accept
NOT_A_PERSON <- str_c(
  "EQUIPO|CONSEJO|PATRONATO|DIRECCION|COMITE|JUNTA|FUNDACION|INSTITUTO|SINDICATO|",
  "ASOCIACION|UNIVERSIT|SCIENCES PO|COLLEGE|SCHOOL|REVISTA|DIARIO|DIGEST|OBJECTIVE|",
  "TELEVISION|NEWSLETTER|GACETA|BLOG|ESCUELA|CENTRO|OBSERVATORIO|PREMIO|PROGRAMA|",
  "CURSO|JORNADA|CONGRESO|ESPANA|NACIONAL|INTERNACIONAL|MOVIMIENTO|INICIO|CONTACTO|",
  "PRENSA|AGENDA|BOLETIN|TIENDA|AVISO|LEGAL|PRIVACIDAD|COOKIES|DISCURSO|ENTREVISTA|",
  "ARTICULO|CONFERENCIA|PONENCIA|VIDEO|FOUNDATION|CAMPAIGN|MANAGER|IP ADDRESS|",
  "SOBRE NOSOTROS|^LEER|^VER |^FISCAL|ENGLISH|ESPANOL|FRANCAIS|DEUTSCH|",
  "ISSEP|DISENSO|CITIZENGO|HAZTEOIR|DENAES")

# what may follow a name and be kept. The column is "role or description" on
# purpose: these sites print a post ("Presidente") and a profession
# ("Filosofo", "Pediatra") in exactly the same place
ROLES <- str_c(
  "PRESIDENT|VICEPRESIDENT|DIRECTOR|SECRETARI|TESORER|VOCAL|PATRON|COORDINADOR|",
  "RESPONSABLE|GERENTE|PORTAVOZ|FUNDADOR|MIEMBRO|ASESOR|PROFESOR|CATEDRATIC|",
  "DOCENTE|INVESTIGADOR|ANALISTA|CONSEJER|DELEGAD|ESCRITOR|PERIODISTA|FILOSOF|",
  "HISTORIADOR|ABOGAD|ECONOMISTA|MILITAR|EMPRESARI|MAGISTRAD|SOCIOLOG|POLITOLOG|",
  "JURISTA|DECANO|RECTOR|EDITOR|COLUMNISTA|DIPUTAD|SENADOR|EURODIPUTAD")

flat <- function(x) str_to_upper(stringi::stri_trans_general(x, "Latin-ASCII"))

# The real test of whether a line is a person: the INE census lists, which the
# project already uses to assign sex to candidates. A word list of things that
# are NOT names never ends; a list of the names that exist does.
ine_forenames <- c("Hombres", "Mujeres") |>
  map(\(s) read_excel("nombres_por_edad_media.xlsx", sheet = s, skip = 5)$Nombre) |>
  list_c() |> flat() |> str_squish()

# nicknames and rare forenames the census does not carry
ALSO_PEOPLE <- c("CAKE", "EDMALY")

# 2 to 6 words, all of them capitalised except the particles
is_person <- function(x) {
  capitalised <- map_lgl(str_split(x, " "), \(w) {
    w <- w[!str_to_lower(flat(w)) %in% PARTICLES]
    length(w) >= 2 && all(str_detect(w, "^\\p{Lu}\\p{L}"))
  })
  str_length(x) >= 5 & str_length(x) <= 60 &
    str_count(x, "\\S+") >= 2 & str_count(x, "\\S+") <= 6 &
    !str_detect(x, "[0-9@#/|]") & capitalised &
    flat(word(x, 1)) %in% c(ine_forenames, ALSO_PEOPLE) &
    !str_detect(flat(x), NOT_A_PERSON) & !str_detect(flat(x), ROLES)
}

people <- lines |>
  # "Ignacio Arsuaga Rato, Presidente" is a person and their role on one line;
  # without splitting it, the line is thrown away for containing "Presidente"
  separate_wider_delim(text, ", ", names = c("person", "inline_role"),
                       too_many = "merge", too_few = "align_start") |>
  mutate(inline_role = replace_na(inline_role, ""),
         # the other layout puts the role on the line below the name
         next_line = lead(person), .by = c(organisation, original, timestamp)) |>
  filter(is_person(person)) |>
  mutate(role = case_when(
           str_detect(flat(inline_role), ROLES) ~ inline_role,
           str_detect(flat(next_line), ROLES) & str_length(next_line) <= 90 ~ next_line,
           .default = ""),
         # Disenso prints the same board in caps on one page and in title case
         # on another: "AMANDO DE MIGUEL" and "Amando de Miguel" are one person
         person = if_else(person == str_to_upper(person), str_to_title(person), person),
         person = str_replace_all(person, str_c("(?<= )(", str_c(str_to_title(PARTICLES),
                                                                 collapse = "|"), ")(?= )"),
                                  str_to_lower))

# the same person is listed with and without the second surname ("Ana Velasco",
# "Ana Velasco Vidal-Abarca"): the longest form wins
variants <- people |>
  distinct(person) |>
  # compound surnames are opened at the hyphen, so that "Alejo Vidal Quadras"
  # falls inside "Alejo Vidal-Quadras Roca"
  mutate(tokens = str_split(flat(person), "[ -]"), first = map_chr(tokens, 1))

people <- variants |>
  rename(long = person, long_tokens = tokens) |>
  inner_join(rename(variants, short = person, short_tokens = tokens), by = "first",
             relationship = "many-to-many") |>
  filter(map2_lgl(short_tokens, long_tokens, \(s, l) all(s %in% l)),
         lengths(short_tokens) <= lengths(long_tokens)) |>
  slice_max(lengths(long_tokens), n = 1, by = short, with_ties = FALSE) |>
  select(person = short, canonical = long) |>
  right_join(people, by = "person") |>
  mutate(person = coalesce(canonical, person)) |>
  summarise(.by = c(organisation, person),
            roles      = str_c(sort(unique(role[role != ""])), collapse = " | "),
            first_seen = min(date),
            last_seen  = max(date),
            n_captures = n_distinct(timestamp),
            source     = first(str_c("https://web.archive.org/web/", timestamp, "/", original))) |>
  arrange(organisation, person)

# --- 4. Solidaridad, from the BOE ---------------------------------------------
# The union's website archives no team page, so its officers are taken from the
# four announcements of the deposit of its statutes (Direccion General de
# Trabajo, union SPDSTE, deposit number 99105954). Searched at boe.es for
# SPDSTE in the title. Rafael Martinez de la Gandara, who signs all four, is
# the civil servant issuing the resolution and is NOT part of the union.
solidaridad_boe <- tribble(
  ~person,                              ~roles,             ~date,        ~boe,
  "Santiago Alarcón Gordon",            "Solicitante del depósito", "2020-08-12", "BOE-B-2020-26040",
  "Paula Bernardina Hidalgo de la Cruz","Promotora",        "2020-08-12", "BOE-B-2020-26040",
  "Raquel Moreno Barba",                "Promotora",        "2020-08-12", "BOE-B-2020-26040",
  "Ángel García Ochoa",                 "Promotor",         "2020-08-12", "BOE-B-2020-26040",
  "Santiago Alarcón Gordon",            "Solicitante del depósito", "2021-02-15", "BOE-B-2021-7089",
  "Rodrigo Alonso Fernández",           "Secretario General", "2021-02-15", "BOE-B-2021-7089",
  "Javier Tomás de la Cruz Bazo",       "Solicitante del depósito", "2025-05-23", "BOE-B-2025-18656",
  "Jordi Albert de la Fuente Miró",     "Secretario General", "2025-05-23", "BOE-B-2025-18656",
  "Javier Tomás de la Cruz Bazo",       "Solicitante del depósito", "2026-07-03", "BOE-B-2026-22639",
  "Jordi Albert de la Fuente Miró",     "Secretario General", "2026-07-03", "BOE-B-2026-22639"
) |>
  summarise(.by = person,
            organisation = "Solidaridad",
            roles      = str_c(sort(unique(roles)), collapse = " | "),
            first_seen = min(ymd(date)),
            last_seen  = max(ymd(date)),
            n_captures = n(),
            source     = str_c("https://www.boe.es/diario_boe/txt.php?id=", first(boe)))

people <- bind_rows(people, solidaridad_boe) |> arrange(organisation, person)

write_csv(people, "personas_organizaciones.csv")

people |> count(organisation, name = "people")

# who sits in more than one of them
people |>
  summarise(.by = person, organisations = str_c(sort(unique(organisation)), collapse = " | "),
            n = n_distinct(organisation)) |>
  filter(n > 1) |>
  arrange(desc(n), person)
