# Correlation

Measures how strongly pairs of variables move together.

- **Pearson r** measures linear association and assumes roughly normal, continuous variables without strong outliers.
- **Spearman ρ** and **Kendall τ** work on ranks, so they suit ordinal data and monotonic but non-linear relationships.
- **Partial correlation** removes the linear effect of the control variables from every variable before correlating them.

The confidence interval for Pearson r uses the Fisher z transformation.

R functions: `cor()`, `cor.test()`, `lm()` for the partial residuals.
