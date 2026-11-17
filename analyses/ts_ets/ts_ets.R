# Exponential smoothing state-space models (forecast::ets)

codegen_ts_ets <- function(o, meta, ctx) {
  freq <- as.integer(o$frequency)
  season <- if (freq == 1 || freq > 24) "N" else o$season
  model <- paste0(o$error, o$trend, season)
  damped <- c(auto = "NULL", yes = "TRUE", no = "FALSE")[[o$damped]]
  if (o$trend == "N") damped <- "FALSE"
  code <- sn_code(
    if (length(o$plot)) sn_libs(ctx$plot_engine),
    "",
    paste0("# Exponential smoothing forecast of ", o$series),
    sn_ts_code(o, ctx),
    sn_ts_split_code(o),
    paste0("fit <- forecast::ets(y_train, model = ", sn_lit(model), ", damped = ", damped, ")   # Z = chosen automatically by AICc"),
    "parameters <- fit$par[names(fit$par) %in% c(\"alpha\", \"beta\", \"gamma\", \"phi\")]",
    sn_ts_forecast_code(o, ctx, sn_label(meta, o$series), "length(parameters)")
  )
  list(code = code, assemble = assemble_ts_ets)
}

assemble_ts_ets <- function(env, o, ctx) {
  sn_ts_guard(env)
  f <- env$fit; p <- env$parameters
  what <- c(alpha = "Level smoothing (α)", beta = "Trend smoothing (β)", gamma = "Seasonal smoothing (γ)", phi = "Damping (φ)")
  tables <- list(
    sn_tbl_wide("model", "Model", list(sn_col("model", "Model", "text"), sn_col("sigma2", "σ²", digits = 5), sn_col("loglik", "Log-likelihood"), sn_col("aic", "AIC"), sn_col("aicc", "AICc"), sn_col("bic", "BIC")),
                list(model = f$method, sigma2 = f$sigma2, loglik = f$loglik, aic = f$aic, aicc = f$aicc, bic = f$bic)),
    sn_table("parameters", "Smoothing Parameters", list(sn_col("par", "Parameter", "text"), sn_col("value", "Value", digits = 4)),
             data.frame(par = unname(what[names(p)]), value = unname(p), stringsAsFactors = FALSE),
             notes = "ETS(error, trend, season): A = additive, M = multiplicative, N = none, d = damped. Values near 1 react fast to recent data."))
  sn_ts_forecast_assemble(env, o, ctx, f$method, tables)
}
