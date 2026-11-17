# One-way ANOVA (Fisher / Welch / Kruskal-Wallis) with post-hoc tests

codegen_anova_oneway <- function(o, meta, ctx) {
  dv <- o$dv; g <- o$group
  f <- paste0(sn_name(dv), " ~ ", sn_name(g))
  cl <- sn_lit(o$conf_level)
  need_fit <- "fisher" %in% o$test || length(o$effect_size) || o$posthoc == "tukey" ||
    "normality" %in% o$assumptions
  code <- sn_code(
    sn_libs(c(if (length(o$effect_size)) "effectsize", if ("levene" %in% o$assumptions) "car",
              if (o$plot != "none") ctx$plot_engine)),
    "",
    paste0("# One-way ANOVA: ", dv, " by ", g),
    paste0("d <- subset(", ctx$data, ", !is.na(", sn_name(dv), ") & !is.na(", sn_name(g), "))"),
    sn_factor_code("d", g, meta),
    if (o$descriptives) sn_group_desc_code("desc", "d", dv, g),
    if (need_fit) paste0("fit <- aov(", f, ", data = d)"),
    if ("fisher" %in% o$test) "anova_table <- summary(fit)[[1]]",
    if ("welch" %in% o$test) paste0("welch <- oneway.test(", f, ", data = d, var.equal = FALSE)"),
    if ("kruskal" %in% o$test) paste0("kw <- kruskal.test(", f, ", data = d)"),
    if ("eta_sq" %in% o$effect_size) paste0("eta <- eta_squared(fit, partial = FALSE, ci = ", cl, ", alternative = \"two.sided\")"),
    if ("omega_sq" %in% o$effect_size) paste0("omega <- omega_squared(fit, partial = FALSE, ci = ", cl, ", alternative = \"two.sided\")"),
    switch(o$posthoc,
      tukey = paste0("posthoc <- TukeyHSD(fit, conf.level = ", cl, ")"),
      bonferroni = , holm = paste0("posthoc <- pairwise.t.test(", sn_ref("d", dv), ", ", sn_ref("d", g),
                                   ", p.adjust.method = ", sn_lit(o$posthoc), ", pool.sd = TRUE)"),
      games_howell = c(
        "# Games-Howell: pairwise Welch comparisons with a studentized-range p-value",
        "games_howell <- function(y, g, conf.level = 0.95) {",
        "  n <- tapply(y, g, length); m <- tapply(y, g, mean); v <- tapply(y, g, var)",
        "  pairs <- t(combn(levels(g), 2))",
        "  do.call(rbind, lapply(seq_len(nrow(pairs)), function(i) {",
        "    a <- pairs[i, 1]; b <- pairs[i, 2]",
        "    se <- sqrt(v[[a]] / n[[a]] + v[[b]] / n[[b]])",
        "    df <- se^4 / ((v[[a]] / n[[a]])^2 / (n[[a]] - 1) + (v[[b]] / n[[b]])^2 / (n[[b]] - 1))",
        "    diff <- m[[b]] - m[[a]]",
        "    crit <- qtukey(conf.level, length(n), df) / sqrt(2)",
        "    data.frame(comparison = paste(b, \"-\", a), diff = diff, lower = diff - crit * se, upper = diff + crit * se,",
        "               p = ptukey(abs(diff) / se * sqrt(2), length(n), df, lower.tail = FALSE))",
        "  }))",
        "}",
        paste0("posthoc <- games_howell(", sn_ref("d", dv), ", ", sn_ref("d", g), ", conf.level = ", cl, ")")),
      dunn = c(
        "# Dunn's test: pairwise z-tests on mean ranks, with tie correction",
        "dunn_test <- function(y, g, method = \"holm\") {",
        "  r <- rank(y); n <- tapply(y, g, length); mr <- tapply(r, g, mean); N <- length(y)",
        "  ties <- table(y); tie_adj <- sum(ties^3 - ties) / (12 * (N - 1))",
        "  pairs <- t(combn(levels(g), 2))",
        "  z <- apply(pairs, 1, function(p) (mr[[p[1]]] - mr[[p[2]]]) /",
        "    sqrt((N * (N + 1) / 12 - tie_adj) * (1 / n[[p[1]]] + 1 / n[[p[2]]])))",
        "  p <- 2 * pnorm(abs(z), lower.tail = FALSE)",
        "  data.frame(comparison = paste(pairs[, 1], \"-\", pairs[, 2]), z = z, p = p, p_adj = p.adjust(p, method))",
        "}",
        paste0("posthoc <- dunn_test(", sn_ref("d", dv), ", ", sn_ref("d", g), ")")),
      NULL),
    if ("normality" %in% o$assumptions) "normality <- shapiro.test(residuals(fit))",
    if ("levene" %in% o$assumptions) sn_levene_code("levene", "d", dv, g),
    sn_plot_code(ctx$plot_engine, o$plot, "d", x = g, y = dv,
                 xlab = sn_label(meta, g), ylab = sn_label(meta, dv))
  )
  list(code = code, assemble = assemble_anova_oneway)
}

