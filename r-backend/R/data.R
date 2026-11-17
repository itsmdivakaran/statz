# Session ----------------------------------------------------------------------

#' A session holds datasets, the reproducible code log and the plot directory.
sn_session_new <- function(work_dir = tempfile("statnext-")) {
  dir.create(file.path(work_dir, "plots"), recursive = TRUE, showWarnings = FALSE)
  sess <- new.env(parent = emptyenv())
  sess$work_dir <- normalizePath(work_dir)
  sess$datasets <- list()
  sess$log <- list()      # list(list(kind, title, code)) in execution order
  sess$plot_seq <- 0L
  sess$plots <- list()
  sess$analyses <- list()  # instance id -> list(title, code); latest run only
  sess$modules <- list()
  sess
}

sn_log <- function(sess, kind, title, code) {
  sess$log[[length(sess$log) + 1L]] <- list(kind = kind, title = title, code = code)
  invisible()
}

sn_dataset <- function(sess, id = "data") {
  ds <- sess$datasets[[id]]
  if (is.null(ds)) sn_abort(paste0("No dataset '", id, "' is loaded."), SN_ERR$invalid_params,
                            hint = "Open a data file first.")
  ds
}

# Import -----------------------------------------------------------------------

SN_FORMATS <- c(csv = "csv", tsv = "tsv", txt = "tsv", xlsx = "excel", xls = "excel",
                sav = "spss", zsav = "spss", sas7bdat = "sas", xpt = "xpt", dta = "stata",
                parquet = "parquet", rds = "rds")

#' Generate the import code for a file. The code assigns `raw`.
sn_import_code <- function(path, format) {
  p <- sn_lit(path)
  switch(format,
    csv = paste0("raw <- utils::read.csv(", p, ", check.names = FALSE, na.strings = c(\"\", \"NA\"))"),
    tsv = paste0("raw <- utils::read.delim(", p, ", check.names = FALSE, na.strings = c(\"\", \"NA\"))"),
    excel = paste0("raw <- readxl::read_excel(", p, ")"),
    spss = paste0("raw <- haven::read_sav(", p, ", user_na = FALSE)"),
    sas = paste0("raw <- haven::read_sas(", p, ")"),
    xpt = paste0("raw <- haven::read_xpt(", p, ")"),
    stata = paste0("raw <- haven::read_dta(", p, ")"),
    parquet = paste0("raw <- arrow::read_parquet(", p, ")"),
    rds = paste0("raw <- readRDS(", p, ")"),
    sn_abort(paste0("Unsupported format: ", format), SN_ERR$invalid_params)
  )
}

SN_FORMAT_PKG <- c(excel = "readxl", spss = "haven", sas = "haven", xpt = "haven",
                   stata = "haven", parquet = "arrow")

sn_import <- function(sess, path, format = NULL, id = "data") {
  if (!file.exists(path)) sn_abort(paste0("File not found: ", path), SN_ERR$invalid_params)
  format <- format %||% unname(SN_FORMATS[tolower(tools::file_ext(path))])
  if (is.na(format)) sn_abort("Unknown file type.", SN_ERR$invalid_params)
  pkg <- SN_FORMAT_PKG[format]
  if (!is.na(pkg) && !requireNamespace(pkg, quietly = TRUE))
    sn_abort(paste0("Package '", pkg, "' is needed to read this file."), SN_ERR$missing_package,
             data = list(packages = list(unname(pkg))))
  code <- sn_import_code(normalizePath(path, winslash = "/"), format)
  labelled <- format %in% c("spss", "sas", "xpt", "stata")
  code <- sn_code(code, paste0(id, " <- ", if (labelled) sn_strip_code("raw") else "as.data.frame(raw)"))
  env <- new.env(parent = globalenv())
  eval(parse(text = code), envir = env)
  meta <- sn_infer_meta(env$raw)
  data <- get(id, envir = env)
  sn_set_dataset(sess, id, data, meta, source = basename(path))
  sn_log(sess, "import", paste("Import", basename(path)), code)
  sn_data_info(sess, id)
}

