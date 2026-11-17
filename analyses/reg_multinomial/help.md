# Multinomial Regression

Models an outcome with three or more unordered categories. One category (the first) is the reference, and each other category gets its own set of coefficients.

- A **relative risk ratio** above 1 means the predictor raises the chance of that category relative to the reference category.
- The likelihood-ratio χ² compares the model with an intercept-only model.

If the categories are ordered, ordinal regression is usually more efficient.

R function: `nnet::multinom()`.
