# Chi-square goodness-of-fit test

codegen_chisq_gof <- function(o, meta, ctx) {
  v <- o$var
  probs <- NULL
  if (nzchar(trimws(o$expected))) {
    probs <- suppressWarnings(as.numeric(strsplit(trimws(o$expected), "[,;[:space:]]+")[[1]]))
    if (anyNA(probs) || any(probs <= 0))
      sn_abort("Expected proportions must be positive numbers separated by commas.", SN_ERR$invalid_options)
  }
  code <- sn_code(
    if (o$plot != "none") sn_libs(ctx$plot_engine),
    "",
    paste0("# Chi-square goodness of fit: ", v),
    paste0("d <- subset(", ctx$data, ", !is.na(", sn_name(v), "))"),
    sn_factor_code("d", v, meta),
    paste0("counts <- table(", sn_ref("d", v), ")"),
    if (!is.null(probs)) c(
      paste0("expected_p <- ", sn_lit(probs)),
      "stopifnot(\"Give one expected proportion per category\" = length(expected_p) == length(counts))",
      "gof <- chisq.test(counts, p = expected_p, rescale.p = TRUE)")
    else "gof <- chisq.test(counts)",
    sn_plot_code(ctx$plot_engine, o$plot, "d", x = v, title = v, xlab = sn_label(meta, v))
  )
  list(code = code, assemble = assemble_chisq_gof)
}

assemble_chisq_gof <- function(env, o, ctx) {
  g <- env$gof
  n <- sum(g$observed)
  freq <- sn_table("counts", "Observed and Expected Counts", list(
    sn_col("level", o$var, "text"), sn_col("obs", "Observed", "int"), sn_col("exp", "Expected"),
    sn_col("prop", "Observed proportion", digits = 3), sn_col("resid", "Std. residual")),
    data.frame(level = names(g$observed), obs = as.integer(g$observed), exp = as.numeric(g$expected),
               prop = as.numeric(g$observed) / n, resid = as.numeric(g$stdres), row.names = NULL))
  test <- sn_table("gof", "Goodness of Fit", list(sn_col("stat", "χ²"), sn_col("df", "df", "int"), sn_col("n", "N", "int"), sn_col("p", "p", "pvalue")),
    data.frame(stat = unname(g$statistic), df = as.integer(g$parameter), n = as.integer(n), p = g$p.value))
  low <- sum(g$expected < 5)
  chk <- sn_check("expected", "Expected counts", if (low > 0) "warn" else "ok",
    if (low > 0) paste0(low, " categor", if (low == 1) "y has" else "ies have", " an expected count below 5; the chi-square approximation may be poor.")
    else "All expected counts are at least 5.")
  p <- sn_get(env, "p")
  sn_result(tables = list(freq, test), assumptions = list(chk), plots = list(if (!is.null(p)) ctx$plot(p, o$var)),
    interpretation = paste0("The observed distribution of ", o$var, if (g$p.value < 0.05) " differed" else " did not differ",
      " significantly from the expected distribution, χ²(", g$parameter, ", N = ", n, ") = ", fmt_num(g$statistic), ", ", apa_p(g$p.value), "."))
}
