# Phase 4: Bayesian analyses (checked against BayesFactor called directly, the package manual's
# examples and identities between one- and two-sided Bayes factors) and plugins.

tbl <- function(res, id) Filter(function(t) t$id == id, res$tables)[[1]]$rows
run_example <- function(module, ...) {
  sess <- new_session()
  spec <- sess$modules[[module]]$spec
  statnextr:::sn_load_example(sess, spec$example$dataset, sess$datasets_dir)
  opts <- spec$example$options; over <- list(...)
  opts[names(over)] <- over
  sn_run_analysis(sess, module, opts)
}
example_data <- function(name) utils::read.csv(file.path(sn_root(), "datasets", paste0(name, ".csv")))
bf_num <- function(s) {
  # "7.67 × 10¹⁴" -> 7.67e14 (display strings in the tables)
  sup <- chartr("⁻⁰¹²³⁴⁵⁶⁷⁸⁹", "-0123456789", s)
  as.numeric(sub("^(.*) × 10(-?[0-9]+)$", "\\1e\\2", sup))
}

test_that("Bayes factor display and evidence labels", {
  expect_equal(statnextr:::fmt_bf(c(86.58973, 0.1894, 7.771e14, 2.3e-5, 1)), c("86.6", "0.189", "7.77 × 10¹⁴", "2.30 × 10⁻⁵", "1.00"))
  expect_equal(statnextr:::sn_bf_evidence(c(150, 50, 20, 5, 2, 1, 0.5, 1 / 200)), c(
    "Extreme evidence for H₁", "Very strong evidence for H₁", "Strong evidence for H₁", "Moderate evidence for H₁",
    "Anecdotal evidence for H₁", "No evidence either way", "Anecdotal evidence for H₀", "Extreme evidence for H₀"))
  expect_equal(bf_num("7.67 × 10¹⁴"), 7.67e14)
})

test_that("Bayesian independent t-test matches ttestBF, and one-sided BFs average to the two-sided BF", {
  skip_if_no_pkgs("BayesFactor")
  res <- run_example("bayes_ttest_ind")
  d <- transform(example_data("mtcars"), am = factor(am))
  ref <- BayesFactor::extractBF(BayesFactor::ttestBF(formula = mpg ~ am, data = d))$bf
  expect_equal(ref, 86.58973, tolerance = 1e-5)
  expect_equal(tbl(res, "bayes_ttest")$bf, "86.6")
  expect_true(grepl("Very strong evidence for H", tbl(res, "bayes_ttest")$evidence))
  expect_lt(tbl(res, "bayes_ttest")$med, 0)
  expect_length(res$plots, 2)
  g <- run_example("bayes_ttest_ind", alternative = "greater", plots = list())
  l <- run_example("bayes_ttest_ind", alternative = "less", plots = list(), bf_type = "bf01")
  bplus <- bf_num(tbl(g, "bayes_ttest")$bf); bminus <- 1 / as.numeric(tbl(l, "bayes_ttest")$bf)
  expect_equal((bplus + bminus) / 2, ref, tolerance = 0.01)
  w <- run_example("bayes_ttest_ind", prior = "custom", prior_r = 1, plots = list())
  expect_equal(as.numeric(tbl(w, "bayes_ttest")$bf),
               BayesFactor::extractBF(BayesFactor::ttestBF(formula = mpg ~ am, data = d, rscale = 1))$bf, tolerance = 0.005)
})

test_that("Bayesian paired and one-sample t-tests match the BayesFactor manual", {
  skip_if_no_pkgs("BayesFactor")
  p <- run_example("bayes_ttest_paired")
  # BayesFactor manual: ttestBF(x = sleep$extra[1:10], y = sleep$extra[11:20], paired = TRUE) = 17.25888
  expect_equal(as.numeric(tbl(p, "bayes_ttest")$bf), 17.3)
  o <- run_example("bayes_ttest_one", plots = list("prior_posterior", "robustness", "sequential"))
  ref <- BayesFactor::extractBF(BayesFactor::ttestBF(example_data("mtcars")$mpg, mu = 20))$bf
  expect_equal(as.numeric(tbl(o, "bayes_ttest")$bf), signif(ref, 3))
  # Posterior delta is relative to the test value (mean 20.09 vs 20: close to zero)
  expect_lt(abs(tbl(o, "bayes_ttest")$med), 0.1)
  expect_length(o$plots, 3)
})

