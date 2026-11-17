# Independent samples t-test (Welch / Student / Mann-Whitney U)

codegen_ttest_ind <- function(o, meta, ctx) {
  g <- o$group
  n <- length(o$dv)
  es_fn <- switch(o$effect_size, cohens_d = "cohens_d", hedges_g = "hedges_g", NULL)
  alt <- sn_lit(o$alternative)
  cl <- sn_lit(o$conf_level)
  blocks <- lapply(seq_len(n), function(i) {
    dv <- o$dv[[i]]
    s <- sn_suffix(i, n)
    d <- paste0("d", s)
    f <- paste0(sn_name(dv), " ~ ", sn_name(g))
    sn_code(
      paste0("# Independent samples t-test: ", dv, " by ", g),
      paste0(d, " <- subset(", ctx$data, ", !is.na(", sn_name(dv), ") & !is.na(", sn_name(g), "))"),
      sn_factor_code(d, g, meta),
      if (o$descriptives) sn_group_desc_code(paste0("desc", s), d, dv, g),
      if ("welch" %in% o$test) paste0("welch", s, " <- t.test(", f, ", data = ", d,
        ", var.equal = FALSE,\n  alternative = ", alt, ", conf.level = ", cl, ")"),
      if ("student" %in% o$test) paste0("student", s, " <- t.test(", f, ", data = ", d,
        ", var.equal = TRUE,\n  alternative = ", alt, ", conf.level = ", cl, ")"),
      if ("mann_whitney" %in% o$test) paste0("mw", s, " <- wilcox.test(", f, ", data = ", d,
        ", exact = FALSE, conf.int = TRUE,\n  alternative = ", alt, ", conf.level = ", cl, ")"),
      if (!is.null(es_fn) && any(c("welch", "student") %in% o$test))
        paste0("es", s, " <- ", es_fn, "(", f, ", data = ", d, ", ci = ", cl, ")"),
      if ("mann_whitney" %in% o$test)
        paste0("rb", s, " <- rank_biserial(", f, ", data = ", d, ", ci = ", cl, ")"),
      if ("normality" %in% o$assumptions) sn_normality_code(paste0("normality", s), d, dv, g),
      if ("levene" %in% o$assumptions) sn_levene_code(paste0("levene", s), d, dv, g),
      sn_plot_code(ctx$plot_engine, o$plot, d, x = g, y = dv, obj = paste0("p", s),
                   xlab = sn_label(meta, g), ylab = sn_label(meta, dv))
    )
  })
  pkgs <- c(if (!is.null(es_fn) || "mann_whitney" %in% o$test) "effectsize",
            if ("levene" %in% o$assumptions) "car",
            if (o$plot != "none") ctx$plot_engine)
  list(code = sn_code(sn_libs(pkgs), "", paste(unlist(blocks), collapse = "\n\n")),
       assemble = assemble_ttest_ind)
}

