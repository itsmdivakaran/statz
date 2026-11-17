# Factorial ANOVA / ANCOVA via lm() + car::Anova(), marginal means via emmeans

codegen_anova_factorial <- function(o, meta, ctx) {
  dv <- o$dv; fac <- o$factors; cov <- o$covariates
  terms <- c(fac, cov, o$interactions)
  cl <- sn_lit(o$conf_level)
  need_emm <- o$emm || o$posthoc != "none"
  contr <- if (o$ss_type == "3") paste0(",\n  contrasts = list(", paste0(sn_name(fac), " = contr.sum", collapse = ", "), ")") else ""
  x <- fac[1]; g <- if (length(fac) > 1) fac[2]
  code <- sn_code(
    sn_libs(c("car", if (need_emm) "emmeans", if (length(o$plot)) ctx$plot_engine)),
    "",
    paste0("# ", if (length(cov)) "ANCOVA" else "ANOVA", ": ", dv, " by ", paste(c(fac, cov), collapse = ", ")),
    sn_prep_code("d", ctx$data, c(dv, fac, cov), meta),
    paste0("fit <- lm(", sn_formula(sn_name(dv), terms), ", data = d", contr, ")"),
    paste0("anova_table <- as.data.frame(Anova(fit, type = ", o$ss_type, "))"),
    "anova_table <- anova_table[rownames(anova_table) != \"(Intercept)\", ]",
    if (o$effect_size) c(
      "ss_resid <- anova_table[\"Residuals\", \"Sum Sq\"]",
      "anova_table$eta_p <- anova_table$`Sum Sq` / (anova_table$`Sum Sq` + ss_resid)",
      "anova_table[\"Residuals\", \"eta_p\"] <- NA"),
    if (need_emm) unlist(lapply(seq_along(fac), function(i) c(
      paste0("emm_", i, " <- emmeans(fit, ~ ", sn_name(fac[i]), ", level = ", cl, ")"),
      if (o$posthoc != "none") paste0("posthoc_", i, " <- pairs(emm_", i, ", adjust = ", sn_lit(o$posthoc), ")")))),
    if ("normality" %in% o$assumptions) "normality <- shapiro.test(residuals(fit))",
    if ("levene" %in% o$assumptions) paste0("levene <- leveneTest(", sn_name(dv), " ~ ", paste(sn_name(fac), collapse = " * "), ", data = d, center = median)"),
    if ("means" %in% o$plot) c(
      "# Cell means with t-based confidence intervals",
      paste0("cells <- aggregate(", sn_name(dv), " ~ ", paste(sn_name(c(x, g)), collapse = " + "), ", data = d, FUN = function(v)\n",
             "  c(mean = mean(v), half = qt(1 - (1 - ", cl, ") / 2, length(v) - 1) * sd(v) / sqrt(length(v))))"),
      paste0("cells <- data.frame(cells[", sn_lit(c(x, g)), "], mean = cells[[", length(c(x, g)) + 1L, "]][, \"mean\"],\n",
             "  lower = cells[[", length(c(x, g)) + 1L, "]][, \"mean\"] - cells[[", length(c(x, g)) + 1L, "]][, \"half\"],\n",
             "  upper = cells[[", length(c(x, g)) + 1L, "]][, \"mean\"] + cells[[", length(c(x, g)) + 1L, "]][, \"half\"])"),
      sn_gg(ctx$plot_engine,
            paste0("cells, aes(", sn_name(x), ", mean", if (!is.null(g)) paste0(", color = ", sn_name(g), ", group = ", sn_name(g)) else ", group = 1", ")"),
            c("geom_line()", "geom_point()", "geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.1)"),
            paste("Mean", dv), sn_label(meta, x), sn_label(meta, dv), "p_means")),
    if (any(c("residuals", "qq") %in% o$plot)) "resid_df <- data.frame(fitted = fitted(fit), resid = residuals(fit))",
    if ("residuals" %in% o$plot) sn_gg(ctx$plot_engine, "resid_df, aes(fitted, resid)",
      if (ctx$plot_engine == "ggnext") "geom_residual()" else c("geom_point(alpha = 0.7)", "geom_hline(yintercept = 0, linetype = 2)"),
      "Residuals vs fitted", "Fitted values", "Residuals", "p_resid"),
    if ("qq" %in% o$plot) sn_qq_plot_code(ctx$plot_engine)
  )
  list(code = code, assemble = assemble_anova_factorial)
}

