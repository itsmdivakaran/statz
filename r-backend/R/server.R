# JSON-RPC 2.0 server over stdio -------------------------------------------------
# One request per line on stdin, one response per line on stdout.
# Everything an analysis prints is captured (see sn_eval), so stdout carries only
# protocol messages. Notifications ($/progress) go to stderr prefixed with
# SN_NOTIFY_PREFIX so the Rust shell can tell them apart from log lines.
# Cancellation: the shell sends SIGINT; R raises an `interrupt` condition that is
# turned into a -32004 error and the worker stays alive.

SN_NOTIFY_PREFIX <- "\x1eSN "
SN_PROTOCOL_VERSION <- 1L

sn_serve <- function(modules_dirs, datasets_dir = NULL, work_dir = tempfile("statnext-"),
                     input = file("stdin")) {
  sess <- sn_session_new(work_dir)
  sess$datasets_dir <- datasets_dir
  sn_load_modules(sess, modules_dirs)
  open(input)
  on.exit(close(input))
  repeat {
    # A cancel (SIGINT) that arrives between requests must not stop the server.
    line <- tryCatch(readLines(input, n = 1L, warn = FALSE), interrupt = function(e) NA_character_)
    if (length(line) == 0L) break                     # stdin closed: shut down
    if (is.na(line)) next
    if (!nzchar(trimws(line))) next
    resp <- sn_handle_line(sess, line)
    if (!is.null(resp)) {
      cat(resp, "\n", sep = "")
      flush(stdout())
    }
    if (isTRUE(sess$shutdown)) break
  }
  invisible()
}

