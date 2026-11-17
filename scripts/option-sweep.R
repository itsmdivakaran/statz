# Usage (repo root): Rscript scripts/option-sweep.R   [ONLY=ttest_ind,chisq] [OUT=file.csv] [VERBOSE=1]
# Lists every run that fails or whose generated R code does not run on its own. Input errors (code -32003) are expected.
# Option sweep: each module's example with every option value varied one at a time, plus an "everything on" run.
# The generated R code of each run is also re-run on its own (no statnextr functions) to check it is standalone.
suppressPackageStartupMessages(library(statnextr))
root <- Sys.getenv("STATNEXT_ROOT", getwd())
sess <- sn_session_new(); sn_load_modules(sess, file.path(root, "analyses")); sess$datasets_dir <- file.path(root, "datasets")
grDevices::pdf(NULL)
out <- list(); n <- 0
run1 <- function(id, opts, label) {
  n <<- n + 1; if (nzchar(Sys.getenv("VERBOSE"))) message("RUN ", id, " ", label)
  r <- tryCatch({
    res <- suppressWarnings(sn_run_analysis(sess, id, opts))
    code_ok <- !grepl("\\bsn_[a-z]", res$code)
    env <- new.env(parent = globalenv()); env$data <- statnextr:::sn_dataset(sess, "data")$data
    standalone <- tryCatch({ withCallingHandlers(suppressWarnings(capture.output(eval(parse(text = res$code), env))), message = function(m) invokeRestart("muffleMessage")); "" },
                           error = function(e) conditionMessage(e))
    list(ok = TRUE, msg = paste0(if (!code_ok) "code calls sn_*; " else "", if (nzchar(standalone)) paste("standalone code error:", standalone) else ""))
  }, error = function(e) list(ok = FALSE, msg = conditionMessage(e), code = if (!is.null(e$code)) e$code else NA))
  if (!r$ok || nzchar(r$msg)) out[[length(out) + 1]] <<- data.frame(module = id, variant = label, ok = r$ok, code = if (is.null(r$code)) NA else r$code, msg = substr(gsub("\n", " ", r$msg), 1, 220))
}
only <- strsplit(Sys.getenv("ONLY", ""), ",")[[1]]
for (id in sort(names(sess$modules))) {
  if (length(only) && !(id %in% only)) next
  spec <- sess$modules[[id]]$spec
  if (is.null(spec$example)) next
  statnextr:::sn_load_example(sess, spec$example$dataset, sess$datasets_dir)
  base <- spec$example$options
  run1(id, base, "example")
  all_on <- base
  for (k in names(spec$options)) {
    o <- spec$options[[k]]; cur <- if (!is.null(base[[k]])) base[[k]] else o$default
    if (identical(o$type, "bool")) { v <- base; v[[k]] <- !isTRUE(cur); run1(id, v, paste0(k, "=", !isTRUE(cur))); all_on[[k]] <- TRUE }
    else if (identical(o$type, "enum")) {
      vals <- unlist(o$values)
      if (isTRUE(o$multiple)) { v <- base; v[[k]] <- as.list(vals); run1(id, v, paste0(k, "=all")); all_on[[k]] <- as.list(vals)
                                v[[k]] <- list(); run1(id, v, paste0(k, "=none")) }
      else for (val in setdiff(vals, cur)) { v <- base; v[[k]] <- val; run1(id, v, paste0(k, "=", val)) }
    }
  }
  run1(id, all_on, "all-on")
  cat(id, "", file = stderr())
}
res <- if (length(out)) do.call(rbind, out) else data.frame()
cat("\nRUNS", n, "ISSUES", nrow(res), "\n")
utils::write.csv(res, Sys.getenv("OUT", "option-sweep.csv"), row.names = FALSE)
if (nrow(res)) print(res, right = FALSE)
