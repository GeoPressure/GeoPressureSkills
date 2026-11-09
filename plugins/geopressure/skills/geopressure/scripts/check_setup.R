# Check that this computer is ready for a GeoPressure analysis.
# Usage: Rscript check_setup.R
# Prints a report and changes nothing. Key values are never read or printed, only whether one exists.

report <- function(ok, msg) {
  cat(if (isTRUE(ok)) "[ok]   " else "[--]   ", msg, "\n", sep = "")
}
installed <- function(p) nzchar(system.file(package = p))
reachable <- function(u) {
  !inherits(try(curlGetHeaders(u, timeout = 10), silent = TRUE), "try-error")
}

# R
report(
  getRversion() >= "4.1.0",
  paste("R", getRversion(), "(GeoPressureR needs R >= 4.1.0)")
)

# Internet and the GeoPressure web services
online <- reachable("https://geopressure.org")
report(online, "internet (geopressure.org)")
report(
  online && reachable("https://glp.mgravey.com/GeoPressure/v2/timeseries/"),
  "GeoPressure API (needed for pressure maps)"
)

# GeoPressure packages: installed version against the latest release on GitHub
latest <- function(p) {
  d <- try(
    read.dcf(url(paste0(
      "https://raw.githubusercontent.com/GeoPressure/",
      p,
      "/main/DESCRIPTION"
    ))),
    silent = TRUE
  )
  if (inherits(d, "try-error")) NA_character_ else unname(d[1, "Version"])
}
for (p in c("GeoPressureR", "GeoLocatoR", "GeoMagR", "GeoPathSampleR")) {
  have <- if (installed(p)) as.character(packageVersion(p)) else NA_character_
  last <- if (online) latest(p) else NA_character_
  msg <- paste0(
    p,
    ": ",
    if (is.na(have)) "not installed" else have,
    if (!is.na(last)) paste0(" (latest release ", last, ")") else ""
  )
  ok <- !is.na(have) &&
    (is.na(last) || package_version(have) >= package_version(last))
  report(ok, msg)
}
cat("        Install or update: pak::pkg_install(\"GeoPressure/<package>\")\n")
cat(
  "        GeoMagR (magnetic data) and GeoPathSampleR (light-only data) are only needed for those analyses.\n"
)

# Optional packages used by some steps
optional <- c(
  ecmwfr = "Copernicus CDS key, wind download and ERA5 time series",
  ncdf4 = "reading wind files",
  Rarr = "ERA5 from cloud stores (Bioconductor: BiocManager::install(\"Rarr\"))",
  keyring = "storing keys (Zenodo, basemaps)"
)
for (p in names(optional)) {
  report(installed(p), paste0(p, ": ", optional[[p]]))
}

# Keys, checked for existence only
has_key <- function(service) {
  if (!installed("keyring")) {
    return(FALSE)
  }
  k <- try(keyring::key_list(service), silent = TRUE)
  !inherits(k, "try-error") && nrow(k) > 0
}
report(
  has_key("ecmwfr"),
  "Copernicus CDS key (for wind): set by the user with ecmwfr::wf_set_key(); accept the dataset licence on the CDS website too"
)
report(
  has_key("ZENODO_TOKEN") || nzchar(Sys.getenv("ZENODO_TOKEN")),
  "Zenodo token (only to check a draft data package)"
)
cat(
  "        Which accounts are needed and how to store keys: ",
  "https://geopressure.org/GeoPressureManual/resources.html#accounts-and-keys\n",
  sep = ""
)

# Memory
mem <- if (Sys.info()[["sysname"]] == "Darwin") {
  as.numeric(system("sysctl -n hw.memsize", intern = TRUE)) / 1024^3
} else if (file.exists("/proc/meminfo")) {
  as.numeric(sub(
    "\\D+(\\d+).*",
    "\\1",
    grep("MemTotal", readLines("/proc/meminfo"), value = TRUE)
  )) /
    1024^2
} else {
  NA
}
if (!is.na(mem)) {
  report(
    mem >= 8,
    sprintf("memory: %.0f GB (8-16 GB recommended for trajectory models)", mem)
  )
}
