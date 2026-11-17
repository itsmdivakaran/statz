# Helpers shared by the meta-analysis modules (metafor) ----

#' Code for a meta-analysis.
#' @param vars columns that must be complete.
#' @param escalc R expression (text) that returns the effect sizes `yi` and variances `vi`.
#' @param effect label of the effect measure, e.g. "Risk ratio".
#' @param log_scale TRUE when `yi` is a log ratio that is reported back-transformed.
sn_meta_code <- function(o, meta, ctx, vars, escalc, effect, log_scale) {
  e <- ctx$plot_engine
  random <- o$model == "random"
  method <- if (random) o$tau2 else "EE"
  test <- if (random && isTRUE(o$knha)) "knha" else "z"
  lvl <- sn_lit(100 * o$conf_level)
  mod <- o$moderator
  fit_args <- paste0("data = es, method = ", sn_lit(method), ", test = ", sn_lit(test), ", level = ", lvl)
  tr <- function(x) if (log_scale) paste0("exp(", x, ")") else x
  code <- sn_code(
    if (length(o$plot)) sn_libs(e),
    "",
    paste0("# ", if (random) "Random-effects" else "Common-effect", " meta-analysis (", tolower(effect), ")"),
    paste0("d <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", sn_lit(unique(c(vars, mod))), ", drop = FALSE]), , drop = FALSE]"),
    if (length(o$study)) paste0("d$study_label <- make.unique(as.character(", sn_ref("d", o$study), "))") else "d$study_label <- paste(\"Study\", seq_len(nrow(d)))",
    paste0("es <- ", escalc, if (log_scale) "   # yi = log ratio, vi = its variance" else "   # yi = effect size, vi = its variance"),
    paste0("meta <- metafor::rma(yi, vi, ", fit_args, ")"),
    paste0("z <- qnorm(1 - (1 - ", sn_lit(o$conf_level), ") / 2)"),
    "studies <- data.frame(study = d$study_label, yi = as.numeric(es$yi), se = sqrt(es$vi), weight = as.numeric(weights(meta)))",
    "studies$lower <- studies$yi - z * studies$se",
    "studies$upper <- studies$yi + z * studies$se",
    "pooled <- predict(meta)   # pooled estimate with confidence and prediction interval",
    if (isTRUE(o$egger)) c("# Egger's regression test for funnel plot asymmetry", "egger <- metafor::regtest(meta, model = \"lm\", predictor = \"sei\")"),
    if (isTRUE(o$trimfill)) "trim_fill <- metafor::trimfill(meta)",
    if (isTRUE(o$leave1out)) "loo <- as.data.frame(metafor::leave1out(meta))",
    if (length(mod)) c(
      "# Meta-regression on the moderator",
      paste0("meta_mod <- metafor::rma(yi, vi, mods = ~ ", if (sn_is_categorical(meta, mod)) paste0("factor(", sn_name(mod), ")") else sn_name(mod), ", ", fit_args, ")")),
    if ("forest" %in% o$plot) c(
      paste0("forest_df <- data.frame(term = c(studies$study, \"Pooled\"), est = ", tr("c(studies$yi, pooled$pred)"), ","),
      paste0("                        lower = ", tr("c(studies$lower, pooled$ci.lb)"), ", upper = ", tr("c(studies$upper, pooled$ci.ub)"), ", weight = c(studies$weight, 100))"),
      "forest_df$term <- factor(forest_df$term, levels = rev(forest_df$term))",
      sn_meta_forest_code(e, paste0(effect, " (", sn_pct(o$conf_level), ")"), log_scale)),
    if ("funnel" %in% o$plot) c(
      "se_max <- max(studies$se) * 1.05",
      "funnel_lines <- data.frame(x = pooled$pred, y = 0, xend = pooled$pred + c(-1, 1) * z * se_max, yend = se_max)",
      sn_gg(e, "studies, aes(yi, se)",
            c("geom_segment(aes(x = x, y = y, xend = xend, yend = yend), data = funnel_lines)", sn_ref_line(e, "v", "pooled$pred"), "geom_point(size = 3)", "scale_y_reverse()"),
            "Funnel plot", if (log_scale) paste0("Log ", tolower(effect)) else effect, "Standard error", "p_funnel"))
  )
  code
}

sn_is_categorical <- function(meta, var) {
  vm <- meta$variables[[var]]
  !identical(vm$measure, "continuous")
}

