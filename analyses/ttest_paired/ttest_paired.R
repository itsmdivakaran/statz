# Paired samples t-test (Student / Wilcoxon signed-rank)

codegen_ttest_paired <- function(o, meta, ctx) {
  v1 <- o$var1; v2 <- o$var2
  x1 <- sn_ref("d", v1); x2 <- sn_ref("d", v2)
  alt <- sn_lit(o$alternative); cl <- sn_lit(o$conf_level)
  code <- sn_code(
    sn_libs(c(if (o$effect_size != "none" || "wilcoxon" %in% o$test) "effectsize",
              if (o$plot != "none") ctx$plot_engine)),
    "",
    paste0("# Paired samples t-test: ", v1, " vs ", v2),
    paste0("d <- subset(", ctx$data, ", !is.na(", sn_name(v1), ") & !is.na(", sn_name(v2), "))"),
    paste0("d$difference <- ", x1, " - ", x2),
    if (o$descriptives) paste0("desc <- sapply(d[c(", sn_lit(v1), ", ", sn_lit(v2), ", \"difference\")], function(x)\n",
                               "  c(n = length(x), mean = mean(x), sd = sd(x), se = sd(x) / sqrt(length(x))))"),
    if ("student" %in% o$test) paste0("tt <- t.test(", x1, ", ", x2, ", paired = TRUE,\n  alternative = ", alt,
                                      ", conf.level = ", cl, ")"),
    if ("wilcoxon" %in% o$test) paste0("wsr <- wilcox.test(", x1, ", ", x2, ", paired = TRUE, exact = FALSE, conf.int = TRUE,\n",
                                       "  alternative = ", alt, ", conf.level = ", cl, ")"),
    if (o$effect_size == "cohens_dz" && "student" %in% o$test) paste0("es <- cohens_d(d$difference, ci = ", cl, ")  # dz"),
    if ("wilcoxon" %in% o$test) paste0("rb <- rank_biserial(d$difference, ci = ", cl, ")"),
    if ("normality" %in% o$assumptions) "normality <- shapiro.test(d$difference)",
    sn_plot_code(ctx$plot_engine, o$plot, "d", x = "difference",
                 title = paste0("Difference: ", v1, " − ", v2), xlab = paste(v1, "−", v2))
  )
  list(code = code, assemble = assemble_ttest_paired)
}

assemble_ttest_paired <- function(env, o, ctx) {
  pct <- paste0(round(100 * o$conf_level), "% CI")
  pair <- paste(o$var1, "−", o$var2)
  rows <- list()
  if ("student" %in% o$test) {
    tt <- env$tt; es <- sn_get(env, "es")
    rows[[1]] <- data.frame(pair = pair, test = "Student", stat = unname(tt$statistic), df = unname(tt$parameter),
      p = tt$p.value, diff = unname(tt$estimate), ci = I(list(unname(as.numeric(tt$conf.int)))),
      es_type = if (is.null(es)) "" else "Cohen's dz", es = if (is.null(es)) NA_real_ else es[[1]][1],
      es_ci = I(list(if (is.null(es)) c(NA, NA) else c(es$CI_low[1], es$CI_high[1]))))
  }
  if ("wilcoxon" %in% o$test) {
    w <- env$wsr; rb <- env$rb
    rows[[length(rows) + 1L]] <- data.frame(pair = pair, test = "Wilcoxon W", stat = unname(w$statistic),
      df = NA_real_, p = w$p.value, diff = unname(w$estimate), ci = I(list(unname(as.numeric(w$conf.int)))),
      es_type = "Rank-biserial r", es = rb[[1]][1], es_ci = I(list(c(rb$CI_low[1], rb$CI_high[1]))))
  }
  desc <- sn_get(env, "desc")
  p <- sn_get(env, "p")
  sn_result(
    tables = list(
      if (!is.null(desc)) sn_table("descriptives", "Descriptives", list(
        sn_col("var", "Variable", "text"), sn_col("n", "N", "int"), sn_col("mean", "Mean"),
        sn_col("sd", "SD"), sn_col("se", "SE")),
        data.frame(var = c(o$var1, o$var2, "Difference"), n = as.integer(desc["n", ]), mean = desc["mean", ],
                   sd = desc["sd", ], se = desc["se", ], row.names = NULL)),
      if (length(rows)) sn_table("ttest", "Paired Samples T-Test", list(
        sn_col("pair", "Pair", "text"), sn_col("test", "Test", "text"), sn_col("stat", "Statistic"),
        sn_col("df", "df"), sn_col("p", "p", "pvalue"), sn_col("diff", "Difference"), sn_col("ci", pct, "ci"),
        sn_col("es_type", "Effect size", "text"), sn_col("es", "Estimate"), sn_col("es_ci", pct, "ci")),
        do.call(rbind, rows),
        notes = "Difference = Measure 1 − Measure 2 (pseudo-median for Wilcoxon).")),
    assumptions = list(if (!is.null(env$normality))
      sn_chk_normality(list(list(var = "Difference", obj = env$normality)))),
    plots = list(if (!is.null(p)) ctx$plot(p, paste("Difference:", pair))),
    interpretation = interpret_ttest_paired(env, o)
  )
}

interpret_ttest_paired <- function(env, o) {
  tt <- sn_get(env, "tt"); desc <- sn_get(env, "desc"); es <- sn_get(env, "es")
  if (is.null(tt) || is.null(desc)) return(NULL)
  sig <- tt$p.value < 0.05
  paste0("A paired-samples t-test showed that ", o$var1, " (M = ", fmt_num(desc["mean", 1]), ", SD = ",
    fmt_num(desc["sd", 1]), ") was ",
    if (!sig) "not significantly different from " else if (tt$estimate > 0) "significantly higher than "
    else "significantly lower than ", o$var2, " (M = ", fmt_num(desc["mean", 2]), ", SD = ",
    fmt_num(desc["sd", 2]), "), t(", fmt_num(tt$parameter, 0), ") = ", fmt_num(tt$statistic), ", ",
    apa_p(tt$p.value), ", mean difference = ", fmt_num(tt$estimate), ", ", round(100 * o$conf_level),
    "% CI ", fmt_ci(tt$conf.int[1], tt$conf.int[2]),
    if (!is.null(es)) paste0(", Cohen's dz = ", fmt_num(es[[1]][1]), ", ", effect_label_d(es[[1]][1]), " effect"),
    ", n = ", desc["n", 1], " pairs.")
}
