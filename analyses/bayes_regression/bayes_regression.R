# Bayesian linear regression (BayesFactor::regressionBF): all subsets of predictors,
# model comparison, model-averaged inclusion Bayes factors and posterior coefficients.

codegen_bayes_regression <- function(o, meta, ctx) {
  y <- o$outcome; x <- unlist(o$covariates)
  vars <- c(y, x)
  f <- paste0(sn_name(y), " ~ ", paste(sn_name(x), collapse = " + "))
  code <- sn_code(
    sn_libs(c("BayesFactor", if (isTRUE(o$inclusion)) "bayestestR")), "",
    paste0("# Bayesian linear regression: ", y, " on ", paste(x, collapse = ", ")),
    paste0("d <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", sn_lit(vars), "]), ", sn_lit(vars), "]"),
    paste0("rscale <- ", sn_bf_prior(o, "reg"), "   # JZS prior scale on the standardized coefficients"),
    paste0("bf <- regressionBF(", f, ", data = d, rscaleCont = rscale, progress = FALSE)",
           if (length(x) > 1) "   # every subset of predictors"),
    sn_bf_models_code("bf"),
    paste0("models$r2 <- sapply(models$model, function(m) if (m == \"Null model\") 0 else\n  summary(lm(paste(", sn_lit(sn_name(y)), ", \"~\", m), data = d))$r.squared)"),
    if (isTRUE(o$inclusion) && length(x) > 1) "inclusion <- bayesfactor_inclusion(bf)",
    if (isTRUE(o$estimates)) sn_code(
      "# Posterior coefficients of the best model",
      "best <- models$model[1]",
      "if (best != \"Null model\") {",
      paste0("  set.seed(", o$seed, ")"),
      paste0("  fit <- lmBF(as.formula(paste(", sn_lit(sn_name(y)), ", \"~\", best)), data = d, rscaleCont = rscale)"),
      "  post <- posterior(fit, iterations = 10000, progress = FALSE)",
      "}"))
  list(code = code, assemble = assemble_bayes_regression)
}

assemble_bayes_regression <- function(env, o, ctx) {
  m <- sn_bf_models(sn_get(env, "models"), o$top)
  all <- sn_get(env, "models")
  inc <- sn_get(env, "inclusion")
  post <- sn_get(env, "post")
  x <- unlist(o$covariates)
  tm <- sn_tbl_bf_models(m, notes = if (nrow(all) > o$top) paste0("Showing the ", o$top, " best of ", nrow(all), " models."))
  tm$columns <- append(tm$columns, list(sn_col("r2", "R²", digits = 3)), 1)
  tm$rows <- cbind(tm$rows[1], r2 = m$r2, tm$rows[-1])
  best <- m[1, ]
  keep <- if (!is.null(post)) intersect(colnames(post), make.names(x))
  sn_result(
    tables = list(tm,
      if (!is.null(inc)) sn_tbl_bf_inclusion(inc),
      if (!is.null(post) && length(keep)) sn_tbl_posterior(post[, c("mu", keep), drop = FALSE], o$ci_level,
        title = paste0("Posterior Coefficients (", best$model, ")"), labels = c(mu = "Intercept (mean of outcome)"))),
    interpretation = paste(c(
      paste0("A Bayesian linear regression compared ", nrow(all), " models for ", o$outcome,
             " (JZS prior scale r = ", fmt_num(sn_bf_prior_value(o, "reg"), 3), ")."),
      paste0("The best model is ", if (best$model == "Null model") "the null model (no predictors)" else paste0("'", best$model, "'"),
             " with posterior probability ", fmt_num(best$post, 3),
             if (best$model != "Null model") paste0(", R² = ", fmt_num(best$r2, 3), " and BF₁₀ = ", fmt_bf(best$bf10),
                                                     " against the null model"), "."),
      if (!is.null(inc)) paste0("Inclusion Bayes factors: ", paste0(rownames(inc), " BF = ", fmt_bf(exp(inc$log_BF)), collapse = "; "), "."),
      if (!is.null(post) && length(keep)) "The posterior coefficients are slopes in the outcome's units per unit of each predictor (posterior means, which are shrunk towards zero)."),
      collapse = "\n\n"))
}
