# Proportional odds (cumulative logit) model via MASS::polr

codegen_reg_ordinal <- function(o, meta, ctx) {
  sn_need_predictors(o)
  dv <- o$dv; cov <- o$covariates; fac <- o$factors
  terms <- c(cov, fac, o$interactions)
  z <- paste0("qnorm(1 - (1 - ", sn_lit(o$conf_level), ") / 2)")
  f <- sn_formula(sn_name(dv), terms)
  code <- sn_code(
    sn_libs(c("MASS", if ("parallel" %in% o$diagnostics) "nnet")),
    "",
    paste0("# Ordinal regression: ", dv, " on ", paste(c(cov, fac), collapse = ", ")),
    sn_prep_code("d", ctx$data, c(dv, cov, fac), meta, ordered = dv, factors = c(dv, fac)),
    paste0("fit <- polr(", f, ", data = d, Hess = TRUE)"),
    "ct <- coef(summary(fit))",
    paste0("coefs <- cbind(ct, p = 2 * pnorm(abs(ct[, 3]), lower.tail = FALSE),\n",
           "  lower = ct[, 1] - ", z, " * ct[, 2], upper = ct[, 1] + ", z, " * ct[, 2])"),
    paste0("null <- polr(", sn_name(dv), " ~ 1, data = d)"),
    "lr_chi <- deviance(null) - deviance(fit); lr_df <- length(coef(fit))",
    "r2_mcfadden <- 1 - deviance(fit) / deviance(null)",
    if ("parallel" %in% o$diagnostics) c(
      "# Proportional odds check: likelihood-ratio test against a multinomial model",
      paste0("multi <- multinom(", f, ", data = d, trace = FALSE)"),
      "po_chi <- deviance(fit) - deviance(multi); po_df <- multi$edf - fit$edf",
      "po_p <- pchisq(po_chi, po_df, lower.tail = FALSE)")
  )
  list(code = code, assemble = assemble_reg_ordinal)
}

assemble_reg_ordinal <- function(env, o, ctx) {
  cf <- env$coefs; fit <- env$fit
  k <- length(stats::coef(fit))
  slopes <- cf[seq_len(k), , drop = FALSE]; cuts <- cf[-seq_len(k), , drop = FALSE]
  lr <- sn_lrt(env$lr_chi, env$lr_df)
  lv <- levels(env$d[[o$dv]])
  fit_tb <- sn_table("fit", "Model Fit", list(sn_col("chi", "χ² (LR)"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue"),
    sn_col("mcf", "McFadden R²", digits = 3), sn_col("aic", "AIC"), sn_col("n", "N", "int")),
    data.frame(chi = lr$chi, df = as.integer(lr$df), p = lr$p, mcf = env$r2_mcfadden, aic = stats::AIC(fit), n = as.integer(stats::nobs(fit))))
  thr <- sn_coef_rows(cuts[, 1:4, drop = FALSE], cuts[, 5:6, drop = FALSE])
  tables <- list(fit_tb,
    sn_tbl_coefs(slopes, o, "z", "Odds ratio", notes = paste0("Odds of a higher category of ", o$dv, " (", paste(lv, collapse = " < "), "). Wald confidence intervals.")),
    sn_table("thresholds", "Thresholds", sn_coef_cols(thr, stat = "z", est = "Estimate", pct = sn_pct(o$conf_level)), thr))
  checks <- list()
  if (!is.null(sn_get(env, "po_p"))) checks <- list(sn_chk_p("parallel", "Proportional odds", env$po_p,
    "No evidence against proportional odds.", "The effect of the predictors differs across outcome thresholds; consider a multinomial model.",
    env$po_chi, "χ²", env$po_df))
  sig <- rownames(slopes)[slopes[, 4] < 0.05]
  text <- paste0("The model ", if (lr$p < 0.05) "fit significantly better than" else "did not fit significantly better than", " the null model, χ²(", lr$df, ") = ",
    fmt_num(lr$chi), ", ", apa_p(lr$p), ". ", if (length(sig)) paste0("Significant predictors (odds ratio): ",
      paste0(sig, " (", fmt_num(exp(slopes[sig, 1]), 2), ")", collapse = ", "), ".") else "No individual predictor was significant.")
  sn_result(tables = tables, assumptions = checks, interpretation = text)
}
