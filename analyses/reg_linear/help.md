# Linear Regression

Models a continuous outcome as a linear function of one or more predictors.

- **Covariates** enter as numbers; **factors** are dummy coded against their first level.
- **B** is the change in the outcome per one-unit change in the predictor, holding the others fixed. **β** is the same on a standard-deviation scale, so predictors can be compared.
- **Interactions** are added under *Model*; main effects stay in the model.

Assumption checks: linearity and constant variance (residual plot, Breusch-Pagan), normal residuals (Q-Q plot, Shapiro-Wilk), no strong collinearity (VIF below about 5) and no single case driving the fit (Cook's distance).

R functions: `lm()`, `confint()`, `car::vif()`, `car::ncvTest()`, `car::Anova()`.
