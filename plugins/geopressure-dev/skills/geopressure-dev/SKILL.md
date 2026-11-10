---
name: geopressure-dev
license: MIT
description: Use when developing, documenting, testing or releasing any GeoPressure repository (GeoPressureR, GeoLocatoR, GeoMagR, GeoPathSampleR, GeoPressureTemplate, GeoPressureManual, GeoLocator-DP, GeoLocatorMaster, GeoPressureAPI, GeoLocator Explorer, the geopressure.org website, altitude-validation, the geopressure skills). Also use when a change in one repo must be carried to the others (a renamed function or argument, a changed default, a new release), when re-rendering the GeoPressureManual, and when checking that the repos, the Manual, the Template and the skills are consistent with each other and with the current release.
---

# GeoPressure development

For the maintainer and agents working on the GeoPressure code. Users of the tools have the
`geopressure` skill. The repos hold the facts (`DESCRIPTION`, `NEWS.md`, `.github/workflows/`,
README, `_quarto.yml`); this skill says where to look and in which order to work. Local clones
sit side by side, e.g. `~/Documents/GitHub/<repo>`.

## The shared standard

[`standards.md`](standards.md) holds the development rules shared by the R repos. Each R repo's
`AGENTS.md` starts with a plain copy of it between `<!-- BEGIN GeoPressure shared standard ...
-->` and `<!-- END GeoPressure shared standard -->`, followed by that repo's own rules, which take
precedence. Read the repo's `AGENTS.md` before editing it.

To change a shared rule, edit `standards.md`, then paste it between the markers of every
`AGENTS.md` in the same change set: GeoPressureR, GeoLocatoR, GeoMagR, GeoPathSampleR,
GeoLocatorMaster, GeoPressureManual, altitude-validation. Never edit the block in one repo only.
Check that the copies match, from the folder of this skill:

```sh
for r in GeoPressureR GeoLocatoR GeoMagR GeoPathSampleR GeoLocatorMaster GeoPressureManual altitude-validation; do
  sed -n '/BEGIN GeoPressure shared standard/,/END GeoPressure shared standard/p' ~/Documents/GitHub/$r/AGENTS.md |
    sed '1,3d;$d' | diff -q - standards.md > /dev/null || echo "$r differs"
done
```

A rule that only one repo needs goes in that repo's section, not in `standards.md`. Never put
development rules in `GeoPressureTemplate/AGENTS.md`: it is a user guide copied into every
user's project.

## Repo map

Check the branch and deploy flow in each repo's `.github/workflows/` before relying on this table.

| Repo | Role | Stack | Branches and deploy |
|---|---|---|---|
| GeoPressureR | Core package: tag, likelihood maps, graph, paths, altitude | R package | `dev` → PR → `main`; pkgdown site deployed from `main`; tag `vX.Y.Z` |
| GeoLocatoR | Build, validate, read and share GeoLocator Data Packages; create and read Template projects | R package | `dev` → `main`; `release-X.Y.Z` for patches |
| GeoMagR | Magnetometer calibration and magnetic likelihood maps | R package, Quarto vignettes | `main`, with feature or release branches merged by PR |
| GeoPathSampleR | Posterior path sampling from light-only maps | R package | `dev` → `main`; Zenodo archives releases from `CITATION.cff` |
| GeoPressureTemplate | Study project skeleton: `config.yml`, `analysis/`, example data | R project | `main`, update branches merged into it; tags `v1.x` |
| GeoPressureManual | Tutorial book | Quarto book | `main`; `publish.yml` deploys from `_freeze/` on push; tags `vX.Y` |
| GeoLocator-DP | Data standard: profile, table schemas, docs site | JSON Schema, Jekyll | `main`; tags `vX.Y`; schema validation and Jekyll workflows |
| GeoLocatorMaster | Builds the Master data package from the Zenodo community | Internal R package | `main`; Zenodo draft updated by hand |
| altitude-validation | Compendium of the altitude paper | R scripts, Quarto manuscript | `main`; tag per submission |
| GeoPressureSkills | Agent skills `geopressure` (users) and `geopressure-dev` | Markdown, R | `main` |

- **GeoPressureAPI**: Python Google Cloud Functions on Earth Engine (`map`, `timeseries`,
  `elevationPath`, `pressurePath`), deployed by hand per function (README, Deployment);
  `test-server.yml` calls the live endpoints every 12 h.
- **GeoLocatorExplorer**: Vue 3 + Vite web map with Python data scripts; deploys to `gh-pages` on
  push to `main`.
- **geopressure.github.io**: Vue 3 + Vite site of geopressure.org; deploys on push to `main`.
- **GeoCollabForm**: Vue 3 + Vuetify intake form and logger planner; deploys on push to `main`.
- **GeoPressureLabel**: Python notebooks; a neural network that predicts labels.

## Release order

Release upstream first; each step depends on the one before. Minimum versions are in each
`DESCRIPTION` (`GeoPressureR (>= ...)`).

1. **GeoLocator-DP** tag, when a schema changes.
2. **GeoPressureR**.
3. **GeoLocatoR** (raise the GeoPressureR minimum; refresh `inst/schemas/` against the DP tag
   with `data-raw/sync_schemas.R`), **GeoMagR**, **GeoPathSampleR**.
4. **GeoPressureTemplate**: `config.yml`, `analysis/` scripts, the version in `README.md`
   ("generated based on GeoPressureTemplate (vX)"), then a tag.
