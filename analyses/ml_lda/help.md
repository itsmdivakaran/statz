# Linear Discriminant Analysis

Finds linear combinations of predictors (discriminants) that best separate the classes, and classifies cases by them.

**Assumptions**
- Cases are independent. The model is trained on one part of the data and judged on the held-out part, so results reflect performance on new data.
- Rows with missing values in the outcome or predictors are dropped.
- Set the random seed to get the same split and model each time.
- Numeric predictors are roughly normal within each class with similar covariance matrices across classes.

**Interpreting the output**
- *Coefficients of linear discriminants* show how each predictor contributes; the proportion of trace is the share of separation each discriminant provides.
- *Accuracy* is compared with the *no-information rate* (always predicting the largest class); a useful model beats it clearly.
- *AUC* (two classes) and *κ* account for chance; *balanced accuracy* is better when classes are unequal.
- For numeric outcomes, *RMSE* and *MAE* are in the units of the outcome; *R²* is the share of variance explained in the test set.
- A much better score on the training data than on the test data indicates overfitting.
- *SHAP values* show how much each predictor pushed each prediction up or down from the average prediction; points coloured by the predictor's value reveal the direction.

**References**
- James, G., Witten, D., Hastie, T., & Tibshirani, R. (2021). *An introduction to statistical learning* (2nd ed.). Springer.
- Štrumbelj, E., & Kononenko, I. (2014). Explaining prediction models and individual predictions with feature contributions. *Knowledge and Information Systems, 41*, 647–665.
- Fisher, R. A. (1936). The use of multiple measurements in taxonomic problems. *Annals of Eugenics, 7*(2), 179–188.
