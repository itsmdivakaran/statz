# Correlation matrix with pairwise tests; optional partial correlation

codegen_correlation <- function(o, meta, ctx) {
  v <- o$vars; ctl <- o$controls
  partial <- length(ctl) > 0
  if (partial && o$method == "kendall")
    sn_abort("Partial correlation is available for Pearson and Spearman.", SN_ERR$invalid_options, data = list(role = "controls"))
  cl <- sn_lit(o$conf_level)
  rank_first <- partial && o$method == "spearman"
  code <- sn_code(
    if (o$plot != "none") sn_libs(ctx$plot_engine),
    "",
    paste0("# ", if (partial) "Partial " else "", tools::toTitleCase(o$method), " correlation: ", paste(v, collapse = ", "),
           if (partial) paste0(" (controlling for ", paste(ctl, collapse = ", "), ")")),
    paste0("vars <- ", sn_lit(v)),
    if (partial) paste0("controls <- ", sn_lit(ctl)),
    paste0("d <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", if (partial) "c(vars, controls)" else "vars", "]), ]"),
    if (partial) c(
      if (rank_first) "d[c(vars, controls)] <- lapply(d[c(vars, controls)], rank)",
      "# Residuals after regressing each variable on the control variables",
      "x <- as.data.frame(lapply(d[vars], function(v) residuals(lm(v ~ ., data = d[controls]))))",
      "n <- nrow(d); k <- length(controls)"
    ) else "x <- d[vars]",
    paste0("cor_matrix <- cor(x, method = ", sn_lit(if (partial) "pearson" else o$method), ")"),
    "pair_idx <- t(combn(vars, 2))",
    if (partial) paste0(
      "cor_pairs <- do.call(rbind, lapply(seq_len(nrow(pair_idx)), function(i) {\n",
      "  r <- cor_matrix[pair_idx[i, 1], pair_idx[i, 2]]\n",
      "  df <- n - 2 - k\n",
      "  t <- r * sqrt(df / (1 - r^2))\n",
      "  ci <- tanh(atanh(r) + c(-1, 1) * qnorm(1 - (1 - ", cl, ") / 2) / sqrt(n - 3 - k))\n",
      "  data.frame(var1 = pair_idx[i, 1], var2 = pair_idx[i, 2], r = r, statistic = t, df = df,\n",
      "             p = 2 * pt(abs(t), df, lower.tail = FALSE), lower = ci[1], upper = ci[2])\n",
      "}))")
    else paste0(
      "cor_pairs <- do.call(rbind, lapply(seq_len(nrow(pair_idx)), function(i) {\n",
      "  ct <- cor.test(x[[pair_idx[i, 1]]], x[[pair_idx[i, 2]]], method = ", sn_lit(o$method), ", conf.level = ", cl, ", exact = FALSE)\n",
      "  ci <- if (is.null(ct$conf.int)) c(NA, NA) else ct$conf.int\n",
      "  data.frame(var1 = pair_idx[i, 1], var2 = pair_idx[i, 2], r = unname(ct$estimate), statistic = unname(ct$statistic),\n",
      "             df = if (is.null(ct$parameter)) NA else unname(ct$parameter), p = ct$p.value, lower = ci[1], upper = ci[2])\n",
      "}))"),
    switch(o$plot,
      heatmap = if (ctx$plot_engine == "ggnext" && o$method != "kendall")
        sn_gg("ggnext", "", paste0("geom_cor(", if (o$method == "spearman" && !partial) "as.data.frame(lapply(x, rank))" else "x", ", vars = vars)"),
              paste(if (partial) "Partial correlation" else "Correlation", "matrix"))
      else c(
        "cor_long <- as.data.frame(as.table(cor_matrix)); names(cor_long) <- c(\"var1\", \"var2\", \"r\")",
        if (ctx$plot_engine == "ggnext")
          sn_gg("ggnext", "cor_long, aes(var1, var2, color = r)", c("geom_tile()", "scale_color_gradient(low = \"#C1462F\", high = \"#12A594\")"),
                "Correlation matrix", "", "")
        else sn_gg("ggplot2", "cor_long, aes(var1, var2, fill = r)",
                   c("geom_tile()", "geom_text(aes(label = sprintf(\"%.2f\", r)))",
                     "scale_fill_gradient2(low = \"#C1462F\", mid = \"#F2F0EA\", high = \"#12A594\", limits = c(-1, 1))"),
                   "Correlation matrix", "", "")),
      scatter = sn_gg(ctx$plot_engine, paste0("d, aes(", sn_name(v[1]), ", ", sn_name(v[2]), ")"),
                      c("geom_point(alpha = 0.7)", "geom_smooth(method = \"lm\")"),
                      paste(v[2], "by", v[1]), sn_label(meta, v[1]), sn_label(meta, v[2])))
  )
  list(code = code, assemble = assemble_correlation)
}

