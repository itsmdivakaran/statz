# Bayesian Linear Regression

Fits every combination of the chosen predictors, ranks the models by their evidence, and averages over models to judge each predictor.

**Assumptions**
- Linear relationships, independent and roughly normal residuals with constant variance.
- JZS (Zellner-Siow) prior on the standardized coefficients with scale r (medium r = 0.354).
- With k predictors there are 2^k models, so keep k moderate (12 at most here).

**Interpreting the output**
- *Model comparison*: P(M|data) is each model's posterior probability, BF₁₀ compares it with the intercept-only model; R² is the ordinary least squares fit.
- *Inclusion Bayes factors*: evidence that a predictor belongs in the model, averaged over all models.
- Evidence labels (Lee & Wagenmakers, 2013): BF₁₀ 1–3 anecdotal, 3–10 moderate, 10–30 strong, 30–100 very strong, above 100 extreme evidence for H₁; the same ranges of BF₀₁ = 1/BF₁₀ give evidence for H₀.
- Unlike a p-value, a Bayes factor can show evidence *for* the null hypothesis.
- Posterior coefficients of the best model are shrunk towards zero relative to least squares.

**References**
- Liang, F., Paulo, R., Molina, G., Clyde, M. A., & Berger, J. O. (2008). Mixtures of g priors for Bayesian variable selection. *Journal of the American Statistical Association, 103*(481), 410–423.
- Rouder, J. N., & Morey, R. D. (2012). Default Bayes factors for model selection in regression. *Multivariate Behavioral Research, 47*(6), 877–903.
- Lee, M. D., & Wagenmakers, E.-J. (2013). *Bayesian cognitive modeling: A practical course*. Cambridge University Press.
- Morey, R. D., & Rouder, J. N. (2024). *BayesFactor: Computation of Bayes factors for common designs* (R package).
