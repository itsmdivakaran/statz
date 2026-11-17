# Cochran's Q Test

Extends the McNemar test to three or more binary measurements on the same subjects. It tests whether the proportion of the counted category is the same in every measurement.

- Each variable must have two categories; the second category is the one counted.
- **Pairwise comparisons** are McNemar tests with adjusted p-values.

R functions: base R formula for Q, `mcnemar.test()`, `p.adjust()`.
