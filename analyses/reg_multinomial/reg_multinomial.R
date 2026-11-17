# Multinomial logistic regression via nnet::multinom

codegen_reg_multinomial <- function(o, meta, ctx) {
  sn_need_predictors(o)
  dv <- o$dv; cov <- o$covariates; fac <- o$factors
  terms <- c(cov, fac, o$interactions)
  z <- paste0("qnorm(1 - (1 - ", sn_lit(o$conf_level), ") / 2)")
  code <- sn_code(
    sn_libs("nnet"),
    "",
    paste0("# Multinomial regression: ", dv, " on ", paste(c(cov, fac), collapse = ", ")),
    sn_prep_code("d", ctx$data, c(dv, cov, fac), meta, factors = c(dv, fac)),
    paste0("fit <- multinom(", sn_formula(sn_name(dv), terms), ", data = d, trace = FALSE)"),
    "s <- summary(fit)",
    "# One row per outcome category (vs the first) and term",
    "coefs <- do.call(rbind, lapply(rownames(s$coefficients), function(lv) {",
    "  b <- s$coefficients[lv, ]; se <- s$standard.errors[lv, ]",
    "  data.frame(outcome = lv, term = names(b), estimate = b, se = se, z = b / se, p = 2 * pnorm(abs(b / se), lower.tail = FALSE),",
    paste0("             lower = b - ", z, " * se, upper = b + ", z, " * se, row.names = NULL)"),
    "}))",
    paste0("null <- multinom(", sn_name(dv), " ~ 1, data = d, trace = FALSE)"),
    "lr_chi <- deviance(null) - deviance(fit); lr_df <- fit$edf - null$edf",
    "r2_mcfadden <- 1 - deviance(fit) / deviance(null)",
    if (o$classification) paste0("class_table <- table(Observed = ", sn_ref("d", dv), ", Predicted = predict(fit))")
  )
  list(code = code, assemble = assemble_reg_multinomial)
}

assemble_reg_multinomial <- function(env, o, ctx) {
  cf <- env$coefs; fit <- env$fit
  lv <- levels(env$d[[o$dv]])
  lr <- sn_lrt(env$lr_chi, env$lr_df)
  int <- cf$term == "(Intercept)"
  rows <- data.frame(outcome = cf$outcome, term = cf$term, est = cf$estimate, se = cf$se, stat = cf$z, p = cf$p,
    ci = I(lapply(seq_len(nrow(cf)), function(i) c(cf$lower[i], cf$upper[i]))),
    exp = ifelse(int, NA, exp(cf$estimate)),
    exp_ci = I(lapply(seq_len(nrow(cf)), function(i) if (int[i]) c(NA_real_, NA_real_) else exp(c(cf$lower[i], cf$upper[i])))))
  pct <- sn_pct(o$conf_level)
  tables <- list(
    sn_table("fit", "Model Fit", list(sn_col("chi", "χ² (LR)"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue"),
      sn_col("mcf", "McFadden R²", digits = 3), sn_col("aic", "AIC"), sn_col("n", "N", "int")),
      data.frame(chi = lr$chi, df = as.integer(lr$df), p = lr$p, mcf = env$r2_mcfadden, aic = stats::AIC(fit), n = nrow(env$d))),
    sn_table("coefficients", "Coefficients", list(sn_col("outcome", o$dv, "text"), sn_col("term", "Term", "text"), sn_col("est", "B", digits = 3),
      sn_col("se", "SE", digits = 3), sn_col("stat", "z"), sn_col("p", "p", "pvalue"), sn_col("ci", pct, "ci", 3),
      sn_col("exp", "Relative risk ratio", digits = 3), sn_col("exp_ci", paste("RRR", pct), "ci", 3)), rows,
      notes = paste0("Each category of ", o$dv, " is compared with the reference category ", lv[1], ". Wald confidence intervals.")))
  ct <- sn_get(env, "class_table")
  if (!is.null(ct)) tables <- c(tables, list(sn_table("classification", "Classification Accuracy", list(sn_col("obs", "Observed", "text"),
    sn_col("n", "N", "int"), sn_col("pc", "% correct", digits = 1)),
    data.frame(obs = c(rownames(ct), "Overall"), n = as.integer(c(rowSums(ct), sum(ct))), pc = 100 * c(diag(ct) / rowSums(ct), sum(diag(ct)) / sum(ct))))))
  text <- paste0("The model ", if (lr$p < 0.05) "fit significantly better than" else "did not fit significantly better than", " the null model, χ²(", lr$df, ") = ",
    fmt_num(lr$chi), ", ", apa_p(lr$p), ", McFadden R² = ", fmt_num(env$r2_mcfadden, 2), ".")
  sn_result(tables = tables, interpretation = text)
}