test_that("Bayesian ANOVA matches anovaBF on ToothGrowth (BayesFactor manual)", {
  skip_if_no_pkgs("BayesFactor", "bayestestR")
  res <- run_example("bayes_anova", estimates = TRUE)
  m <- tbl(res, "models")
  expect_equal(m$model[1], "supp + dose + supp:dose")
  # Manual: full model about 7.7e14 against the null (Monte Carlo error a few percent)
  expect_equal(bf_num(m$bf10[1]), 7.7e14, tolerance = 0.06)
  expect_equal(bf_num(m$bf10[m$model == "dose"]), 4.98e12, tolerance = 0.01)
  expect_equal(sum(m$post), 1, tolerance = 1e-8)
  inc <- tbl(res, "inclusion")
  expect_setequal(inc$effect, c("supp", "dose", "dose:supp"))
  expect_gt(bf_num(inc$bf[inc$effect == "dose"]), 1e12)
  est <- tbl(res, "posterior")
  expect_equal(est$mean[est$par == "mu"], mean(example_data("toothgrowth")$len), tolerance = 0.01)
  # Repeated measures: subject as a random factor
  sess <- new_session("sleep_wide")
  long <- data.frame(id = factor(rep(1:10, 2)), drug = factor(rep(c("d1", "d2"), each = 10)),
                     extra = c(example_data("sleep_wide")$drug1, example_data("sleep_wide")$drug2))
  ref <- BayesFactor::extractBF(BayesFactor::anovaBF(extra ~ drug + id, data = long, whichRandom = "id", progress = FALSE))$bf
  expect_gt(ref, 10)
})

test_that("Bayesian correlation, contingency table, regression and binomial match BayesFactor", {
  skip_if_no_pkgs("BayesFactor", "bayestestR")
  mt <- example_data("mtcars")
  c <- run_example("bayes_cor", plot = "prior_posterior")
  r <- tbl(c, "bayes_cor")
  expect_equal(bf_num(r$bf[1]), signif(BayesFactor::extractBF(BayesFactor::correlationBF(mt$mpg, mt$wt))$bf, 3))
  expect_equal(r$r[1], cor(mt$mpg, mt$wt))
  expect_true(grepl("H\u2080", r$evidence[3]))      # wt and qsec: evidence for no correlation
  expect_true(r$cri[[1]][2] < 0)

  ct <- run_example("bayes_contingency", sampling = "indepMulti_rows")
  inf <- example_data("infert")
  ref <- BayesFactor::extractBF(BayesFactor::contingencyTableBF(table(inf$spontaneous, inf$case), sampleType = "indepMulti", fixedMargin = "rows"))$bf
  expect_equal(bf_num(tbl(ct, "bayes_contingency")$bf), signif(ref, 3))
  two <- run_example("bayes_contingency", rows = list("case"), cols = list("induced"))
  expect_null(tbl(two, "bayes_contingency")$med)   # 2 x 3: no odds ratio
  sess <- new_session()
  sess$datasets[["data"]] <- NULL
  d2 <- data.frame(a = rep(c("x", "y"), c(60, 40)), b = c(rep(c("p", "q"), c(45, 15)), rep(c("p", "q"), c(10, 30))))
  tf <- tempfile(fileext = ".csv"); utils::write.csv(d2, tf, row.names = FALSE)
  statnextr::sn_import(sess, tf, NULL, "data")
  or <- sn_run_analysis(sess, "bayes_contingency", list(rows = list("a"), cols = list("b")))
  expect_equal(tbl(or, "bayes_contingency")$med, log(45 * 30 / (15 * 10)), tolerance = 0.15)

  rg <- run_example("bayes_regression")
  m <- tbl(rg, "models")
  ref <- BayesFactor::extractBF(BayesFactor::regressionBF(mpg ~ wt + hp + qsec, data = mt, progress = FALSE))
  expect_equal(m$model[1], rownames(ref)[which.max(ref$bf)])
  expect_equal(bf_num(m$bf10[1]), signif(max(ref$bf), 3))
  expect_equal(m$r2[1], summary(lm(as.formula(paste("mpg ~", m$model[1])), data = mt))$r.squared)
  expect_equal(tbl(rg, "inclusion")$post[1], sum(ref$bf[grepl("wt", rownames(ref))]) / (1 + sum(ref$bf)), tolerance = 1e-6)

  b <- run_example("bayes_binomial")
  bt <- tbl(b, "bayes_binomial")
  expect_equal(bt$count, c(165L, 83L))
  expect_equal(bf_num(bt$bf[2]), signif(BayesFactor::extractBF(BayesFactor::proportionBF(83, 248, p = 0.5))$bf, 3))
  expect_equal(bt$med[2], 83 / 248, tolerance = 0.03)   # shrunk slightly towards 0.5
})

