# Binary logistic regression with odds ratios, fit statistics, classification and ROC

codegen_reg_logistic <- function(o, meta, ctx) {
  sn_need_predictors(o)
  dv <- o$dv; cov <- o$covariates; fac <- o$factors
  terms <- c(cov, fac, o$interactions)
  cl <- sn_lit(o$conf_level); dg <- o$diagnostics
  code <- sn_code(
    sn_libs(c(if ("vif" %in% dg && length(terms) >= 2) "car", if (length(o$plot)) ctx$plot_engine)),
    "",
    paste0("# Logistic regression: ", dv, " on ", paste(c(cov, fac), collapse = ", ")),
    sn_prep_code("d", ctx$data, c(dv, cov, fac), meta, factors = c(dv, fac)),
    paste0("# Models the probability of the second category: levels(", sn_ref("d", dv), ")[2]"),
    paste0("fit <- glm(", sn_formula(sn_name(dv), terms), ", data = d, family = binomial)"),
    paste0("coefs <- cbind(coef(summary(fit)), confint.default(fit, level = ", cl, "))"),
    "n <- nobs(fit)",
    "lr_chi <- fit$null.deviance - fit$deviance; lr_df <- fit$df.null - fit$df.residual",
    "r2_mcfadden <- 1 - fit$deviance / fit$null.deviance",
    "r2_nagelkerke <- (1 - exp((fit$deviance - fit$null.deviance) / n)) / (1 - exp(-fit$null.deviance / n))",
    "pred <- fitted(fit); y <- as.integer(fit$y)",
    "auc <- (mean(rank(pred)[y == 1]) - (sum(y == 1) + 1) / 2) / sum(y == 0)",
    if (o$classification) paste0("class_table <- table(Observed = ", sn_ref("d", dv), ", Predicted = factor(pred >= 0.5, c(FALSE, TRUE), levels(", sn_ref("d", dv), ")))"),
    if ("vif" %in% dg && length(terms) >= 2) "vif_values <- vif(fit)",
    if ("hl" %in% dg) c(
      "# Hosmer-Lemeshow test with 10 groups of predicted risk",
      "hl_group <- cut(pred, breaks = unique(quantile(pred, 0:10 / 10)), include.lowest = TRUE)",
      "hl_obs <- tapply(y, hl_group, sum); hl_exp <- tapply(pred, hl_group, sum); hl_n <- tapply(y, hl_group, length)",
      "hl_stat <- sum((hl_obs - hl_exp)^2 / (hl_exp * (1 - hl_exp / hl_n)))",
      "hl_df <- length(hl_obs) - 2; hl_p <- pchisq(hl_stat, hl_df, lower.tail = FALSE)"),
    if ("roc" %in% o$plot) {
      if (ctx$plot_engine == "ggnext") c(
        paste0("roc_df <- data.frame(truth = ", sn_ref("d", dv), ", score = pred)"),
        sn_gg("ggnext", "roc_df, aes(truth = truth, score = score)", "geom_roc()", "ROC curve", "1 − Specificity", "Sensitivity", "p_roc"))
      else c(
        "cuts <- sort(unique(c(-Inf, pred, Inf)), decreasing = TRUE)",
        "roc_df <- data.frame(fpr = sapply(cuts, function(k) mean(pred[y == 0] >= k)), tpr = sapply(cuts, function(k) mean(pred[y == 1] >= k)))",
        sn_gg("ggplot2", "roc_df, aes(fpr, tpr)", c("geom_line()", "geom_abline(linetype = 2)"), "ROC curve", "1 − Specificity", "Sensitivity", "p_roc"))
    },
    if ("coef" %in% o$plot) c(sn_coef_df_code(), sn_forest_plot_code(ctx$plot_engine, title = "Coefficients", xlab = paste0("Log odds (", sn_pct(o$conf_level), ")")))
  )
  list(code = code, assemble = assemble_reg_logistic)
}

assemble_reg_logistic <- function(env, o, ctx) {
  fit <- env$fit
  lv <- levels(env$d[[o$dv]])
  lr <- sn_lrt(env$lr_chi, env$lr_df)
  fit_tb <- sn_table("fit", "Model Fit", list(sn_col("chi", "χ² (LR)"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue"),
    sn_col("mcf", "McFadden R²", digits = 3), sn_col("nag", "Nagelkerke R²", digits = 3), sn_col("auc", "AUC", digits = 3),
    sn_col("aic", "AIC"), sn_col("n", "N", "int")),
    data.frame(chi = lr$chi, df = as.integer(lr$df), p = lr$p, mcf = env$r2_mcfadden, nag = env$r2_nagelkerke, auc = env$auc,
               aic = stats::AIC(fit), n = as.integer(env$n)))
  tables <- list(fit_tb, sn_tbl_coefs(env$coefs, o, "z", "Odds ratio",
    notes = c(paste0("Outcome modelled: ", o$dv, " = ", lv[2], " (reference: ", lv[1], ")."), "Wald confidence intervals.")))
  ct <- sn_get(env, "class_table")
  if (!is.null(ct)) {
    acc <- sum(diag(ct)) / sum(ct)
    tables <- c(tables, list(sn_table("classification", "Classification Table (cut-off 0.5)", list(sn_col("obs", "Observed", "text"),
      sn_col("p0", paste("Predicted", lv[1]), "int"), sn_col("p1", paste("Predicted", lv[2]), "int"), sn_col("pc", "% correct", digits = 1)),
      data.frame(obs = lv, p0 = as.integer(ct[, 1]), p1 = as.integer(ct[, 2]), pc = 100 * diag(ct) / rowSums(ct)),
      notes = sprintf("Overall accuracy %.1f%%; sensitivity %.1f%%, specificity %.1f%%.", 100 * acc, 100 * ct[2, 2] / sum(ct[2, ]), 100 * ct[1, 1] / sum(ct[1, ])))))
  }
  checks <- list(sn_chk_vif(sn_get(env, "vif_values")))
  if (!is.null(sn_get(env, "hl_p"))) checks <- c(checks, list(sn_chk_p("hl", "Calibration (Hosmer-Lemeshow)", env$hl_p,
    "Predicted and observed risks agree.", "Predicted risks deviate from observed rates; the model may be poorly calibrated.", env$hl_stat, "χ²", env$hl_df)))
  cf <- env$coefs[-1, , drop = FALSE]
  sig <- rownames(cf)[cf[, 4] < 0.05]
  text <- paste0("The model ", if (lr$p < 0.05) "fit significantly better than" else "did not fit significantly better than", " the null model, χ²(", lr$df, ") = ",
    fmt_num(lr$chi), ", ", apa_p(lr$p), ", Nagelkerke R² = ", fmt_num(env$r2_nagelkerke, 2), ", AUC = ", fmt_num(env$auc, 2), ". ",
    if (length(sig)) paste0("Significant predictors (odds ratio): ", paste0(sig, " (", fmt_num(exp(cf[sig, 1]), 2), ")", collapse = ", "), ".") else "No individual predictor was significant.")
  sn_result(tables = tables, assumptions = checks, plots = sn_plots(env, ctx, list(p_roc = "ROC curve", p_coef = "Coefficients")), interpretation = text)
}
