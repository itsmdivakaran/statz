# Helpers shared by the time-series modules ----

sn_ts_period <- c("1" = "none", "4" = "quarterly", "12" = "monthly", "7" = "daily with a weekly cycle", "52" = "weekly")

#' Code: build the ts object `y` from the series variable (rows sorted by the time variable when given).
sn_ts_code <- function(o, ctx) {
  v <- o$series; tm <- o$time
  freq <- as.integer(o$frequency)
  sn_code(
    paste0("d <- ", ctx$data, "[!is.na(", sn_ref(ctx$data, v), "), , drop = FALSE]"),
    if (length(tm)) paste0("d <- d[order(", sn_ref("d", tm), "), , drop = FALSE]   # rows in time order"),
    paste0("y <- ts(", sn_ref("d", v), ", frequency = ", freq, ", start = c(", as.integer(o$start_year), ", ", min(as.integer(o$start_period), freq), "))"))
}

#' Abort when the series has gaps or too few points (checked on the evaluated series in assemble).
sn_ts_guard <- function(env, min_n = 10) {
  if (length(env$y) < min_n) sn_abort(sprintf("The series has only %d observations; at least %d are needed.", length(env$y), min_n), SN_ERR$invalid_options, data = list(role = "series"))
}

#' Line plot of a ts object.
sn_ts_line_code <- function(engine, title, ylab, obj = "p_series", y = "y") {
  sn_code(
    paste0("series_df <- data.frame(time = as.numeric(time(", y, ")), value = as.numeric(", y, "))"),
    sn_gg(engine, "series_df, aes(time, value)", "geom_line()", title, "Time", ylab, obj))
}

#' Code shared by the forecasting modules once `fit` exists: forecasts, accuracy, residual check, plots.
sn_ts_forecast_code <- function(o, ctx, ylab, n_par) {
  e <- ctx$plot_engine
  h <- as.integer(o$horizon); hold <- as.integer(o$holdout)
  lvl <- sn_lit(100 * o$conf_level)
  sn_code(
    paste0("fc <- forecast::forecast(fit, h = ", if (hold > 0) hold + h else h, ", level = ", lvl, ")"),
    "forecast_tbl <- data.frame(time = as.numeric(time(fc$mean)), forecast = as.numeric(fc$mean), lower = as.numeric(fc$lower), upper = as.numeric(fc$upper))",
    "accuracy_train <- forecast::accuracy(fit)",
    if (hold > 0) c(
      paste0("# Accuracy on the last ", hold, " observations, which the model did not see"),
      "accuracy_test <- forecast::accuracy(fc, y_test)"),
    "# Ljung-Box test: are the residuals free of autocorrelation?",
    paste0("lb_lag <- min(", 2 * as.integer(o$frequency), ", 10, length(y_train) %/% 5)"), 
    paste0("lb_lag <- max(lb_lag, ", n_par, " + 1)"),
    paste0("ljung_box <- Box.test(residuals(fit), lag = lb_lag, type = \"Ljung-Box\", fitdf = ", n_par, ")"),
    if ("forecast" %in% o$plot) c(
      "plot_df <- rbind(",
      "  data.frame(time = as.numeric(time(y)), value = as.numeric(y), lower = NA, upper = NA, part = \"Observed\"),",
      "  data.frame(time = forecast_tbl$time, value = forecast_tbl$forecast, lower = forecast_tbl$lower, upper = forecast_tbl$upper, part = \"Forecast\"))",
      if (e == "ggnext") sn_gg(e, "plot_df, aes(time, value, ymin = lower, ymax = upper, group = part)", "geom_forecast_band()", "Forecast", "Time", ylab, "p_forecast")
      else sn_gg(e, "plot_df, aes(time, value)", c("geom_ribbon(aes(ymin = lower, ymax = upper), data = plot_df[plot_df$part == \"Forecast\", ], alpha = 0.25)", "geom_line(aes(linetype = part))"),
                 "Forecast", "Time", ylab, "p_forecast")),
    if ("residuals" %in% o$plot) sn_ts_acf_code(e, "residuals(fit)", "Residual autocorrelation", "p_residuals", "resid_acf")
  )
}

#' ACF bar plot with white-noise limits.
sn_ts_acf_code <- function(engine, x, title, obj, df, lag = NULL, type = "acf") {
  sn_code(
    paste0(df, " <- with(", if (type == "acf") "acf" else "pacf", "(", x, if (!is.null(lag)) paste0(", lag.max = ", lag), ", plot = FALSE), data.frame(lag = as.numeric(lag) * frequency(y), value = as.numeric(acf)))"),
    if (type == "acf") paste0(df, " <- ", df, "[", df, "$lag > 0, ]"),
    paste0(df, "_limit <- qnorm(0.975) / sqrt(length(", x, "))   # limits expected for white noise"),
    sn_gg(engine, paste0(df, ", aes(x = lag, y = 0, xend = lag, yend = value)"),
          c("geom_segment()", sn_ref_line(engine, "h", paste0(df, "_limit")), sn_ref_line(engine, "h", paste0("-", df, "_limit"))),
          title, "Lag", if (type == "acf") "Autocorrelation" else "Partial autocorrelation", obj))
}