#' Load a bundled example dataset (datasets/<name>.csv + <name>.meta.json).
sn_load_example <- function(sess, name, datasets_dir, id = "data") {
  csv <- file.path(datasets_dir, paste0(name, ".csv"))
  if (!file.exists(csv)) sn_abort(paste0("No example dataset '", name, "'."), SN_ERR$invalid_params)
  info <- sn_import(sess, csv, "csv", id)
  meta_file <- file.path(datasets_dir, paste0(name, ".meta.json"))
  if (file.exists(meta_file)) {
    m <- jsonlite::fromJSON(meta_file, simplifyVector = FALSE)
    for (v in names(m$variables)) {
      cur <- sess$datasets[[id]]$meta$variables[[v]]
      if (is.null(cur)) next
      for (f in names(m$variables[[v]])) cur[[f]] <- m$variables[[v]][[f]]
      sess$datasets[[id]]$meta$variables[[v]] <- cur
    }
  }
  sn_data_info(sess, id)
}

sn_strip_code <- function(obj) {
  paste0("as.data.frame(lapply(", obj, ", function(x) { attributes(x)[c(\"labels\", \"label\", ",
         "\"format.spss\", \"format.sas\", \"format.stata\", \"display_width\", \"na_values\")] <- NULL; ",
         "if (inherits(x, \"haven_labelled\")) x <- unclass(x); x }), check.names = FALSE)")
}

sn_set_dataset <- function(sess, id, data, meta, source = NULL) {
  sess$datasets[[id]] <- list(id = id, data = data, meta = meta, source = source)
}

# Metadata ---------------------------------------------------------------------

sn_infer_meta <- function(df) {
  vars <- lapply(names(df), function(nm) {
    x <- df[[nm]]
    labels <- attr(x, "labels", exact = TRUE)
    vl <- if (!is.null(labels))
      unname(Map(function(v, l) list(value = unname(v), label = l), unname(labels), names(labels)))
    else list()
    measure <- if (is.ordered(x)) "ordinal"
      else if (is.factor(x) || is.character(x) || is.logical(x) || length(vl) > 0) "nominal"
      else if (inherits(x, c("Date", "POSIXt"))) "date"
      else if (is.numeric(x)) "continuous"
      else "nominal"
    list(name = nm, label = attr(x, "label", exact = TRUE) %||% "",
         type = sn_type(x), measure = measure, value_labels = vl, missing = list())
  })
  list(variables = stats::setNames(vars, names(df)))
}

sn_type <- function(x) {
  if (inherits(x, "Date")) "date" else if (inherits(x, "POSIXt")) "datetime"
  else if (is.factor(x)) "factor" else if (is.logical(x)) "logical"
  else if (is.integer(x)) "integer" else if (is.numeric(x)) "double" else "string"
}

sn_data_info <- function(sess, id = "data") {
  ds <- sn_dataset(sess, id)
  list(id = id, source = ds$source, nrow = nrow(ds$data), ncol = ncol(ds$data),
       variables = unname(ds$meta$variables))
}

# Grid access ------------------------------------------------------------------

#' Rows window for the virtualised grid, column-major to keep payloads small.
sn_data_slice <- function(sess, id = "data", offset = 0L, limit = 200L) {
  ds <- sn_dataset(sess, id)
  n <- nrow(ds$data)
  offset <- max(0L, as.integer(offset))
  idx <- seq_len(min(as.integer(limit), max(0L, n - offset))) + offset
  cols <- lapply(ds$data[idx, , drop = FALSE], function(x) {
    x <- if (is.factor(x)) as.character(x) else if (inherits(x, c("Date", "POSIXt"))) format(x) else x
    I(x)  # keep length-1 columns as JSON arrays
  })
  list(id = id, offset = offset, nrow = n, columns = cols)
}

# Edits ------------------------------------------------------------------------
# Every data edit is applied by evaluating generated code, which is also logged,
# so exported scripts reproduce the edit.

