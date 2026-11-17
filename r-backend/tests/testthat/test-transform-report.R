patch <- function(sess, ...) statnextr::sn_dispatch(sess, "data.patch", list(ops = list(list(...))))

test_that("compute adds a variable and logs reproducible code", {
  sess <- new_session("mtcars")
  info <- patch(sess, op = "compute", name = "kpl", expr = "mpg * 0.425", label = "Km per litre")
  v <- info$variables[[info$ncol]]
  expect_equal(c(v$name, v$label, v$measure), c("kpl", "Km per litre", "continuous"))
  expect_equal(sess$datasets$data$data$kpl, sess$datasets$data$data$mpg * 0.425)
  expect_match(sess$log[[length(sess$log)]]$code, "data$kpl <- with(data, mpg * 0.425)", fixed = TRUE)
})

test_that("recode merges categories and can set unmatched values to missing", {
  sess <- new_session("mtcars")
  rules <- list(list(from = list("4"), to = "small"), list(from = list("6", "8"), to = "large"))
  info <- patch(sess, op = "recode", column = "cyl", into = "size", rules = rules, unmatched = "keep")
  expect_equal(as.vector(table(sess$datasets$data$data$size)[c("large", "small")]), c(21L, 11L))
  expect_equal(info$variables[[info$ncol]]$measure, "nominal")
  patch(sess, op = "recode", column = "gear", into = "gear", rules = list(list(from = list("3"), to = "1")), unmatched = "missing")
  expect_equal(sum(is.na(sess$datasets$data$data$gear)), 17L)
  vals <- statnextr::sn_dispatch(sess, "data.values", list(column = "cyl"))
  expect_equal(vapply(vals$values, function(v) v$value, ""), c("4", "6", "8"))
})

test_that("filter keeps matching rows and undo restores data and log", {
  sess <- new_session("mtcars")
  n_log <- length(sess$log)
  expect_equal(patch(sess, op = "filter", expr = "mpg > 20 & am == 1")$nrow, 10L)
  info <- statnextr::sn_dispatch(sess, "data.undo", list())
  expect_equal(info$nrow, 32L); expect_length(sess$log, n_log)
  expect_error(statnextr::sn_dispatch(sess, "data.undo", list()), class = "sn_error")
})

test_that("invalid transforms are rejected with a clear message", {
  sess <- new_session("mtcars")
  expect_error(patch(sess, op = "compute", name = "2x", expr = "1"), "Variable names")
  expect_error(patch(sess, op = "compute", name = "z", expr = "mpg +"), "not a complete R expression")
  expect_error(patch(sess, op = "compute", name = "z", expr = "nosuch * 2"), "R could not run this")
  expect_error(patch(sess, op = "filter", expr = "mpg > 1000"), "No rows match")
  expect_equal(ncol(sess$datasets$data$data), 12L)
})

test_that("results export to Word, PDF and HTML", {
  skip_if_no_pkgs("effectsize", "car", "rsvg", "zip", "qpdf")
  sess <- new_session("mtcars")
  sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg"), group = list("am")), instance = "a1")
  sn_run_analysis(sess, "descriptives", list(vars = list("mpg", "hp", "wt")), instance = "a2")
  dir <- withr::local_tempdir()
  out <- function(f) statnextr::sn_dispatch(sess, "report.export", list(path = file.path(dir, paste0("r.", f)), format = f))$path
  files <- zip::zip_list(out("docx"))$filename
  expect_true(all(c("[Content_Types].xml", "word/document.xml", "word/styles.xml") %in% files))
  expect_true(any(grepl("^word/media/plot1\\.png$", files)))
  doc <- paste(readLines(unz(file.path(dir, "r.docx"), "word/document.xml"), warn = FALSE, encoding = "UTF-8"), collapse = "")
  expect_match(doc, "Independent Samples T-Test", fixed = TRUE); expect_match(doc, "<w:tbl>", fixed = TRUE)
  expect_gte(qpdf::pdf_length(out("pdf")), 1L)
  html <- paste(readLines(out("html"), warn = FALSE, encoding = "UTF-8"), collapse = "")
  expect_match(html, "<table>", fixed = TRUE); expect_match(html, "Table 1", fixed = TRUE)
  only <- statnextr::sn_dispatch(sess, "report.export", list(path = file.path(dir, "one.html"), format = "html", instances = list("a2")))
  expect_false(grepl("T-Test", paste(readLines(only$path, warn = FALSE), collapse = ""), fixed = TRUE))
  empty <- new_session("mtcars")
  expect_error(statnextr::sn_dispatch(empty, "report.export", list(path = file.path(dir, "x.pdf"), format = "pdf")), class = "sn_error")
})
