# Reference values: published results where they exist, otherwise the same model fitted directly in R.

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

test_that("every module runs on its example with both plot engines", {
  sess <- new_session()
  for (engine in c("ggnext", "ggplot2")) {
    if (engine == "ggnext" && !requireNamespace("ggnext", quietly = TRUE)) next
    withr::local_envvar(STATNEXT_PLOT_ENGINE = engine)
    for (id in names(sess$modules)) {
      spec <- sess$modules[[id]]$spec
      if (!all(vapply(setdiff(unlist(spec$r$packages), "ggnext"), requireNamespace, TRUE, quietly = TRUE))) next
      statnextr:::sn_load_example(sess, spec$example$dataset, sess$datasets_dir)
      res <- sn_run_analysis(sess, id, spec$example$options)
      expect_true(length(res$tables) > 0, info = id)
      expect_silent(parse(text = res$code))
      for (p in res$plots) { expect_identical(p$engine, engine, info = id); expect_true(file.exists(p$svg), info = id) }
    }
  }
})

test_that("Wilcoxon signed-rank and Friedman match base R", {
  skip_if_no_pkgs("effectsize")
  d <- example_data("sleep_wide")
  ref <- suppressWarnings(wilcox.test(d$drug1, d$drug2, paired = TRUE, exact = FALSE))
  w <- tbl(run_example("wilcoxon_paired"), "tests")
  expect_equal(w$stat[1], unname(ref$statistic)); expect_equal(w$p[1], ref$p.value)
  o <- example_data("orthodont_wide")
  ref <- friedman.test(as.matrix(o[, c("age8", "age10", "age12", "age14")]))
  f <- tbl(run_example("friedman"), "friedman")
  expect_equal(f$stat, unname(ref$statistic)); expect_equal(f$p, ref$p.value)
  expect_equal(f$w, unname(ref$statistic) / (nrow(o) * 3))
})

test_that("correlation matches cor.test, including partial correlation", {
  res <- run_example("correlation")
  p <- tbl(res, "pairs"); ref <- cor.test(mtcars$mpg, mtcars$hp)
  expect_equal(p$r[1], unname(ref$estimate)); expect_equal(p$p[1], ref$p.value)
  expect_equal(unlist(p$ci[[1]]), as.numeric(ref$conf.int))
  sp <- tbl(run_example("correlation", method = "spearman"), "pairs")
  expect_equal(sp$r[1], cor(mtcars$mpg, mtcars$hp, method = "spearman"))
  pc <- tbl(run_example("correlation", vars = list("mpg", "hp"), controls = list("wt")), "pairs")
  expect_equal(pc$r[1], cor(resid(lm(mpg ~ wt, mtcars)), resid(lm(hp ~ wt, mtcars))))
})

test_that("factorial ANOVA reproduces the ToothGrowth table", {
  skip_if_no_pkgs("car", "emmeans")
  a <- tbl(run_example("anova_factorial"), "anova")
  expect_equal(a$F[1:3], c(15.572, 92.000, 4.107), tolerance = 1e-3)
  expect_equal(a$df[1:3], c(1L, 2L, 2L))
  expect_equal(a$eta[1], 205.35 / (205.35 + 712.106), tolerance = 1e-4)
})

test_that("repeated measures ANOVA reproduces the Orthodont results", {
  skip_if_no_pkgs("car")
  a <- tbl(run_example("anova_rm"), "anova")
  expect_equal(a$F[a$source == "Age"], 35.35, tolerance = 1e-3)
  expect_equal(a$F[a$source == "sex"], 9.292, tolerance = 1e-3)
  expect_equal(c(a$df1[a$source == "Age"], a$df2[a$source == "Age"]), c(3, 75))
})

test_that("categorical tests match base R and published values", {
  i <- example_data("infert")
  b <- tbl(run_example("binomial_test"), "binomial")
  expect_equal(b$p[1], binom.test(b$count[1], b$total[1])$p.value)
  g <- tbl(run_example("chisq_gof"), "gof")
  expect_equal(g$stat, unname(chisq.test(table(mtcars$cyl))$statistic))
  m <- tbl(run_example("mcnemar"), "mcnemar")       # Agresti (2013), presidential approval
  expect_equal(m$stat[1], (abs(86 - 150) - 1)^2 / (86 + 150))
  q <- tbl(run_example("cochran_q"), "cochran")
  expect_equal(c(q$stat, q$df), c(9.75, 2))
})

test_that("linear regression matches lm()", {
  skip_if_no_pkgs("car")
  res <- run_example("reg_linear")
  ref <- lm(mpg ~ wt + hp + factor(am), mtcars)
  cf <- tbl(res, "coefficients")
  expect_equal(cf$est, unname(coef(ref))); expect_equal(cf$p, unname(coef(summary(ref))[, 4]))
  expect_equal(tbl(res, "fit")$r2, summary(ref)$r.squared)
  z <- as.data.frame(scale(mtcars[, c("mpg", "wt", "hp")])); z$am <- factor(mtcars$am)
  expect_equal(cf$beta[2:3], unname(coef(lm(mpg ~ wt + hp + am, z))[2:3]))
})

