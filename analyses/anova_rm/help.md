# Repeated Measures ANOVA

Compares means across measurements taken on the same subjects. Data are in wide format: one row per subject and one column per measurement.

- Add **between-subject factors** for a mixed design; the interaction with the within-subject factor is tested automatically.
- **Sphericity** (equal variances of all pairwise differences) is tested with Mauchly's test when there are three or more measurements. If it fails, use the **Greenhouse-Geisser** or **Huynh-Feldt** corrected p-value.
- **Pairwise comparisons** are paired t-tests with adjusted p-values.

R functions: `lm(cbind(...) ~ ...)`, `car::Anova(idata =, idesign =)`, `pairwise.t.test(paired = TRUE)`.