assemble_anova_oneway <- function(env, o, ctx) {
  pct <- paste0(round(100 * o$conf_level), "% CI")
  tables <- list()
  if (o$descriptives) tables$desc <- sn_tbl_group_desc(list(list(var = o$dv, obj = env$desc)))
  if ("fisher" %in% o$test) {
    a <- env$anova_table
    eta <- sn_get(env, "eta"); omega <- sn_get(env, "omega")
    rows <- data.frame(
      source = c(o$group, "Residuals"), ss = a[["Sum Sq"]], df = as.integer(a[["Df"]]),
      ms = a[["Mean Sq"]], F = a[["F value"]], p = a[["Pr(>F)"]],
      eta = c(if (is.null(eta)) NA else eta[[2]][1], NA),
      eta_ci = I(list(if (is.null(eta)) c(NA, NA) else c(eta$CI_low[1], eta$CI_high[1]), c(NA, NA))),
      omega = c(if (is.null(omega)) NA else omega[[2]][1], NA),
      omega_ci = I(list(if (is.null(omega)) c(NA, NA) else c(omega$CI_low[1], omega$CI_high[1]), c(NA, NA))))
    cols <- list(sn_col("source", "Source", "text"), sn_col("ss", "Sum of squares"), sn_col("df", "df", "int"),
      sn_col("ms", "Mean square"), sn_col("F", "F"), sn_col("p", "p", "pvalue"))
    if (!is.null(eta)) cols <- c(cols, list(sn_col("eta", "η²", digits = 3), sn_col("eta_ci", pct, "ci", 3)))
    if (!is.null(omega)) cols <- c(cols, list(sn_col("omega", "ω²", digits = 3), sn_col("omega_ci", pct, "ci", 3)))
    keep <- vapply(cols, function(c) c$id, "")
    tables$anova <- sn_table("anova", "ANOVA", cols, rows[, keep, drop = FALSE])
  }
  robust <- list()
  if ("welch" %in% o$test) {
    w <- env$welch
    robust$w <- data.frame(test = "Welch", stat = unname(w$statistic), df1 = unname(w$parameter[1]),
                           df2 = unname(w$parameter[2]), p = w$p.value)
  }
  if ("kruskal" %in% o$test) {
    k <- env$kw
    robust$k <- data.frame(test = "Kruskal-Wallis H", stat = unname(k$statistic), df1 = unname(k$parameter),
                           df2 = NA_real_, p = k$p.value)
  }
  if (length(robust)) tables$robust <- sn_table("robust", "Robust Tests", list(
    sn_col("test", "Test", "text"), sn_col("stat", "Statistic"), sn_col("df1", "df1"), sn_col("df2", "df2"),
    sn_col("p", "p", "pvalue")), do.call(rbind, unname(robust)))
  ph <- sn_get(env, "posthoc")
  if (!is.null(ph)) tables$posthoc <- if (o$posthoc == "tukey") {
    m <- ph[[1]]
    sn_table("posthoc", "Post-hoc Comparisons (Tukey HSD)", list(
      sn_col("comparison", "Comparison", "text"), sn_col("diff", "Mean difference"), sn_col("ci", pct, "ci"),
      sn_col("p", "p (adjusted)", "pvalue")),
      data.frame(comparison = gsub("-", " − ", rownames(m), fixed = TRUE), diff = m[, "diff"],
                 ci = I(lapply(seq_len(nrow(m)), function(i) unname(m[i, c("lwr", "upr")]))),
                 p = m[, "p adj"], row.names = NULL))
  } else if (o$posthoc == "games_howell") {
    sn_table("posthoc", "Post-hoc Comparisons (Games-Howell)", list(
      sn_col("comparison", "Comparison", "text"), sn_col("diff", "Mean difference"), sn_col("ci", pct, "ci"),
      sn_col("p", "p (adjusted)", "pvalue")),
      data.frame(comparison = gsub(" - ", " − ", ph$comparison, fixed = TRUE), diff = ph$diff,
                 ci = I(lapply(seq_len(nrow(ph)), function(i) c(ph$lower[i], ph$upper[i]))), p = ph$p, row.names = NULL),
      notes = "Does not assume equal variances or equal group sizes.")
  } else if (o$posthoc == "dunn") {
    sn_table("posthoc", "Post-hoc Comparisons (Dunn)", list(
      sn_col("comparison", "Comparison", "text"), sn_col("z", "z"), sn_col("p", "p", "pvalue"),
      sn_col("p_adj", "p (Holm)", "pvalue")),
      data.frame(comparison = gsub(" - ", " − ", ph$comparison, fixed = TRUE), z = ph$z, p = ph$p, p_adj = ph$p_adj, row.names = NULL),
      notes = "Pairwise comparisons of mean ranks; use after a Kruskal-Wallis test.")
  } else {
    pv <- ph$p.value
    idx <- which(!is.na(pv), arr.ind = TRUE)
    sn_table("posthoc", paste0("Post-hoc Comparisons (", tools::toTitleCase(o$posthoc), ")"), list(
      sn_col("comparison", "Comparison", "text"), sn_col("p", "p (adjusted)", "pvalue")),
      data.frame(comparison = paste(rownames(pv)[idx[, 1]], "−", colnames(pv)[idx[, 2]]),
                 p = pv[idx], row.names = NULL),
      notes = "Pairwise t-tests using the pooled SD.")
  }
  p <- sn_get(env, "p")
  sn_result(
    tables = unname(tables),
    assumptions = list(
      if (!is.null(env$normality)) sn_chk_normality(list(list(var = "Residuals", obj = env$normality))),
      if (!is.null(env$levene)) sn_chk_levene(list(list(var = o$dv, obj = env$levene)),
                                              welch = "welch" %in% o$test)),
    plots = list(if (!is.null(p)) ctx$plot(p, paste(o$dv, "by", o$group))),
    interpretation = interpret_anova_oneway(env, o)
  )
}

