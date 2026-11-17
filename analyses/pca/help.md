# Principal Component Analysis

Replaces a set of correlated variables with a few uncorrelated components that keep most of the variance. Use it to summarise many measurements, to build an index, or before clustering.

**Assumptions**
- Variables are measured on interval scales and are related roughly linearly.
- Standardize (the default) when variables use different units; otherwise large-variance variables dominate.
- Enough cases: at least 5 to 10 per variable. KMO of .60 or more and a significant Bartlett test suggest reduction is worthwhile.

**Interpreting the output**
- *Eigenvalue*: variance captured by a component. With standardized variables, components above 1 explain more than one original variable (Kaiser criterion).
- *Loadings* are correlations between variables and components; values above about 0.4 in absolute value matter.
- *Communality* is the share of a variable's variance kept by the retained components.
- Use the scree plot: keep the components before the curve flattens.

**References**
- Jolliffe, I. T., & Cadima, J. (2016). Principal component analysis: A review and recent developments. *Philosophical Transactions of the Royal Society A, 374*, 20150202.
- Kaiser, H. F. (1974). An index of factorial simplicity. *Psychometrika, 39*(1), 31–36.
