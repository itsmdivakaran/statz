# Module registry --------------------------------------------------------------
# A module is a folder with spec.json + an R file defining `codegen_<id>()`.
# Built-ins and plugins share this format.

sn_load_modules <- function(sess, dirs) {
  for (dir in dirs) {
    for (sub in list.dirs(dir, recursive = FALSE)) {
      spec_file <- file.path(sub, "spec.json")
      if (!file.exists(spec_file)) next
      mod <- tryCatch(sn_load_module(sub), error = function(e) {
        message("statnextr: skipping module ", basename(sub), ": ", conditionMessage(e))
        NULL
      })
      if (!is.null(mod)) sess$modules[[mod$spec$id]] <- mod
    }
  }
  invisible(names(sess$modules))
}

sn_load_module <- function(dir) {
  spec <- jsonlite::fromJSON(file.path(dir, "spec.json"), simplifyVector = FALSE)
  env <- new.env(parent = asNamespace("statnextr"))
  exprs <- parse(file.path(dir, spec$r$file), keep.source = FALSE, encoding = "UTF-8")
  for (e in exprs) eval(e, envir = env)
  fn <- get0(spec$r$fn, envir = env, inherits = FALSE)
  if (!is.function(fn)) stop("function ", spec$r$fn, " not found")
  help <- file.path(dir, "help.md")
  list(spec = spec, codegen = fn, dir = dir,
       help = if (file.exists(help)) paste(readLines(help, warn = FALSE), collapse = "\n"))
}

sn_module <- function(sess, id) {
  mod <- sess$modules[[id]]
  if (is.null(mod)) sn_abort(paste0("Unknown analysis: ", id), SN_ERR$not_found)
  mod
}

# Option validation ------------------------------------------------------------

#' Fill defaults and validate options against the module spec and the data.
sn_validate <- function(spec, options, meta, data) {
  out <- list()
  for (role in spec$roles) {
    vars <- unlist(options[[role$id]] %||% list())
    n <- length(vars)
    if (n < (role$min %||% 0)) sn_abort(
      paste0("Add a variable to '", role$label, "'."), SN_ERR$invalid_options,
      data = list(role = role$id, reason = "missing"))
    if (!is.null(role$max) && n > role$max) sn_abort(
      paste0("'", role$label, "' takes at most ", role$max, " variable(s)."), SN_ERR$invalid_options,
      data = list(role = role$id, reason = "too_many"))
    for (v in vars) {
      vm <- meta$variables[[v]]
      if (is.null(vm)) sn_abort(paste0("Unknown variable: ", v), SN_ERR$invalid_options)
      ok <- unlist(role$measure)
      if (length(ok) && !vm$measure %in% ok) sn_abort(
        paste0("'", v, "' is ", vm$measure, "; '", role$label, "' needs ",
               paste(ok, collapse = " or "), "."), SN_ERR$invalid_options,
        data = list(role = role$id, variable = v, reason = "measure"))
      lv <- role$levels
      if (!is.null(lv)) {
        k <- length(unique(stats::na.omit(data[[v]])))
        if ((!is.null(lv$exactly) && k != lv$exactly) || (!is.null(lv$min) && k < lv$min)) sn_abort(
          paste0("'", v, "' has ", k, " levels; '", role$label, "' needs ",
                 if (!is.null(lv$exactly)) lv$exactly else paste("at least", lv$min), "."),
          SN_ERR$invalid_options, data = list(role = role$id, variable = v, reason = "levels"))
      }
    }
    out[[role$id]] <- vars
  }
  for (id in names(spec$options)) {
    o <- spec$options[[id]]
    val <- options[[id]] %||% o$default
    if (o$type == "enum") {
      val <- unlist(val)
      bad <- setdiff(val, unlist(o$values))
      if (length(bad)) sn_abort(paste0("Invalid value for ", id, ": ", bad[1]), SN_ERR$invalid_options)
      if (!isTRUE(o$multiple) && length(val) != 1) sn_abort(paste0(id, " takes one value."), SN_ERR$invalid_options)
      if (isTRUE(o$multiple) && is.null(val)) val <- character()
    } else if (o$type == "number") {
      val <- as.numeric(val)
      if (length(val) != 1 || is.na(val) || (!is.null(o$min) && val < o$min) ||
          (!is.null(o$max) && val > o$max))
        sn_abort(paste0(id, " must be between ", o$min, " and ", o$max, "."), SN_ERR$invalid_options)
    } else if (o$type == "bool") {
      val <- isTRUE(as.logical(val))
    }
    out[[id]] <- val
  }
  out
}
