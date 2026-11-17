# Time series exploration: decomposition, autocorrelation, stationarity

codegen_ts_explore <- function(o, meta, ctx) {
  e <- ctx$plot_engine
  freq <- as.integer(o$frequency)
  dec <- if (freq == 1) "none" else o$decompose
  lab <- paste0(if (o$transform == "log") "log " else "", sn_label(meta, o$series))
  plots <- unlist(o$plot)
  code <- sn_code(
    if (length(plots)) sn_libs(e),
    "",
    paste0("# Time series: ", o$series, " (seasonal period ", freq, ")"),
    sn_ts_code(o, ctx),
    if (o$transform == "log") "y <- log(y)",
    if (dec == "stl") c("decomp <- stl(y, s.window = \"periodic\")", "components <- as.data.frame(decomp$time.series)")
    else if (dec != "none") c(paste0("decomp <- decompose(y, type = ", sn_lit(dec), ")"), "components <- data.frame(seasonal = as.numeric(decomp$seasonal), trend = as.numeric(decomp$trend), remainder = as.numeric(decomp$random))"),
    if (dec != "none") c(
      "# Strength of trend and seasonality (0 = none, 1 = dominant)",
      if (dec == "multiplicative") "strength <- with(log(components), c(trend = max(0, 1 - var(remainder, na.rm = TRUE) / var(trend + remainder, na.rm = TRUE)), seasonal = max(0, 1 - var(remainder, na.rm = TRUE) / var(seasonal + remainder, na.rm = TRUE))))"
      else "strength <- with(components, c(trend = max(0, 1 - var(remainder, na.rm = TRUE) / var(trend + remainder, na.rm = TRUE)), seasonal = max(0, 1 - var(remainder, na.rm = TRUE) / var(seasonal + remainder, na.rm = TRUE))))",
      "seasonal_tbl <- data.frame(period = as.integer(cycle(y))[seq_len(frequency(y))], effect = components$seasonal[seq_len(frequency(y))])"),
    paste0("lags <- min(", as.integer(o$lags), ", length(y) - 2)"),
    "autocorrelation <- data.frame(lag = seq_len(lags), acf = as.numeric(acf(y, lag.max = lags, plot = FALSE)$acf)[-1], pacf = as.numeric(pacf(y, lag.max = lags, plot = FALSE)$acf))",
    "ljung_box <- Box.test(y, lag = lags, type = \"Ljung-Box\")",
    if (o$tests) c(
      "# Stationarity: ADF tests H0 = unit root (non-stationary); KPSS tests H0 = stationary",
      "adf <- suppressWarnings(tseries::adf.test(y))     # warns when p is outside the tabulated range",
      "kpss <- suppressWarnings(tseries::kpss.test(y))"),
    if ("series" %in% plots) sn_ts_line_code(e, paste("Time series of", o$series), lab),
    if ("decomposition" %in% plots && dec != "none") c(
      "parts <- c(\"Observed\", \"Trend\", \"Seasonal\", \"Remainder\")",
      "decomp_df <- data.frame(time = rep(as.numeric(time(y)), 4), value = c(as.numeric(y), components$trend, components$seasonal, components$remainder),",
      "                        component = factor(rep(parts, each = length(y)), levels = parts))",
      "decomp_df <- decomp_df[!is.na(decomp_df$value), ]",
      sn_gg(e, "decomp_df, aes(time, value)", c("geom_line()", "facet_wrap(vars(component), ncol = 1, scales = \"free_y\")"), NULL, "Time", lab, "p_decomposition")),
    if ("acf" %in% plots) sn_ts_acf_code(e, "y", "Autocorrelation (ACF)", "p_acf", "acf_df", "lags"),
    if ("pacf" %in% plots) sn_ts_acf_code(e, "y", "Partial autocorrelation (PACF)", "p_pacf", "pacf_df", "lags", "pacf")
  )
  list(code = code, assemble = assemble_ts_explore)
}

