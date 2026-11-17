# Exploratory factor analysis (psych::fa)

codegen_efa <- function(o, meta, ctx) {
  v <- o$vars
  k <- as.integer(o$n_factors)
  if (k >= length(v)) sn_abort("The number of factors must be smaller than the number of items.", SN_ERR$invalid_options, data = list(option = "n_factors"))
  rot <- if (k == 1) "none" else o$rotation
  code <- sn_code(
    if (o$plot != "none") sn_libs(ctx$plot_engine),
    "",
    paste0("# Exploratory factor analysis: ", k, " factor", if (k > 1) "s", ", ", o$method, " extraction, ", rot, " rotation"),
    paste0("vars <- ", sn_lit(v)),
    paste0("x <- ", ctx$data, "[complete.cases(", ctx$data, "[, vars]), vars]"),
    paste0("efa <- psych::fa(x, nfactors = ", k, ", fm = ", sn_lit(o$method), ", rotate = ", sn_lit(rot), ")"),
    "loadings <- unclass(efa$loadings)",
    "communality <- efa$communality",
    "variance <- efa$Vaccounted",
    "factor_cor <- efa$Phi   # NULL when the factors are uncorrelated",
    "eigenvalues <- eigen(cor(x))$values",
    if (o$factorability) sn_factorability_code("x"),
    if (o$plot == "scree") c(
      "scree <- data.frame(factor = seq_along(eigenvalues), eigenvalue = eigenvalues)",
      sn_scree_code(ctx$plot_engine, "scree", "factor", "eigenvalue", xlab = "Factor", ref = 1))
  )
  list(code = code, assemble = assemble_efa)
}

assemble_efa <- function(env, o, ctx) {
  f <- env$efa; L <- env$loadings; va <- env$variance; k <- ncol(L)
  h2 <- env$communality
  if (o$sort && k > 0) {
    top <- apply(abs(L), 1, which.max)
    ord <- order(top, -apply(abs(L), 1, max))
    L <- L[ord, , drop = FALSE]; h2 <- h2[ord]
  }
  vrows <- data.frame(factor = colnames(va), ss = va["SS loadings", ], prop = 100 * va["Proportion Var", ],
                      cum = 100 * (if ("Cumulative Var" %in% rownames(va)) va["Cumulative Var", ] else va["Proportion Var", ]), row.names = NULL)
  rmsea <- f$RMSEA
  tables <- list(
    sn_tbl_matrix("loadings", "Factor Loadings", L, "Item", extra = list(Communality = h2, Uniqueness = 1 - h2), cut = o$cut,
      notes = c(sprintf("N = %d complete cases. Extraction: %s; rotation: %s.", nrow(env$x), c(minres = "minimum residual", ml = "maximum likelihood", pa = "principal axis")[[o$method]], f$rotation),
                if (o$cut > 0) sprintf("Loadings below %.2f in absolute value are hidden.", o$cut))),
    sn_table("variance", "Variance Explained", list(sn_col("factor", "Factor", "text"), sn_col("ss", "SS loadings", digits = 3), sn_col("prop", "% of variance", digits = 1), sn_col("cum", "Cumulative %", digits = 1)), vrows),
    if (!is.null(env$factor_cor)) sn_tbl_matrix("factor_cor", "Factor Correlations", env$factor_cor, "Factor"),
    sn_tbl_wide("fit", "Model Fit",
      list(sn_col("chi", "χ²", digits = 2), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue"), sn_col("rmsea", "RMSEA", digits = 3),
           sn_col("rmsea_ci", "RMSEA 90% CI", "ci", 3), sn_col("tli", "TLI", digits = 3), sn_col("rmsr", "RMSR", digits = 3), sn_col("bic", "BIC", digits = 1)),
      list(chi = f$STATISTIC, df = as.integer(f$dof), p = f$PVAL, rmsea = if (length(rmsea)) rmsea[[1]] else NA,
           rmsea_ci = if (length(rmsea) >= 3) I(list(unname(rmsea[2:3]))) else NA, tli = f$TLI %||% NA, rmsr = f$rms, bic = f$BIC %||% NA))
  )
  r <- if (length(rmsea)) rmsea[[1]] else NA
  text <- sprintf("An exploratory factor analysis of %d items (N = %d) extracted %d factor%s, which together explained %.1f%% of the variance.%s",
    nrow(L), nrow(env$x), k, if (k == 1) "" else "s", max(vrows$cum),
    if (!is.na(r)) sprintf(" Model fit was %s (RMSEA = %s, TLI = %s).", if (r <= 0.05) "good" else if (r <= 0.08) "acceptable" else "poor", fmt_num(r, 3), fmt_num(f$TLI, 3)) else "")
  sn_result(tables = Filter(Negate(is.null), tables), assumptions = sn_chk_factorability(env),
            plots = sn_plots(env, ctx, c(p_scree = "Scree plot")), interpretation = text)
}
