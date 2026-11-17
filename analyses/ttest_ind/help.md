# Independent Samples T-Test

Compares the means of one continuous outcome between two independent groups.

**Assumptions**
- Observations are independent.
- The outcome is roughly normal in each group (less important when each group has more than ~30 cases).
- Student's test assumes equal variances; Welch's test (the default) does not.

**Interpreting the output**
- *t*, *df* and *p* test whether the population means differ.
- The mean difference and its confidence interval give the size and precision of the difference (group 1 − group 2).
- Cohen's *d* expresses the difference in pooled standard deviations (0.2 small, 0.5 medium, 0.8 large).
- Mann-Whitney U is the rank-based alternative when normality is doubtful; its effect size is the rank-biserial correlation.

**References**
- Delacre, M., Lakens, D., & Leys, C. (2017). Why psychologists should by default use Welch's t-test instead of Student's t-test. *International Review of Social Psychology, 30*(1), 92–101.
- Cohen, J. (1988). *Statistical power analysis for the behavioral sciences* (2nd ed.). Erlbaum.