assemble_anova_factorial <- function(env, o, ctx) {
  pct <- sn_pct(o$conf_level)
  a <- env$anova_table
  rows <- data.frame(source = rownames(a), ss = a[["Sum Sq"]], df = as.integer(a[["Df"]]), ms = a[["Sum Sq"]] / a[["Df"]],
                     F = a[["F value"]], p = a[["Pr(>F)"]], row.names = NULL)
  cols <- list(sn_col("source", "Source", "text"), sn_col("ss", "Sum of squares"), sn_col("df", "df", "int"),
               sn_col("ms", "Mean square"), sn_col("F", "F"), sn_col("p", "p", "pvalue"))
  if (o$effect_size) { rows$eta <- a$eta_p; cols <- c(cols, list(sn_col("eta", "η²p", digits = 3))) }
  tables <- list(sn_table("anova", if (length(o$covariates)) "ANCOVA" else "ANOVA", cols, rows,
                          notes = paste0("Type ", if (o$ss_type == "3") "III" else "II", " sums of squares.")))
  for (i in seq_along(o$factors)) {
    f <- o$factors[i]
    emm <- sn_get(env, paste0("emm_", i)); ph <- sn_get(env, paste0("posthoc_", i))
    if (o$emm && !is.null(emm)) {
      e <- as.data.frame(emm)
      tables <- c(tables, list(sn_table(paste0("emm_", i), paste0("Estimated Marginal Means: ", f), list(
        sn_col("level", f, "text"), sn_col("mean", "Mean"), sn_col("se", "SE"), sn_col("df", "df"), sn_col("ci", pct, "ci")),
        data.frame(level = as.character(e[[1]]), mean = e$emmean, se = e$SE, df = e$df,
                   ci = I(lapply(seq_len(nrow(e)), function(j) c(e$lower.CL[j], e$upper.CL[j])))))))
    }
    if (!is.null(ph)) {
      q <- as.data.frame(ph)
      tables <- c(tables, list(sn_table(paste0("posthoc_", i), paste0("Post-hoc Comparisons: ", f, " (", tools::toTitleCase(o$posthoc), ")"), list(
        sn_col("comparison", "Comparison", "text"), sn_col("diff", "Mean difference"), sn_col("se", "SE"), sn_col("df", "df"),
        sn_col("t", "t"), sn_col("p", "p (adjusted)", "pvalue")),
        data.frame(comparison = gsub(" - ", " − ", as.character(q$contrast), fixed = TRUE), diff = q$estimate, se = q$SE, df = q$df,
                   t = q$t.ratio, p = q$p.value),
        notes = if (length(o$interactions) || length(o$factors) > 1 || length(o$covariates)) "Based on estimated marginal means, averaged over the other terms.")))
    }
  }
  eff <- rows[rows$source != "Residuals", ]
  dfr <- rows$df[rows$source == "Residuals"]
  text <- paste(vapply(seq_len(nrow(eff)), function(i) paste0(
    "The effect of ", eff$source[i], " was ", if (eff$p[i] < 0.05) "" else "not ", "significant, F(", eff$df[i], ", ", dfr, ") = ",
    fmt_num(eff$F[i]), ", ", apa_p(eff$p[i]), if (o$effect_size) paste0(", η²p = ", fmt_num(eff$eta[i], 2)), "."), ""), collapse = " ")
  lev <- sn_get(env, "levene"); nm <- sn_get(env, "normality")
  sn_result(
    tables = tables,
    assumptions = list(
      if (!is.null(nm)) sn_chk_normality(list(list(var = "Residuals", obj = nm))),
      if (!is.null(lev)) sn_chk_levene(list(list(var = o$dv, obj = lev)), welch = FALSE)),
    plots = sn_plots(env, ctx, list(p_means = paste("Mean", o$dv), p_resid = "Residuals vs fitted", p_qq = "Q-Q plot of residuals")),
    interpretation = text)
}
