# Chi-square test of association (Pearson / Fisher's exact) with Cramer's V

codegen_chisq <- function(o, meta, ctx) {
  r <- o$rows; k <- o$cols
  cl <- sn_lit(o$conf_level)
  code <- sn_code(
    sn_libs(c(if (o$effect_size) "effectsize", if (o$plot != "none") ctx$plot_engine)),
    "",
    paste0("# Chi-square test: ", r, " by ", k),
    paste0("d <- subset(", ctx$data, ", !is.na(", sn_name(r), ") & !is.na(", sn_name(k), "))"),
    sn_factor_code("d", r, meta),
    sn_factor_code("d", k, meta),
    paste0("tab <- table(", sn_name(r), " = ", sn_ref("d", r), ", ", sn_name(k), " = ", sn_ref("d", k), ")"),
    if ("chisq" %in% o$test) paste0("chi <- chisq.test(tab, correct = ", o$correct, ")"),
    if (!"chisq" %in% o$test) "expected <- outer(rowSums(tab), colSums(tab)) / sum(tab)",
    if ("fisher" %in% o$test) "fisher <- fisher.test(tab, simulate.p.value = any(dim(tab) > 2), B = 1e4)",
    if (o$effect_size) paste0("cv <- cramers_v(tab, adjust = FALSE, ci = ", cl, ", alternative = \"two.sided\")"),
    sn_plot_code(ctx$plot_engine, o$plot, "d", x = r, fill = k,
                 xlab = sn_label(meta, r), title = paste(r, "by", k))
  )
  list(code = code, assemble = assemble_chisq)
}

assemble_chisq <- function(env, o, ctx) {
  tab <- env$tab
  expected <- if (!is.null(env$chi)) env$chi$expected else env$expected
  lv <- colnames(tab)
  ids <- paste0("c", seq_along(lv))
  block <- function(stat, m) {
    df <- as.data.frame(matrix(m, nrow = nrow(tab), dimnames = list(NULL, ids)))
    cbind(data.frame(level = rownames(tab), stat = stat), df, total = rowSums(m))
  }
  rt <- rowSums(tab); ct <- colSums(tab); n <- sum(tab)
  parts <- list(block("Count", unclass(tab)))
  if ("expected" %in% o$cells) parts$e <- block("Expected", expected)
  if ("row_pct" %in% o$cells) { m <- 100 * unclass(tab) / rt; b <- block("% within row", m); b$total <- 100; parts$r <- b }
  if ("col_pct" %in% o$cells) { m <- 100 * sweep(unclass(tab), 2, ct, "/"); b <- block("% within column", m); b$total <- 100 * rt / n; parts$c <- b }
  if ("total_pct" %in% o$cells) { m <- 100 * unclass(tab) / n; b <- block("% of total", m); b$total <- 100 * rt / n; parts$t <- b }
  ct_rows <- do.call(rbind, unname(parts))
  ord <- order(match(ct_rows$level, rownames(tab)), match(ct_rows$stat, unique(ct_rows$stat)))
  ct_rows <- ct_rows[ord, ]
  ct_rows$level[duplicated(ct_rows$level)] <- ""
  rownames(ct_rows) <- NULL
  cols <- c(list(sn_col("level", o$rows, "text"), sn_col("stat", "", "text")),
            lapply(seq_along(lv), function(i) sn_col(ids[i], lv[i])), list(sn_col("total", "Total")))
  tables <- list(sn_table("crosstab", paste("Contingency Table:", o$rows, "×", o$cols), cols, ct_rows,
                          notes = paste0("Columns: ", o$cols, ". N = ", n, ".")))
  tests <- list()
  if (!is.null(env$chi)) tests$chi <- data.frame(test = if (isTRUE(o$correct) && all(dim(tab) == 2))
    "χ² (Yates)" else "Pearson χ²", stat = unname(env$chi$statistic),
    df = unname(env$chi$parameter), p = env$chi$p.value)
  if (!is.null(env$fisher)) tests$f <- data.frame(test = paste0("Fisher's exact",
    if (any(dim(tab) > 2)) " (simulated p)" else ""), stat = NA_real_, df = NA_real_, p = env$fisher$p.value)
  if (length(tests)) tables$tests <- sn_table("tests", "Tests of Association", list(
    sn_col("test", "Test", "text"), sn_col("stat", "Value"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue")),
    do.call(rbind, unname(tests)))
  cv <- sn_get(env, "cv")
  if (!is.null(cv)) tables$es <- sn_table("effect", "Effect Size", list(
    sn_col("measure", "Measure", "text"), sn_col("value", "Value", digits = 3),
    sn_col("ci", paste0(round(100 * o$conf_level), "% CI"), "ci", 3)),
    data.frame(measure = "Cramér's V", value = cv[[1]][1], ci = I(list(c(cv$CI_low[1], cv$CI_high[1])))))
  low <- mean(expected < 5); tiny <- any(expected < 1)
  chk <- sn_check("expected", "Expected cell counts",
    if (low > 0.2 || tiny) "warn" else "ok",
    paste0(round(100 * low), "% of cells have expected counts below 5 (minimum ", fmt_num(min(expected)), ").",
           if (low > 0.2 || tiny) " The χ² approximation may be poor; use Fisher's exact test." else ""))
  p <- sn_get(env, "p")
  sn_result(tables = unname(tables), assumptions = list(chk),
            plots = list(if (!is.null(p)) ctx$plot(p, paste(o$rows, "by", o$cols))),
            interpretation = interpret_chisq(env, o))
}

interpret_chisq <- function(env, o) {
  chi <- sn_get(env, "chi")
  if (is.null(chi)) return(NULL)
  cv <- sn_get(env, "cv")
  paste0("A chi-square test of independence ", if (chi$p.value < 0.05) "showed a significant" else
    "did not show a significant", " association between ", o$rows, " and ", o$cols, ", χ²(",
    chi$parameter, ", N = ", sum(env$tab), ") = ", fmt_num(chi$statistic), ", ", apa_p(chi$p.value),
    if (!is.null(cv)) paste0(", Cramér's V = ", fmt_num(cv[[1]][1])), ".")
}
