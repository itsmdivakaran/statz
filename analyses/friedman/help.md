# Friedman Test

Non-parametric alternative to repeated measures ANOVA. Each row is one subject and each selected variable is one condition or time point.

- Values are ranked within each subject, and the test asks whether the mean ranks differ between conditions.
- **Kendall's W** is the effect size, from 0 (no agreement in ranks) to 1 (identical ordering in every subject).
- **Pairwise comparisons** use Wilcoxon signed-rank tests with adjusted p-values.

R functions: `friedman.test()`, `pairwise.wilcox.test(paired = TRUE)`.