sn_handle_line <- function(sess, line) {
  req <- tryCatch(jsonlite::fromJSON(line, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(req) || is.null(req$method))
    return(sn_rpc_error(NULL, -32700L, "Parse error"))
  id <- req$id
  sess$current_job <- id
  out <- tryCatch(
    {
      # Capture anything a handler prints so stdout carries only protocol lines.
      utils::capture.output(res <- sn_dispatch(sess, req$method, req$params %||% list()))
      list(result = res)
    },
    sn_error = function(e) list(error = list(code = e$code, message = conditionMessage(e),
                                             data = c(list(hint = e$hint), e$data))),
    interrupt = function(e) list(error = list(code = SN_ERR$cancelled, message = "Cancelled")),
    error = function(e) list(error = list(
      code = SN_ERR$r_error, message = conditionMessage(e),
      data = list(r_call = paste(deparse(conditionCall(e)), collapse = " "))))
  )
  if (is.null(id)) return(NULL)                      # notification: no response
  if (!is.null(out$error)) return(sn_rpc_error(id, out$error$code, out$error$message, out$error$data))
  paste0('{"jsonrpc":"2.0","id":', jsonlite::toJSON(id, auto_unbox = TRUE),
         ',"result":', sn_to_json(out$result), '}')
}

sn_rpc_error <- function(id, code, message, data = NULL) {
  as.character(jsonlite::toJSON(
    list(jsonrpc = "2.0", id = id, error = list(code = code, message = message, data = data)),
    auto_unbox = TRUE, null = "null"))
}

#' Progress notification for long jobs.
sn_progress <- function(sess, pct, message = "") {
  msg <- jsonlite::toJSON(list(jsonrpc = "2.0", method = "$/progress",
                               params = list(id = sess$current_job, pct = pct, message = message)),
                          auto_unbox = TRUE, null = "null")
  cat(SN_NOTIFY_PREFIX, msg, "\n", sep = "", file = stderr())
}

sn_dispatch <- function(sess, method, p) {
  ds <- p$dataset %||% "data"
  switch(method,
    system.hello = list(
      protocol = SN_PROTOCOL_VERSION,
      r_version = paste(R.version$major, R.version$minor, sep = "."),
      statnextr = as.character(utils::packageVersion("statnextr")),
      plot_engine = sn_plot_engine(),
      modules = as.list(names(sess$modules)),
      missing_packages = as.list(sn_missing_packages(sess))
    ),
    system.shutdown = { sess$shutdown <- TRUE; list(ok = TRUE) },
    pkg.install = sn_install_packages(sess, unlist(p$packages), p$repos),
    data.import = sn_import(sess, p$path, p$format, ds),
    data.example = sn_load_example(sess, p$name, sess$datasets_dir, ds),
    data.examples = sn_list_examples(sess$datasets_dir),
    data.info = sn_data_info(sess, ds),
    data.slice = sn_data_slice(sess, ds, p$offset %||% 0L, p$limit %||% 200L),
    data.patch = sn_data_patch(sess, ds, p$ops),
    data.undo = sn_data_undo(sess, ds),
    data.values = sn_data_values(sess, ds, p$column),
    data.save = sn_data_save(sess, p$path),
    data.load = sn_data_load(sess, p$path),
    analysis.list = lapply(unname(sess$modules), function(m) m$spec),
    analysis.help = list(markdown = sn_module(sess, p$module)$help),
    analysis.run = sn_run_analysis(sess, p$module, p$options %||% list(), ds, p$instance),
    analysis.remove = { sess$analyses[[p$instance]] <- NULL; list(ok = TRUE) },
    code.run = sn_run_code(sess, p$code, ds),
    session.script = list(script = sn_session_script(sess, p$format %||% "R")),
    report.export = sn_report_export(sess, p$path, p$format %||% "docx", unlist(p$instances)),
    plot.export = sn_export_plot(sess, p$plot_id, p$format, p$path, p$width %||% 1600L),
    sn_abort(paste0("Unknown method: ", method), SN_ERR$not_found)
  )
}

sn_list_examples <- function(dir) {
  if (is.null(dir)) return(list())
  files <- list.files(dir, pattern = "\\.csv$")
  lapply(sub("\\.csv$", "", files), function(n) {
    meta <- file.path(dir, paste0(n, ".meta.json"))
    m <- if (file.exists(meta)) jsonlite::fromJSON(meta, simplifyVector = FALSE) else list()
    list(name = n, title = m$title %||% n, description = m$description %||% "")
  })
}

# Packages ---------------------------------------------------------------------

sn_required_packages <- function(sess) {
  unique(c("jsonlite", "glue", "rsvg", "ggnext", "readxl", "haven", "zip", "qpdf",
           unlist(lapply(sess$modules, function(m) m$spec$r$packages))))
}

sn_missing_packages <- function(sess) {
  pk <- sn_required_packages(sess)
  pk[!vapply(pk, requireNamespace, logical(1), quietly = TRUE)]
}

#' Install into the first library on .libPaths(), which the shell sets to the
#' app's private library (R_LIBS_USER). Progress is reported per package.
sn_install_packages <- function(sess, packages = NULL, repos = NULL) {
  packages <- packages %||% sn_missing_packages(sess)
  repos <- repos %||% getOption("repos")
  done <- character(); failed <- character()
  for (i in seq_along(packages)) {
    pkg <- packages[[i]]
    sn_progress(sess, round(100 * (i - 1) / length(packages)), paste("Installing", pkg))
    ok <- tryCatch({
      utils::install.packages(pkg, repos = repos, quiet = TRUE)
      requireNamespace(pkg, quietly = TRUE)
    }, error = function(e) FALSE)
    if (ok) done <- c(done, pkg) else failed <- c(failed, pkg)
  }
  sn_progress(sess, 100, "Done")
  list(installed = as.list(done), failed = as.list(failed))
}

#' Entry point used by the desktop shell:
#' Rscript --vanilla -e "statnextr::sn_main()" --args --modules=DIR[:DIR] --datasets=DIR --workdir=DIR
sn_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  get <- function(name) {
    hit <- grep(paste0("^--", name, "="), args, value = TRUE)
    if (length(hit)) sub(paste0("^--", name, "="), "", hit[1])
  }
  modules <- get("modules")
  if (is.null(modules)) stop("--modules is required")
  sn_serve(
    modules_dirs = strsplit(modules, .Platform$path.sep, fixed = TRUE)[[1]],
    datasets_dir = get("datasets"),
    work_dir = get("workdir") %||% tempfile("statnext-")
  )
}
