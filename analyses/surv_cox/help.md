# Cox Regression

Relates the time until an event to one or more predictors while allowing for censored cases. Results are hazard ratios: how much the event rate changes per unit of a covariate or between categories.

**Assumptions**
- Proportional hazards: each hazard ratio is constant over time (checked with scaled Schoenfeld residuals).
- Censoring is unrelated to the risk of the event.
- About 10 or more events per estimated coefficient.
- Continuous covariates act linearly on the log hazard.

**Interpreting the output**
- A *hazard ratio* above 1 means a higher event rate (shorter survival); below 1 means a lower rate.
- *Concordance* is the probability that the model ranks a random pair of cases correctly (0.5 chance, 1 perfect).
- If the proportional-hazards check fails for a variable, consider stratifying on it or modelling a time-varying effect.

**References**
- Cox, D. R. (1972). Regression models and life-tables. *Journal of the Royal Statistical Society: Series B, 34*(2), 187–220.
- Grambsch, P. M., & Therneau, T. M. (1994). Proportional hazards tests and diagnostics based on weighted residuals. *Biometrika, 81*(3), 515–526.
