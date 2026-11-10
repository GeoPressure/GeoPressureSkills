---
name: geopressure
license: MIT
description: Use for anything about tracking birds or other animals with multi-sensor geolocators (pressure, light, acceleration, temperature or magnetic loggers) and the GeoPressure tools - GeoPressureR, GeoPressureTemplate, GeoPressureManual, GeoPressureAPI, GeoLocatoR and GeoLocator Data Packages, GeoMagR, GeoPathSampleR, GeoLocator Explorer. Covers running an analysis from raw logger files (SOI .pressure/.glf/.acceleration, Migrate Technology .deg/.lux, Lund, PresTag, BAS, CSV), labelling flights, likelihood maps, trajectories with wind, altitude, reading and plotting results, error messages, updating old scripts, explaining the method and papers, citing, planning a tracking study, and publishing or reusing tracks on Zenodo. Use it even when no package is named, e.g. "here are my logger files, where did my bird go?"
---

# GeoPressure

GeoPressure is a set of open-source tools to reconstruct where and when animals, mostly small
migratory birds, moved, from geolocators that record atmospheric pressure and often light,
acceleration, temperature or the magnetic field. All code is at https://github.com/GeoPressure and
the entry page is https://geopressure.org.

This skill does not hold the answers. The tools change often, so the facts live in the packages,
the Manual, the Template and the papers, and this skill tells you where each kind of answer lives
and how to work with a GeoPressure user. Read the source it points to before you answer.

## The tools

| Tool | What it is for | Docs |
|---|---|---|
| GeoPressureR | R package: from raw tag data to stationary periods, likelihood maps (pressure, light), a trajectory model (with wind), trajectories and flight altitude | https://geopressure.org/GeoPressureR/ |
| GeoPressureTemplate | Folder structure and scripts for a study: one `config.yml`, raw data, label files, analysis scripts | https://github.com/GeoPressure/GeoPressureTemplate |
| GeoPressureManual | Tutorial book explaining every step with worked examples | https://geopressure.org/GeoPressureManual/ |
| GeoPressureAPI | Web service that GeoPressureR calls to compare tag pressure with ERA5 on Google Earth Engine | https://github.com/GeoPressure/GeoPressureAPI |
| GeoLocator-DP | Data standard (Frictionless data package) for geolocator data and GeoPressureR results | https://geopressure.org/GeoLocator-DP/ |
| GeoLocatoR | R package to build, validate, read and share GeoLocator Data Packages | https://geopressure.org/GeoLocatoR/ |
| GeoLocator Explorer | Web map of published tracks | https://geopressure.org/GeoLocatorExplorer/ |
| GeoMagR | R package: magnetometer calibration and magnetic likelihood maps | https://geopressure.org/GeoMagR/ |
| GeoPathSampleR | R package: sample paths from light-only, day-by-day likelihood maps | https://geopressure.org/GeoPathSampleR/ |
| Forum | Questions, announcements, service incidents | https://geopressure.discourse.group |
| GeoCollab | Collaboration call and logger planner of the Swiss Ornithological Institute | https://geopressure.org/GeoCollabForm/ |

## Where each kind of answer lives

| To answer... | Go to | How to read it |
|---|---|---|
| What a function does, its arguments and defaults | Its reference page, for the installed version | `?fn` in R, or `https://geopressure.org/<package>/reference/<fn>.md` (all pages: `https://geopressure.org/<package>/llms.txt`), which documents the latest release |
| Exactly how it behaves: edge cases, error messages | The source code | `https://github.com/GeoPressure/<repo>` at tag `v<installed version>`, `main` (latest release) or `dev` (development version) |
| How to do a step well, with examples | The Manual | Chapters below; rendered page, or the source at `https://raw.githubusercontent.com/GeoPressure/GeoPressureManual/main/<chapter>.qmd` |
| How a study project is organised and run | The Template | Its `config.yml`, `analysis/` scripts and `AGENTS.md` |
| What changed between versions, old function names | Each package's NEWS | `https://geopressure.org/<package>/news/index.md`, or `news(package = "GeoPressureR")` |
| The method, its assumptions and limits | The papers | Table below; `citation("<package>")` gives the current citation |
| Format of a data package | GeoLocator-DP | Its site: tables, fields, vocabularies, changelog |
| Tracks from other studies | Zenodo community `geolocator-dp`, the Master GeoLocator Data Package (concept DOI 10.5281/zenodo.18187092, always the latest release), GeoLocator Explorer | See "Reusing published tracks" below; Manual chapters `geolocator-read` and `geolocator-master` |
| ERA5 data, API behaviour, limits, outages | GeoPressureAPI README and code, forum announcements | The README's status badge shows whether the service is up |
| Known problems and their fixes | Forum and GitHub issues | https://geopressure.discourse.group; `https://github.com/search?q=org:GeoPressure+<words>&type=issues` |
| Whether a species or study suits the method, logger settings | Manual `index` (data requirements), GeoCollab planner, papers, forum | |

### Manual chapters

`https://geopressure.org/GeoPressureManual/<chapter>.html`. The Manual repo's `_quarto.yml` has
the current list.