#' Tables, checks and text shared by the forecasting modules.
sn_ts_forecast_assemble <- function(env, o, ctx, model_label, tables = list()) {
  ft <- env$forecast_tbl; pct <- sn_pct(o$conf_level)
  hold <- as.integer(o$holdout)
  acc_row <- function(a, set) data.frame(set = set, rmse = a[1, "RMSE"], mae = a[1, "MAE"], mape = a[1, "MAPE"], mase = if ("MASE" %in% colnames(a)) a[1, "MASE"] else NA, stringsAsFactors = FALSE)
  acc <- acc_row(env$accuracy_train, "Training")
  at <- sn_get(env, "accuracy_test")
  if (!is.null(at)) acc <- rbind(acc, acc_row(at["Test set", , drop = FALSE], sprintf("Hold-out (last %d)", hold)))
  rows <- data.frame(time = fmt_time(ft$time, as.integer(o$frequency)), forecast = ft$forecast, stringsAsFactors = FALSE)
  rows$ci <- I(lapply(seq_len(nrow(ft)), function(i) c(ft$lower[i], ft$upper[i])))
  if (hold > 0) { yt <- as.numeric(env$y_test); rows$actual <- c(yt, rep(NA, nrow(rows) - length(yt))) }
  lb <- env$ljung_box
  tables <- c(tables, list(
    sn_table("accuracy", "Forecast Accuracy", list(sn_col("set", "Data", "text"), sn_col("rmse", "RMSE", digits = 3), sn_col("mae", "MAE", digits = 3), sn_col("mape", "MAPE (%)", digits = 2), sn_col("mase", "MASE", digits = 3)), acc,
             notes = c("MASE below 1 means the model beats a naive forecast.", if (hold > 0) "Hold-out accuracy is the honest measure: those observations were not used to fit the model.")),
    sn_table("forecast", "Forecasts", c(list(sn_col("time", "Time", "text"), sn_col("forecast", "Forecast", digits = 2), sn_col("ci", sub("CI", "interval", pct), "ci", 2)),
                                        if (hold > 0) list(sn_col("actual", "Actual", digits = 2))), rows)))
  chk <- sn_check("residuals", "Residual autocorrelation (Ljung-Box)", if (lb$p.value < 0.05) "warn" else "ok",
    if (lb$p.value < 0.05) "The residuals are still autocorrelated; the model misses some structure in the series." else "The residuals look like white noise.",
    sn_table("ljung_box", "Ljung-Box Test", list(sn_col("stat", "Q"), sn_col("df", "df", "int"), sn_col("p", "p", "pvalue")), data.frame(stat = unname(lb$statistic), df = as.integer(lb$parameter), p = lb$p.value)))
  text <- sprintf("%s was fitted to %d observations of %s (training MAPE = %.1f%%%s). The forecast for %s is %s, %s [%s, %s].",
    model_label, length(env$y_train), o$series, acc$mape[1], if (!is.null(at)) sprintf("; hold-out MAPE = %.1f%%", acc$mape[2]) else "",
    rows$time[nrow(rows)], fmt_num(ft$forecast[nrow(ft)], 1), sub("CI", "interval", pct), fmt_num(ft$lower[nrow(ft)], 1), fmt_num(ft$upper[nrow(ft)], 1))
  sn_result(tables = tables, assumptions = list(chk), plots = sn_plots(env, ctx, c(p_forecast = "Forecast", p_residuals = "Residual autocorrelation")), interpretation = text)
}

#' "1961 Jan", "1961 Q2", "1961" or the plain time index.
fmt_time <- function(t, freq) {
  yr <- floor(t + 1e-6); per <- round((t - yr) * freq) + 1
  if (freq == 12) paste(yr, month.abb[per]) else if (freq == 4) paste0(yr, " Q", per) else if (freq == 1) as.character(yr) else sprintf("%d.%02d", yr, per)
}

#' Code: training series (all but the hold-out) and the hold-out itself.
sn_ts_split_code <- function(o) {
  hold <- as.integer(o$holdout)
  if (hold > 0) c(paste0("y_train <- head(y, length(y) - ", hold, ")"), paste0("y_test <- tail(y, ", hold, ")")) else "y_train <- y"
}
