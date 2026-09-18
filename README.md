# How Vox selects its candidates

Code and data of the Master Final Project *How Vox selects its candidates*
(Noah Emanuel Fürup, Universidad Carlos III de Madrid).

The project builds a dataset of every person who stood on a Vox list between 2014 and
2026 (European, general, regional and municipal elections), links it to the candidates of
the PP, Ciudadanos and the historical Spanish far right and to the members of Vox's
satellite organisations, and uses it to answer two questions:

- **RQ1.** Where does Vox take its electable candidates from? (network of electable candidates)
- **RQ2.** How do the candidates placed in electable positions differ from those placed just
  below the electability threshold? (general election of July 2023)

## Structure

```
BASE DE DATOS VOX/
├── BASE DE DATOS VOX.Rproj   open this first: every path is relative to it (package here)
├── README.md
├── code/                     the analysis, in the order it runs
│   ├── 01_context.qmd
│   ├── 02_data_extraction.qmd
│   ├── 03_satellite_organisations.qmd
│   ├── 04_data_enrichment.qmd
│   ├── 05_descriptives_maps.qmd
│   ├── 06_network.qmd
│   ├── 07_regressions.qmd
│   └── auxiliary/            scripts that produced some raw files (outside the pipeline)
├── data/
│   ├── raw/                  files as downloaded or scraped
│   ├── manual/               datasets built by hand from the press and other sources
│   └── processed/            objects each script saves for the next one (.RData)
├── outputs/
│   ├── figures/
│   └── network/              Gephi files of the network
├── docs/                     literature and notes
└── archive/                  earlier versions and material outside the analysis
```

## How to run

1. Open `BASE DE DATOS VOX.Rproj` in RStudio.
2. Run or render the scripts of `code/` **in their numerical order**. Each script saves the
   objects the following ones need in `data/processed/<script>.RData`, and loads those of
   the scripts before it in its `SETUP` chunk.
3. `02_data_extraction.qmd` downloads the general, European and municipal lists from the
   Ministry of the Interior (infoelectoral) and its GitHub mirror, and
   `03_satellite_organisations.qmd` queries the Wayback Machine: both need an internet
   connection, and 03 takes about five minutes.

| Script | What it does | Loads | Saves |
|---|---|---|---|
| `01_context` | Figures and tables of the theoretical framework: electoral systems in Europe, far-right parties since 1976 and their family tree, signatories and founders of Vox, replication of Rama et al. (2021, fig. 4.12) with CIS study 3269 | – | `01_context.RData` |
| `02_data_extraction` | Candidates of Vox, PP, Cs and the historical far right in every election | – | `02_data_extraction.RData` |
| `03_satellite_organisations` | Members of DENAES, Disenso, ISSEP, HazteOir, CitizenGO, Solidaridad, Revuelta and Homo Legens | 02 | `03_satellite_organisations.RData` |
| `04_data_enrichment` | Names, sex, signatories and founders, government and party posts, seats, expected seats and electability threshold, ISCO-08, candidacies in 2013-2017, previous parties | 01, 02 | `04_data_enrichment.RData` |
| `05_descriptives_maps` | Electoral results, candidates by level, faceted cartogram, maps of territorial penetration | 02, 03, 04 | – |
| `06_network` | Network of electable candidates and satellite members; exports it to Gephi (`outputs/network/`) | 01, 03, 04 | – |
| `07_regressions` | Validation of the electability threshold; candidates within and just below it in July 2023 | 02, 04 | – |

## Data

**`data/raw/`** — sources as obtained:

