# Intraclass correlations (Shrout & Fleiss, 1979)

codegen_reliability_icc <- function(o, meta, ctx) {
  r <- o$raters
  code <- sn_code(
    sn_libs("psych"),
    "",
    paste0("# Intraclass correlations: ", length(r), " raters, one row per rated subject"),
    paste0("ratings <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", sn_lit(r), "]), ", sn_lit(r), "]"),
    paste0("icc <- ICC(ratings, alpha = ", sn_lit(1 - o$conf_level), ", lmer = FALSE)"),
    "icc_results <- icc$results"
  )
  list(code = code, assemble = assemble_reliability_icc)
}

assemble_reliability_icc <- function(env, o, ctx) {
  r <- env$icc_results
  desc <- c(ICC1 = "One-way random, single rater", ICC2 = "Two-way random, single rater, absolute agreement", ICC3 = "Two-way mixed, single rater, consistency",
            ICC1k = "One-way random, mean of raters", ICC2k = "Two-way random, mean of raters, absolute agreement", ICC3k = "Two-way mixed, mean of raters, consistency")
  short <- c(ICC1 = "ICC(1,1)", ICC2 = "ICC(2,1)", ICC3 = "ICC(3,1)", ICC1k = "ICC(1,k)", ICC2k = "ICC(2,k)", ICC3k = "ICC(3,k)")
  type <- as.character(r$type)
  rows <- data.frame(type = unname(short[type]), model = unname(desc[type]), icc = r$ICC, F = r$F, df1 = as.integer(r$df1), df2 = as.integer(r$df2), p = r$p)
  rows$ci <- I(lapply(seq_len(nrow(r)), function(i) c(r[["lower bound"]][i], r[["upper bound"]][i])))
  tb <- sn_table("icc", "Intraclass Correlations", list(sn_col("type", "Type", "text"), sn_col("model", "Model", "text"), sn_col("icc", "ICC", digits = 3),
    sn_col("ci", sn_pct(o$conf_level), "ci", 3), sn_col("F", "F"), sn_col("df1", "df1", "int"), sn_col("df2", "df2", "int"), sn_col("p", "p", "pvalue")),
    rows[, c("type", "model", "icc", "ci", "F", "df1", "df2", "p")],
    notes = paste0(env$icc$n.obs, " subjects rated by ", env$icc$n.judge, " raters."))
  i <- match(o$focus, type); v <- r$ICC[i]
  lab <- if (v < 0.5) "poor" else if (v < 0.75) "moderate" else if (v < 0.9) "good" else "excellent"
  text <- paste0("Reliability was ", lab, ", ", short[[o$focus]], " = ", fmt_num(v), ", ", sn_pct(o$conf_level), " ",
                 fmt_ci(r[["lower bound"]][i], r[["upper bound"]][i]), " (", tolower(desc[[o$focus]]), "; Koo & Li, 2016 thresholds).")
  checks <- list(sn_check("n", "Number of subjects", if (env$icc$n.obs < 30) "warn" else "ok",
    if (env$icc$n.obs < 30) paste0("Only ", env$icc$n.obs, " subjects; the confidence interval is wide. At least 30 subjects are recommended.") else "At least 30 subjects were rated."))
  sn_result(tables = list(tb), assumptions = checks, interpretation = text)
}
