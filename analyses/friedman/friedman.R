# Friedman rank sum test for repeated measurements in wide format

codegen_friedman <- function(o, meta, ctx) {
  v <- o$measures
  need_long <- o$posthoc != "none" || o$plot != "none"
  code <- sn_code(
    if (o$plot != "none") sn_libs(ctx$plot_engine),
    "",
    paste0("# Friedman test: ", paste(v, collapse = ", ")),
    paste0("d <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", sn_lit(v), "]), ", sn_lit(v), "]"),
    if (o$descriptives) "desc <- sapply(d, function(v) c(n = length(v), median = median(v), q1 = unname(quantile(v, 0.25)), q3 = unname(quantile(v, 0.75))))",
    "friedman <- friedman.test(as.matrix(d))",
    if (o$kendall_w) "kendall_w <- unname(friedman$statistic) / (nrow(d) * (ncol(d) - 1))",
    if (need_long) paste0("long <- data.frame(condition = factor(rep(names(d), each = nrow(d)), levels = names(d)), value = unlist(d, use.names = FALSE))"),
    if (o$posthoc != "none") paste0("posthoc <- pairwise.wilcox.test(long$value, long$condition, paired = TRUE,\n  p.adjust.method = ",
                                     sn_lit(o$posthoc), ", exact = FALSE)"),
    if (o$plot != "none") sn_plot_code(ctx$plot_engine, o$plot, "long", x = "condition", y = "value", title = "Repeated measurements",
                                      xlab = "Measurement", ylab = "Value")
  )
  list(code = code, assemble = assemble_friedman)
}

assemble_friedman <- function(env, o, ctx) {
  f <- env$friedman; w <- sn_get(env, "kendall_w")
  tables <- list()
  if (o$descriptives) {
    m <- t(env$desc)
    tables$desc <- sn_table("descriptives", "Descriptives", list(
      sn_col("var", "Variable", "text"), sn_col("n", "N", "int"), sn_col("median", "Median"),
      sn_col("q1", "25th percentile"), sn_col("q3", "75th percentile")),
      data.frame(var = rownames(m), n = as.integer(m[, "n"]), median = m[, "median"], q1 = m[, "q1"], q3 = m[, "q3"], row.names = NULL))
  }
  row <- data.frame(stat = unname(f$statistic), df = as.integer(f$parameter), p = f$p.value)
  cols <- list(sn_col("stat", "χ²"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue"))
  if (!is.null(w)) { row$w <- w; cols <- c(cols, list(sn_col("w", "Kendall's W", digits = 3))) }
  tables$test <- sn_table("friedman", "Friedman Test", cols, row)
  ph <- sn_get(env, "posthoc")
  if (!is.null(ph)) {
    pv <- ph$p.value; idx <- which(!is.na(pv), arr.ind = TRUE)
    tables$posthoc <- sn_table("posthoc", paste0("Pairwise Wilcoxon Signed-Rank Tests (", tools::toTitleCase(o$posthoc), ")"),
      list(sn_col("comparison", "Comparison", "text"), sn_col("p", "p (adjusted)", "pvalue")),
      data.frame(comparison = paste(rownames(pv)[idx[, 1]], "−", colnames(pv)[idx[, 2]]), p = pv[idx], row.names = NULL))
  }
  p <- sn_get(env, "p")
  text <- paste0("A Friedman test ", if (f$p.value < 0.05) "showed a significant" else "did not show a significant",
    " difference across the ", length(o$measures), " measurements, χ²(", f$parameter, ") = ", fmt_num(f$statistic), ", ", apa_p(f$p.value),
    if (!is.null(w)) paste0(", Kendall's W = ", fmt_num(w, 2)), ".")
  sn_result(tables = unname(tables), plots = list(if (!is.null(p)) ctx$plot(p, "Repeated measurements")), interpretation = text)
}