test_that("logistic regression matches glm()", {
  d <- example_data("infert")
  res <- run_example("reg_logistic", factors = list(), covariates = list("age", "parity"), diagnostics = list(), plot = list())
  ref <- glm(case ~ age + parity, data = d, family = binomial)
  cf <- tbl(res, "coefficients")
  expect_equal(cf$est, unname(coef(ref)), tolerance = 1e-6)
  expect_equal(cf$exp[2], unname(exp(coef(ref)[2])), tolerance = 1e-6)
  expect_equal(tbl(res, "fit")$chi, ref$null.deviance - ref$deviance, tolerance = 1e-6)
})

test_that("ordinal, multinomial and count models reproduce the MASS examples", {
  skip_if_no_pkgs("MASS", "nnet")
  o <- tbl(run_example("reg_ordinal"), "coefficients")       # MASS::housing, Venables & Ripley (2002) sec. 7.3
  expect_equal(o$est[o$term == "influenceLow"], -1.2888, tolerance = 1e-3)
  expect_equal(o$est[o$term == "typeTower"], 0.5724, tolerance = 1e-3)
  m <- tbl(run_example("reg_multinomial"), "fit")
  expect_equal(m$df, 6); expect_true(m$p < 0.001)
  q <- tbl(run_example("reg_count"), "fit")                  # MASS::quine negative binomial, theta = 1.275
  expect_equal(q$theta, 1.275, tolerance = 1e-3)
  d <- example_data("quine")
  ref <- glm(days ~ ethnicity + sex + age + learner, data = d, family = poisson)
  p <- tbl(run_example("reg_count", family = "poisson"), "coefficients")
  expect_equal(p$est, unname(coef(ref)), tolerance = 1e-6)
})

test_that("linear mixed model reproduces the sleepstudy fit", {
  skip_if_no_pkgs("lme4", "lmerTest", "performance")
  res <- run_example("mixed_linear")                           # Bates et al. (2015), JSS 67(1)
  cf <- tbl(res, "coefficients")
  expect_equal(cf$est, c(251.405, 10.467), tolerance = 1e-4)
  expect_equal(cf$se, c(6.825, 1.546), tolerance = 1e-3)
  r <- tbl(res, "random")
  expect_equal(r$sd[c(1, 2, 4)], c(24.741, 5.922, 25.592), tolerance = 1e-3)
  expect_equal(r$cor[3], 0.066, tolerance = 2e-2)
  ri <- tbl(run_example("mixed_linear", random_slopes = list()), "random")
  expect_equal(nrow(ri), 2)
})

test_that("generalized mixed model matches glmer()", {
  skip_if_no_pkgs("lme4")
  d <- example_data("bacteria")
  ref <- lme4::glmer(present ~ week + treatment + (1 | id), data = d, family = binomial)
  cf <- tbl(run_example("mixed_glmm"), "coefficients")
  expect_equal(cf$est, unname(lme4::fixef(ref)), tolerance = 1e-5)
})

test_that("Kaplan-Meier and Cox regression reproduce the lung results", {
  skip_if_no_pkgs("survival")
  res <- run_example("surv_km", times = "365")
  s <- tbl(res, "summary")
  expect_equal(s$median, c(270, 426)); expect_equal(s$events, c(112L, 53L))
  expect_equal(tbl(res, "logrank")$chi, 10.33, tolerance = 1e-3)
  expect_equal(tbl(res, "times")$surv, c(0.3361, 0.5265), tolerance = 1e-3)
  cx <- tbl(run_example("surv_cox"), "coefficients")
  expect_equal(cx$est, c(0.011067, 0.463728, -0.552612), tolerance = 1e-4)
  expect_equal(cx$exp[3], 0.5754, tolerance = 1e-3)
  expect_error(run_example("surv_km", times = "soon"), class = "sn_error")
})

test_that("reliability statistics match published values", {
  a <- tbl(run_example("reliability_alpha"), "reliability")
  expect_equal(a$alpha, 0.8431, tolerance = 1e-4)
  rv <- tbl(run_example("reliability_alpha", reverse = list("critical")), "items")
  expect_true(rv$item_rest[rv$item == "critical"] < 0)
  skip_if_no_pkgs("psych")
  icc <- tbl(run_example("reliability_icc"), "icc")           # Shrout & Fleiss (1979), Table 4
  expect_equal(round(icc$icc, 2), c(0.17, 0.29, 0.71, 0.44, 0.62, 0.91))
  k <- tbl(run_example("reliability_kappa"), "kappa")         # Cohen (1968)
  expect_equal(k$kappa, 0.4915, tolerance = 1e-3)
  expect_equal(nrow(tbl(run_example("reliability_kappa", weighted = TRUE), "kappa")), 2)
})

test_that("option validation handles subset and interaction options", {
  skip_if_no_pkgs("lme4", "lmerTest", "performance")
  res <- run_example("mixed_linear", random_slopes = list("days", "not_a_variable"))
  expect_match(res$code, "(1 + days | subject)", fixed = TRUE)
  expect_error(run_example("reg_linear", covariates = list(), factors = list()), class = "sn_error")
  res <- run_example("reg_linear", interactions = list("wt:hp"), plot = list(), diagnostics = list())
  expect_true("wt:hp" %in% tbl(res, "coefficients")$term)
})
