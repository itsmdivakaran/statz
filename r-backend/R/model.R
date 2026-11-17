# Helpers shared by model-based modules (ANOVA family, regression, mixed, survival) ----

#' Code: complete cases on `vars`, then labelled factors for every nominal/ordinal variable.
#' @param ordered variables to turn into ordered factors.
sn_prep_code <- function(df, data, vars, meta, ordered = character(), numeric_factors = character()) {
  vars <- unique(vars)
  cat_vars <- Filter(function(v) meta$variables[[v]]$measure %in% c("nominal", "ordinal") || v %in% numeric_factors, vars)
  sn_code(
    paste0(df, " <- ", data, "[complete.cases(", data, "[, ", sn_lit(vars), ", drop = FALSE]), , drop = FALSE]"),
    vapply(cat_vars, function(v) sn_factor_code(df, v, meta), ""),
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
