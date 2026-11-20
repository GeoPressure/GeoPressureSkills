#!/usr/bin/env bash
# Copy the GeoPressureR example project (config.yml and data/) into the working folder.
set -eu
Rscript -e 'd <- system.file("extdata", package = "GeoPressureR"); file.copy(file.path(d, c("config.yml", "data")), ".", recursive = TRUE)'