- `index`: what the method does, prerequisites, data requirements
- Basic tutorial: `tag-object` (read data, crop, label), `pressure-map` (likelihood maps, `sd`),
  `trajectory` (graph, movement model, most likely path, marginal map, simulations)
- Advanced tutorial: `light-map` (twilights, calibration), `trajectory-with-wind` (ERA5 wind,
  airspeed, bird flight model)
- Labelling tools: `pressurepath` (ERA5 along a path, altitude), `geopressureviz`, `geolightviz`,
  `labelling-tracks` (labelling rules and checks)
- GeoPressureTemplate: `geopressuretemplate-intro`, `geopressuretemplate-label`,
  `geopressuretemplate-twilight`, `geopressuretemplate-workflow`
- GeoLocator DP: `geolocator-create` (publish your data), `geolocator-read` (reuse a study),
  `geolocator-master` (all published studies)
- Appendices: `resources` (papers, talks, basemap keys), `probability-aggregation`

### Method: papers, chapters and code

| Part of the method | Paper | Manual | Code |
|---|---|---|---|
| Pressure likelihood maps | Nussbaumer et al. 2023, Methods Ecol Evol, https://doi.org/10.1111/2041-210X.14043 | `pressure-map` | GeoPressureR `R/geopressure_map*.R`; GeoPressureAPI `map/` |
| Trajectory model (hidden Markov model on a graph), wind, movement | Nussbaumer et al. 2023, Methods Ecol Evol, https://doi.org/10.1111/2041-210X.14082 | `trajectory`, `trajectory-with-wind` | `R/graph_*.R`, `R/tag_download_wind.R`, `R/bird_create.R` |
| What pressure loggers can and cannot do, in practice | Rhyne et al. 2024, Ornithology, https://doi.org/10.1093/ornithology/ukae010 | `index` | |
| Light | | `light-map` | `R/twilight_create.R`, `R/geolight_*.R` |
| Magnetic field | Nussbaumer et al. 2026, Methods Ecol Evol, https://doi.org/10.1111/2041-210x.70355 | | GeoMagR |
| Flight altitude from pressure | Manuscript in review; code at https://github.com/GeoPressure/altitude-validation | `pressurepath` | `R/pressurepath_create.R`; GeoPressureAPI `altitude.py` |
| Paths from light-only data | Manuscript in review; see the GeoPathSampleR site | | GeoPathSampleR |
| Combining likelihoods from several sensors | | `probability-aggregation` | |

## Working rules

- **Ground every answer in a source and link it**: the reference page, chapter, file, paper or
  issue. Say clearly when something is your own reasoning. Users build analyses and papers on
  these answers, and the method has subtle parts that are easy to get plausibly wrong.
- **Find the user's versions first** (`packageVersion("GeoPressureR")`, and GeoLocatoR, GeoMagR or
  GeoPathSampleR if used). Functions and arguments get renamed, and some releases change results.
  Old scripts, tutorials found online and your own memory may use names that no longer exist, so
  check every function and argument against the reference before using it. Answer for the
  installed version, and say when updating would help.
- **When the docs and the code disagree, the code is what runs.** Tell the user, and suggest
  reporting the mismatch.
- **Run things when you can, and look at the result** (summaries, plots) before saying it worked.
  If you cannot run R (no R, or no internet), write the script for the user to run, say that it
  has not been run, and ask for the output.
- **The judgement calls belong to the user**: which points are flights or outliers, `sd`, the map
  extent, which results to trust. Prepare, check and explain, propose a choice with your reasons,
  and let them decide. The interactive apps (`trainset()`, `geopressureviz()`,
  `geolightviz()`) open in the user's browser: ask the user to use them and tell them what to
  look for.
- **Some steps are slow.** Pressure maps take minutes; wind downloads from the Copernicus Climate
  Data Store can take hours. Run them in the background where possible and say what is happening.
- **Tag data are often unpublished or under embargo.** Do not send them anywhere, beyond what the
  GeoPressureR functions themselves send to the GeoPressure API, without the user's agreement.
- **Accounts and keys are the user's.** Never ask for passwords or tokens, and never put one in a
  script or file. Which accounts are needed for what, and how the user stores each key in their
  system keyring, is in the Manual:
  https://geopressure.org/GeoPressureManual/resources.html#accounts-and-keys. Send the user there
  and let them run the commands themselves.
- **If no source answers the question, say so.** Suggest asking on the forum or opening an issue
  in the relevant repo, so the gap gets fixed in the docs.

## Common jobs

These are the jobs that need steps in a set order. For anything else, use the map above and the
working rules.

### "Here are my files, do the analysis"

The step-by-step procedure lives in the GeoPressureTemplate, so it stays in step with the tools.