assemble_ttest_ind <- function(env, o, ctx) {
  n <- length(o$dv)
  pct <- paste0(round(100 * o$conf_level), "% CI")
  es_label <- switch(o$effect_size, cohens_d = "Cohen's d", hedges_g = "Hedges' g", "")
  rows <- list(); desc <- list(); norm <- list(); lev <- list(); plots <- list()
  for (i in seq_len(n)) {
    s <- sn_suffix(i, n)
    dv <- o$dv[[i]]
    es <- sn_get(env, paste0("es", s))
    for (tn in intersect(c("welch", "student"), o$test)) {
      tt <- sn_get(env, paste0(tn, s))
      rows[[length(rows) + 1L]] <- data.frame(
        var = dv, test = if (tn == "welch") "Welch" else "Student",
        stat = unname(tt$statistic), df = unname(tt$parameter), p = tt$p.value,
        diff = unname(tt$estimate[1] - tt$estimate[2]),
        ci = I(list(unname(as.numeric(tt$conf.int)))),
        es_type = es_label, es = if (!is.null(es)) es[[1]][1] else NA_real_,
        es_ci = I(list(if (!is.null(es)) c(es$CI_low[1], es$CI_high[1]) else c(NA, NA))))
    }
    if ("mann_whitney" %in% o$test) {
      mw <- sn_get(env, paste0("mw", s)); rb <- sn_get(env, paste0("rb", s))
      rows[[length(rows) + 1L]] <- data.frame(
        var = dv, test = "Mann-Whitney U", stat = unname(mw$statistic), df = NA_real_,
        p = mw$p.value, diff = unname(mw$estimate), ci = I(list(unname(as.numeric(mw$conf.int)))),
        es_type = "Rank-biserial r", es = rb[[1]][1], es_ci = I(list(c(rb$CI_low[1], rb$CI_high[1]))))
    }
    if (o$descriptives) desc[[i]] <- list(var = dv, obj = sn_get(env, paste0("desc", s)))
    if ("normality" %in% o$assumptions) norm[[i]] <- list(var = dv, obj = sn_get(env, paste0("normality", s)))
    if ("levene" %in% o$assumptions) lev[[i]] <- list(var = dv, obj = sn_get(env, paste0("levene", s)))
    p <- sn_get(env, paste0("p", s))
    if (!is.null(p)) plots[[i]] <- ctx$plot(p, paste(dv, "by", o$group))
  }
  main <- if (length(rows)) sn_table("ttest", "Independent Samples T-Test", list(
    sn_col("var", "Variable", "text"), sn_col("test", "Test", "text"),
    sn_col("stat", "Statistic"), sn_col("df", "df"), sn_col("p", "p", "pvalue"),
    sn_col("diff", "Difference"), sn_col("ci", pct, "ci"),
    sn_col("es_type", "Effect size", "text"), sn_col("es", "Estimate"), sn_col("es_ci", pct, "ci")),
    do.call(rbind, rows),
    notes = c(
      "Difference = group 1 − group 2 (Hodges-Lehmann estimate for Mann-Whitney U).",
      if ("welch" %in% o$test) "Welch's t-test does not assume equal variances.",
      if (o$alternative != "two.sided") paste0("Alternative hypothesis: ", o$alternative, ".")))
  sn_result(
    tables = c(list(if (o$descriptives) sn_tbl_group_desc(desc)), list(main)),
    assumptions = list(
      if (length(norm)) sn_chk_normality(norm),
      if (length(lev)) sn_chk_levene(lev, welch = "welch" %in% o$test)),
    plots = plots,
    interpretation = interpret_ttest_ind(env, o)
  )
}

interpret_ttest_ind <- function(env, o) {
  n <- length(o$dv)
  paras <- vapply(seq_len(n), function(i) {
    s <- sn_suffix(i, n)
    dv <- o$dv[[i]]
    tn <- intersect(c("welch", "student"), o$test)[1]
    desc <- sn_get(env, paste0("desc", s))
    if (is.na(tn) || is.null(desc)) return("")
    tt <- sn_get(env, paste0(tn, s)); es <- sn_get(env, paste0("es", s))
    m <- desc[[ncol(desc)]]; lv <- as.character(desc[[1]])
    grp <- function(k) paste0(lv[k], " (M = ", fmt_num(m[k, "mean"]), ", SD = ", fmt_num(m[k, "sd"]),
                              ", n = ", m[k, "n"], ")")
    es_txt <- if (!is.null(es)) paste0(", ", if (o$effect_size == "hedges_g") "Hedges' g" else "Cohen's d",
      " = ", fmt_num(es[[1]][1]), ", ", round(100 * o$conf_level), "% CI ",
      fmt_ci(es$CI_low[1], es$CI_high[1]), ", ", effect_label_d(es[[1]][1]), " effect") else ""
    paste0("A", if (tn == "welch") " Welch" else " Student", " independent-samples t-test showed that ",
      dv, if (tt$p.value >= 0.05) paste0(" did not differ significantly between ", grp(1), " and ", grp(2))
        else paste0(" was ", if (m[1, "mean"] < m[2, "mean"]) "lower" else "higher", " for ", grp(1),
                    " than for ", grp(2)),
      ", t(", fmt_num(tt$parameter), ") = ", fmt_num(tt$statistic), ", ", apa_p(tt$p.value),
      ", mean difference = ", fmt_num(tt$estimate[1] - tt$estimate[2]), ", ",
      round(100 * o$conf_level), "% CI ", fmt_ci(tt$conf.int[1], tt$conf.int[2]), es_txt, ".")
  }, "")
  paste(paras[nzchar(paras)], collapse = "\n\n")
}
