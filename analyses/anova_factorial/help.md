# Factorial ANOVA / ANCOVA

Tests how one or more factors, their interactions and optional covariates affect a continuous outcome.

- **Fixed factors** are categorical predictors. All interactions between factors are included by default; remove or add them under *Model*.
- **Covariates** are continuous predictors. Adding one turns the analysis into an ANCOVA.
- **Type III** sums of squares (the default, as in SPSS) test each term after all others, using sum-to-zero contrasts. **Type II** respects marginality and is preferable when interactions are absent.
- **Estimated marginal means** are model-based means, averaged over the other terms and evaluated at the mean of the covariates.

Assumptions: independent observations, normal residuals, equal variances across cells and, for ANCOVA, parallel regression slopes.

R functions: `lm()`, `car::Anova()`, `emmeans::emmeans()`, `pairs()`.
