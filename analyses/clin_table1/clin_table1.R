# Baseline characteristics table ("Table 1")

codegen_clin_table1 <- function(o, meta, ctx) {
  v <- unlist(o$vars); cv <- unlist(o$cat_vars); g <- o$group
  if (!length(c(v, cv))) sn_abort("Add at least one variable.", SN_ERR$invalid_options, data = list(role = "vars", reason = "missing"))
  k <- if (length(g)) ctx$n_distinct(g) else 0
  two <- k == 2
  tests <- isTRUE(o$tests) && k >= 2
  smd <- (isTRUE(o$smd) || o$plot == "balance") && two
  dg <- as.integer(o$digits)
  median <- o$cont_stat == "median_iqr"
  e <- ctx$plot_engine
  code <- sn_code(
    if (o$plot == "balance" && two) sn_libs(e),
    "",
    paste0("# Baseline characteristics", if (length(g)) paste0(" by ", g)),
    paste0("vars <- ", if (length(v)) sn_lit(v) else "character()"),
    paste0("cat_vars <- ", if (length(cv)) sn_lit(cv) else "character()"),
    if (length(g)) c(paste0("d <- ", ctx$data, "[!is.na(", sn_ref(ctx$data, g), "), , drop = FALSE]"), sn_factor_code("d", g, meta), paste0("group <- droplevels(", sn_ref("d", g), ")"))
    else paste0("d <- ", ctx$data),
    vapply(cv, function(x) sn_factor_code("d", x, meta), ""),
    paste0("groups <- ", if (length(g) && o$total) "c(list(Overall = d), split(d, group))" else if (length(g)) "split(d, group)" else "list(Overall = d)"),
    "",
    if (length(v)) c(
      if (median) paste0("fmt_cont <- function(x) sprintf(\"%.", dg, "f [%.", dg, "f, %.", dg, "f]\", median(x, na.rm = TRUE), quantile(x, 0.25, na.rm = TRUE), quantile(x, 0.75, na.rm = TRUE))")
      else paste0("fmt_cont <- function(x) sprintf(\"%.", dg, "f (%.", dg, "f)\", mean(x, na.rm = TRUE), sd(x, na.rm = TRUE))"),
      "continuous <- do.call(rbind, lapply(vars, function(v) sapply(groups, function(g) fmt_cont(g[[v]]))))",
      "rownames(continuous) <- vars"),
    if (length(cv)) c(
      "# n (%) of the non-missing values for every category",
      "fmt_cat <- function(x) { n <- table(x); setNames(sprintf(\"%d (%.1f%%)\", as.integer(n), 100 * as.numeric(n) / sum(n)), names(n)) }",
      "categorical <- lapply(cat_vars, function(v) sapply(groups, function(g) fmt_cat(g[[v]])))",
      "names(categorical) <- cat_vars"),
    "n_group <- sapply(groups, nrow)",
    "n_missing <- do.call(rbind, lapply(c(vars, cat_vars), function(v) sapply(groups, function(g) sum(is.na(g[[v]])))))",
    "rownames(n_missing) <- c(vars, cat_vars)",
    if (tests) c(
      "",
      "# Tests of group differences",
      if (length(v)) {
        if (median) paste0("p_cont <- sapply(vars, function(v) ", if (two) "wilcox.test(d[[v]] ~ group, exact = FALSE)$p.value)   # Wilcoxon rank-sum test" else "kruskal.test(d[[v]] ~ group)$p.value)   # Kruskal-Wallis test")
        else paste0("p_cont <- sapply(vars, function(v) ", if (two) "t.test(d[[v]] ~ group)$p.value)   # Welch t-test" else "oneway.test(d[[v]] ~ group, var.equal = TRUE)$p.value)   # one-way ANOVA")
      },
      if (length(cv)) c(
        "set.seed(1)   # Fisher's test is simulated for tables larger than 2 x 2",
        "test_cat <- function(x) {",
        "  tab <- table(x, group)",
        "  if (any(suppressWarnings(chisq.test(tab))$expected < 5))",
        "    c(p = fisher.test(tab, simulate.p.value = !all(dim(tab) == 2), B = 10000)$p.value, exact = 1)",
        "  else c(p = chisq.test(tab, correct = FALSE)$p.value, exact = 0)",
        "}",
        "p_cat <- sapply(cat_vars, function(v) test_cat(d[[v]]))")),
    if (smd) c(
      "",
      "# Standardized mean differences between the two groups (pooled SD; Yang & Dalton for categories)",
      "g1 <- groups[[levels(group)[1]]]; g2 <- groups[[levels(group)[2]]]",
      if (length(v)) "smd_cont <- sapply(vars, function(v) (mean(g1[[v]], na.rm = TRUE) - mean(g2[[v]], na.rm = TRUE)) / sqrt((var(g1[[v]], na.rm = TRUE) + var(g2[[v]], na.rm = TRUE)) / 2))",
      if (length(cv)) c(
        "smd_cat <- sapply(cat_vars, function(v) {",
        "  p1 <- prop.table(table(g1[[v]]))[-1]; p2 <- prop.table(table(g2[[v]]))[-1]",
        "  S <- (diag(p1, length(p1)) - outer(p1, p1) + diag(p2, length(p2)) - outer(p2, p2)) / 2",
        "  tryCatch(sqrt(drop(t(p1 - p2) %*% solve(S) %*% (p1 - p2))), error = function(e) NA)",
        "})"),
      paste0("smd <- c(", paste(c(if (length(v)) "smd_cont", if (length(cv)) "smd_cat"), collapse = ", "), ")"),
      if (o$plot == "balance") c(
        "smd_df <- data.frame(variable = factor(names(smd), levels = rev(names(smd))), smd = abs(smd))",
        if (e == "ggnext") c(
          sn_ylabels_code("smd_df", "variable", "0", "max(smd_df$smd, 0.1, na.rm = TRUE)"),
          paste0("p_balance <- ", paste(c("ggnext(smd_df, aes(smd, variable))", "geom_point(size = 4)", sn_ref_line(e, "v", 0.1), sn_ylabels_layer("variable"),
                 "labs(title = \"Balance between groups\", x = \"Absolute standardized mean difference\")", sn_ylabels_theme()), collapse = " +\n  ")))
        else sn_gg(e, "smd_df, aes(smd, variable)", c("geom_point(size = 3)", sn_ref_line(e, "v", 0.1)), "Balance between groups", "Absolute standardized mean difference", "", "p_balance")))
  )
  list(code = code, assemble = function(env, o, ctx) {
    grp <- env$groups; gn <- names(grp); ng <- env$n_group
    labels <- vapply(c(v, cv), function(x) sn_label(meta, x), "")
    blank <- stats::setNames(as.list(rep("", length(gn))), paste0("g", seq_along(gn)))
    mk <- function(label, cells = NULL, p = NA, test = "", s = NA) {
      r <- data.frame(characteristic = label, stringsAsFactors = FALSE)
      for (i in seq_along(gn)) r[[paste0("g", i)]] <- if (is.null(cells)) "" else unname(cells[[gn[i]]] %||% cells[i])
      r$p <- p; r$test <- test; r$smd <- s
      r
    }
    pc <- sn_get(env, "p_cont"); pk <- sn_get(env, "p_cat"); sm <- sn_get(env, "smd")
    cont_test <- if (median) (if (two) "Wilcoxon" else "Kruskal-Wallis") else (if (two) "Welch t" else "ANOVA")
    rows <- list(mk("N", as.list(stats::setNames(as.character(ng), gn))))
    miss <- env$n_missing
    for (x in v) {
      rows <- c(rows, list(mk(paste0(labels[[x]], if (median) ", median [Q1, Q3]" else ", mean (SD)"), as.list(env$continuous[x, ]), if (!is.null(pc)) pc[[x]] else NA, if (!is.null(pc)) cont_test else "", if (!is.null(sm)) sm[[x]] else NA)))
      if (o$missing && any(miss[x, ] > 0)) rows <- c(rows, list(mk("   Missing", as.list(stats::setNames(as.character(miss[x, ]), gn)))))
    }
    for (x in cv) {
      m <- env$categorical[[x]]
      if (!is.matrix(m)) m <- matrix(m, ncol = length(gn), dimnames = list(names(m) %||% levels(env$d[[x]]), gn))
      rows <- c(rows, list(mk(paste0(labels[[x]], ", n (%)"), NULL, if (!is.null(pk)) pk["p", x] else NA,
                              if (!is.null(pk)) (if (pk["exact", x] == 1) "Fisher exact" else "Chi-square") else "", if (!is.null(sm)) sm[[x]] else NA)))
      for (l in rownames(m)) rows <- c(rows, list(mk(paste0("   ", l), as.list(m[l, ]))))
      if (o$missing && any(miss[x, ] > 0)) rows <- c(rows, list(mk("   Missing", as.list(stats::setNames(as.character(miss[x, ]), gn)))))
    }
    tb <- do.call(rbind, rows)
    cols <- c(list(sn_col("characteristic", "Characteristic", "text")), lapply(seq_along(gn), function(i) sn_col(paste0("g", i), sprintf("%s (N = %d)", gn[i], ng[i]), "text")))
    if (!is.null(pc) || !is.null(pk)) cols <- c(cols, list(sn_col("p", "p", "pvalue"), sn_col("test", "Test", "text")))
    if (!is.null(sm)) { tb$smd <- abs(tb$smd); cols <- c(cols, list(sn_col("smd", "SMD", digits = 3))) }
    tb <- tb[, vapply(cols, function(c) c$id, ""), drop = FALSE]
    notes <- c("Percentages are of the non-missing values in each column.",
               if (isTRUE(o$tests) && k < 2) "p-values need a grouping variable.",
               if ((isTRUE(o$smd) || o$plot == "balance") && !two) "Standardized mean differences need exactly two groups.",
               if (!is.null(sm)) "SMD = absolute standardized mean difference; values above 0.1 indicate imbalance.",
               if (!is.null(pc) || !is.null(pk)) "In a randomized trial, baseline p-values test the randomization, not the treatment; report them only if required.")
    text <- sprintf("The table summarises %d characteristic%s for %d subjects%s.", length(c(v, cv)), if (length(c(v, cv)) == 1) "" else "s", nrow(env$d),
                    if (length(g)) sprintf(" in %d groups (%s)", k, paste(sprintf("%s: %d", levels(env$group), as.integer(table(env$group))), collapse = ", ")) else "")
    allp <- c(pc, if (!is.null(pk)) pk["p", ])
    if (length(allp)) { sig <- names(allp)[!is.na(allp) & allp < 0.05]; text <- paste0(text, if (length(sig)) paste0(" The groups differed at the .05 level on ", paste(sig, collapse = ", "), ".") else " No characteristic differed between groups at the .05 level.") }
    if (!is.null(sm)) { big <- names(sm)[!is.na(sm) & abs(sm) > 0.1]; text <- paste0(text, if (length(big)) paste0(" Standardized differences above 0.1: ", paste(big, collapse = ", "), ".") else " All standardized differences were at most 0.1.") }
    sn_result(tables = list(sn_table("table1", "Baseline Characteristics", cols, tb, notes = notes)), plots = sn_plots(env, ctx, c(p_balance = "Balance plot")), interpretation = text)
  })
}
