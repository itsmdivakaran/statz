# Cochran's Q test for k related binary measurements

codegen_cochran_q <- function(o, meta, ctx) {
  v <- o$vars
  code <- sn_code(
    paste0("# Cochran's Q: ", paste(v, collapse = ", ")),
    paste0("vars <- ", sn_lit(v)),
    sn_prep_code("d", ctx$data, v, meta),
    "# 1 = second category of each variable, 0 = first",
    "x <- sapply(d[vars], function(v) as.integer(v) - 1L)",
    "k <- ncol(x); col_tot <- colSums(x); row_tot <- rowSums(x); N <- sum(x)",
    "q <- (k - 1) * (k * sum(col_tot^2) - N^2) / (k * N - sum(row_tot^2))",
    "cochran <- list(statistic = q, df = k - 1, p.value = pchisq(q, k - 1, lower.tail = FALSE))",
    if (o$posthoc != "none") c(
      "pair_idx <- t(combn(vars, 2))",
      "pair_p <- apply(pair_idx, 1, function(p) mcnemar.test(table(factor(x[, p[1]], 0:1), factor(x[, p[2]], 0:1)))$p.value)",
      paste0("posthoc <- data.frame(var1 = pair_idx[, 1], var2 = pair_idx[, 2], p = pair_p, p_adj = p.adjust(pair_p, ", sn_lit(o$posthoc), "))"))
  )
  list(code = code, assemble = assemble_cochran_q)
}

assemble_cochran_q <- function(env, o, ctx) {
  x <- env$x; q <- env$cochran
  second <- vapply(o$vars, function(v) levels(env$d[[v]])[2], "")
  props <- sn_table("props", "Proportions", list(sn_col("var", "Variable", "text"), sn_col("level", "Category counted", "text"),
    sn_col("count", "Count", "int"), sn_col("n", "N", "int"), sn_col("prop", "Proportion", digits = 3)),
    data.frame(var = o$vars, level = second, count = as.integer(colSums(x)), n = nrow(x), prop = colMeans(x), row.names = NULL))
  test <- sn_table("cochran", "Cochran's Q Test", list(sn_col("stat", "Q"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue")),
    data.frame(stat = q$statistic, df = as.integer(q$df), p = q$p.value))
  tables <- list(props, test)
  ph <- sn_get(env, "posthoc")
  if (!is.null(ph)) tables <- c(tables, list(sn_table("posthoc", paste0("Pairwise McNemar Tests (", tools::toTitleCase(o$posthoc), ")"), list(
    sn_col("comparison", "Comparison", "text"), sn_col("p", "p", "pvalue"), sn_col("p_adj", "p (adjusted)", "pvalue")),
    data.frame(comparison = paste(ph$var1, "−", ph$var2), p = ph$p, p_adj = ph$p_adj))))
  sn_result(tables = tables, interpretation = paste0("Cochran's Q test ", if (q$p.value < 0.05) "showed a significant" else "did not show a significant",
    " difference in proportions across the ", length(o$vars), " measurements, Q(", q$df, ") = ", fmt_num(q$statistic), ", ", apa_p(q$p.value), "."))
}
