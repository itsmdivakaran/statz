# Wilcoxon Signed-Rank Test

Compares two related measurements without assuming that the differences are normally distributed.

- **Wilcoxon signed-rank** ranks the absolute differences and tests whether positive and negative ranks balance. It assumes the differences are symmetric around their median.
- **Sign test** only uses the direction of each difference. It has less power but makes no symmetry assumption.
- **Rank-biserial correlation** is the effect size: 0 means no effect, ±1 means every difference has the same sign.

R functions: `wilcox.test(paired = TRUE)`, `binom.test()`, `effectsize::rank_biserial()`.
