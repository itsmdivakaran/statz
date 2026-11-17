# Poisson, quasi-Poisson and negative binomial regression for counts

codegen_reg_count <- function(o, meta, ctx) {
  sn_need_predictors(o)
  dv <- o$dv; cov <- o$covariates; fac <- o$factors; ex <- o$exposure
  terms <- c(cov, fac, o$interactions)
  rhs <- paste0(sn_rhs(terms), if (length(ex)) paste0(" + offset(log(", sn_name(ex), "))"))
  f <- paste0(sn_name(dv), " ~ ", rhs)
  cl <- sn_lit(o$conf_level)
  code <- sn_code(
    sn_libs(c(if (o$family == "negbin") "MASS", if (length(o$plot)) ctx$plot_engine)),
    "",
    paste0("# ", c(poisson = "Poisson", quasipoisson = "Quasi-Poisson", negbin = "Negative binomial")[[o$family]], " regression: ", dv, " on ", paste(c(cov, fac), collapse = ", ")),
    sn_prep_code("d", ctx$data, c(dv, cov, fac, ex), meta, factors = fac),
    if (o$family == "negbin") paste0("fit <- glm.nb(", f, ", data = d)") else paste0("fit <- glm(", f, ", data = d, family = ", o$family, ")"),
    paste0("coefs <- cbind(coef(summary(fit)), confint.default(fit, level = ", cl, "))"),
    "dispersion <- sum(residuals(fit, type = \"pearson\")^2) / df.residual(fit)",
    if (o$family != "quasipoisson") c(
      paste0("null <- update(fit, . ~ ", if (length(ex)) paste0("offset(log(", sn_name(ex), "))") else "1", ")"),
      "lr_chi <- as.numeric(2 * (logLik(fit) - logLik(null))); lr_df <- attr(logLik(fit), \"df\") - attr(logLik(null), \"df\")"),
    if ("residuals" %in% o$plot) sn_resid_plot_code(ctx$plot_engine, resid = "residuals(fit, type = \"deviance\")"),
    if ("coef" %in% o$plot) c(sn_coef_df_code(), sn_forest_plot_code(ctx$plot_engine, title = "Coefficients", xlab = paste0("Log rate (", sn_pct(o$conf_level), ")")))
  )
  list(code = code, assemble = assemble_reg_count)
}

assemble_reg_count <- function(env, o, ctx) {
  fit <- env$fit
  quasi <- o$family == "quasipoisson"
  row <- data.frame(dev = stats::deviance(fit), dfr = as.integer(stats::df.residual(fit)), disp = env$dispersion, n = as.integer(stats::nobs(fit)))
  cols <- list(sn_col("dev", "Residual deviance"), sn_col("dfr", "df", "int"), sn_col("disp", "Dispersion (Pearson χ²/df)", digits = 3))
  if (!quasi) {
    lr <- sn_lrt(env$lr_chi, env$lr_df)
    row$chi <- lr$chi; row$df <- as.integer(lr$df); row$p <- lr$p; row$aic <- stats::AIC(fit)
    cols <- c(list(sn_col("chi", "χ² (LR)"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue")), cols, list(sn_col("aic", "AIC")))
  }
  if (o$family == "negbin") { row$theta <- fit$theta; cols <- c(cols, list(sn_col("theta", "θ", digits = 3))) }
  cols <- c(cols, list(sn_col("n", "N", "int")))
  tables <- list(sn_table("fit", "Model Fit", cols, row[, vapply(cols, function(c) c$id, ""), drop = FALSE]),
    sn_tbl_coefs(env$coefs, o, if (quasi) "t" else "z", "Rate ratio",
      notes = c("Wald confidence intervals.", if (length(o$exposure)) paste0("Offset: log(", o$exposure, ")."))))
  checks <- list()
  if ("dispersion" %in% o$diagnostics) {
    over <- o$family == "poisson" && env$dispersion > 1.5
    checks <- list(sn_check("dispersion", "Overdispersion", if (over) "warn" else "ok",
      paste0("Dispersion = ", fmt_num(env$dispersion), if (over) "; the counts vary more than a Poisson model allows. Use the negative binomial or quasi-Poisson model."
             else if (o$family == "poisson") "; close to 1, as a Poisson model assumes." else "; this model allows for overdispersion.")))
  }
  cf <- env$coefs[-1, , drop = FALSE]; sig <- rownames(cf)[cf[, 4] < 0.05]
  text <- paste0(if (!quasi) paste0("The model ", if (lr$p < 0.05) "fit significantly better than" else "did not fit significantly better than",
    " the null model, χ²(", lr$df, ") = ", fmt_num(lr$chi), ", ", apa_p(lr$p), ". "),
    if (length(sig)) paste0("Significant predictors (rate ratio): ", paste0(sig, " (", fmt_num(exp(cf[sig, 1]), 2), ")", collapse = ", "), ".") else "No individual predictor was significant.")
  sn_result(tables = tables, assumptions = checks, plots = sn_plots(env, ctx, list(p_resid = "Residuals vs fitted", p_coef = "Coefficients")), interpretation = text)
}
