# Regularized Regression

Linear or logistic regression with a penalty that shrinks coefficients. The lasso sets some to exactly zero (variable selection); ridge shrinks all; the elastic net mixes both. Cross-validation chooses the penalty strength λ.

**Assumptions**
- Cases are independent. The model is trained on one part of the data and judged on the held-out part, so results reflect performance on new data.
- Rows with missing values in the outcome or predictors are dropped.
- Set the random seed to get the same split and model each time.
- Predictors are standardized internally, so units do not affect the penalty.

**Interpreting the output**
- Coefficients are penalized: they have no standard errors or p-values. Zero means the variable was dropped.
- 'Largest within 1 SE' gives a simpler model whose error is close to the best.
- *Accuracy* is compared with the *no-information rate* (always predicting the largest class); a useful model beats it clearly.
- *AUC* (two classes) and *κ* account for chance; *balanced accuracy* is better when classes are unequal.
- For numeric outcomes, *RMSE* and *MAE* are in the units of the outcome; *R²* is the share of variance explained in the test set.
- A much better score on the training data than on the test data indicates overfitting.
- *SHAP values* show how much each predictor pushed each prediction up or down from the average prediction; points coloured by the predictor's value reveal the direction.

**References**
- James, G., Witten, D., Hastie, T., & Tibshirani, R. (2021). *An introduction to statistical learning* (2nd ed.). Springer.
- Štrumbelj, E., & Kononenko, I. (2014). Explaining prediction models and individual predictions with feature contributions. *Knowledge and Information Systems, 41*, 647–665.
- Tibshirani, R. (1996). Regression shrinkage and selection via the lasso. *Journal of the Royal Statistical Society B, 58*(1), 267–288.
- Friedman, J., Hastie, T., & Tibshirani, R. (2010). Regularization paths for generalized linear models via coordinate descent. *Journal of Statistical Software, 33*(1).
