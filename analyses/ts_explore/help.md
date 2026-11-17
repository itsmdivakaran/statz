# Time Series Explorer

Describes a series before modelling: trend, seasonal pattern, autocorrelation and stationarity.

**Assumptions**
- Observations are equally spaced in time and in time order (choose a time variable to sort the rows).
- Set the seasonal period: 12 for monthly data, 4 for quarterly, 1 for none.
- No gaps: missing values in the series are dropped, which shifts the time index.

**Interpreting the output**
- The *decomposition* splits the series into trend, seasonal and remainder parts. Use multiplicative (or a log transform) when seasonal swings grow with the level.
- *Strength* of trend and seasonality runs from 0 (none) to 1 (dominant).
- *ACF/PACF* bars outside the dashed limits show autocorrelation; they guide the choice of ARIMA orders.
- *ADF* tests the null of a unit root; *KPSS* tests the null of stationarity. A stationary series has a small ADF p and a large KPSS p.

**References**
- Hyndman, R. J., & Athanasopoulos, G. (2021). *Forecasting: Principles and practice* (3rd ed.). OTexts.
- Cleveland, R. B., Cleveland, W. S., McRae, J. E., & Terpenning, I. (1990). STL: A seasonal-trend decomposition procedure based on loess. *Journal of Official Statistics, 6*(1), 3–73.
