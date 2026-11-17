# Logistic Regression

Models the probability of one of two outcome categories. The second category of the outcome is the one modelled; the first is the reference.

- **Odds ratio** above 1 means higher odds of the outcome per one-unit increase (or versus the reference level); below 1 means lower odds.
- **Model fit**: the likelihood-ratio χ² compares the model with an intercept-only model. McFadden and Nagelkerke R² are pseudo-R² values. **AUC** is the area under the ROC curve (0.5 = chance, 1 = perfect discrimination).
- **Hosmer-Lemeshow** compares predicted and observed risk in ten groups; a significant result signals poor calibration.

Confidence intervals are Wald intervals.

R functions: `glm(family = binomial)`, `confint.default()`, `car::vif()`.
