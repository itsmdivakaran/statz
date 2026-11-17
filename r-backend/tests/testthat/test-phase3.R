# Phase 3 reference values: published results where they exist, otherwise the same model fitted directly.

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
ci <- function(x) unlist(x)

test_that("PCA reproduces the USArrests eigenvalues and loadings", {
  res <- run_example("pca")
  v <- tbl(res, "variance")
  expect_equal(v$eigenvalue, c(2.4802, 0.9898, 0.3566, 0.1734), tolerance = 1e-4)
  expect_equal(v$proportion[1], 62.0, tolerance = 1e-3)
  pc <- prcomp(USArrests, scale. = TRUE)
  L <- tbl(res, "loadings")
  expect_equal(abs(L$c1), abs(unname(pc$rotation[, 1] * pc$sdev[1])), tolerance = 1e-6)
  expect_equal(L$x1, unname(rowSums((pc$rotation[, 1:2] %*% diag(pc$sdev[1:2]))^2)), tolerance = 1e-6)
  expect_true(all(vapply(res$assumptions, `[[`, "", "status") == "ok"))
})

test_that("factor analysis matches psych::fa", {
  skip_if_no_pkgs("psych", "GPArotation")
  res <- run_example("efa", n_factors = 3, vars = as.list(c(paste0("A", 1:5), paste0("C", 1:5), paste0("E", 1:5))))
  d <- example_data("bfi")[, c(paste0("A", 1:5), paste0("C", 1:5), paste0("E", 1:5))]
  ref <- psych::fa(d[complete.cases(d), ], nfactors = 3, fm = "minres", rotate = "oblimin")
  f <- tbl(res, "fit")
  expect_equal(f$rmsea, unname(ref$RMSEA[1]), tolerance = 1e-6)
  expect_equal(f$tli, ref$TLI, tolerance = 1e-6)
  expect_equal(sort(tbl(res, "loadings")$x1), sort(unname(ref$communality)), tolerance = 1e-6)
})

test_that("k-means and hierarchical clustering match stats", {
  skip_if_no_pkgs("cluster")
  km <- run_example("cluster_kmeans")
  fit <- tbl(km, "fit")
  set.seed(123); ref <- kmeans(scale(iris[1:4]), 3, nstart = 25, iter.max = 100)
  expect_equal(fit$within, ref$tot.withinss, tolerance = 1e-8)
  expect_equal(fit$ratio, 0.767, tolerance = 1e-3)
  expect_equal(sort(tbl(km, "sizes")$n), sort(ref$size))
  hc <- run_example("cluster_hier")
  ref <- cutree(hclust(dist(scale(USArrests)), "ward.D2"), 4)
  expect_equal(tbl(hc, "sizes")$n, as.vector(table(ref)))
  expect_equal(tbl(hc, "fit")$ac, cluster::coef.hclust(hclust(dist(scale(USArrests)), "ward.D2")), tolerance = 1e-8)
})

test_that("diagnostic accuracy and ROC reproduce the pROC aSAH results", {
  skip_if_no_pkgs("pROC")
  dx <- run_example("diag_2x2")
  ct <- tbl(dx, "crosstab")
  expect_equal(c(ct$pos[1:2], ct$neg[1:2]), c(26, 15, 14, 58))
  acc <- tbl(dx, "accuracy")
  expect_equal(acc$est[1:2], 100 * c(26 / 41, 58 / 72))
  expect_equal(ci(acc$ci[[1]]), 100 * as.numeric(binom.test(26, 41)$conf.int))
  expect_equal(tbl(dx, "ratios")$est[1], (26 / 41) / (14 / 72))
  roc <- run_example("roc")
  a <- tbl(roc, "auc")
  expect_equal(a$auc, c(0.7314, 0.6120), tolerance = 1e-4)
  expect_equal(ci(a$ci[[1]]), c(0.6301, 0.8326), tolerance = 1e-3)
  expect_equal(tbl(roc, "cutoff")$threshold[1], 0.205)
  expect_equal(tbl(roc, "comparison")$p, 0.1643, tolerance = 1e-3)
})

