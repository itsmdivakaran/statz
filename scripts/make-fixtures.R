# Regenerates tests/fixtures/<module>.result.json by running every module on its example.
# Usage (repo root): Rscript scripts/make-fixtures.R
suppressMessages(library(statnextr))
root <- Sys.getenv("STATNEXT_ROOT", getwd())
sess <- sn_session_new()
sn_load_modules(sess, file.path(root, "analyses"))
for (id in names(sess$modules)) {
  spec <- sess$modules[[id]]$spec
  statnextr:::sn_load_example(sess, spec$example$dataset, file.path(root, "datasets"))
  res <- sn_run_analysis(sess, id, spec$example$options)
  # Plot files live in a temp folder; keep only the file names so fixtures are stable.
  res$plots <- lapply(res$plots, function(p) { for (f in c("svg", "html", "data_csv")) if (!is.null(p[[f]])) p[[f]] <- basename(p[[f]]); p })
  writeLines(sn_to_json(res, pretty = TRUE), file.path(root, "tests", "fixtures", paste0(id, ".result.json")), useBytes = TRUE)
  cat("wrote", id, "\n")
}
