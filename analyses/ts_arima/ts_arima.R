# ARIMA forecasting (forecast package)

codegen_ts_arima <- function(o, meta, ctx) {
  freq <- as.integer(o$frequency)
  lam <- if (o$transform == "log") ", lambda = 0, biasadj = FALSE" else ""
  i <- function(x) as.integer(x)
  n_par <- if (o$selection == "auto") "length(coef(fit))" else i(o$p) + i(o$q) + (if (freq > 1) i(o$sp) + i(o$sq) else 0)
  code <- sn_code(
    if (length(o$plot)) sn_libs(ctx$plot_engine),
    "",
    paste0("# ARIMA forecast of ", o$series),
    sn_ts_code(o, ctx),
    sn_ts_split_code(o),
    if (o$selection == "auto") paste0("fit <- forecast::auto.arima(y_train", lam, ")   # orders chosen by AICc")
    else paste0("fit <- forecast::Arima(y_train, order = c(", i(o$p), ", ", i(o$d), ", ", i(o$q), ")",
                if (freq > 1) paste0(", seasonal = c(", i(o$sp), ", ", i(o$sd), ", ", i(o$sq), ")"), if (o$drift) ", include.drift = TRUE", lam, ")"),
    "coefs <- data.frame(term = names(coef(fit)), estimate = unname(coef(fit)), se = sqrt(diag(vcov(fit))))",
    "coefs$z <- coefs$estimate / coefs$se",
    "coefs$p <- 2 * pnorm(abs(coefs$z), lower.tail = FALSE)",
    sn_ts_forecast_code(o, ctx, sn_label(meta, o$series), n_par)
  )
  list(code = code, assemble = assemble_ts_arima)
}

assemble_ts_arima <- function(env, o, ctx) {
  sn_ts_guard(env)
  f <- env$fit; cf <- env$coefs
  name <- env$fc$method
  tables <- list(
    sn_tbl_wide("model", "Model", list(sn_col("model", "Model", "text"), sn_col("sigma2", "σ²", digits = 5), sn_col("loglik", "Log-likelihood"), sn_col("aic", "AIC"), sn_col("aicc", "AICc"), sn_col("bic", "BIC")),
                list(model = name, sigma2 = f$sigma2, loglik = f$loglik, aic = f$aic, aicc = f$aicc, bic = f$bic)),
    if (nrow(cf)) sn_table("coefficients", "Coefficients", list(sn_col("term", "Term", "text"), sn_col("estimate", "Estimate", digits = 4), sn_col("se", "SE", digits = 4), sn_col("z", "z"), sn_col("p", "p", "pvalue")), cf,
                           notes = if (o$transform == "log") "The model was fitted to the log series; forecasts are back-transformed."))
  sn_ts_forecast_assemble(env, o, ctx, name, Filter(Negate(is.null), tables))
}
