# =============================================================================
# People listed by the satellite organisations of the Spanish radical right
#
# Reproducible retrieval from the Internet Archive with {archiveRetriever}:
#
#   1. retrieve_urls()   mementos of each organisation's homepage
#   2. retrieve_links()  every link those mementos contain
#   3. keep the sections that list people, by URL path
#   4. retrieve_urls()   again, now on each of those pages, to get every
#                        archived version of it
#   5. scrape_urls()     the text of each version
#   6. a name heuristic turns that text into (person, role) pairs
#
# The date attached to every row is the date of the CAPTURE, not of the
# appointment: the person was listed on that page on that day, which is not
# necessarily when they took office.
# =============================================================================

library(archiveRetriever)
library(tidyverse)
library(stringi)

START <- "2009-01-01"
END   <- as.character(Sys.Date())

organisations <- tribble(
  ~organisation, ~homepage,
  "DENAES",      "http://denaes.es",
  "Disenso",     "https://fundaciondisenso.org",
  "HazteOir",    "https://www.hazteoir.org",
  "CitizenGO",   "https://citizengo.org",
  "ISSEP",       "https://issep.es",
  "Solidaridad", "https://sindicatosolidaridad.es"
)

# solidaridad.es, a neighbourhood association in Malaga registered in 2009, is
# NOT the trade union Solidaridad, founded in 2020: the domain is left out.

# --- 1. mementos of each homepage -------------------------------------------
homepage_mementos <- organisations |>
  mutate(memento = map(homepage, possibly(
    \(h) retrieve_urls(h, startDate = START, endDate = END), character()))) |>
  unnest(memento)

# --- 2. links contained in those mementos -----------------------------------
site_links <- homepage_mementos |>
  mutate(links = map(memento, possibly(\(m) retrieve_links(m)$Urls, character()))) |>
  select(organisation, links) |>
  unnest(links) |>
  distinct()

# --- 3. the sections that enumerate people ----------------------------------
# The filter is on the path segment of the URL. Filtering on the text of the
# page would drag in every news item that happens to say "consejo" or "junta".
people_sections <- regex(
  "/(equipo|patronato|patronato-de-honor|quienes-somos|conocenos|nosotros|
     sobre-nosotros|organigrama|organos|consejo|comite|junta|directiva|
     profesores?|claustro|docentes|miembros|fundadores|team|staff|about|
     author)(/|$)",
  ignore_case = TRUE, comments = TRUE)

people_pages <- site_links |>
  mutate(
    original = str_remove(links, "^https?://web[.]archive[.]org/web/[0-9]+[a-z_]*/"),
    original = str_remove(str_remove(original, "[?].*$"), "/$"),
    path     = str_remove(original, "^https?://[^/]+")) |>
  filter(str_detect(path, people_sections),
         !str_detect(original, "[.](jpg|jpeg|png|gif|pdf|css|js|svg|xml)$"),
         !str_detect(original, "//(www[.])?solidaridad[.]es")) |>
  distinct(organisation, original)

# --- 4. every archived version of those pages -------------------------------
page_mementos <- people_pages |>
  mutate(memento = map(original, possibly(
    \(u) retrieve_urls(u, startDate = START, endDate = END), character()))) |>
  unnest(memento) |>
  mutate(capture_date = ymd(str_extract(memento, "(?<=/web/)[0-9]{8}")))

# --- 5. the text of each version --------------------------------------------
scraped <- page_mementos |>
  mutate(text = map_chr(memento, possibly(
    \(m) scrape_urls(m, Paths = c(text = "//main | //article | //body"),
                     ignoreErrors = TRUE, stopatempty = FALSE)$text[1],
    NA_character_))) |>
  filter(!is.na(text))

# --- 6. from text to people --------------------------------------------------
PARTICLES <- c("de", "del", "la", "las", "los", "y", "e", "da", "do",
               "van", "von", "el", "i", "san", "santa")

# Labels, menu entries and headlines that the capitalisation rule would
# otherwise accept as names ("Equipo de Direccion", "Discurso de Abascal").
NOT_A_PERSON <- str_c(
  "EQUIPO|CONSEJO|PATRONATO|DIRECCION|COMITE|JUNTA|FUNDACION|INSTITUTO|SINDICATO|",
  "ASOCIACION|REVISTA|DIARIO|DIGITAL|BLOG|ESCUELA|CENTRO|OBSERVATORIO|PREMIO|",
  "PROGRAMA|CURSO|JORNADA|CONGRESO|ESPANA|NACIONAL|INTERNACIONAL|MOVIMIENTO|",
  "INICIO|CONTACTO|PRENSA|AGENDA|BOLETIN|TIENDA|AVISO|LEGAL|PRIVACIDAD|COOKIES|",
  "DISCURSO|ENTREVISTA|ARTICULO|CONFERENCIA|PONENCIA|VIDEO|CAMPAIGN|FOUNDATION|",
  "ENGLISH|ESPANOL|FRANCAIS|PORTUGUESE|DEUTSCH")

