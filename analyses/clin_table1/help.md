# Baseline Characteristics (Table 1)

Summarises subjects' characteristics, overall and by group, in the layout used in clinical papers.

**Assumptions**
- Continuous variables as mean (SD) when roughly symmetric, otherwise median [Q1, Q3].
- Percentages use non-missing values; missing counts are shown separately.
- Tests: Welch t or ANOVA (Wilcoxon or Kruskal-Wallis for medians); chi-square, or Fisher's exact test when expected counts are below 5.

**Interpreting the output**
- In randomized trials, baseline p-values are discouraged (CONSORT): differences are due to chance by design. Use *standardized mean differences* instead; above 0.1 suggests imbalance.
- In observational studies, imbalance on confounders should be addressed in the analysis.

**References**
- Moher, D., et al. (2010). CONSORT 2010 explanation and elaboration. *BMJ, 340*, c869.
- Austin, P. C. (2009). Balance diagnostics for comparing the distribution of baseline covariates between treatment groups in propensity-score matched samples. *Statistics in Medicine, 28*(25), 3083–3107.