assemble_ts_explore <- function(env, o, ctx) {
  sn_ts_guard(env, 2 * as.integer(o$frequency) + 2)
  y <- env$y; freq <- as.integer(o$frequency)
  tt <- as.numeric(stats::time(y))
  tables <- list(sn_tbl_wide("summary", "Series Summary",
    list(sn_col("n", "N", "int"), sn_col("start", "Start", "text"), sn_col("end", "End", "text"), sn_col("mean", "Mean"), sn_col("sd", "SD"), sn_col("min", "Minimum"), sn_col("max", "Maximum")),
    list(n = length(y), start = fmt_time(tt[1], freq), end = fmt_time(tt[length(tt)], freq), mean = mean(y), sd = stats::sd(y), min = min(y), max = max(y))))
  if (o$transform == "log") tables[[1]]$notes <- list("Statistics are for the log-transformed series.")
  st <- sn_get(env, "strength")
  text <- sprintf("The series %s has %d observations from %s to %s.", o$series, length(y), fmt_time(tt[1], freq), fmt_time(tt[length(tt)], freq))
  if (!is.null(st)) {
    grade <- function(x) if (x >= 0.8) "strong" else if (x >= 0.5) "moderate" else "weak"
    tables <- c(tables, list(
      sn_tbl_wide("strength", "Trend and Seasonality", list(sn_col("trend", "Trend strength", digits = 3), sn_col("seasonal", "Seasonal strength", digits = 3)), list(trend = st[["trend"]], seasonal = st[["seasonal"]])),
      sn_table("seasonal", "Seasonal Effects", list(sn_col("period", "Period", "text"), sn_col("effect", "Effect", digits = 3)),
               data.frame(period = if (freq == 12) month.abb[env$seasonal_tbl$period] else as.character(env$seasonal_tbl$period), effect = env$seasonal_tbl$effect, stringsAsFactors = FALSE),
               notes = if (o$decompose == "multiplicative") "Multiplicative effects: 1 = no effect." else "Additive effects in the units of the series.")))
    text <- paste0(text, sprintf(" It shows a %s trend (strength %s) and %s seasonality (strength %s).", grade(st[["trend"]]), fmt_num(st[["trend"]], 2), grade(st[["seasonal"]]), fmt_num(st[["seasonal"]], 2)))
  }
  ac <- env$autocorrelation
  tables <- c(tables, list(sn_table("autocorrelation", "Autocorrelation", list(sn_col("lag", "Lag", "int"), sn_col("acf", "ACF", digits = 3), sn_col("pacf", "PACF", digits = 3)), ac,
    notes = sprintf("Ljung-Box Q(%d) = %s, %s. Values beyond ±%s differ from white noise.", env$lags, fmt_num(env$ljung_box$statistic), apa_p(env$ljung_box$p.value), fmt_num(stats::qnorm(0.975) / sqrt(length(y)), 3)))))
  checks <- list()
  adf <- sn_get(env, "adf"); kp <- sn_get(env, "kpss")
  if (!is.null(adf)) {
    stationary <- adf$p.value < 0.05 && kp$p.value >= 0.05
    tables <- c(tables, list(sn_table("stationarity", "Stationarity Tests", list(sn_col("test", "Test", "text"), sn_col("h0", "Null hypothesis", "text"), sn_col("stat", "Statistic", digits = 3), sn_col("p", "p", "pvalue")),
      data.frame(test = c("Augmented Dickey-Fuller", "KPSS"), h0 = c("Unit root (non-stationary)", "Stationary"), stat = c(unname(adf$statistic), unname(kp$statistic)), p = c(adf$p.value, kp$p.value), stringsAsFactors = FALSE),
      notes = "p-values are interpolated from tables and are bounded between .01 and .10.")))
    checks <- list(sn_check("stationarity", "Stationarity", if (stationary) "ok" else "warn",
      if (stationary) "Both tests agree that the series is stationary." else "The series does not look stationary; difference it (ARIMA does this for you) or remove the trend before modelling."))
    text <- paste0(text, if (stationary) " The series appears stationary." else " The series is not stationary.")
  }
  sn_result(tables = tables, assumptions = checks,
            plots = sn_plots(env, ctx, c(p_series = "Time series", p_decomposition = "Decomposition", p_acf = "Autocorrelation (ACF)", p_pacf = "Partial autocorrelation (PACF)")), interpretation = text)
}