5. **GeoPressureManual**: install the released packages, re-render (see below), tag. Its tags
   follow GeoPressureR minor versions (`git tag` in the Manual).
6. **Skills**: run the audit below, then update `geopressure` and this skill.

## When something changes in GeoPressureR

A renamed or removed function or argument, or a changed default, reaches far. First search all
repos for the name:

```sh
cd ~/Documents/GitHub && grep -rn --include='*.R' --include='*.qmd' --include='*.Rmd' \
  --include='*.md' --include='*.yml' '<name>' GeoPressureR GeoLocatoR GeoMagR GeoPathSampleR \
  GeoPressureTemplate GeoPressureManual GeoLocatorMaster GeoPressureSkills
```

In GeoPressureR:
- Keep the old name working and warn: `lifecycle::deprecated()` and `lifecycle::deprecate_warn()`
  (see `R/graph_add_wind.R`). Add a NEWS bullet that names the replacement.
- `R/param_create.R`: the default `param` lists each argument of the functions the template runs
  as `formals(fn)$arg`, plus stored-only keys (e.g. `graph_add_wind$pressure_source`, which
  `geopressuretemplate_graph()` drops before calling the function).
- `R/print.param.R` prints those keys one by one. `R/geopressuretemplate_config.R`, `_tag.R`,
  `_graph.R` and `_pressurepath.R` pass `config$<fn>` to each function with `do.call()`.
- `inst/extdata/config.yml` (example project) and `data-raw/fixtures.R`, which rebuilds the
  stored 18LX outputs when their structure changes.
- `_pkgdown.yml` reference index (new or renamed export), `tests/testthat/`, and the Shiny apps
  in `inst/geopressureviz/` and `inst/trainset/`.
- If an API request changes: GeoPressureAPI (`R/*_api.R`, `R/geopressure_map_mismatch.R`).

Elsewhere:
- **Template**: `config.yml` (its keys are function arguments) and the `analysis/` scripts.
- **Manual**: the chapters that call it; re-render them.
- **GeoLocatoR**: `R/config_to_tibble.R` (a type for each config key), `R/params_to_tags.R`,
  `R/gldp_to_tag.R`, `R/gldp_fix_geopressurer.R` (param layout), `R/read_geopressuretemplate.R`.
- **GeoLocator-DP** schemas and GeoLocatoR `inst/schemas/`, when columns of paths, edges,
  pressurepaths, staps or twilights change.
- **GeoMagR, GeoPathSampleR**: their `GeoPressureR::` calls.
- **Skills**: `plugins/geopressure/skills/geopressure/SKILL.md` (function names, Manual chapters, code paths in the
  method table), its `scripts/check_setup.R` and `evals/`.

## Template conventions

- `AGENTS.md`, `README.md`, `DESCRIPTION` and `config.yml` are written for users and copied into
  their projects. Keep developer notes out of them.
- The Manual's pre-render downloads `analysis/1-label.qmd`, `analysis/2-twilight.qmd` and
  `config.yml` from the Template's `main`. Edit them in the Template, merge to `main`, then render
  the Manual.
- GeoLocatoR clones the Template in `create_geopressuretemplate()` and reads its files in
  `read_geopressuretemplate()` and `status_geopressuretemplate()`. Renaming a Template file or
  folder (`GeoPressureTemplate.Rproj`, `config.yml`, `data/raw-tag/`, `data/tag-label/`,
  `data/twilight-label/`, `data/interim/`) breaks them.
- The example tags (18LX, CB619) also live in the Manual's `data/` and, trimmed, in
  GeoPressureR `inst/extdata/`.

## Manual build

- `_quarto.yml` sets `freeze: auto`; `_freeze/` is committed. `publish.yml` renders from
  `_freeze/` without R and deploys on push to `main`, so execute every change locally first.
- `quarto render` runs `R/pre-render.ts`, which runs `R/getGeoPressureTemplateQmd.R` (skipped
  when `CI` is set) to copy the three Template files.
- A project render re-executes only chapters whose source changed. After a package release,
  render each affected chapter on its own (`quarto render <chapter>.qmd` always executes) and
  delete its `<chapter>_cache/` first: knitr caches do not notice a package update.
- Commit `_freeze/` with the chapters. Keys and accounts needed to render are in
  `resources.qmd` ("Accounts and keys").

## Audit: do the docs match the release?

Check that the Manual, the Template and both skills use only functions and arguments of the
current release.

1. Install the released packages (`pak::pak("GeoPressure/GeoPressureR@vX.Y.Z")`, same for
   GeoLocatoR, GeoMagR, GeoPathSampleR). To audit against `dev`, install the `dev` branch.
2. Run, from `~/Documents/GitHub`:
   `Rscript GeoPressureSkills/plugins/geopressure-dev/skills/geopressure-dev/scripts/audit_calls.R GeoPressureManual GeoPressureTemplate GeoPressureSkills/plugins`.
   It parses R code, R chunks and inline code, and `config.yml` files, and lists functions that
   are missing, internal or deprecated, unknown or deprecated arguments, and config keys no
   function takes. It cannot check arguments of functions that take `...`.
3. Check each hit against NEWS. `evals/*/files/` hold old code on purpose. Then check what the script cannot: links to reference pages
   (`geopressure.org/<package>/reference/<fn>.html`), the chapter list in the `geopressure` skill
   against `_quarto.yml`, and code paths named in its method table.
4. The real test is running the code: render the affected Manual chapters, and run the Template
   on its example tags (`geopressuretemplate("18LX")` from the Template root).
