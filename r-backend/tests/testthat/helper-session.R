# Repo root: STATNEXT_ROOT, else three levels up from tests/testthat.
sn_root <- function() {
  root <- Sys.getenv("STATNEXT_ROOT", "")
  if (nzchar(root)) return(root)
  normalizePath(file.path(testthat::test_path(), "..", "..", ".."), mustWork = TRUE)
}

new_session <- function(example = NULL) {
  sess <- sn_session_new()
  sn_load_modules(sess, file.path(sn_root(), "analyses"))
  sess$datasets_dir <- file.path(sn_root(), "datasets")
  if (!is.null(example)) statnextr:::sn_load_example(sess, example, sess$datasets_dir)
  sess
}

row_of <- function(res, table_id, col, value) {
  tb <- Filter(function(t) t$id == table_id, res$tables)[[1]]$rows
  tb[tb[[col]] == value, , drop = FALSE]
}

skip_if_no_pkgs <- function(...) for (p in c(...)) testthat::skip_if_not_installed(p)