assemble_correlation <- function(env, o, ctx) {
  cp <- env$cor_pairs; cm <- env$cor_matrix
  partial <- length(o$controls) > 0
  sym <- c(pearson = "r", spearman = "ρ", kendall = "τ")[[o$method]]
  stat <- if (partial || o$method == "pearson") "t" else if (o$method == "spearman") "S" else "z"
  tables <- list()
  if (o$matrix) {
    rows <- data.frame(var = rownames(cm), stringsAsFactors = FALSE)
    for (j in seq_len(ncol(cm))) rows[[paste0("c", j)]] <- cm[, j]
    tables$matrix <- sn_table("matrix", paste0(if (partial) "Partial " else "", "Correlation Matrix (", sym, ")"),
      c(list(sn_col("var", "", "text")), lapply(seq_len(ncol(cm)), function(j) sn_col(paste0("c", j), colnames(cm)[j], digits = 3))), rows)
  }
  rows <- data.frame(var1 = cp$var1, var2 = cp$var2, r = cp$r, stat = cp$statistic, df = cp$df, p = cp$p)
  cols <- list(sn_col("var1", "Variable 1", "text"), sn_col("var2", "Variable 2", "text"), sn_col("r", sym, digits = 3))
  if (!all(is.na(cp$lower))) {
    rows$ci <- I(lapply(seq_len(nrow(cp)), function(i) c(cp$lower[i], cp$upper[i])))
    cols <- c(cols, list(sn_col("ci", sn_pct(o$conf_level), "ci", 3)))
  }
  cols <- c(cols, list(sn_col("stat", stat)), if (!all(is.na(cp$df))) list(sn_col("df", "df", "int")), list(sn_col("p", "p", "pvalue")))
  rows$df <- as.integer(rows$df)
  tables$pairs <- sn_table("pairs", "Pairwise Correlations", cols, rows[, vapply(cols, function(c) c$id, ""), drop = FALSE],
    notes = c(sprintf("N = %d complete cases.", nrow(env$d)),
              if (partial) paste0("Controlling for ", paste(o$controls, collapse = ", "), "."),
              if (o$method != "pearson" && !partial) "p-values use the normal or t approximation."))
  sig <- cp[cp$p < 0.05, , drop = FALSE]
  top <- cp[which.max(abs(cp$r)), ]
  text <- paste0(nrow(sig), " of ", nrow(cp), " ", if (partial) "partial " else "", tools::toTitleCase(o$method),
    " correlations were significant at the .05 level. The strongest was between ", top$var1, " and ", top$var2,
    ", ", sym, " = ", fmt_num(top$r, 2), ", ", apa_p(top$p), ".")
  p <- sn_get(env, "p")
  sn_result(tables = unname(tables),
            plots = list(if (!is.null(p)) ctx$plot(p, if (o$plot == "scatter") paste(o$vars[2], "by", o$vars[1]) else "Correlation matrix")),
            interpretation = text)
}
