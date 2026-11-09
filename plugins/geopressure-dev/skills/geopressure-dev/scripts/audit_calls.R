#!/usr/bin/env Rscript
# Audit R code in docs (Manual, Template, skills) against the installed
# GeoPressure packages. Install the release to audit against first: the
# versions used are printed.
#
# Usage: Rscript audit_calls.R <file or folder> ...
#
# Reads .R files, R chunks and inline code of .qmd, .Rmd and .md files, and
# config.yml files. Reports, with file and line: functions that no loaded
# package provides, internal or deprecated GeoPressure functions, unknown or
# deprecated arguments, and config.yml keys that GeoPressureR does not take.
# Unparsable code (placeholders, shell) is counted, not checked. Each hit is a
# lead to check, not a verdict.

gp <- c("GeoPressureR", "GeoLocatoR", "GeoMagR", "GeoPathSampleR")
gp <- gp[vapply(gp, requireNamespace, logical(1), quietly = TRUE)]
cat(paste(gp, vapply(gp, \(p) format(packageVersion(p)), "")), sep = "\n")
exports <- lapply(setNames(gp, gp), getNamespaceExports)
base_pkgs <- c("base", "stats", "utils", "graphics", "grDevices", "methods")
base_names <- unlist(lapply(base_pkgs, getNamespaceExports))
tidyverse <- c("dplyr", "ggplot2", "lubridate", "purrr", "readr", "stringr")
tidyverse <- c(tidyverse, "forcats", "tibble", "tidyr")
out <- new.env()
out$hits <- character()
out$skipped <- 0L
hit <- function(file, line, msg) {
  out$hits <- c(out$hits, sprintf("%s:%d: %s", file, line, msg))
}

# Deprecation as written with lifecycle in the GeoPressure packages
fn_deprecated <- function(f, fn) {
  b <- paste(deparse(body(f)), collapse = " ")
  grepl("deprecate_", b, fixed = TRUE) &&
    grepl(sprintf('"%s()"', fn), b, fixed = TRUE)
}
args_deprecated <- function(f) {
  dep <- c("lifecycle::deprecated()", "deprecated()")
  d <- vapply(formals(f), \(x) is.call(x) && deparse(x) %in% dep, logical(1))
  names(d)[d]
}

# Code pieces with their first line: whole .R files, fenced R chunks, and
# inline code spans outside chunks
pieces <- function(file, x) {
  if (grepl("\\.[rR]$", file)) {
    return(list(list(code = x, line = 1L)))
  }
  open <- grepl("^\\s*```+\\s*(\\{[rR]([ ,][^}]*)?\\}|[rR])\\s*$", x)
  close <- grepl("^\\s*```+\\s*$", x)
  fence <- grepl("^\\s*```", x)
  res <- list()
  inside <- logical(length(x))
  i <- 1L
  while (i <= length(x)) {
    if (fence[i]) {
      j <- i + which(close[-seq_len(i)])[1]
      if (is.na(j)) {
        j <- length(x) + 1L
      }
      inside[i:min(j, length(x))] <- TRUE
      if (open[i] && j > i + 1L) {
        res[[length(res) + 1L]] <- list(
          code = x[(i + 1L):(j - 1L)],
          line = i + 1L
        )
      }
      i <- j
    }
    i <- i + 1L
  }
  for (k in which(!inside & grepl("`[^`]*\\(", x))) {
    for (s in regmatches(x[k], gregexpr("`[^`]+`", x[k]))[[1]]) {
      s <- sub("^r ", "", gsub("`", "", s))
      if (grepl("\\(", s)) res[[length(res) + 1L]] <- list(code = s, line = k)
    }
  }
  res
}

check_code <- function(file, code, line0, known) {
  pd <- tryCatch(
    getParseData(parse(text = code, keep.source = TRUE)),
    error = \(e) NULL
  )
  if (is.null(pd)) {
    out$skipped <- out$skipped + 1L
    return(invisible())
  }
  for (r in which(pd$token == "SYMBOL_FUNCTION_CALL")) {
    fn <- pd$text[r]
    line <- line0 + pd$line1[r] - 1L
    sib <- pd[pd$parent == pd$parent[r], ]
    # Skip methods called with $ or @, and other packages called with ::
    if (any(sib$token %in% c("'$'", "'@'"))) {
      next
    }
    pkg <- sib$text[sib$token == "SYMBOL_PACKAGE"]
    if (length(pkg) && !pkg %in% gp) {
      next
    }
    owner <- if (length(pkg)) {
      pkg
    } else {
      gp[vapply(exports, \(e) fn %in% e, NA)][1]
    }
    if (is.na(owner) || !fn %in% exports[[owner]]) {
      int <- gp[vapply(
        gp,
        \(p) exists(fn, asNamespace(p), inherits = FALSE),
        NA
      )][1]
      if (!is.na(int)) {
        hit(file, line, sprintf("%s() is not exported by %s", fn, int))
      } else if (length(pkg) || (!is.null(known) && !fn %in% known)) {
        hit(
          file,
          line,
          sprintf(
            "%s%s() not found",
            if (length(pkg)) paste0(pkg, "::") else "",
            fn
          )
        )
      }
      next
    }
    f <- getExportedValue(owner, fn)
    if (!is.function(f)) {
      next
    }
    if (fn_deprecated(f, fn)) {
      hit(file, line, sprintf("%s() is deprecated in %s", fn, owner))
    }
    call_id <- pd$parent[pd$id == pd$parent[r]]
    args <- pd$text[pd$token == "SYMBOL_SUB" & pd$parent == call_id]
    fa <- names(formals(f))
    for (a in intersect(args, args_deprecated(f))) {
      hit(file, line, sprintf("%s(%s) is deprecated", fn, a))
    }
    if (!"..." %in% fa) {
      for (a in setdiff(args, fa)) {
        hit(file, line, sprintf("%s() has no argument %s", fn, a))
      }
    }
  }
}

