# Helpers shared by model-based modules (ANOVA family, regression, mixed, survival) ----

#' Code: complete cases on `vars`, then labelled factors for the variables in `factors`.
#' @param ordered variables to turn into ordered factors.
sn_prep_code <- function(df, data, vars, meta, factors = character(), ordered = character()) {
  vars <- unique(vars)
  sn_code(
    paste0(df, " <- ", data, "[complete.cases(", data, "[, ", sn_lit(vars), ", drop = FALSE]), , drop = FALSE]"),
    vapply(intersect(vars, factors), function(v) sn_factor_code(df, v, meta), ""),
    vapply(intersect(ordered, vars), function(v) paste0(sn_ref(df, v), " <- factor(", sn_ref(df, v), ", ordered = TRUE)"), "")
  )
}

#' "a:b" -> "a:b" with each component quoted for a formula.
sn_term <- function(term) {
  vapply(strsplit(term, ":", fixed = TRUE), function(p) paste(sn_name(p), collapse = ":"), "")
}

#' Right-hand side of a formula from term strings; "1" when empty.
sn_rhs <- function(terms) if (length(terms)) paste(sn_term(terms), collapse = " + ") else "1"

sn_formula <- function(lhs, terms) paste0(lhs, " ~ ", sn_rhs(terms))

#' Coefficient rows from a coefficient matrix (estimate, SE, statistic, p in that order)
#' and a two-column CI matrix. With `exp = TRUE` adds exponentiated estimate and CI.
sn_coef_rows <- function(cf, ci = NULL, exp = FALSE, df_col = NULL) {
  cf <- as.matrix(cf)
  n <- nrow(cf)
  pcol <- ncol(cf)
  rows <- data.frame(term = rownames(cf), est = cf[, 1], se = cf[, 2], row.names = NULL)
  if (!is.null(df_col)) rows$df <- cf[, df_col]
  rows$stat <- cf[, pcol - 1]
  rows$p <- cf[, pcol]
  if (!is.null(ci)) {
    ci <- matrix(ci, ncol = 2)
    rows$ci <- I(lapply(seq_len(n), function(i) unname(ci[i, ])))
    if (exp) {
      rows$exp <- exp(cf[, 1])
      rows$exp_ci <- I(lapply(seq_len(n), function(i) unname(exp(ci[i, ]))))
    }
  }
  rows
}

#' Columns matching sn_coef_rows().
sn_coef_cols <- function(rows, stat = "t", est = "B", exp_label = NULL, pct = "95% CI") {
  cols <- list(sn_col("term", "Term", "text"), sn_col("est", est, digits = 3), sn_col("se", "SE", digits = 3))
  if (!is.null(rows$df)) cols <- c(cols, list(sn_col("df", "df")))
  cols <- c(cols, list(sn_col("stat", stat), sn_col("p", "p", "pvalue")))
  if (!is.null(rows$ci)) cols <- c(cols, list(sn_col("ci", pct, "ci", 3)))
  if (!is.null(rows$exp)) cols <- c(cols, list(sn_col("exp", exp_label, digits = 3),
                                               sn_col("exp_ci", paste(exp_label, pct), "ci", 3)))
  cols
}

#' One-row-per-statistic "Model Fit" table from a named list (NULL entries dropped).
sn_tbl_fit <- function(stats, id = "fit", title = "Model Fit", digits = 3) {
  stats <- Filter(function(x) !is.null(x) && length(x) == 1 && !is.na(x), stats)
  sn_table(id, title, list(sn_col("stat", "Statistic", "text"), sn_col("value", "Value", digits = digits)),
           data.frame(stat = names(stats), value = as.numeric(unlist(stats)), row.names = NULL))
}

#' Assumption check from a single htest-like p-value.
sn_chk_p <- function(id, test, p, ok, bad, stat = NULL, stat_label = "Statistic", df = NULL, alpha = 0.05) {
  rows <- data.frame(stat = unname(stat %||% NA_real_), p = unname(p))
  cols <- list(sn_col("stat", stat_label, digits = 3))
  if (!is.null(df)) { rows$df <- unname(df); cols <- c(cols, list(sn_col("df", "df"))) }
  cols <- c(cols, list(sn_col("p", "p", "pvalue")))
  rows <- rows[, vapply(cols, function(c) c$id, ""), drop = FALSE]
  sn_check(id, test, if (isTRUE(p < alpha)) "warn" else "ok", if (isTRUE(p < alpha)) bad else ok,
           sn_table(id, test, cols, rows))
}