sn_data_patch <- function(sess, id = "data", ops) {
  ds <- sn_dataset(sess, id)
  code <- character()
  touched <- character(); labels <- list(); structural <- FALSE; title <- "Edit data"
  for (op in ops) {
    switch(op$op,
      set_cell = {
        var <- op$column
        if (is.null(ds$meta$variables[[var]])) sn_abort(paste0("Unknown variable: ", var), SN_ERR$invalid_params)
        code <- c(code, paste0(id, "[", as.integer(op$row) + 1L, ", ", sn_lit(var), "] <- ",
                               sn_lit(sn_coerce(op$value, ds$data[[var]]))))
      },
      rename = {
        code <- c(code, paste0("names(", id, ")[names(", id, ") == ", sn_lit(op$from), "] <- ",
                               sn_lit(op$to)))
        m <- ds$meta$variables[[op$from]]
        m$name <- op$to
        ds$meta$variables[[op$from]] <- NULL
        ds$meta$variables[[op$to]] <- m
      },
      set_meta = {
        allowed <- c("label", "measure", "value_labels", "missing")
        if (!op$field %in% allowed) sn_abort(paste0("Cannot set ", op$field), SN_ERR$invalid_params)
        ds$meta$variables[[op$column]][[op$field]] <- op$value
        if (op$field == "missing" && length(op$value) > 0) {
          ref <- sn_ref(id, op$column)
          code <- c(code, paste0(ref, "[", ref, " %in% ", sn_lit(unlist(op$value)), "] <- NA"))
        }
      },
      compute = {
        name <- sn_new_name(op$name)
        code <- c(code, paste0(sn_ref(id, name), " <- with(", id, ", ", sn_expr(op$expr), ")"))
        touched <- c(touched, name); structural <- TRUE; title <- paste("Compute", name)
        if (nzchar(op$label %||% "")) labels[[name]] <- op$label
      },
      recode = {
        src <- op$column
        if (is.null(ds$meta$variables[[src]])) sn_abort(paste0("Unknown variable: ", src), SN_ERR$invalid_params)
        into <- if (nzchar(op$into %||% "")) sn_new_name(op$into) else src
        rules <- Filter(function(r) length(unlist(r$from)) > 0, op$rules)
        if (!length(rules)) sn_abort("Add at least one recode rule.", SN_ERR$invalid_params)
        code <- c(code,
          paste0("old <- as.character(", sn_ref(id, src), ")"),
          paste0("new <- ", if (identical(op$unmatched, "missing")) "rep(NA_character_, length(old))" else "old"),
          vapply(rules, function(r) paste0("new[old %in% ", sn_lit(as.character(unlist(r$from))), "] <- ",
                                           if (is.null(r$to) || !nzchar(r$to)) "NA" else sn_lit(as.character(r$to))), ""),
          paste0(sn_ref(id, into), " <- type.convert(new, as.is = TRUE)"))
        touched <- c(touched, into); structural <- TRUE; title <- paste("Recode", src)
        if (nzchar(op$label %||% "")) labels[[into]] <- op$label
      },
      filter = {
        code <- c(code, paste0(id, " <- ", id, "[which(with(", id, ", ", sn_expr(op$expr), ")), , drop = FALSE]"),
                  paste0("rownames(", id, ") <- NULL"))
        structural <- TRUE; title <- "Filter rows"
      },
      sn_abort(paste0("Unknown edit: ", op$op), SN_ERR$invalid_params)
    )
  }
  if (length(code)) {
    env <- new.env(parent = globalenv())
    assign(id, ds$data, envir = env)
    tryCatch(eval(parse(text = code), envir = env), error = function(e) {
      if (inherits(e, "sn_error")) stop(e)
      sn_abort(paste0("R could not run this: ", conditionMessage(e)), SN_ERR$invalid_params)
    })
    new <- get(id, envir = env)
    if (structural) {
      if (!nrow(new)) sn_abort("No rows match this filter.", SN_ERR$invalid_params)
      bad <- touched[!vapply(new[touched], is.atomic, TRUE)]
      if (length(bad)) sn_abort("The expression must give one value per row.", SN_ERR$invalid_params)
      # Snapshot for undo (see sn_data_undo); keep the last 10.
      snap <- c(sess$snapshots[[id]], list(list(data = sess$datasets[[id]]$data, meta = sess$datasets[[id]]$meta, log = length(sess$log))))
      sess$snapshots[[id]] <- utils::tail(snap, 10L)
    }
    ds$data <- new
    sn_log(sess, "edit", title, paste(code, collapse = "\n"))
  }
  # New and recoded variables get fresh metadata; labels are kept.
  if (length(touched)) {
    inf <- sn_infer_meta(ds$data[unique(touched)])$variables
    for (v in names(inf)) {
      m <- inf[[v]]
      m$label <- labels[[v]] %||% ds$meta$variables[[v]]$label %||% ""
      ds$meta$variables[[v]] <- m
    }
  }
  # Keep meta order in sync with columns.
  ds$meta$variables <- ds$meta$variables[names(ds$data)]
  sess$datasets[[id]] <- ds
  sn_data_info(sess, id)
}

