# ARIMA Forecast

Models a series from its own past values (AR), past errors (MA) and differences (I), with seasonal terms where needed. Automatic selection picks the orders with the lowest AICc.

**Assumptions**
- Observations are equally spaced in time and in time order (choose a time variable to sort the rows).
- Set the seasonal period: 12 for monthly data, 4 for quarterly, 1 for none.
- No gaps: missing values in the series are dropped, which shifts the time index.
- Use a log transform when variability grows with the level.

**Interpreting the output**
- The model name ARIMA(p,d,q)(P,D,Q)[m] gives the orders; coefficients near ±1 may signal over-differencing.
- *Prediction intervals* widen with the horizon; they assume the future behaves like the past.
- *Hold out* the last periods to test the forecast honestly; compare hold-out MAPE and MASE between models.
- *MASE* below 1 means the model beats a naive forecast.
- The *Ljung-Box* test checks that residuals are white noise; if not, the model misses structure.

**References**
- Box, G. E. P., Jenkins, G. M., Reinsel, G. C., & Ljung, G. M. (2015). *Time series analysis: Forecasting and control* (5th ed.). Wiley.
- Hyndman, R. J., & Khandakar, Y. (2008). Automatic time series forecasting: The forecast package for R. *Journal of Statistical Software, 27*(3).
