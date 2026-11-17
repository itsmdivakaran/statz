# Count Regression

Models a count outcome (0, 1, 2, …) on a log scale.

- **Poisson** assumes the variance equals the mean. Check the dispersion statistic: values well above 1 mean overdispersion and too-small standard errors.
- **Negative binomial** adds a parameter (θ) for extra variance and is the usual remedy. **Quasi-Poisson** keeps the Poisson estimates and inflates the standard errors.
- A **rate ratio** is the multiplicative change in the expected count per one-unit increase in the predictor.
- **Exposure** (for example person-years or area) enters as an offset, so the model describes rates.

R functions: `glm(family = poisson)`, `MASS::glm.nb()`.