test_that("generated Bayesian code is standalone R", {
  skip_if_no_pkgs("BayesFactor", "bayestestR")
  res <- run_example("bayes_anova")
  expect_false(grepl("sn_", res$code, fixed = TRUE))
  for (m in c("bayes_regression", "bayes_ttest_ind", "bayes_cor", "bayes_contingency", "bayes_binomial"))
    expect_false(grepl("sn_", run_example(m, plots = list())$code, fixed = TRUE), info = m)
})

test_that("plugins install from a folder or zip, run, update and uninstall", {
  pd <- tempfile("plugins"); dir.create(pd)
  sess <- new_session("iris"); sess$plugin_dir <- pd
  tmp <- tempfile(); dir.create(tmp)
  t <- statnextr:::sn_plugin_template(tmp, "my_cv")
  expect_true(all(file.exists(file.path(t$path, c("spec.json", "my_cv.R", "help.md", "README.md")))))
  expect_true(statnextr:::sn_plugin_check(t$path)$ok)
  zipf <- file.path(tmp, "my_cv.zip")
  old <- setwd(tmp); utils::zip(zipf, "my_cv", flags = "-rq"); setwd(old)
  info <- statnextr:::sn_plugin_install(sess, zipf)
  expect_equal(info$id, "my_cv"); expect_false(info$updated)
  expect_equal(sess$modules$my_cv$spec$source, "plugin")
  res <- sn_run_analysis(sess, "my_cv", list(vars = list("sepal_length"), group = list("species")))
  cv <- tbl(res, "cv")
  ir <- example_data("iris")
  expect_equal(cv$cv[cv$group == "setosa"], 100 * sd(ir$sepal_length[ir$species == "setosa"]) / mean(ir$sepal_length[ir$species == "setosa"]))
  expect_true(statnextr:::sn_plugin_install(sess, t$path)$updated)
  expect_length(statnextr:::sn_plugin_list(sess), 1)
  # A plugin cannot replace a built-in analysis, and broken plugins are refused with reasons
  bad <- file.path(tmp, "bad"); dir.create(bad)
  file.copy(list.files(t$path, full.names = TRUE), bad)
  s <- jsonlite::fromJSON(file.path(bad, "spec.json"), simplifyVector = FALSE); s$id <- "ttest_ind"
  jsonlite::write_json(s, file.path(bad, "spec.json"), auto_unbox = TRUE, null = "null")
  expect_error(statnextr:::sn_plugin_install(sess, bad), "built-in")
  s$id <- "Bad Id"; s$r$fn <- "nope"; jsonlite::write_json(s, file.path(bad, "spec.json"), auto_unbox = TRUE, null = "null")
  chk <- statnextr:::sn_plugin_check(bad)
  expect_false(chk$ok)
  expect_true(any(grepl("id must be", unlist(chk$errors))))
  # A new session loads installed plugins; removing deletes the folder
  s2 <- new_session(); sn_load_modules(s2, pd, source = "plugin"); s2$plugin_dir <- pd
  expect_true("my_cv" %in% names(s2$modules))
  expect_true(statnextr:::sn_plugin_remove(s2, "my_cv")$ok)
  expect_false(dir.exists(file.path(pd, "my_cv")))
  expect_error(statnextr:::sn_plugin_remove(s2, "ttest_ind"), "No plugin")
})