interpret_anova_oneway <- function(env, o) {
  parts <- character()
  if ("fisher" %in% o$test) {
    a <- env$anova_table; eta <- sn_get(env, "eta")
    parts <- c(parts, paste0("A one-way ANOVA ", if (a[["Pr(>F)"]][1] < 0.05) "showed a significant" else
      "did not show a significant", " effect of ", o$group, " on ", o$dv, ", F(", a$Df[1], ", ", a$Df[2], ") = ",
      fmt_num(a[["F value"]][1]), ", ", apa_p(a[["Pr(>F)"]][1]),
      if (!is.null(eta)) paste0(", η² = ", fmt_num(eta[[2]][1], 2)), "."))
  }
  if ("welch" %in% o$test) {
    w <- env$welch
    parts <- c(parts, paste0("Welch's test, which does not assume equal variances, gave F(",
      fmt_num(w$parameter[1], 0), ", ", fmt_num(w$parameter[2]), ") = ", fmt_num(w$statistic), ", ",
      apa_p(w$p.value), "."))
  }
  ph <- sn_get(env, "posthoc")
  if (o$posthoc == "tukey" && !is.null(ph)) {
    m <- ph[[1]]; sig <- rownames(m)[m[, "p adj"] < 0.05]
    parts <- c(parts, if (length(sig)) paste0("Tukey post-hoc comparisons showed significant differences for ",
      paste(gsub("-", " vs ", sig, fixed = TRUE), collapse = "; "), ".")
      else "No pairwise difference was significant after Tukey adjustment.")
  }
  if (!length(parts)) return(NULL)
  paste(parts, collapse = " ")
}
