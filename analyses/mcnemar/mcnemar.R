# McNemar test for paired binary data

codegen_mcnemar <- function(o, meta, ctx) {
  x <- o$x; y <- o$y
  code <- sn_code(
    paste0("# McNemar test: ", x, " vs ", y),
    sn_prep_code("d", ctx$data, c(x, y), meta),
    paste0("lv <- union(levels(", sn_ref("d", x), "), levels(", sn_ref("d", y), "))"),
    paste0("tab <- table(factor(", sn_ref("d", x), ", levels = lv), factor(", sn_ref("d", y), ", levels = lv), dnn = ", sn_lit(c(x, y)), ")"),
    paste0("mcnemar <- mcnemar.test(tab, correct = ", sn_lit(o$correct), ")"),
    if (o$exact) "exact <- binom.test(tab[1, 2], tab[1, 2] + tab[2, 1], p = 0.5)"
  )
  list(code = code, assemble = assemble_mcnemar)
}

assemble_mcnemar <- function(env, o, ctx) {
  tab <- env$tab; m <- env$mcnemar; e <- sn_get(env, "exact")
  if (!all(dim(tab) == 2)) sn_abort("Both variables must use the same two categories.", SN_ERR$invalid_options, data = list(role = "y"))
  ct <- data.frame(row = rownames(tab), a = as.integer(tab[, 1]), b = as.integer(tab[, 2]), total = as.integer(rowSums(tab)))
  ct <- rbind(ct, data.frame(row = "Total", a = sum(tab[, 1]), b = sum(tab[, 2]), total = sum(tab)))
  crosstab <- sn_table("crosstab", paste(o$x, "×", o$y), list(sn_col("row", o$x, "text"), sn_col("a", colnames(tab)[1], "int"),
    sn_col("b", colnames(tab)[2], "int"), sn_col("total", "Total", "int")), ct)
  rows <- data.frame(test = paste0("McNemar χ²", if (o$correct) " (continuity corrected)" else ""), stat = unname(m$statistic),
                     df = as.integer(m$parameter), p = m$p.value)
  if (!is.null(e)) rows <- rbind(rows, data.frame(test = "Exact binomial", stat = NA_real_, df = NA_integer_, p = e$p.value))
  test <- sn_table("mcnemar", "McNemar Test", list(sn_col("test", "Test", "text"), sn_col("stat", "Statistic"), sn_col("df", "df", "int"),
    sn_col("p", "p", "pvalue")), rows,
    notes = paste0("Discordant pairs: ", tab[1, 2], " changed from ", rownames(tab)[1], " to ", colnames(tab)[2], ", ", tab[2, 1],
                   " from ", rownames(tab)[2], " to ", colnames(tab)[1], "."))
  disc <- tab[1, 2] + tab[2, 1]
  chk <- sn_check("discordant", "Discordant pairs", if (disc < 25) "warn" else "ok",
    if (disc < 25) "Fewer than 25 discordant pairs; rely on the exact test." else "Enough discordant pairs for the chi-square approximation.")
  sn_result(tables = list(crosstab, test), assumptions = list(chk),
    interpretation = paste0("The proportions for ", o$x, " and ", o$y, if (m$p.value < 0.05) " differed" else " did not differ",
      " significantly, McNemar χ²(", m$parameter, ") = ", fmt_num(m$statistic), ", ", apa_p(m$p.value), "."))
}