#' Plot assignment: `obj <- ctor(args) + layers + labs + theme`.
sn_gg <- function(engine, args, layers, title = NULL, x = NULL, y = NULL, obj = "p") {
  ctor <- if (engine == "ggnext") "ggnext" else "ggplot"
  lab <- c(if (!is.null(title)) paste0("title = ", sn_lit(title)),
           if (!is.null(x)) paste0("x = ", sn_lit(x)), if (!is.null(y)) paste0("y = ", sn_lit(y)))
  paste0(obj, " <- ", paste(c(paste0(ctor, "(", args, ")"), layers,
                              if (length(lab)) paste0("labs(", paste(lab, collapse = ", "), ")"),
                              sn_plot_theme(engine)), collapse = " +\n  "))
}

#' Residuals-vs-fitted plot code for a fitted model object `fit`.
sn_resid_plot_code <- function(engine, fit = "fit", obj = "p_resid", resid = paste0("residuals(", fit, ")")) {
  sn_code(
    paste0("resid_df <- data.frame(fitted = fitted(", fit, "), resid = ", resid, ")"),
    sn_gg(engine, "resid_df, aes(fitted, resid)",
          if (engine == "ggnext") "geom_residual()" else c("geom_point(alpha = 0.7)", "geom_hline(yintercept = 0, linetype = 2)"),
          "Residuals vs fitted", "Fitted values", "Residuals", obj))
}

#' Q-Q plot of residuals.
sn_qq_plot_code <- function(engine, obj = "p_qq") {
  sn_gg(engine, "resid_df, aes(sample = resid)", c("geom_qq()", "geom_qq_line()"),
        "Normal Q-Q plot of residuals", "Theoretical quantiles", "Sample quantiles", obj)
}

#' Forest plot of estimates from a data frame `df` with columns term, est, lower, upper.
sn_forest_plot_code <- function(engine, df = "coef_df", title = "Estimates", xlab = "Estimate (95% CI)", ref = 0, obj = "p_coef") {
  if (engine == "ggnext")
    return(sn_gg(engine, paste0(df, ", aes(est, term, ymin = lower, ymax = upper)"),
                 paste0("geom_forest(ref = ", ref, ")"), title, xlab, NULL, obj))
  sn_gg(engine, paste0(df, ", aes(term, est, ymin = lower, ymax = upper)"),
        c("geom_pointrange()", paste0("geom_hline(yintercept = ", ref, ", linetype = 2)"), "coord_flip()"),
        title, NULL, xlab, obj)
}

#' Render every plot object named in `ids` that exists in env.
sn_plots <- function(env, ctx, ids) {
  Filter(Negate(is.null), lapply(names(ids), function(nm) {
    p <- sn_get(env, nm)
    if (!is.null(p)) ctx$plot(p, ids[[nm]])
  }))
}

sn_pct <- function(conf_level) paste0(round(100 * conf_level), "% CI")

#' Abort unless at least one predictor is assigned to one of `roles`.
sn_need_predictors <- function(o, roles = c("covariates", "factors")) {
  if (!length(unlist(o[roles]))) sn_abort("Add at least one predictor.", SN_ERR$invalid_options,
                                          data = list(role = roles[1], reason = "missing"))
}

#' Code: data frame for a coefficient forest plot from a matrix whose columns `ci` hold the CI.
sn_coef_df_code <- function(coefs = "coefs", rows = "-1", ci = c(5, 6), exp = FALSE) {
  f <- function(x) if (exp) paste0("exp(", x, ")") else x
  sn_code(
    paste0("coef_df <- data.frame(term = rownames(", coefs, "), est = ", f(paste0(coefs, "[, 1]")), ", lower = ", f(paste0(coefs, "[, ", ci[1], "]")),
           ", upper = ", f(paste0(coefs, "[, ", ci[2], "]")), ")", if (nzchar(rows)) paste0("[", rows, ", ]")),
    "coef_df$term <- factor(coef_df$term, levels = rev(coef_df$term))")
}

#' Coefficient table for models whose `coefs` matrix is cbind(coef(summary(fit)), CI).
sn_tbl_coefs <- function(coefs, o, stat = "z", exp_label = NULL, title = "Coefficients", id = "coefficients", notes = character()) {
  rows <- sn_coef_rows(coefs[, 1:4, drop = FALSE], coefs[, 5:6, drop = FALSE], exp = !is.null(exp_label))
  if (!is.null(exp_label)) {
    int <- rows$term == "(Intercept)"
    rows$exp[int] <- NA
    rows$exp_ci[int] <- list(c(NA_real_, NA_real_))
  }
  sn_table(id, title, sn_coef_cols(rows, stat = stat, exp_label = exp_label, pct = sn_pct(o$conf_level)), rows, notes = notes)
}

