# One-Way ANOVA

Compares the means of a continuous outcome across two or more independent groups.

**Assumptions**
- Observations are independent.
- Residuals are roughly normal.
- The classical (Fisher) F-test assumes equal group variances; Welch's F does not.

**Interpreting the output**
- *F* and *p* test whether all group means are equal.
- η² is the share of variance explained by group; ω² is a less biased estimate of the same.
- Post-hoc tests show which pairs of groups differ, adjusting for multiple comparisons (Tukey HSD for the classical model; Bonferroni/Holm-adjusted pooled-SD t-tests).
- Kruskal-Wallis is the rank-based alternative.

**References**
- Field, A. (2018). *Discovering statistics using IBM SPSS Statistics* (5th ed.). Sage.
- Welch, B. L. (1951). On the comparison of several mean values: an alternative approach. *Biometrika, 38*, 330–336.
