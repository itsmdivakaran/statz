# Linear mixed model (lmerTest) with Satterthwaite tests, random effects, R² and ICC

codegen_mixed_linear <- function(o, meta, ctx) {
  sn_need_predictors(o)
  dv <- o$dv; cov <- o$covariates; fac <- o$factors; g <- o$cluster
  terms <- c(cov, fac, o$interactions)
  dg <- o$diagnostics
  f <- paste0(sn_formula(sn_name(dv), terms), " + ", sn_random_term(g, o$random_slopes))
  code <- sn_code(
    sn_libs(c("lmerTest", if (length(o$plot)) ctx$plot_engine)),
    "",
    paste0("# Linear mixed model: ", dv, " with observations grouped by ", g),
    sn_prep_code("d", ctx$data, c(dv, cov, fac, g), meta, factors = c(fac, g)),
    paste0("fit <- lmer(", f, ", data = d, REML = ", sn_lit(o$method == "REML"), ")"),
    paste0("coefs <- cbind(coef(summary(fit)), confint(fit, parm = \"beta_\", method = \"Wald\", level = ", sn_lit(o$conf_level), "))"),
    "term_tests <- as.data.frame(anova(fit))  # Type III, Satterthwaite df",
    "random_effects <- as.data.frame(VarCorr(fit))",
    if (o$r2) c("r2 <- performance::r2_nakagawa(fit)", "icc <- performance::icc(fit)"),
    if ("singular" %in% dg) "singular <- isSingular(fit)",
    if ("normality" %in% dg) "normality <- shapiro.test(residuals(fit))",
    if (any(c("residuals", "qq") %in% o$plot)) sn_resid_plot_code(ctx$plot_engine),
    if ("qq" %in% o$plot) sn_qq_plot_code(ctx$plot_engine),
    if ("coef" %in% o$plot) c(sn_coef_df_code(ci = c(6, 7)), sn_forest_plot_code(ctx$plot_engine, title = "Fixed effects", xlab = paste0("B (", sn_pct(o$conf_level), ")")))
  )
  list(code = code, assemble = assemble_mixed_linear)
}

assemble_mixed_linear <- function(env, o, ctx) {
  fit <- env$fit; cf <- env$coefs
  rows <- sn_coef_rows(cf[, 1:5, drop = FALSE], cf[, 6:7, drop = FALSE], df_col = 3)
  r2 <- sn_get(env, "r2"); icc <- sn_get(env, "icc")
  num <- function(x) if (is.null(x) || !is.numeric(x) || !length(x) || is.na(x[1])) NULL else unname(x[1])
  fit_tb <- sn_tbl_wide("fit", "Model Fit",
    list(sn_col("r2m", "R² marginal", digits = 3), sn_col("r2c", "R² conditional", digits = 3), sn_col("icc", "ICC", digits = 3),
         sn_col("aic", "AIC"), sn_col("bic", "BIC"), sn_col("ll", "Log-likelihood"), sn_col("n", "N", "int"), sn_col("g", "Groups", "int")),
    list(r2m = num(r2$R2_marginal), r2c = num(r2$R2_conditional), icc = if (is.list(icc)) num(icc$ICC_adjusted),
         aic = stats::AIC(fit), bic = stats::BIC(fit), ll = as.numeric(stats::logLik(fit)), n = as.integer(stats::nobs(fit)),
         g = as.integer(lme4::ngrps(fit)[1])))
  tt <- env$term_tests
  tables <- list(fit_tb,
    sn_table("coefficients", "Fixed Effects", sn_coef_cols(rows, stat = "t", pct = sn_pct(o$conf_level)), rows,
      notes = c("Satterthwaite degrees of freedom; Wald confidence intervals.", if (length(o$factors)) "Factor terms compare each level with the first (reference) level.")),
    sn_table("tests", "Tests of Fixed Effects (Type III)", list(sn_col("term", "Term", "text"), sn_col("F", "F"), sn_col("df1", "df1", "int"), sn_col("df2", "df2"), sn_col("p", "p", "pvalue")),
      data.frame(term = rownames(tt), F = tt[["F value"]], df1 = as.integer(tt[["NumDF"]]), df2 = tt[["DenDF"]], p = tt[["Pr(>F)"]], row.names = NULL)),
    sn_tbl_random(env$random_effects))
  checks <- list()
  sg <- sn_get(env, "singular")
  if (!is.null(sg)) checks <- c(checks, list(sn_check("singular", "Singular fit", if (sg) "warn" else "ok",
    if (sg) "The fit is singular: a random-effect variance is near zero or a correlation is near ±1. Simplify the random effects." else "The random-effects structure is estimable (no singular fit).")))
  nm <- sn_get(env, "normality")
  if (!is.null(nm)) checks <- c(checks, list(sn_chk_p("normality", "Normality of residuals (Shapiro-Wilk)", nm$p.value,
    "No evidence against normal residuals.", "Residuals depart from normality; check the Q-Q plot.", nm$statistic, "W")))
  sig <- rownames(tt)[tt[["Pr(>F)"]] < 0.05]
  text <- paste0("A linear mixed model with a random intercept", if (length(o$random_slopes)) paste0(" and random slope", if (length(o$random_slopes) > 1) "s", " for ", paste(o$random_slopes, collapse = ", ")),
    " for ", o$cluster, " was fitted by ", if (o$method == "REML") "REML" else "maximum likelihood", " (", stats::nobs(fit), " observations, ", lme4::ngrps(fit)[1], " groups). ",
    if (length(sig)) paste0("Significant fixed effects: ", paste(sig, collapse = ", "), ". ") else "No fixed effect was significant. ",
    if (!is.null(num(r2$R2_marginal))) paste0("Fixed effects explained ", fmt_num(100 * r2$R2_marginal, 1), "% of the variance",
      if (!is.null(num(r2$R2_conditional))) paste0("; fixed and random effects together ", fmt_num(100 * r2$R2_conditional, 1), "%"), "."))
  sn_result(tables = tables, assumptions = checks,
    plots = sn_plots(env, ctx, list(p_resid = "Residuals vs fitted", p_qq = "Q-Q plot of residuals", p_coef = "Fixed effects")), interpretation = text)
}
