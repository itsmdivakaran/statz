# Wilcoxon signed-rank and sign tests for two related measurements

codegen_wilcoxon_paired <- function(o, meta, ctx) {
  x <- o$x; y <- o$y
  cl <- sn_lit(o$conf_level)
  code <- sn_code(
    sn_libs(c(if (o$effect_size && "wilcoxon" %in% o$test) "effectsize", if (o$plot != "none") ctx$plot_engine)),
    "",
    paste0("# Paired non-parametric tests: ", x, " vs ", y),
    paste0("d <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", sn_lit(c(x, y)), "]), ]"),
    paste0("d$difference <- ", sn_ref("d", x), " - ", sn_ref("d", y)),
    if (o$descriptives) paste0("desc <- sapply(d[, ", sn_lit(c(x, y, "difference")), "], function(v)\n",
                               "  c(n = length(v), median = median(v), q1 = unname(quantile(v, 0.25)), q3 = unname(quantile(v, 0.75))))"),
    if ("wilcoxon" %in% o$test) paste0("wilcoxon <- wilcox.test(", sn_ref("d", x), ", ", sn_ref("d", y),
      ", paired = TRUE, alternative = ", sn_lit(o$alternative), ",\n  conf.int = TRUE, conf.level = ", cl, ", exact = FALSE)"),
    if ("wilcoxon" %in% o$test && o$effect_size) paste0("rb <- rank_biserial(", sn_ref("d", x), ", ", sn_ref("d", y),
      ", paired = TRUE, ci = ", cl, ")"),
    if ("sign" %in% o$test) c(
      "n_pos <- sum(d$difference > 0); n_neg <- sum(d$difference < 0)",
      paste0("sign_test <- binom.test(n_pos, n_pos + n_neg, alternative = ", sn_lit(o$alternative), ")")),
    switch(o$plot,
      histogram = sn_plot_code(ctx$plot_engine, "histogram", "d", x = "difference", title = paste(x, "−", y), xlab = "Difference"),
      box_jitter = c(
        paste0("long <- data.frame(measurement = factor(rep(", sn_lit(c(x, y)), ", each = nrow(d)), levels = ", sn_lit(c(x, y)),
               "),\n  value = c(", sn_ref("d", x), ", ", sn_ref("d", y), "))"),
        sn_plot_code(ctx$plot_engine, "box_jitter", "long", x = "measurement", y = "value", title = paste(x, "and", y),
                     xlab = "Measurement", ylab = "Value")))
  )
  list(code = code, assemble = assemble_wilcoxon_paired)
}

assemble_wilcoxon_paired <- function(env, o, ctx) {
  pct <- sn_pct(o$conf_level)
  tables <- list()
  if (o$descriptives) {
    m <- t(env$desc)
    tables$desc <- sn_table("descriptives", "Descriptives", list(
      sn_col("var", "Variable", "text"), sn_col("n", "N", "int"), sn_col("median", "Median"),
      sn_col("q1", "25th percentile"), sn_col("q3", "75th percentile")),
      data.frame(var = rownames(m), n = as.integer(m[, "n"]), median = m[, "median"], q1 = m[, "q1"], q3 = m[, "q3"], row.names = NULL))
  }
  rows <- list()
  w <- sn_get(env, "wilcoxon"); rb <- sn_get(env, "rb"); s <- sn_get(env, "sign_test")
  if (!is.null(w)) rows$w <- data.frame(test = "Wilcoxon signed-rank", stat = unname(w$statistic), p = w$p.value,
    est = unname(w$estimate), ci = I(list(as.numeric(w$conf.int))),
    rb = if (is.null(rb)) NA_real_ else rb[[1]], rb_ci = I(list(if (is.null(rb)) c(NA, NA) else c(rb$CI_low, rb$CI_high))))
  if (!is.null(s)) rows$s <- data.frame(test = "Sign test", stat = unname(s$statistic), p = s$p.value,
    est = NA_real_, ci = I(list(c(NA_real_, NA_real_))), rb = NA_real_, rb_ci = I(list(c(NA_real_, NA_real_))))
  if (length(rows)) {
    cols <- list(sn_col("test", "Test", "text"), sn_col("stat", "Statistic"), sn_col("p", "p", "pvalue"))
    if (!is.null(w)) cols <- c(cols, list(sn_col("est", "Location shift"), sn_col("ci", pct, "ci")))
    if (!is.null(rb)) cols <- c(cols, list(sn_col("rb", "Rank-biserial r", digits = 3), sn_col("rb_ci", paste("r", pct), "ci", 3)))
    all <- do.call(rbind, unname(rows))
    tables$tests <- sn_table("tests", "Paired Samples Tests", cols, all[, vapply(cols, function(c) c$id, ""), drop = FALSE],
      notes = c(if (!is.null(w)) "Wilcoxon: V statistic, normal approximation with continuity correction; location shift is the Hodges-Lehmann pseudo-median of the differences.",
                if (!is.null(s)) "Sign test: statistic is the number of positive differences; ties are dropped."))
  }
  p <- sn_get(env, "p")
  text <- if (!is.null(w)) paste0("A Wilcoxon signed-rank test ", if (w$p.value < 0.05) "showed a significant" else "did not show a significant",
    " difference between ", o$x, " and ", o$y, ", V = ", fmt_num(w$statistic, 1), ", ", apa_p(w$p.value),
    if (!is.null(rb)) paste0(", rank-biserial r = ", fmt_num(rb[[1]], 2)), ".")
  sn_result(tables = unname(tables), plots = list(if (!is.null(p)) ctx$plot(p, paste(o$x, "and", o$y))), interpretation = text)
}
