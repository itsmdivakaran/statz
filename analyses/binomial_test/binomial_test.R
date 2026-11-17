# Exact binomial test of each level's proportion against a test value

codegen_binomial_test <- function(o, meta, ctx) {
  v <- o$vars
  code <- sn_code(
    paste0("# Binomial test: ", paste(v, collapse = ", ")),
    paste0("d <- ", ctx$data),
    vapply(v, function(x) sn_factor_code("d", x, meta), ""),
    unlist(lapply(seq_along(v), function(i) {
      s <- sn_suffix(i, length(v))
      c(paste0("counts", s, " <- table(", sn_ref("d", v[i]), ")"),
        paste0("binom", s, " <- lapply(counts", s, ", function(k) binom.test(k, sum(counts", s, "), p = ", sn_lit(o$p0),
               ",\n  alternative = ", sn_lit(o$alternative), ", conf.level = ", sn_lit(o$conf_level), "))"))
    }))
  )
  list(code = code, assemble = assemble_binomial_test)
}

assemble_binomial_test <- function(env, o, ctx) {
  rows <- do.call(rbind, lapply(seq_along(o$vars), function(i) {
    s <- sn_suffix(i, length(o$vars))
    b <- get(paste0("binom", s), envir = env)
    data.frame(var = o$vars[i], level = names(b), count = vapply(b, function(t) as.integer(t$statistic), 1L),
               total = vapply(b, function(t) as.integer(t$parameter), 1L), prop = vapply(b, function(t) unname(t$estimate), 0),
               ci = I(lapply(b, function(t) as.numeric(t$conf.int))), p = vapply(b, function(t) t$p.value, 0), row.names = NULL)
  }))
  tb <- sn_table("binomial", "Binomial Test", list(
    sn_col("var", "Variable", "text"), sn_col("level", "Level", "text"), sn_col("count", "Count", "int"), sn_col("total", "Total", "int"),
    sn_col("prop", "Proportion", digits = 3), sn_col("ci", sn_pct(o$conf_level), "ci", 3), sn_col("p", "p", "pvalue")), rows,
    notes = paste0("Tested against a proportion of ", o$p0, ". Exact (Clopper-Pearson) confidence intervals."))
  r <- rows[1, ]
  sn_result(tables = list(tb), interpretation = paste0("For ", r$var, ", the proportion of '", r$level, "' was ", fmt_num(r$prop, 2),
    " (", r$count, " of ", r$total, "), which ", if (r$p < 0.05) "differed" else "did not differ", " significantly from ", o$p0, ", ", apa_p(r$p), "."))
}