#' Undo the last compute, recode or filter (and any cell edits made after it).
sn_data_undo <- function(sess, id = "data") {
  snaps <- sess$snapshots[[id]]
  if (!length(snaps)) sn_abort("Nothing to undo.", SN_ERR$invalid_params)
  last <- snaps[[length(snaps)]]
  ds <- sn_dataset(sess, id)
  ds$data <- last$data; ds$meta <- last$meta
  sess$datasets[[id]] <- ds
  sess$log <- sess$log[seq_len(last$log)]
  sess$snapshots[[id]] <- snaps[-length(snaps)]
  sn_data_info(sess, id)
}

#' Distinct values of a variable with counts, for the recode dialog.
sn_data_values <- function(sess, id = "data", column, limit = 200L) {
  ds <- sn_dataset(sess, id)
  if (is.null(ds$meta$variables[[column]])) sn_abort(paste0("Unknown variable: ", column), SN_ERR$invalid_params)
  x <- ds$data[[column]]
  tb <- table(as.character(x))
  vals <- names(tb)
  if (is.numeric(x)) vals <- vals[order(as.numeric(vals))]
  vl <- ds$meta$variables[[column]]$value_labels
  lab <- stats::setNames(vapply(vl, function(l) as.character(l$label), ""), vapply(vl, function(l) as.character(l$value), ""))
  keep <- utils::head(vals, limit)
  list(column = column, distinct = length(vals), missing = sum(is.na(x)), numeric = is.numeric(x),
       values = lapply(keep, function(v) list(value = v, n = as.integer(tb[[v]]), label = if (v %in% names(lab)) lab[[v]])))
}

sn_new_name <- function(name) {
  name <- trimws(name %||% "")
  if (!nzchar(name) || make.names(name) != name)
    sn_abort("Variable names must start with a letter and use only letters, digits, '.' and '_'.", SN_ERR$invalid_params)
  name
}

#' A single R expression typed by the user, checked to parse.
sn_expr <- function(expr) {
  expr <- trimws(expr %||% "")
  ok <- tryCatch(length(parse(text = expr, keep.source = FALSE)) == 1L, error = function(e) FALSE)
  if (!ok) sn_abort("This is not a complete R expression.", SN_ERR$invalid_params,
                    hint = "Examples: weight / height^2, log(income), age >= 18 & group == \"A\"")
  expr
}

sn_coerce <- function(value, like) {
  if (is.null(value) || identical(value, "")) return(NA)
  if (is.numeric(like)) {
    v <- suppressWarnings(as.numeric(value))
    if (is.na(v)) sn_abort(paste0("'", value, "' is not a number."), SN_ERR$invalid_params)
    return(v)
  }
  if (is.logical(like)) return(as.logical(value))
  as.character(value)
}

# Project persistence ----------------------------------------------------------
# The shell zips this file with the UI state into a .statnext project.

sn_data_save <- function(sess, path) {
  saveRDS(list(version = 1L, datasets = sess$datasets, log = sess$log, analyses = sess$analyses),
          path, compress = "xz")
  list(path = normalizePath(path, winslash = "/"))
}

sn_data_load <- function(sess, path) {
  st <- readRDS(path)
  if (!identical(st$version, 1L)) sn_abort("Unsupported project file version.", SN_ERR$invalid_params)
  sess$datasets <- st$datasets
  sess$log <- st$log
  sess$analyses <- st$analyses
  lapply(names(sess$datasets), function(id) sn_data_info(sess, id))
}