test_that("meta-analysis reproduces the BCG vaccine results (metafor)", {
  skip_if_no_pkgs("metafor")
  m <- run_example("meta_binary")
  p <- tbl(m, "pooled"); h <- tbl(m, "heterogeneity")
  expect_equal(log(p$est), -0.7145, tolerance = 1e-4)
  expect_equal(h$tau2, 0.3132, tolerance = 1e-3)
  expect_equal(h$i2, 92.22, tolerance = 1e-3)
  expect_equal(ci(p$pi[[1]]), c(0.1546, 1.5490), tolerance = 1e-3)
  g <- tbl(run_example("meta_generic"), "pooled")
  expect_equal(g$est, p$est, tolerance = 1e-3)
  cont <- tbl(run_example("meta_continuous", measure = "SMD", knha = TRUE), "pooled")
  d <- example_data("stroke_los")
  ref <- metafor::rma(measure = "SMD", n1i = n_stroke_unit, m1i = mean_stroke_unit, sd1i = sd_stroke_unit,
                      n2i = n_usual, m2i = mean_usual, sd2i = sd_usual, data = d, test = "knha")
  expect_equal(cont$est, as.numeric(ref$beta), tolerance = 1e-8)
  expect_equal(cont$p, ref$pval, tolerance = 1e-8)
})

test_that("machine-learning modules report sensible test-set performance", {
  skip_if_no_pkgs("rpart", "ranger", "gbm", "glmnet", "e1071", "pROC")
  for (m in c("ml_forest", "ml_boost", "ml_svm")) {
    perf <- tbl(run_example(m), "performance")
    expect_gt(perf$value[perf$metric == "AUC"], 0.75)
    expect_gt(perf$value[perf$metric == "Accuracy"], perf$value[perf$metric == "No-information rate"])
  }
  for (m in c("ml_tree", "ml_nb", "ml_lda")) {
    perf <- tbl(run_example(m), "performance")
    expect_gt(perf$value[perf$metric == "Accuracy"], 0.9)
  }
  # The tree matches rpart fitted on the same split.
  d <- example_data("iris"); d$species <- factor(d$species)
  set.seed(123); test_rows <- sample(nrow(d), round(0.25 * nrow(d)))
  set.seed(123); fit <- rpart::rpart(species ~ ., d[-test_rows, ], method = "class", control = rpart::rpart.control(cp = 0.01, maxdepth = 5, minsplit = 20))
  acc <- mean(predict(fit, d[test_rows, ], type = "class") == d$species[test_rows])
  expect_equal(tbl(run_example("ml_tree"), "performance")$value[1], acc)
  # SHAP for a numeric outcome.
  res <- run_example("ml_glmnet", shap = TRUE)
  expect_true(any(vapply(res$tables, `[[`, "", "id") == "shap"))
  expect_gt(tbl(res, "performance")$value[3], 0)   # test-set R²
})

test_that("ARIMA finds the airline model for AirPassengers", {
  skip_if_no_pkgs("forecast")
  res <- run_example("ts_arima", holdout = 0)
  expect_equal(tbl(res, "model")$model, "ARIMA(0,1,1)(0,1,1)[12]")
  expect_equal(tbl(res, "coefficients")$estimate, c(-0.4018, -0.5569), tolerance = 1e-3)
  et <- run_example("ts_ets", holdout = 0)
  ref <- forecast::ets(AirPassengers)
  expect_equal(tbl(et, "model")$aicc, ref$aicc, tolerance = 1e-6)
  ex <- run_example("ts_explore")
  expect_equal(tbl(ex, "summary")$n, 144L)
  expect_equal(tbl(ex, "autocorrelation")$acf[1], acf(AirPassengers, plot = FALSE)$acf[2], tolerance = 1e-10)
})

test_that("clinical tables count subjects correctly", {
  t1 <- run_example("clin_table1")
  rows <- tbl(t1, "table1")
  d <- example_data("adsl_sim")
  expect_equal(rows$g1[1], as.character(nrow(d)))
  sex <- rows[rows$characteristic == "Sex, n (%)", ]
  expect_equal(sex$p, chisq.test(table(d$SEX, d$TRT01P), correct = FALSE)$p.value)
  age <- rows[grepl("^Age", rows$characteristic), ]
  expect_equal(age$g1, sprintf("%.1f (%.1f)", mean(d$AGE), sd(d$AGE)))
  ae <- run_example("clin_ae")
  a <- example_data("adae_sim")
  ov <- tbl(ae, "overview")
  n_pbo <- length(unique(a$USUBJID[a$TRT01P == "Placebo"]))
  expect_equal(ov$a1[1], sprintf("%d (%.1f%%)", n_pbo, 100 * n_pbo / 85))
  ev <- tbl(ae, "events")
  pr <- ev[trimws(ev$event) == "Pruritus", ]
  k <- length(unique(a$USUBJID[a$TRT01P == "Drug 81 mg" & a$AEDECOD == "Pruritus"]))
  expect_equal(pr$a3, sprintf("%d (%.1f%%)", k, 100 * k / 84))
  expect_error(run_example("clin_ae", arm_n = "Placebo=85"), "not in 'Subjects per arm'")
})
