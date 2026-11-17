# One sample t-test (Student / Wilcoxon signed-rank)

codegen_ttest_one <- function(o, meta, ctx) {
  n <- length(o$dv)
  mu <- sn_lit(o$mu); alt <- sn_lit(o$alternative); cl <- sn_lit(o$conf_level)
  blocks <- lapply(seq_len(n), function(i) {
    dv <- o$dv[[i]]; s <- sn_suffix(i, n); d <- paste0("d", s); x <- sn_ref(d, dv)
    sn_code(
      paste0("# One sample t-test: ", dv, " vs ", o$mu),
      paste0(d, " <- subset(", ctx$data, ", !is.na(", sn_name(dv), "))"),
      if (o$descriptives) paste0("desc", s, " <- c(n = length(", x, "), mean = mean(", x, "), sd = sd(", x,
                                 "), se = sd(", x, ") / sqrt(length(", x, ")))"),
      if ("student" %in% o$test) paste0("tt", s, " <- t.test(", x, ", mu = ", mu,
        ", alternative = ", alt, ", conf.level = ", cl, ")"),
      if ("wilcoxon" %in% o$test) paste0("wsr", s, " <- wilcox.test(", x, ", mu = ", mu,
        ", exact = FALSE, conf.int = TRUE,\n  alternative = ", alt, ", conf.level = ", cl, ")"),
      if (o$effect_size == "cohens_d" && "student" %in% o$test)
        paste0("es", s, " <- cohens_d(", x, ", mu = ", mu, ", ci = ", cl, ")"),
      if ("wilcoxon" %in% o$test) paste0("rb", s, " <- rank_biserial(", x, ", mu = ", mu, ", ci = ", cl, ")"),
      if ("normality" %in% o$assumptions) sn_normality_code(paste0("normality", s), d, dv),
      sn_plot_code(ctx$plot_engine, o$plot, d, x = dv, obj = paste0("p", s),
                   xlab = sn_label(meta, dv), title = dv)
    )
  })
  pkgs <- c(if (o$effect_size != "none" || "wilcoxon" %in% o$test) "effectsize",
            if (o$plot != "none") ctx$plot_engine)
  list(code = sn_code(sn_libs(pkgs), "", paste(unlist(blocks), collapse = "\n\n")),
       assemble = assemble_ttest_one)
}

assemble_ttest_one <- function(env, o, ctx) {
  n <- length(o$dv)
  pct <- paste0(round(100 * o$conf_level), "% CI")
  rows <- list(); desc <- list(); norm <- list(); plots <- list()
  for (i in seq_len(n)) {
    s <- sn_suffix(i, n); dv <- o$dv[[i]]
    if ("student" %in% o$test) {
      tt <- sn_get(env, paste0("tt", s)); es <- sn_get(env, paste0("es", s))
      rows[[length(rows) + 1L]] <- data.frame(
        var = dv, test = "Student", stat = unname(tt$statistic), df = unname(tt$parameter),
        p = tt$p.value, diff = unname(tt$estimate) - o$mu,
        ci = I(list(unname(as.numeric(tt$conf.int)) - o$mu)),
        es_type = if (is.null(es)) "" else "Cohen's d", es = if (is.null(es)) NA_real_ else es[[1]][1],
        es_ci = I(list(if (is.null(es)) c(NA, NA) else c(es$CI_low[1], es$CI_high[1]))))
    }
    if ("wilcoxon" %in% o$test) {
      w <- sn_get(env, paste0("wsr", s)); rb <- sn_get(env, paste0("rb", s))
      rows[[length(rows) + 1L]] <- data.frame(
        var = dv, test = "Wilcoxon W", stat = unname(w$statistic), df = NA_real_, p = w$p.value,
        diff = unname(w$estimate) - o$mu, ci = I(list(unname(as.numeric(w$conf.int)) - o$mu)),
        es_type = "Rank-biserial r", es = rb[[1]][1], es_ci = I(list(c(rb$CI_low[1], rb$CI_high[1]))))
    }
    if (o$descriptives) {
      v <- sn_get(env, paste0("desc", s))
      desc[[i]] <- data.frame(var = dv, n = as.integer(v[["n"]]), mean = v[["mean"]], sd = v[["sd"]], se = v[["se"]])
    }
    if ("normality" %in% o$assumptions) norm[[i]] <- list(var = dv, obj = sn_get(env, paste0("normality", s)))
    p <- sn_get(env, paste0("p", s))
    if (!is.null(p)) plots[[i]] <- ctx$plot(p, dv)
  }
  sn_result(
    tables = list(
      if (o$descriptives) sn_table("descriptives", "Descriptives", list(
        sn_col("var", "Variable", "text"), sn_col("n", "N", "int"), sn_col("mean", "Mean"),
        sn_col("sd", "SD"), sn_col("se", "SE")), do.call(rbind, desc)),
      if (length(rows)) sn_table("ttest", "One Sample T-Test", list(
        sn_col("var", "Variable", "text"), sn_col("test", "Test", "text"), sn_col("stat", "Statistic"),
        sn_col("df", "df"), sn_col("p", "p", "pvalue"), sn_col("diff", "Difference"), sn_col("ci", pct, "ci"),
        sn_col("es_type", "Effect size", "text"), sn_col("es", "Estimate"), sn_col("es_ci", pct, "ci")),
        do.call(rbind, rows), notes = paste0("Test value = ", o$mu,
          ". Difference = mean − test value (pseudo-median for Wilcoxon)."))),
    assumptions = list(if (length(norm)) sn_chk_normality(norm)),
    plots = plots,
    interpretation = interpret_ttest_one(env, o)
  )
}

interpret_ttest_one <- function(env, o) {
  if (!"student" %in% o$test || !o$descriptives) return(NULL)
  n <- length(o$dv)
  paste(vapply(seq_len(n), function(i) {
    s <- sn_suffix(i, n); dv <- o$dv[[i]]
    tt <- sn_get(env, paste0("tt", s)); v <- sn_get(env, paste0("desc", s)); es <- sn_get(env, paste0("es", s))
    sig <- tt$p.value < 0.05
    paste0("A one-sample t-test showed that the mean of ", dv, " (M = ", fmt_num(v[["mean"]]), ", SD = ",
      fmt_num(v[["sd"]]), ", n = ", v[["n"]], ") was ",
      if (!sig) "not significantly different from " else if (v[["mean"]] > o$mu) "significantly higher than "
      else "significantly lower than ", o$mu, ", t(", fmt_num(tt$parameter, 0), ") = ", fmt_num(tt$statistic),
      ", ", apa_p(tt$p.value), ", ", round(100 * o$conf_level), "% CI of the difference ",
      fmt_ci(tt$conf.int[1] - o$mu, tt$conf.int[2] - o$mu),
      if (!is.null(es)) paste0(", Cohen's d = ", fmt_num(es[[1]][1]), ", ", effect_label_d(es[[1]][1]), " effect"), ".")
  }, ""), collapse = "\n\n")
}
