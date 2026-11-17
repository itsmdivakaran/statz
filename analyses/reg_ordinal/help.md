# Ordinal Regression

Proportional odds model for an outcome with ordered categories. Each odds ratio describes how the odds of being in a higher category change with the predictor, and is assumed to be the same at every threshold between categories.

- The **thresholds** are the cut points between adjacent categories on the latent scale.
- The **proportional odds** check compares the model with a multinomial model that lets every threshold have its own coefficients. A significant result means the assumption is doubtful.

The category order comes from the value labels, or from the sorted values when there are none.

R functions: `MASS::polr()`, `nnet::multinom()` for the check.
