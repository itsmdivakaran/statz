# Reference: SPSS-style (bias-corrected) skewness/kurtosis for mtcars mpg: 0.672, -0.022.

test_that("descriptives match reference values", {
  sess <- new_session("mtcars")
  res <- sn_run_analysis(sess, "descriptives", list(
    vars = list("mpg", "am"), stats = list("n", "mean", "sd", "skewness", "kurtosis")))
  r <- row_of(res, "descriptives", "var", "mpg")
  expect_equal(r$n, 32L)
  expect_equal(r$mean, 20.090625)
  expect_equal(r$sd, 6.026948, tolerance = 1e-6)
  expect_equal(r$skewness, 0.672, tolerance = 1e-3)
  expect_equal(r$kurtosis, -0.022, tolerance = 2e-2)
  f <- row_of(res, "freq_am", "level", "Manual")
  expect_equal(f$n, 13L)
})

test_that("split by group", {
  sess <- new_session("mtcars")
  res <- sn_run_analysis(sess, "descriptives", list(vars = list("mpg"), split = list("am")))
  expect_equal(row_of(res, "descriptives", "group", "Automatic")$mean, mean(mtcars$mpg[mtcars$am == 0]))
})
