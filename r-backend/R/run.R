# Runner -----------------------------------------------------------------------
# codegen -> eval exactly that code -> assemble result. The code returned to the
# UI is the code that ran.

sn_run_analysis <- function(sess, module, options, dataset = "data", instance = NULL) {
  mod <- sn_module(sess, module)
  ds <- sn_dataset(sess, dataset)
  pkgs <- unlist(mod$spec$r$packages)
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  missing <- setdiff(missing, "ggnext")   # ggnext is optional: plots fall back to ggplot2
  if (length(missing)) sn_abort(
    paste0("Missing R packages: ", paste(missing, collapse = ", ")), SN_ERR$missing_package,
    hint = "Install them from the Packages screen.", data = list(packages = as.list(missing)))

  o <- sn_validate(mod$spec, options, ds$meta, ds$data)
  ctx <- sn_ctx(sess, dataset)
  gen <- mod$codegen(o, ds$meta, ctx)
  ev <- sn_eval(gen$code, stats::setNames(list(ds$data), dataset))
  res <- gen$assemble(ev$env, o, ctx)
  res$module <- mod$spec$id
  res$module_version <- mod$spec$version
  res$title <- mod$spec$title
  res$status <- if (length(ev$warnings)) "warn" else "ok"
  res$code <- gen$code
  res$warnings <- as.list(ev$warnings)
  res$console <- ev$console
  res$meta <- list(r_version = paste(R.version$major, R.version$minor, sep = "."),
                   packages = sn_pkg_versions(pkgs), dataset = dataset)
  if (!is.null(instance))
    sess$analyses[[instance]] <- list(title = mod$spec$title, code = gen$code,
                                      result = res[c("tables", "assumptions", "plots", "interpretation")])
  res
}

#' Context handed to codegen/assemble: dataset name and plot rendering.
sn_ctx <- function(sess, dataset) {
  list(
    data = dataset,
    # Number of distinct non-missing values of a variable, for codegen that depends on it (e.g. two-class outcomes).
    n_distinct = function(var) length(unique(stats::na.omit(sn_dataset(sess, dataset)$data[[var]]))),
    values = function(var) unique(as.character(stats::na.omit(sn_dataset(sess, dataset)$data[[var]]))),
    plot_engine = sn_plot_engine(),
    plot = function(p, title, fallback_reason = NULL) sn_render_plot(sess, p, title, fallback_reason)
  )
}

#' Evaluate generated code in a fresh environment, capturing printed output and
#' warnings so nothing reaches the JSON-RPC stdout stream.
sn_eval <- function(code, objects = list()) {
  env <- new.env(parent = globalenv())
  for (nm in names(objects)) assign(nm, objects[[nm]], envir = env)
  warns <- character()
  # ggnext and ggplot2 both export aes(), geom_*(): whichever the code loads must come first on the search path.
  for (pair in list(c("ggnext", "ggplot2"), c("ggplot2", "ggnext")))
    if (grepl(paste0("library(", pair[1], ")"), code, fixed = TRUE) && paste0("package:", pair[2]) %in% search())
      try(detach(paste0("package:", pair[2]), character.only = TRUE), silent = TRUE)
  exprs <- parse(text = code, keep.source = FALSE)
  console <- utils::capture.output(
    withCallingHandlers(
      for (e in exprs) eval(e, envir = env),
      warning = function(w) {
        warns <<- c(warns, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) invokeRestart("muffleMessage")
    )
  )
  list(env = env, warnings = unique(warns), console = paste(console, collapse = "\n"))
}

#' Run user-edited code from the Syntax pane against a dataset.
sn_run_code <- function(sess, code, dataset = "data") {
  ds <- sn_dataset(sess, dataset)
  ev <- sn_eval(code, stats::setNames(list(ds$data), dataset))
  plots <- list()
  for (nm in ls(ev$env)) {
    obj <- get(nm, envir = ev$env)
    if (inherits(obj, c("ggnext::GgnextPlot", "GgnextPlot", "ggplot")))
      plots[[length(plots) + 1L]] <- sn_render_plot(sess, obj, nm)
  }
  list(console = ev$console, warnings = as.list(ev$warnings), plots = plots, code = code)
}

sn_pkg_versions <- function(pkgs) {
  pkgs <- as.character(pkgs)
  pkgs <- pkgs[vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (!length(pkgs)) return(structure(list(), names = character()))   # serialises as {} rather than []
  stats::setNames(lapply(pkgs, function(p) as.character(utils::packageVersion(p))), pkgs)
}

# Session script export ---------------------------------------------------------

sn_session_script <- function(sess, format = c("R", "Rmd", "qmd")) {
  format <- match.arg(format)
  chunks <- c(
    lapply(sess$log, function(x) list(title = x$title, code = x$code)),
    unname(sess$analyses)
  )
  header <- paste0("StatNext session script | ", format(Sys.Date()), " | ",
                   R.version.string)
  if (format == "R") {
    body <- vapply(chunks, function(ch) paste0("# ---- ", ch$title, " ----\n", ch$code), "")
    return(paste(c(paste("#", header), "", body), collapse = "\n\n"))
  }
  yaml <- paste0("---\ntitle: \"StatNext analysis\"\ndate: \"", format(Sys.Date()), "\"\n",
                 if (format == "qmd") "format: html\n" else "output: html_document\n", "---")
  body <- vapply(chunks, function(ch) paste0("## ", ch$title, "\n\n```{r}\n", ch$code, "\n```"), "")
  paste(c(yaml, "", paste0("<!-- ", header, " -->"), "", body), collapse = "\n\n")
}

#' ggnext when installed; STATNEXT_PLOT_ENGINE=ggplot2 forces the fallback (used by tests).
sn_plot_engine <- function() {
  forced <- Sys.getenv("STATNEXT_PLOT_ENGINE", "")
  if (forced %in% c("ggnext", "ggplot2")) return(forced)
  if (requireNamespace("ggnext", quietly = TRUE)) "ggnext" else "ggplot2"
}