# What may follow a name and be kept. The column is called "role or
# description" on purpose: these sites print a post ("Presidente") and a
# profession ("Filosofo", "Pediatra") in exactly the same place.
ROLE_WORDS <- str_c(
  "PRESIDENT|VICEPRESIDENT|DIRECTOR|SECRETARI|TESORER|VOCAL|PATRON|COORDINADOR|",
  "RESPONSABLE|GERENTE|PORTAVOZ|FUNDADOR|MIEMBRO|ASESOR|PROFESOR|CATEDRATIC|",
  "DOCENTE|INVESTIGADOR|ANALISTA|CONSEJER|DELEGAD|ESCRITOR|PERIODISTA|FILOSOF|",
  "HISTORIADOR|ABOGAD|ECONOMISTA|MILITAR|GENERAL|EMPRESARI|MAGISTRAD|SOCIOLOG|",
  "POLITOLOG|JURISTA|DECANO|RECTOR|EDITOR|COLUMNISTA|DIPUTAD|SENADOR|EURODIPUTAD")

flat <- function(x) str_to_upper(stri_trans_general(x, "Latin-ASCII"))

# 2 to 6 words, every one of them capitalised except the particles
is_person_name <- function(x) {
  x <- str_squish(x)
  capitalised <- map_lgl(str_split(x, " "), \(w) {
    w <- w[!str_to_lower(flat(w)) %in% PARTICLES]
    length(w) >= 2 && all(str_detect(w, "^\\p{Lu}\\p{L}"))
  })
  str_length(x) >= 5 & str_length(x) <= 60 &
    str_count(x, "\\S+") >= 2 & str_count(x, "\\S+") <= 6 &
    !str_detect(x, "[0-9@#/|]") &
    capitalised &
    !str_detect(flat(x), NOT_A_PERSON) &
    !str_detect(flat(x), ROLE_WORDS)
}

people <- scraped |>
  select(organisation, original, capture_date, text) |>
  separate_longer_delim(text, "\n") |>
  mutate(line = str_squish(text), .keep = "unused") |>
  filter(line != "") |>
  # "Ignacio Arsuaga Rato, Presidente" is a person and their role; without
  # splitting it, the whole line is discarded for containing "Presidente"
  separate_wider_delim(line, ", ", names = c("person", "role"),
                       too_many = "merge", too_few = "align_start") |>
  mutate(role = replace_na(role, "")) |>
  filter(is_person_name(person),
         str_length(role) <= 90,
         role == "" | str_detect(flat(role), ROLE_WORDS) | str_count(role, "\\S+") <= 5) |>
  mutate(section = case_when(
    str_detect(original, "patronato-de-honor")        ~ "Honorary board",
    str_detect(original, "patronato|patronos")        ~ "Board of trustees",
    str_detect(original, "profesor|claustro|docente") ~ "Faculty",
    str_detect(original, "junta|directiva|comite")    ~ "Executive committee",
    str_detect(original, "consejo")                   ~ "Advisory council",
    # a byline says who signs content on the site, which is not the same as
    # belonging to its team
    str_detect(original, "author")                    ~ "Bylines on the website",
    str_detect(original, "equipo|team|staff")         ~ "Staff",
    .default = "Other page"))

# one row per person and organisation, with the span over which they are listed
people_summary <- people |>
  summarise(.by = c(organisation, person),
            sections   = str_c(sort(unique(section)), collapse = " | "),
            roles      = str_c(sort(unique(role[role != ""])), collapse = " | "),
            first_seen = min(capture_date),
            last_seen  = max(capture_date),
            n_captures = n()) |>
  arrange(organisation, person)

# the point of the whole thing: who sits in more than one of these bodies
overlap <- people_summary |>
  summarise(.by = person,
            organisations   = str_c(sort(unique(organisation)), collapse = " | "),
            n_organisations = n_distinct(organisation)) |>
  filter(n_organisations > 1) |>
  arrange(desc(n_organisations), person)

write_csv(people,         "satellite_orgs_people_long.csv")
write_csv(people_summary, "satellite_orgs_people.csv")
write_csv(overlap,        "satellite_orgs_overlap.csv")
