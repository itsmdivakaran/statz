# Linear regression with standardized coefficients and diagnostics

codegen_reg_linear <- function(o, meta, ctx) {
  sn_need_predictors(o)
  dv <- o$dv; cov <- o$covariates; fac <- o$factors
  terms <- c(cov, fac, o$interactions)
  cl <- sn_lit(o$conf_level)
  dg <- o$diagnostics
  use_car <- o$anova || any(c("vif", "bp") %in% dg)
  code <- sn_code(
    sn_libs(c(if (use_car) "car", if (length(o$plot)) ctx$plot_engine)),
    "",
    paste0("# Linear regression: ", dv, " on ", paste(c(cov, fac), collapse = ", ")),
    sn_prep_code("d", ctx$data, c(dv, cov, fac), meta, factors = fac),
    paste0("fit <- lm(", sn_formula(sn_name(dv), terms), ", data = d)"),
    paste0("coefs <- cbind(coef(summary(fit)), confint(fit, level = ", cl, "))"),
    if (o$std_beta) c(
      "# Standardized coefficients: refit with the outcome and continuous predictors scaled",
      paste0("d_std <- d; num <- ", sn_lit(c(dv, cov))),
      "d_std[num] <- lapply(d_std[num], function(v) as.numeric(scale(v)))",
      "std_beta <- coef(update(fit, data = d_std))"),
    "fit_summary <- summary(fit)",
    if (o$anova) "term_anova <- as.data.frame(Anova(fit, type = 2))",
    if ("vif" %in% dg && length(terms) >= 2) "vif_values <- vif(fit)",
    if ("normality" %in% dg) "normality <- shapiro.test(residuals(fit))",
    if ("bp" %in% dg) "bp <- ncvTest(fit)",
    if ("dw" %in% dg) "dw <- sum(diff(residuals(fit))^2) / sum(residuals(fit)^2)",
    if ("cook" %in% dg) "cooks <- cooks.distance(fit)",
    if (any(c("residuals", "qq") %in% o$plot)) sn_resid_plot_code(ctx$plot_engine),
    if ("qq" %in% o$plot) sn_qq_plot_code(ctx$plot_engine),
    if ("coef" %in% o$plot) c(sn_coef_df_code(), sn_forest_plot_code(ctx$plot_engine, title = "Coefficients", xlab = paste0("B (", sn_pct(o$conf_level), ")")))
  )
  list(code = code, assemble = assemble_reg_linear)
}

assemble_reg_linear <- function(env, o, ctx) {
  cf <- env$coefs; s <- env$fit_summary; fit <- env$fit
  rows <- sn_coef_rows(cf[, 1:4, drop = FALSE], cf[, 5:6, drop = FALSE])
  cols <- sn_coef_cols(rows, stat = "t", pct = sn_pct(o$conf_level))
  sb <- sn_get(env, "std_beta")
  if (!is.null(sb)) {
    rows$beta <- unname(sb[rows$term]); rows$beta[rows$term == "(Intercept)"] <- NA
    cols <- append(cols, list(sn_col("beta", "β", digits = 3)), after = 3)
    rows <- rows[, vapply(cols, function(c) c$id, ""), drop = FALSE]
  }
  f <- s$fstatistic
  fit_tb <- sn_table("fit", "Model Fit", list(sn_col("r2", "R²", digits = 3), sn_col("adj", "Adjusted R²", digits = 3), sn_col("rmse", "Residual SE", digits = 3),
    sn_col("F", "F"), sn_col("df1", "df1", "int"), sn_col("df2", "df2", "int"), sn_col("p", "p", "pvalue"), sn_col("aic", "AIC"), sn_col("n", "N", "int")),
    data.frame(r2 = s$r.squared, adj = s$adj.r.squared, rmse = s$sigma, F = unname(f[1]), df1 = as.integer(f[2]), df2 = as.integer(f[3]),
               p = stats::pf(f[1], f[2], f[3], lower.tail = FALSE), aic = stats::AIC(fit), n = as.integer(stats::nobs(fit)), row.names = NULL))
  tables <- list(fit_tb, sn_table("coefficients", "Coefficients", cols, rows,
    notes = if (length(o$factors)) "Factor terms compare each level with the first (reference) level."))
  ta <- sn_get(env, "term_anova")
  if (!is.null(ta)) tables <- c(tables, list(sn_table("anova", "ANOVA (Type II)", list(sn_col("term", "Term", "text"), sn_col("ss", "Sum of squares"),
    sn_col("df", "df", "int"), sn_col("F", "F"), sn_col("p", "p", "pvalue")),
    data.frame(term = rownames(ta), ss = ta[["Sum Sq"]], df = as.integer(ta[["Df"]]), F = ta[["F value"]], p = ta[["Pr(>F)"]], row.names = NULL))))
  checks <- list(sn_chk_vif(sn_get(env, "vif_values")))
  nm <- sn_get(env, "normality"); bp <- sn_get(env, "bp"); dw <- sn_get(env, "dw"); ck <- sn_get(env, "cooks")
  if (!is.null(nm)) checks <- c(checks, list(sn_chk_p("normality", "Normality of residuals (Shapiro-Wilk)", nm$p.value,
    "No evidence against normal residuals.", "Residuals depart from normality; check the Q-Q plot. Large samples tolerate mild departures.", nm$statistic, "W")))
  if (!is.null(bp)) checks <- c(checks, list(sn_chk_p("bp", "Constant variance (Breusch-Pagan)", bp$p, "No evidence of heteroscedasticity.",
    "Residual variance changes with the fitted values; consider robust standard errors or a transformation.", bp$ChiSquare, "χ²", bp$Df)))
  if (!is.null(dw)) checks <- c(checks, list(sn_check("dw", "Independence (Durbin-Watson)", if (dw < 1.5 || dw > 2.5) "warn" else "ok",
    paste0("Durbin-Watson = ", fmt_num(dw), if (dw < 1.5 || dw > 2.5) "; residuals may be autocorrelated (values near 2 indicate independence)." else "; no sign of autocorrelation."))))
  if (!is.null(ck)) {
    cut <- 4 / length(ck); top <- utils::head(sort(ck, decreasing = TRUE), 5)
    checks <- c(checks, list(sn_check("cook", "Influential cases (Cook's distance)", if (max(ck) > 1) "warn" else "ok",
      paste0(sum(ck > cut), " case(s) exceed 4/n = ", fmt_num(cut, 3), "; the largest Cook's distance is ", fmt_num(max(ck), 3),
             if (max(ck) > 1) ", above 1, so single cases strongly influence the fit." else "."),
      sn_table("cook", "Largest Cook's Distances", list(sn_col("case", "Row", "text"), sn_col("d", "Cook's D", digits = 3)),
               data.frame(case = names(top), d = unname(top))))))
  }
  pr <- rows[rows$term != "(Intercept)", ]
  sig <- pr$term[pr$p < 0.05]
  text <- paste0("The model explained ", fmt_num(100 * s$r.squared, 1), "% of the variance in ", o$dv, " (adjusted R² = ", fmt_num(s$adj.r.squared, 2),
    "), F(", f[2], ", ", f[3], ") = ", fmt_num(f[1]), ", ", apa_p(stats::pf(f[1], f[2], f[3], lower.tail = FALSE)), ". ",
    if (length(sig)) paste0("Significant predictors: ", paste(sig, collapse = ", "), ".") else "No individual predictor was significant.")
  sn_result(tables = tables, assumptions = checks,
    plots = sn_plots(env, ctx, list(p_resid = "Residuals vs fitted", p_qq = "Q-Q plot of residuals", p_coef = "Coefficients")), interpretation = text)
}
