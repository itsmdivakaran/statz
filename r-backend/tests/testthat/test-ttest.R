# Reference values: R t.test() documentation and widely published mtcars/sleep results
# (mtcars mpg ~ am: Welch t = -3.7671, df = 18.332, p = 0.001374; Student t = -4.1061, df = 30,
#  p = 0.000285. sleep: paired t = -4.0621, df = 9, p = 0.002833).

test_that("independent t-test matches reference values", {
  skip_if_no_pkgs("effectsize", "car")
  sess <- new_session("mtcars")
  res <- sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg"), group = list("am"),
                                                  test = list("welch", "student"), plot = "none"))
  w <- row_of(res, "ttest", "test", "Welch")
  expect_equal(w$stat, -3.7671, tolerance = 1e-4)
  expect_equal(w$df, 18.332, tolerance = 1e-4)
  expect_equal(w$p, 0.001374, tolerance = 1e-3)
  expect_equal(w$diff, 17.147368 - 24.392308, tolerance = 1e-6)
  expect_equal(w$ci[[1]], c(-11.280194, -3.209684), tolerance = 1e-6)
  # Cohen's d with pooled SD and noncentral-t CI.
  expect_equal(w$es, -1.4779, tolerance = 1e-3)
  expect_equal(w$es_ci[[1]], c(-2.2660, -0.6706), tolerance = 1e-3)
  s <- row_of(res, "ttest", "test", "Student")
  expect_equal(s$stat, -4.1061, tolerance = 1e-4)
  expect_equal(s$df, 30)
  expect_equal(s$p, 0.000285, tolerance = 1e-2)
  # Value labels from metadata are applied to the grouping factor.
  expect_equal(row_of(res, "descriptives", "group", "Manual")$n, 13L)
  expect_match(res$interpretation$text, "t\\(18.33\\) = −3.77, p = .001")
})

test_that("generated code reproduces the result when run on its own", {
  skip_if_no_pkgs("effectsize", "car")
  sess <- new_session("mtcars")
  res <- sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg"), group = list("am"), plot = "none"))
  env <- new.env()
  env$data <- read.csv(file.path(sn_root(), "datasets", "mtcars.csv"), check.names = FALSE)
  eval(parse(text = res$code), envir = env)
  expect_equal(unname(env$welch$statistic), row_of(res, "ttest", "test", "Welch")$stat)
})

test_that("Mann-Whitney U and multiple DVs", {
  skip_if_no_pkgs("effectsize", "car")
  sess <- new_session("mtcars")
  res <- sn_run_analysis(sess, "ttest_ind", list(dv = list("mpg", "hp"), group = list("am"),
                                                  test = list("mann_whitney"), plot = "none"))
  ref <- suppressWarnings(wilcox.test(mpg ~ am, data = mtcars, exact = FALSE))
  mw <- row_of(res, "ttest", "var", "mpg")
  expect_equal(mw$stat, unname(ref$statistic))
  expect_equal(mw$p, ref$p.value)
  expect_equal(nrow(Filter(function(t) t$id == "ttest", res$tables)[[1]]$rows), 2)
})

test_that("one-sample t-test", {
  skip_if_no_pkgs("effectsize")
  sess <- new_session("mtcars")
  res <- sn_run_analysis(sess, "ttest_one", list(dv = list("mpg"), mu = 20, plot = "none"))
  ref <- t.test(mtcars$mpg, mu = 20)
  r <- row_of(res, "ttest", "test", "Student")
  expect_equal(r$stat, unname(ref$statistic))
  expect_equal(r$p, ref$p.value)
  expect_equal(r$es, (mean(mtcars$mpg) - 20) / sd(mtcars$mpg), tolerance = 1e-8)
})

test_that("paired t-test matches the sleep reference", {
  skip_if_no_pkgs("effectsize")
  sess <- new_session("sleep_wide")
  res <- sn_run_analysis(sess, "ttest_paired", list(var1 = list("drug1"), var2 = list("drug2"), plot = "none"))
  r <- row_of(res, "ttest", "test", "Student")
  expect_equal(r$stat, -4.0621, tolerance = 1e-4)
  expect_equal(r$df, 9)
  expect_equal(r$p, 0.002833, tolerance = 1e-3)
  expect_equal(r$diff, -1.58)
  expect_equal(r$es, -1.58 / 1.229995, tolerance = 1e-5)   # dz = mean diff / SD diff
})
