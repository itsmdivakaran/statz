# Accuracy of a binary diagnostic test against a reference standard

codegen_diag_2x2 <- function(o, meta, ctx) {
  t <- o$test; r <- o$reference
  cl <- sn_lit(o$conf_level)
  prev <- o$prevalence / 100
  code <- sn_code(
    paste0("# Diagnostic accuracy of ", t, " against ", r),
    sn_prep_code("d", ctx$data, c(t, r), meta, factors = c(t, r)),
    paste0("test_pos <- ", sn_ref("d", t), " == levels(", sn_ref("d", t), ")[", if (o$test_positive == "first") 1 else 2, "]"),
    paste0("disease <- ", sn_ref("d", r), " == levels(", sn_ref("d", r), ")[", if (o$ref_positive == "first") 1 else 2, "]"),
    "tp <- sum(test_pos & disease); fp <- sum(test_pos & !disease)",
    "fn <- sum(!test_pos & disease); tn <- sum(!test_pos & !disease)",
    "n <- tp + fp + fn + tn",
    "",
    "# Proportions with exact (Clopper-Pearson) confidence intervals",
    paste0("prop_ci <- function(x, n) c(estimate = x / n, lower = binom.test(x, n, conf.level = ", cl, ")$conf.int[1], upper = binom.test(x, n, conf.level = ", cl, ")$conf.int[2])"),
    "accuracy <- rbind(",
    "  Sensitivity = prop_ci(tp, tp + fn),",
    "  Specificity = prop_ci(tn, tn + fp),",
    "  `Positive predictive value` = prop_ci(tp, tp + fp),",
    "  `Negative predictive value` = prop_ci(tn, tn + fn),",
    "  Accuracy = prop_ci(tp + tn, n),",
    "  Prevalence = prop_ci(tp + fn, n))",
    "sens <- tp / (tp + fn); spec <- tn / (tn + fp)",
    "",
    "# Likelihood ratios and diagnostic odds ratio with log-method confidence intervals",
    paste0("z <- qnorm(1 - (1 - ", cl, ") / 2)"),
    "ratio_ci <- function(est, se) c(estimate = est, lower = exp(log(est) - z * se), upper = exp(log(est) + z * se))",
    "ratios <- rbind(",
    "  `Positive likelihood ratio` = ratio_ci(sens / (1 - spec), sqrt(1 / tp - 1 / (tp + fn) + 1 / fp - 1 / (fp + tn))),",
    "  `Negative likelihood ratio` = ratio_ci((1 - sens) / spec, sqrt(1 / fn - 1 / (tp + fn) + 1 / tn - 1 / (fp + tn))),",
    "  `Diagnostic odds ratio` = ratio_ci((tp * tn) / (fp * fn), sqrt(1 / tp + 1 / fp + 1 / fn + 1 / tn)))",
    "youden <- sens + spec - 1",
    if (prev > 0) c(
      "",
      paste0("# Predictive values at a prevalence of ", o$prevalence, "% (Bayes' theorem)"),
      paste0("prev <- ", sn_lit(prev)),
      "ppv_adj <- sens * prev / (sens * prev + (1 - spec) * (1 - prev))",
      "npv_adj <- spec * (1 - prev) / (spec * (1 - prev) + (1 - sens) * prev)")
  )
  list(code = code, assemble = assemble_diag_2x2)
}

assemble_diag_2x2 <- function(env, o, ctx) {
  a <- env$accuracy; r <- env$ratios
  tl <- levels(env$d[[o$test]]); rl <- levels(env$d[[o$reference]])
  tpos <- tl[if (o$test_positive == "first") 1 else 2]; tneg <- setdiff(tl, tpos)
  rpos <- rl[if (o$ref_positive == "first") 1 else 2]; rneg <- setdiff(rl, rpos)
  ct <- data.frame(row = c(paste0("Test positive (", tpos, ")"), paste0("Test negative (", tneg, ")"), "Total"),
                   pos = c(env$tp, env$fn, env$tp + env$fn), neg = c(env$fp, env$tn, env$fp + env$tn), total = c(env$tp + env$fp, env$fn + env$tn, env$n))
  pct <- sn_pct(o$conf_level)
  mk <- function(m, mult) { rows <- data.frame(measure = rownames(m), est = mult * m[, 1], row.names = NULL); rows$ci <- I(lapply(seq_len(nrow(m)), function(i) mult * unname(m[i, 2:3]))); rows }
  tables <- list(
    sn_table("crosstab", paste(o$test, "×", o$reference), list(sn_col("row", "", "text"), sn_col("pos", paste0("Disease present (", rpos, ")"), "int"),
      sn_col("neg", paste0("Disease absent (", rneg, ")"), "int"), sn_col("total", "Total", "int")), ct),
    sn_table("accuracy", "Accuracy Measures", list(sn_col("measure", "Measure", "text"), sn_col("est", "%", digits = 1), sn_col("ci", pct, "ci", 1)), mk(a, 100),
      notes = c("Exact (Clopper-Pearson) confidence intervals.", sprintf("Youden index = %s.", fmt_num(env$youden, 3)),
                "Predictive values and accuracy apply only at the prevalence in this sample.")),
    sn_table("ratios", "Likelihood Ratios", list(sn_col("measure", "Measure", "text"), sn_col("est", "Estimate", digits = 2), sn_col("ci", pct, "ci", 2)), mk(r, 1),
      notes = "Confidence intervals by the log method.")
  )
  if (o$prevalence > 0) tables <- c(tables, list(sn_table("adjusted", sprintf("Predictive Values at %s%% Prevalence", format(o$prevalence)),
    list(sn_col("measure", "Measure", "text"), sn_col("est", "%", digits = 1)),
    data.frame(measure = c("Positive predictive value", "Negative predictive value"), est = 100 * c(env$ppv_adj, env$npv_adj)))))
  zero <- any(c(env$tp, env$fp, env$fn, env$tn) == 0)
  chk <- sn_check("cells", "Cell counts", if (zero) "warn" else "ok",
    if (zero) "At least one cell of the 2 × 2 table is zero, so some ratios cannot be estimated." else "All four cells of the 2 × 2 table are non-zero.")
  lrp <- r[1, 1]
  text <- sprintf("Against %s, %s had a sensitivity of %.1f%% (%s [%.1f, %.1f]) and a specificity of %.1f%% [%.1f, %.1f] in %d subjects. The positive likelihood ratio was %s and the negative likelihood ratio %s%s.",
    o$reference, o$test, 100 * a[1, 1], pct, 100 * a[1, 2], 100 * a[1, 3], 100 * a[2, 1], 100 * a[2, 2], 100 * a[2, 3], env$n, fmt_num(lrp, 2), fmt_num(r[2, 1], 2),
    if (is.finite(lrp)) paste0("; a positive result is ", if (lrp >= 10) "strong" else if (lrp >= 5) "moderate" else if (lrp >= 2) "weak" else "negligible", " evidence for the disease") else "")
  sn_result(tables = tables, assumptions = list(chk), interpretation = text)
}
