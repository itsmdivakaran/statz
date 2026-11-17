# Principal component analysis (prcomp)

codegen_pca <- function(o, meta, ctx) {
  v <- o$vars; g <- o$group
  k <- min(as.integer(o$n_components), length(v))
  code <- sn_code(
    if (length(o$plot)) sn_libs(ctx$plot_engine),
    "",
    paste0("# Principal component analysis: ", paste(v, collapse = ", ")),
    paste0("vars <- ", sn_lit(v)),
    paste0("d <- ", ctx$data, "[complete.cases(", ctx$data, "[, vars]), , drop = FALSE]"),
    "x <- d[vars]",
    paste0("pca <- prcomp(x, center = TRUE, scale. = ", if (o$standardize) "TRUE" else "FALSE", ")"),
    "eigenvalues <- pca$sdev^2",
    "variance <- data.frame(component = seq_along(eigenvalues), eigenvalue = eigenvalues,",
    "                       proportion = eigenvalues / sum(eigenvalues), cumulative = cumsum(eigenvalues) / sum(eigenvalues))",
    if (o$retain == "kaiser") paste0("n_comp <- max(1, sum(eigenvalues > mean(eigenvalues)))   # Kaiser criterion", if (o$standardize) ": eigenvalue above 1")
    else paste0("n_comp <- ", k),
    "# Loadings: correlations between the variables and the component scores",
    "loadings <- cor(x, pca$x[, seq_len(n_comp), drop = FALSE])",
    if (o$rotation == "varimax") c(
      "if (n_comp > 1) {",
      "  loadings <- unclass(varimax(loadings, normalize = TRUE)$loadings)",
      "  colnames(loadings) <- paste0(\"RC\", seq_len(n_comp))",
      "}"),
    "communality <- rowSums(loadings^2)",
    if (o$factorability) sn_factorability_code("x"),
    if ("scree" %in% o$plot) sn_scree_code(ctx$plot_engine, "variance", "component", "eigenvalue", ref = if (o$standardize) 1),
    if ("scores" %in% o$plot) c(
      paste0("scores <- data.frame(PC1 = pca$x[, 1], PC2 = pca$x[, 2]", if (length(g)) paste0(", group = factor(", sn_ref("d", g), ")"), ")"),
      sn_gg(ctx$plot_engine, paste0("scores, aes(PC1, PC2", if (length(g)) ", color = group", ")"), "geom_point(size = 3, alpha = 0.8)",
            "Component scores", NULL, NULL, "p_scores"),
      "p_scores <- p_scores + labs(x = sprintf(\"PC1 (%.1f%%)\", 100 * variance$proportion[1]), y = sprintf(\"PC2 (%.1f%%)\", 100 * variance$proportion[2]))")
  )
  list(code = code, assemble = assemble_pca)
}

assemble_pca <- function(env, o, ctx) {
  va <- env$variance; L <- env$loadings; k <- env$n_comp
  rows <- data.frame(component = paste0("PC", va$component), eigenvalue = va$eigenvalue, proportion = 100 * va$proportion, cumulative = 100 * va$cumulative)
  rotated <- o$rotation == "varimax" && k > 1
  tables <- list(
    sn_table("variance", "Variance Explained", list(sn_col("component", "Component", "text"), sn_col("eigenvalue", "Eigenvalue", digits = 3),
        sn_col("proportion", "% of variance", digits = 1), sn_col("cumulative", "Cumulative %", digits = 1)), rows,
      notes = c(sprintf("N = %d complete cases.", nrow(env$d)),
                if (o$standardize) "Based on the correlation matrix (standardized variables)." else "Based on the covariance matrix (variables in their own units).")),
    sn_tbl_matrix("loadings", paste0(if (rotated) "Rotated " else "", "Component Loadings"), L, "Variable", extra = list(Communality = env$communality), cut = o$cut,
      notes = c("Loadings are correlations between each variable and the component.",
                if (rotated) paste0("Varimax rotation.", if (o$standardize) paste0(" Variance after rotation: ", paste(sprintf("%s %.1f%%", colnames(L), 100 * colSums(L^2) / nrow(L)), collapse = ", "), ".")),
                if (o$cut > 0) sprintf("Loadings below %.2f in absolute value are hidden.", o$cut)))
  )
  text <- sprintf("A principal component analysis of %d variables (N = %d) retained %d component%s%s, explaining %.1f%% of the total variance. The first component explained %.1f%%.",
    ncol(env$x), nrow(env$d), k, if (k == 1) "" else "s",
    if (o$retain == "kaiser") " by the Kaiser criterion" else "", 100 * va$cumulative[k], 100 * va$proportion[1])
  sn_result(tables = tables, assumptions = sn_chk_factorability(env),
            plots = sn_plots(env, ctx, c(p_scree = "Scree plot", p_scores = "Component scores")), interpretation = text)
}