# config.yml sections are GeoPressureR functions and their keys are arguments
# or param_create() defaults; geopressuretemplate keys are those its functions
# read
check_config <- function(file, x) {
  y <- suppressWarnings(yaml::read_yaml(file, eval.expr = FALSE))
  defaults <- GeoPressureR::param_create("x", default = TRUE)
  ns <- asNamespace("GeoPressureR")
  gpt <- grep("^geopressuretemplate", ls(ns), value = TRUE)
  b <- paste(unlist(lapply(gpt, \(n) deparse(get(n, ns)))), collapse = " ")
  gpt_keys <- regmatches(b, gregexpr("geopressuretemplate\\$[a-z_]+", b))[[1]]
  gpt_keys <- unique(sub(".*\\$", "", gpt_keys))
  for (id in names(y)) {
    for (sec in names(y[[id]])) {
      keys <- names(y[[id]][[sec]])
      line <- grep(sprintf("^\\s+%s:", sec), x)[1]
      if (sec == "geopressuretemplate") {
        allowed <- gpt_keys
      } else if (sec %in% exports$GeoPressureR) {
        f <- getExportedValue("GeoPressureR", sec)
        allowed <- c(names(formals(f)), names(defaults[[sec]]))
        for (a in intersect(keys, args_deprecated(f))) {
          hit(file, line, sprintf("%s: %s$%s is deprecated", id, sec, a))
        }
      } else {
        hit(
          file,
          line,
          sprintf("%s: %s is not a GeoPressureR function", id, sec)
        )
        next
      }
      for (a in setdiff(keys, allowed)) {
        hit(file, line, sprintf("%s: %s takes no %s", id, sec, a))
      }
    }
  }
}

pattern <- "\\.(R|r|qmd|Rmd|md)$|^config\\.yml$"
files <- unlist(lapply(commandArgs(trailingOnly = TRUE), \(p) {
  if (dir.exists(p)) {
    list.files(p, pattern, recursive = TRUE, full.names = TRUE)
  } else {
    p
  }
}))
skip_dirs <- "/(_freeze|docs|renv|node_modules|[^/]*_cache|[^/]*_files)/"
files <- files[!grepl(skip_dirs, files)]

for (file in files) {
  x <- readLines(file, warn = FALSE)
  if (basename(file) == "config.yml") {
    check_config(file, x)
    next
  }
  p <- pieces(file, x)
  # Names available to bare calls: base, attached or pkg:: packages, and
  # functions defined in the file
  txt <- paste(unlist(lapply(p, `[[`, "code")), collapse = "\n")
  lib <- regmatches(txt, gregexpr("(library|require)\\(\\w+", txt))[[1]]
  ns <- regmatches(txt, gregexpr("\\b[A-Za-z][A-Za-z0-9.]*::", txt))[[1]]
  used <- unique(c(sub(".*\\(", "", lib), sub("::", "", ns, fixed = TRUE)))
  if ("tidyverse" %in% used) {
    used <- c(used, tidyverse)
  }
  ok <- vapply(used, requireNamespace, logical(1), quietly = TRUE)
  if (!all(ok)) {
    cat(sprintf(
      "%s: unknown functions not checked, not installed: %s\n",
      file,
      toString(used[!ok])
    ))
  }
  def <- "[A-Za-z._][A-Za-z0-9._]*(?=\\s*(<-|=)\\s*(function|\\\\\\())"
  local <- regmatches(txt, gregexpr(def, txt, perl = TRUE))[[1]]
  known <- if (all(ok)) {
    c(base_names, unlist(lapply(used, getNamespaceExports)), local)
  }
  for (q in p) {
    check_code(file, q$code, q$line, known)
  }
}

cat(out$hits, sep = "\n")
cat(sprintf(
  "%d findings in %d files; %d code pieces not parsed.\n",
  length(out$hits),
  length(files),
  out$skipped
))
