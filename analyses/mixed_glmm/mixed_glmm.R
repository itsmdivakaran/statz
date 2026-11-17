# Generalized linear mixed model (lme4::glmer): logistic or Poisson with random effects

codegen_mixed_glmm <- function(o, meta, ctx) {
  sn_need_predictors(o)
  dv <- o$dv; cov <- o$covariates; fac <- o$factors; g <- o$cluster
  terms <- c(cov, fac, o$interactions)
  bin <- o$family == "binomial"
  f <- paste0(sn_formula(sn_name(dv), terms), " + ", sn_random_term(g, o$random_slopes))
  code <- sn_code(
    sn_libs("lme4"),
    "",
    paste0("# ", if (bin) "Logistic" else "Poisson", " mixed model: ", dv, " with observations grouped by ", g),
    sn_prep_code("d", ctx$data, c(dv, cov, fac, g), meta, factors = c(if (bin) dv, fac, g)),
    if (bin) paste0("# Models the probability of the second category: levels(", sn_ref("d", dv), ")[2]"),
    paste0("fit <- glmer(", f, ", data = d, family = ", o$family, ")"),
    paste0("coefs <- cbind(coef(summary(fit)), confint(fit, parm = \"beta_\", method = \"Wald\", level = ", sn_lit(o$conf_level), "))"),
    "random_effects <- as.data.frame(VarCorr(fit))",
    "singular <- isSingular(fit)",
    if (!bin) "dispersion <- sum(residuals(fit, type = \"pearson\")^2) / df.residual(fit)"
  )
  list(code = code, assemble = assemble_mixed_glmm)
}

assemble_mixed_glmm <- function(env, o, ctx) {
  fit <- env$fit; bin <- o$family == "binomial"
  if (bin && nlevels(env$d[[o$dv]]) != 2) sn_abort("The dependent variable must have exactly two categories for a logistic mixed model.",
    SN_ERR$invalid_options, data = list(role = "dv", reason = "levels"))
  fit_tb <- sn_tbl_wide("fit", "Model Fit",
    list(sn_col("aic", "AIC"), sn_col("bic", "BIC"), sn_col("ll", "Log-likelihood"), sn_col("n", "N", "int"), sn_col("g", "Groups", "int")),
    list(aic = stats::AIC(fit), bic = stats::BIC(fit), ll = as.numeric(stats::logLik(fit)), n = as.integer(stats::nobs(fit)), g = as.integer(lme4::ngrps(fit)[1])))
  lv <- levels(env$d[[o$dv]])
  coef_tb <- sn_tbl_coefs(env$coefs, o, "z", if (bin) "Odds ratio" else "Rate ratio", title = "Fixed Effects",
    notes = c(if (bin) paste0("Outcome modelled: ", o$dv, " = ", lv[2], " (reference: ", lv[1], ")."), "Wald confidence intervals; estimates are conditional on the random effects."))
  checks <- list(sn_check("singular", "Singular fit", if (env$singular) "warn" else "ok",
    if (env$singular) "The fit is singular: a random-effect variance is near zero. Simplify the random effects." else "The random-effects structure is estimable (no singular fit)."))
  dp <- sn_get(env, "dispersion")
  if (!is.null(dp)) checks <- c(checks, list(sn_check("dispersion", "Overdispersion", if (dp > 1.5) "warn" else "ok",
    paste0("Pearson dispersion = ", fmt_num(dp), if (dp > 1.5) "; counts vary more than a Poisson model expects, so standard errors may be too small." else "; consistent with a Poisson model."))))
  rows <- coef_tb$rows; pr <- rows[rows$term != "(Intercept)", ]
  sig <- pr$term[pr$p < 0.05]
  text <- paste0("A ", if (bin) "logistic" else "Poisson", " mixed model with a random intercept for ", o$cluster, " was fitted (", stats::nobs(fit), " observations, ",
    lme4::ngrps(fit)[1], " groups). ", if (length(sig)) paste0("Significant fixed effects: ", paste(sig, collapse = ", "), ".") else "No fixed effect was significant.")
  sn_result(tables = list(fit_tb, coef_tb, sn_tbl_random(env$random_effects)), assumptions = checks, interpretation = text)
}
