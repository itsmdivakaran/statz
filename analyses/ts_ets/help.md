# Exponential Smoothing

Forecasts with weighted averages that give recent observations more weight, with optional trend (possibly damped) and seasonality. Includes Holt and Holt-Winters models. 'Automatic' picks each component by AICc.

**Assumptions**
- Observations are equally spaced in time and in time order (choose a time variable to sort the rows).
- Set the seasonal period: 12 for monthly data, 4 for quarterly, 1 for none.
- No gaps: missing values in the series are dropped, which shifts the time index.

**Interpreting the output**
- The model name ETS(error, trend, season) uses A additive, M multiplicative, N none, d damped.
- Smoothing parameters near 1 react quickly to recent data; near 0 they change slowly.
- *Prediction intervals* widen with the horizon; they assume the future behaves like the past.
- *Hold out* the last periods to test the forecast honestly; compare hold-out MAPE and MASE between models.
- *MASE* below 1 means the model beats a naive forecast.
- The *Ljung-Box* test checks that residuals are white noise; if not, the model misses structure.

**References**
- Hyndman, R. J., Koehler, A. B., Ord, J. K., & Snyder, R. D. (2008). *Forecasting with exponential smoothing: The state space approach*. Springer.
