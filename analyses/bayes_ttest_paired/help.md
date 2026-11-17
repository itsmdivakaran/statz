# Bayesian Paired Samples T-Test

Weighs the evidence for a change between two related measures (H₁), such as before and after, against no change (H₀).

**Assumptions**
- Pairs are independent of each other.
- The differences are roughly normal.
- Cauchy prior on the standardized mean difference δ with width r (medium r = 0.707 by default).

**Interpreting the output**
- BF₁₀ says how many times more likely the data are under H₁ than under H₀.
- Evidence labels (Lee & Wagenmakers, 2013): BF₁₀ 1–3 anecdotal, 3–10 moderate, 10–30 strong, 30–100 very strong, above 100 extreme evidence for H₁; the same ranges of BF₀₁ = 1/BF₁₀ give evidence for H₀.
- Unlike a p-value, a Bayes factor can show evidence *for* the null hypothesis.
- δ is the mean difference (measure 1 − measure 2) divided by the standard deviation of the differences.

**References**
- Rouder, J. N., Speckman, P. L., Sun, D., Morey, R. D., & Iverson, G. (2009). Bayesian t tests for accepting and rejecting the null hypothesis. *Psychonomic Bulletin & Review, 16*(2), 225–237.
- Lee, M. D., & Wagenmakers, E.-J. (2013). *Bayesian cognitive modeling: A practical course*. Cambridge University Press.
- Morey, R. D., & Rouder, J. N. (2024). *BayesFactor: Computation of Bayes factors for common designs* (R package).