1. Check the computer: run `Rscript scripts/check_setup.R` (in this skill's folder). It reports R
   and package versions, missing packages, keys and whether the GeoPressure API can be reached,
   without changing anything. Installation instructions are in each package's README.
2. Look at the files. `tag_create()` recognises the logger brand from the file names; its
   reference page lists the formats. Other formats can be read from CSV files or data frames
   (`manufacturer = "tabular"`, pressure in hPa).
3. Ask only what the data cannot tell you: species, tag ids, where and when each bird was equipped
   and recaptured, the rough area it may have travelled to, and anything unusual about the logger
   (for example, its clock set to local time instead of UTC).
4. Create a project with `GeoLocatoR::create_geopressuretemplate("<path>")`, or with "Use this
   template" on the GeoPressureTemplate GitHub page. Copy each tag's raw files, unchanged, to
   `data/raw-tag/<id>/`.
5. Open the project's `AGENTS.md` and follow it. If the project has none (created from an older
   Template), follow the Manual's GeoPressureTemplate chapters and the `analysis/` scripts in order.

### "How do I...?" or "Why does this fail?"

Check the installed version, then the reference page and source, the relevant Manual chapter, and
NEWS if it looks like a renamed function or changed behaviour. For errors from the GeoPressure API
or the Copernicus CDS, also search the forum and the GeoPressureAPI issues. Reproduce the error
when you can before proposing a fix.

### Updating old code

Read each package's NEWS between the user's version and the current one. It lists renamed and
removed functions and arguments, and the releases that change results, which mean recomputing.
Deprecated names also raise a warning that names the replacement. Update the code, run it, and
tell the user which results need recomputing.

### Explaining the method or writing a paper

Use the method table: read the relevant paper section and Manual chapter, and the code when the
detail matters (an exact formula or default). For a methods section, take the settings actually
used from the results (`tag$param`, or `config.yml` in a Template project) and the package versions
(stored in `param$GeoPressureR_version`), cite each package with `citation()`, and acknowledge the
ERA5 data as the Copernicus licence asks.

### Sharing your data

Follow the Manual chapter `geolocator-create` and the Template's `analysis/20-datapackage.R`.
Publishing on Zenodo needs the user's own account: you build and validate the package, and the
user uploads and submits it.

### Reusing published tracks and the Master package

Published GeoLocator Data Packages are Zenodo records of the `geolocator-dp` community. The Master
GeoLocator Data Package compiles the open ones into versioned releases. It is not in the community
search: its concept DOI, 10.5281/zenodo.18187092, resolves to the latest release. The how-to is in
the Manual chapters `geolocator-read` and `geolocator-master`.

- **Choose the source.** To look at tracks: GeoLocator Explorer. For one study, or one bird to
  re-analyse: its own package. Across studies: the Master, not a loop over community records.
  Before saying what exists, check the Master's `datapackages` catalogue (embargoed packages
  included) and the community for newer packages, and say that only data shared as packages are
  covered.
- **Fetch only what the question needs.** `read_zenodo()` downloads every table, including large
  ones (the Master's `pressurepaths`, a study's raw `measurements`). Each table is a separate file
  of the version record, listed in its `datapackage.json`. Download the descriptor and the tables
  you need, and remove the other resources from the descriptor before `read_gldp()`, which reads
  every file it lists. Keep the version DOI and the GeoLocatoR version with the results: reading
  upgrades older packages and can change values (GeoLocatoR NEWS).
- **Join on the keys.** Join on `tag_id` with `stap_id` (`stap_s`, `stap_t` in `edges`), plus
  `type` and `j` between `paths`, `edges` and `pressurepaths`. Count birds in `paths`, not `tags`.
  Equipment and retrieval cut the first and last stationary periods. Edges with `n > 1` span
  unlocated stops. A fractional `stap_id` in `pressurepaths` is a flight sample: never round it to
  join. Drop `discard` labels; altitude is above sea level. Across studies, weight each bird
  equally.
- **Pick the trajectory type.** Use `most_likely` for positions and `simulation` for uncertainty:
  sum distances or durations per `tag_id` and `j`, then summarise across `j`. Count a track's
  simulations before quoting an interval, and give a range if there are few. For a region, give
  the share of simulations in it.
- **Embargo and licence.** Embargoed data are not in the Master or the public files: the user asks
  the authors, or opens a Zenodo share link in Explorer. Depending on the GeoLocatoR version
  (see `?read_zenodo`), a Zenodo token stored in the environment or keyring may be used for every
  record, so on a data owner's computer it can read embargoed files: say so, and keep such data
  out of anything shared unless the user agrees. Licences are per
  package (`datapackages$licenses`); read each record's description for requests to data users.
- **Cite and contact.** Cite the Master release and each source package of the birds used (join
  `datapackages` on `tags(master)$datapackage_id`). When a result rests on a few studies, suggest
  contacting their authors.
- **Not in the Master.** Raw measurements and many tags' parameters: take them from the source
  package named by `datapackage_id`, the version that was compiled; its concept DOI shows whether a
  newer one exists. A `tag_id` shared by two sources gets a suffix in the Master.
- **Re-analyse.** On the source package, `gldp_to_tag(pkg, tag_id)` gives a GeoPressureR `tag`, and
  `create_geopressuretemplate(path, pkg = pkg)` gives a project for the whole study. Read NEWS from
  `param$GeoPressureR_version` onwards to see which results have changed.
