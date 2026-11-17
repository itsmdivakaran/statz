# Chi-Square Goodness of Fit

Tests whether the counts in the categories of one variable match a set of expected proportions.

- Leave **expected proportions** blank to test against equal proportions.
- Otherwise give one number per category, in the order shown in the table. They are rescaled to sum to 1, so ratios such as `1, 2, 1` also work.
- Standardised residuals beyond about ±2 mark the categories that deviate most.

The approximation needs expected counts of at least 5 in each category.

R function: `chisq.test(p = ...)`.
