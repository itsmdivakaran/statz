# Edge cases found by running every option value of every analysis.

run_example <- function(module, ...) {
  sess <- new_session()
  spec <- sess$modules[[module]]$spec
  statnextr:::sn_load_example(sess, spec$example$dataset, sess$datasets_dir)
  opts <- spec$example$options; over <- list(...)
  opts[names(over)] <- over
  sn_run_analysis(sess, module, opts)
}

test_that("chi-square with no test ticked still shows the table", {
  res <- run_example("chisq", test = list())
  ids <- vapply(res$tables, `[[`, "", "id")
  expect_true("crosstab" %in% ids)
  expect_false("tests" %in% ids)
})

test_that("regression on a categorical outcome is refused with a clear message, not a crash", {
  skip_if_no_pkgs("gbm")
  err <- tryCatch(run_example("ml_boost", task = "regression"), error = function(e) e)
  expect_s3_class(err, "sn_error")
  expect_equal(err$code, statnextr:::SN_ERR$invalid_options)
  expect_match(conditionMessage(err), "needs a numeric outcome")
  # The session keeps working afterwards (gbm used to corrupt memory here).
  expect_gt(length(run_example("ml_boost", importance = FALSE)$plots), 0)
})
