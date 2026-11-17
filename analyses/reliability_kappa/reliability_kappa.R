# Cohen's kappa for two raters, optionally weighted

codegen_reliability_kappa <- function(o, meta, ctx) {
  a <- o$rater1; b <- o$rater2
  if (identical(a, b)) sn_abort("Choose two different variables.", SN_ERR$invalid_options, data = list(role = "rater2", reason = "duplicate"))
  code <- sn_code(
    sn_libs("psych"),
    "",
    paste0("# Agreement between ", a, " and ", b),
    sn_prep_code("d", ctx$data, c(a, b), meta, factors = c(a, b)),
    paste0("categories <- union(levels(", sn_ref("d", a), "), levels(", sn_ref("d", b), "))"),
    paste0("agreement <- table(factor(", sn_ref("d", a), ", categories), factor(", sn_ref("d", b), ", categories))"),
    "percent_agreement <- 100 * sum(diag(agreement)) / sum(agreement)",
    paste0("kappa <- cohen.kappa(unclass(agreement), alpha = ", sn_lit(1 - o$conf_level), ")")
  )
  list(code = code, assemble = assemble_reliability_kappa)
}

assemble_reliability_kappa <- function(env, o, ctx) {
  tab <- env$agreement; k <- env$kappa; lv <- env$categories
  ct <- data.frame(rater = lv, unclass(tab)[, , drop = FALSE], check.names = FALSE, row.names = NULL)
  names(ct) <- c("rater", paste0("c", seq_along(lv)))
  ct$total <- as.integer(rowSums(tab))
  tot <- as.data.frame(c(list(rater = "Total"), as.list(stats::setNames(as.integer(colSums(tab)), paste0("c", seq_along(lv)))), list(total = as.integer(sum(tab)))))
  ct <- rbind(ct, tot)
  for (i in seq_along(lv)) ct[[i + 1]] <- as.integer(ct[[i + 1]])
  cross <- sn_table("agreement", paste(o$rater1, "×", o$rater2), c(list(sn_col("rater", o$rater1, "text")),
    lapply(seq_along(lv), function(i) sn_col(paste0("c", i), lv[i], "int")), list(sn_col("total", "Total", "int"))), ct)
  cf <- k$confid
  rows <- data.frame(type = c("Unweighted", "Weighted (quadratic)"), kappa = cf[, "estimate"], row.names = NULL)
  rows$ci <- I(list(unname(cf[1, c("lower", "upper")]), unname(cf[2, c("lower", "upper")])))
  if (!o$weighted) rows <- rows[1, , drop = FALSE]
  kt <- sn_table("kappa", "Cohen's Kappa", list(sn_col("type", "Kappa", "text"), sn_col("kappa", "κ", digits = 3), sn_col("ci", sn_pct(o$conf_level), "ci", 3)), rows,
    notes = paste0("Observed agreement: ", fmt_num(env$percent_agreement, 1), "% of ", sum(tab), " cases."))
  v <- if (o$weighted) cf[2, "estimate"] else cf[1, "estimate"]
  lab <- if (v < 0) "poor" else if (v <= 0.2) "slight" else if (v <= 0.4) "fair" else if (v <= 0.6) "moderate" else if (v <= 0.8) "substantial" else "almost perfect"
  i <- if (o$weighted) 2 else 1
  text <- paste0("Agreement between ", o$rater1, " and ", o$rater2, " was ", lab, ", ", if (o$weighted) "weighted " else "", "κ = ", fmt_num(v), ", ",
                 sn_pct(o$conf_level), " ", fmt_ci(cf[i, "lower"], cf[i, "upper"]), " (Landis & Koch, 1977 thresholds); the raters agreed on ",
                 fmt_num(env$percent_agreement, 1), "% of cases.")
  checks <- list(sn_check("categories", "Categories used by both raters", if (any(rowSums(tab) == 0 | colSums(tab) == 0)) "warn" else "ok",
    if (any(rowSums(tab) == 0 | colSums(tab) == 0)) "A category was used by only one rater; kappa is then harder to interpret." else "Both raters used every category."))
  sn_result(tables = list(cross, kt), assumptions = checks, interpretation = text)
}