#' VIF check from car::vif() output (vector, or GVIF matrix when factors are present).
sn_chk_vif <- function(v) {
  if (is.null(v)) return(NULL)
  if (is.matrix(v)) rows <- data.frame(term = rownames(v), vif = v[, ncol(v)]^2, row.names = NULL)
  else rows <- data.frame(term = names(v), vif = unname(v))
  bad <- rows$vif > 5
  sn_check("vif", "Multicollinearity (VIF)", if (any(bad)) "warn" else "ok",
    if (any(bad)) paste0("High collinearity for ", paste(rows$term[bad], collapse = ", "), " (VIF above 5).") else "No variance inflation factor exceeds 5.",
    sn_table("vif", "Variance Inflation Factors", list(sn_col("term", "Term", "text"), sn_col("vif", "VIF")), rows,
             notes = if (is.matrix(v)) "For factors, the value is GVIF^(1/(2·df)) squared, comparable to a VIF."))
}

#' Likelihood-ratio rows: chi-square, df, p.
sn_lrt <- function(chi, df) list(chi = chi, df = df, p = stats::pchisq(chi, df, lower.tail = FALSE))

# Mixed models -------------------------------------------------------------------

#' "(1 + x | g)" random-effects term.
sn_random_term <- function(cluster, slopes = character()) {
  paste0("(", paste(c("1", sn_name(slopes)), collapse = " + "), " | ", sn_name(cluster), ")")
}

#' Random-effects table from as.data.frame(VarCorr(fit)).
sn_tbl_random <- function(vc) {
  is_cov <- !is.na(vc$var2)
  rows <- data.frame(group = vc$grp, term = ifelse(is.na(vc$var1), "", ifelse(is_cov, paste0(vc$var1, " ~ ", vc$var2), vc$var1)),
                     var = ifelse(is_cov, NA, vc$vcov), sd = ifelse(is_cov, NA, vc$sdcor), cor = ifelse(is_cov, vc$sdcor, NA))
  cols <- list(sn_col("group", "Group", "text"), sn_col("term", "Term", "text"), sn_col("var", "Variance", digits = 3), sn_col("sd", "SD", digits = 3))
  if (any(is_cov)) cols <- c(cols, list(sn_col("cor", "Correlation", digits = 3))) else rows$cor <- NULL
  sn_table("random", "Random Effects", cols, rows)
}

#' Name for the derived 0/1 event column that does not clash with a used variable.
sn_event_name <- function(vars) if ("event" %in% vars) "event_01" else "event"

#' Code that defines the 0/1 event column `name` from a two-valued status variable.
sn_event_code <- function(df, event, level, name = "event") {
  sn_code(
    paste0("# Event = the ", if (level == "first") "lower" else "higher", " of the two values of ", event),
    paste0("status_values <- sort(unique(", sn_ref(df, event), "))"),
    paste0(df, "$", name, " <- as.integer(", sn_ref(df, event), " == status_values[", if (level == "first") 1 else 2, "])"))
}

#' Fit-statistics table with one column per statistic.
sn_tbl_wide <- function(id, title, cols, values) {
  keep <- !vapply(values, function(v) is.null(v) || is.na(v), TRUE)
  sn_table(id, title, cols[keep], as.data.frame(values[keep], check.names = FALSE))
}

#' Dashed reference line: `dir` "h" (yintercept), "v" (xintercept) or "ab" (intercept, slope as "a, b").
sn_ref_line <- function(engine, dir, at) {
  fn <- c(h = "geom_hline(yintercept = ", v = "geom_vline(xintercept = ", ab = "geom_abline(")[[dir]]
  if (dir == "ab") at <- paste0("intercept = ", at[1], ", slope = ", at[2])
  paste0(fn, at, if (engine == "ggnext") ", dash = \"4 4\")" else ", linetype = 2)")
}

#' ggnext keeps a fixed left margin, which clips long category labels on the y axis. These helpers draw the
#' labels inside the panel instead. `df` has one row per label in column `col`; `lo`/`hi` are R expressions
#' for the range of the plotted x values; `panel_px` is the approximate panel width.
sn_ylabels_code <- function(df, col, lo, hi, log = FALSE, panel_px = 500) {
  sn_code(
    "# Names are drawn inside the panel, left of the data (ggnext clips long axis labels)",
    paste0("label_pad <- min(0.5, (max(nchar(as.character(", df, "$", col, "))) * 7 + 12) / ", panel_px, ")"),
    if (log) paste0(df, "$label_x <- ", lo, " / (", hi, " / ", lo, ")^(label_pad / (1 - label_pad))")
    else paste0(df, "$label_x <- ", lo, " - (", hi, " - ", lo, ") * label_pad / (1 - label_pad)"))
}
sn_ylabels_layer <- function(col, data = NULL) {
  paste0("geom_text(aes(x = label_x, y = ", col, ", label = ", col, ")", if (!is.null(data)) paste0(", data = ", data), ", anchor = \"start\")")
}
sn_ylabels_theme <- function(legend = TRUE) {
  paste0("theme(axis_title_y = FALSE, axis_text_y = FALSE, ", if (!legend) "legend_position = \"none\", ", "base = theme_modern())")
}