| Folder or file | Content and origin |
|---|---|
| `candidates/` | Candidate lists compiled for the regional and municipal elections of Vox, PP, Cs and the historical far right |
| `autonomicas_scrape/` | Regional lists scraped from the official gazettes, with the scripts that scraped them |
| `infoelectoral_results/` | Congress results by constituency (Ministry of the Interior, `PROV_02` files) and municipal files |
| `infoelectoral_repo/` | Local copy of the infoelectoral parser repository (Jaime Obregón, GitHub) |
| `datos_pp_locales/` | Municipal election files of the Ministry of the Interior (download cache of 02) |
| `datos_generales_jec/` | General election material of the Junta Electoral Central |
| `party_registry/` | Registry of political parties of the Ministry of the Interior (Maldita, 2024; update of September 2026) |
| `ine/` | INE: municipality codes (2026), forenames by mean age, surname frequencies |
| `alcaldes/` | Mayors of the 2015, 2019 and 2023 mandates and councillors of 2023 (Ministry of Territorial Policy) |
| `parliaments/` | Deputies of the Congress and of several regional parliaments |
| `cis_estimaciones/` | CIS pre-electoral seat estimates used for the electability threshold, with the original PDFs |
| `cis_3269/` | Microdata of CIS study 3269 (post-electoral survey, November 2019) |
| `comite_ejecutivo/`, `organizaciones/` | Archived pages of Vox's executive and of the satellite organisations |
| `partidos_hist/`, `wikidata_cache/` | Sources of the historical parties and of Wikidata queries |
| `idea_electoral_systems.xlsx` | IDEA Electoral System Design Database |
| `ches_1999_2024_means_v2.csv` | Chapel Hill Expert Survey, 1999-2024 |

**`data/manual/`** — built by hand, with a source for every row:

| File | Content |
|---|---|
| `isco_candidatos_2023.xlsx` | Occupation (ISCO-08) of the Congress candidates of July 2023 within and just below the electability threshold |
| `prev_party_prensa.xlsx` | Previous parties of candidates found in the press |
| `organizaciones_candidatos.xlsx` | Organisations of the candidates found in the press |
| `vox_cargos_organos.xlsx` | Government and party posts of Vox members |
| `personas_organizaciones.*`, `personas_wikidata.xlsx` | People linked to organisations and Wikidata records |
| `far_right_parties_sources.csv`, `far_right_register_review.csv`, `homonym_review.csv`, `sociodemographic_collection.csv` | Review files of the far-right parties, homonyms and sociodemographic data |

**Data not in the repository** (too large for GitHub, or not ours to redistribute):
`data/raw/infoelectoral_repo/` (clone of the infoelectoral parser repository, 3.4 GB),
`data/raw/autonomicas_scrape/`, `data/raw/organizaciones/`, `data/raw/comite_ejecutivo/`
(scraping caches), `data/raw/datos_pp_locales/` (download cache of 02), `data/raw/cis_3269/`
(CIS microdata: download study 3269 from cis.es) and the articles in `docs/`.

## Outputs

- `outputs/network/`: nodes and edges of the network for Gephi (`vox_nodes_gephi.csv`,
  `vox_edges_gephi.csv`) and the Gephi project (`vox_network.gephi`).
- `outputs/figures/`: figures exported for the text.

## R packages

tidyverse, readxl, here, sf, rnaturalearth, mapSpain, cartogram, httr2, rvest, xml2,
countrycode, stargazer, broom, sandwich, lmtest, survival, haven, MASS, tidygraph, ggraph.

## Notes

- The scripts in `code/auxiliary/` were written for the earlier layout of the folder, with
  every file at the root: their paths have not been updated.
- The reorganisation of September 2026 is recorded in `archive/restructure_manifest.csv`;
  `python archive/undo_restructure.py` moves every file back to where it was.
- Working notes taken out of the scripts:
  - 01: *ARREGLAR FRANCIA, NORUEGA que faltan* (electoral systems map); *HACERLO FACETED, FALANGE* (family tree).
  - 02: *EXPLICAR COMO FUNCIONAN LO DE 02197706_TOTA y decir que el github copia la estructura del ministerio*;
    *CHEQUEAR SI SE PUEDE MEJORAR CODIGO DE DESCARGA DE DATOS GENERALS*;
    *VER SI SOLO CONCURRIO EN 646 municipios de 8116 en 2019*; *QUITAR ESTO PARA QUE YA ESTÉ ASI EN TODOS* (name normalisation).
  - 04: *LIMPIAR y arreglar CEN*.