#' Forest plot of `forest_df` (term, est, lower, upper, weight). ggnext draws the study names inside
#' the panel because its left margin does not grow with long axis labels.
sn_meta_forest_code <- function(engine, xlab, log_scale, obj = "p_forest") {
  ref <- if (log_scale) 1 else 0
  if (engine != "ggnext")
    return(sn_gg(engine, "forest_df, aes(term, est, ymin = lower, ymax = upper)",
                 c("geom_pointrange()", sn_ref_line(engine, "h", ref), if (log_scale) "scale_y_log10()", "coord_flip()"), "Forest plot", "", xlab, obj))
  sn_code(
    sn_ylabels_code("forest_df", "term", "min(forest_df$lower)", "max(forest_df$upper)", log = log_scale),
    paste0(obj, " <- ", paste(c(
      "ggnext(forest_df, aes(est, term, ymin = lower, ymax = upper, size = weight))",
      paste0("geom_forest(ref = ", ref, ")"),
      sn_ylabels_layer("term"),
      if (log_scale) "scale_x_log10()",
      paste0("labs(title = \"Forest plot\", x = ", sn_lit(xlab), ")"),
      sn_ylabels_theme(legend = FALSE)), collapse = " +\n  ")))
}

#' Result tables, checks and text for a meta-analysis fitted by sn_meta_code().
sn_meta_assemble <- function(env, o, ctx, effect, log_scale) {
  m <- env$meta; s <- env$studies; pr <- env$pooled
  random <- o$model == "random"
  tf <- if (log_scale) exp else identity
  pct <- sn_pct(o$conf_level)
  ci_rows <- function(lo, hi) I(lapply(seq_along(lo), function(i) c(tf(lo[i]), tf(hi[i]))))
  srows <- data.frame(study = s$study, est = tf(s$yi), weight = s$weight, stringsAsFactors = FALSE)
  srows$ci <- ci_rows(s$lower, s$upper)
  knha <- identical(m$test, "knha")
  prow <- data.frame(model = if (random) "Random effects" else "Common effect", k = as.integer(m$k), est = tf(pr$pred), se = m$se, stat = unname(m$zval), p = m$pval)
  prow$ci <- ci_rows(pr$ci.lb, pr$ci.ub)
  pcols <- list(sn_col("model", "Model", "text"), sn_col("k", "k", "int"), sn_col("est", effect, digits = 3), sn_col("se", if (log_scale) "SE (log)" else "SE", digits = 3), sn_col("ci", pct, "ci", 3))
  has_pi <- random && isTRUE(o$prediction) && !is.null(pr$pi.lb)
  if (has_pi) { prow$pi <- ci_rows(pr$pi.lb, pr$pi.ub); pcols <- c(pcols, list(sn_col("pi", sub("CI", "prediction interval", pct), "ci", 3))) }
  if (knha) { prow$df <- m$ddf; pcols <- c(pcols, list(sn_col("stat", "t"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue"))) }
  else pcols <- c(pcols, list(sn_col("stat", "z"), sn_col("p", "p", "pvalue")))
  tables <- list(
    sn_table("studies", "Individual Studies", list(sn_col("study", "Study", "text"), sn_col("est", effect, digits = 3), sn_col("ci", pct, "ci", 3), sn_col("weight", "Weight (%)", digits = 1)),
             srows[, c("study", "est", "ci", "weight")]),
    sn_table("pooled", "Pooled Effect", pcols, prow[, vapply(pcols, function(c) c$id, ""), drop = FALSE],
      notes = c(if (random) paste0("τ² estimated by ", c(REML = "restricted maximum likelihood", DL = "DerSimonian-Laird", PM = "Paule-Mandel")[[o$tau2]], if (knha) "; Hartung-Knapp adjustment" else "", "."),
                if (log_scale) "Estimates and intervals are back-transformed from the log scale.")),
    sn_tbl_wide("heterogeneity", "Heterogeneity",
      list(sn_col("q", "Q"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue"), sn_col("tau2", "τ²", digits = 4), sn_col("tau", "τ", digits = 4), sn_col("i2", "I² (%)", digits = 1), sn_col("h2", "H²")),
      list(q = m$QE, df = as.integer(m$k - 1), p = m$QEp, tau2 = if (random) m$tau2 else NA, tau = if (random) sqrt(m$tau2) else NA, i2 = m$I2, h2 = m$H2))
  )
  mm <- sn_get(env, "meta_mod")
  if (!is.null(mm)) {
    cf <- stats::coef(summary(mm))
    rows <- data.frame(term = rownames(cf), est = cf$estimate, se = cf$se, stat = cf[[3]], p = cf$pval)
    rows$ci <- I(lapply(seq_len(nrow(cf)), function(i) c(cf$ci.lb[i], cf$ci.ub[i])))
    tables <- c(tables, list(sn_table("moderator", paste0("Meta-Regression: ", o$moderator),
      list(sn_col("term", "Term", "text"), sn_col("est", if (log_scale) "B (log scale)" else "B", digits = 4), sn_col("se", "SE", digits = 4), sn_col("stat", if (identical(mm$test, "knha")) "t" else "z"),
           sn_col("p", "p", "pvalue"), sn_col("ci", pct, "ci", 4)), rows,
      notes = c(sprintf("Test of moderators: Q%s = %s, %s.", if (identical(mm$test, "knha")) sprintf("M F(%d, %d)", mm$QMdf[1], mm$QMdf[2]) else sprintf("M(%d)", mm$QMdf[1]), fmt_num(mm$QM), apa_p(mm$QMp)),
                if (random && !is.null(mm$R2)) sprintf("The moderator accounts for %.1f%% of the between-study variance (R²).", mm$R2),
                sprintf("Residual heterogeneity: QE(%d) = %s, %s.", mm$k - mm$p, fmt_num(mm$QE), apa_p(mm$QEp))))))
  }
  eg <- sn_get(env, "egger"); tfl <- sn_get(env, "trim_fill")
  if (!is.null(eg) || !is.null(tfl)) {
    rows <- list()
    if (!is.null(eg)) rows$egger <- data.frame(test = "Egger's regression test", result = sprintf("t(%d) = %s, %s", eg$dfs, fmt_num(eg$zval), apa_p(eg$pval)), stringsAsFactors = FALSE)
    if (!is.null(tfl)) rows$tf <- data.frame(test = "Trim and fill", stringsAsFactors = FALSE,
      result = sprintf("%d missing stud%s on the %s; adjusted %s = %s [%s, %s]", tfl$k0, if (tfl$k0 == 1) "y" else "ies", tfl$side, tolower(effect),
                       fmt_num(tf(tfl$beta[1]), 3), fmt_num(tf(tfl$ci.lb), 3), fmt_num(tf(tfl$ci.ub), 3)))
    tables <- c(tables, list(sn_table("bias", "Small-Study Effects (Publication Bias)", list(sn_col("test", "Method", "text"), sn_col("result", "Result", "text")), do.call(rbind, unname(rows)))))
  }
  lo <- sn_get(env, "loo")
  if (!is.null(lo)) {
    rows <- data.frame(study = s$study, est = tf(lo$estimate), p = lo$pval, i2 = lo$I2, stringsAsFactors = FALSE)
    rows$ci <- ci_rows(lo$ci.lb, lo$ci.ub)
    tables <- c(tables, list(sn_table("leave1out", "Leave-One-Out Sensitivity", list(sn_col("study", "Study omitted", "text"), sn_col("est", effect, digits = 3), sn_col("ci", pct, "ci", 3),
      sn_col("p", "p", "pvalue"), sn_col("i2", "I² (%)", digits = 1)), rows[, c("study", "est", "ci", "p", "i2")])))
  }
  checks <- list(sn_check("k", "Number of studies", if (m$k < 5) "warn" else "ok",
    if (m$k < 5) sprintf("Only %d studies: the between-study variance and the pooled interval are unreliable.", m$k) else sprintf("%d studies were pooled.", m$k)))
  if (!is.null(eg)) checks <- c(checks, list(sn_check("egger", "Funnel plot asymmetry (Egger)", if (m$k < 10) "warn" else if (eg$pval < 0.1) "warn" else "ok",
    if (m$k < 10) "With fewer than 10 studies the test has little power; do not read a non-significant result as absence of bias."
    else if (eg$pval < 0.1) "The funnel plot is asymmetric, which can indicate publication bias or other small-study effects." else "No evidence of funnel plot asymmetry.")))
  i2 <- m$I2
  het <- if (i2 >= 75) "considerable" else if (i2 >= 50) "substantial" else if (i2 >= 30) "moderate" else "low"
  text <- sprintf("A %s meta-analysis of %d studies gave a pooled %s of %s, %s [%s, %s], %s = %s, %s. Heterogeneity was %s (I² = %.1f%%, Q(%d) = %s, %s).",
    if (random) "random-effects" else "common-effect", m$k, tolower(effect), fmt_num(tf(pr$pred), 2), pct, fmt_num(tf(pr$ci.lb), 2), fmt_num(tf(pr$ci.ub), 2),
    if (knha) sprintf("t(%d)", m$ddf) else "z", fmt_num(m$zval), apa_p(m$pval), het, i2, m$k - 1, fmt_num(m$QE), apa_p(m$QEp))
  if (has_pi) text <- paste0(text, sprintf(" The prediction interval for a new study is [%s, %s].", fmt_num(tf(pr$pi.lb), 2), fmt_num(tf(pr$pi.ub), 2)))
  sn_result(tables = tables, assumptions = checks, plots = sn_plots(env, ctx, c(p_forest = "Forest plot", p_funnel = "Funnel plot")), interpretation = text)
}
