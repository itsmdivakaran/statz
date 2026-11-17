# Bayesian Independent Samples T-Test

Weighs the evidence for a difference between two independent group means (H₁) against no difference (H₀) with a Bayes factor.

**Assumptions**
- Observations are independent.
- The outcome is roughly normal in each group with equal variances.
- The prior on the standardized effect size δ is a Cauchy distribution; its width r sets how large effects are expected (medium r = 0.707 is the usual default).

**Interpreting the output**
- BF₁₀ says how many times more likely the data are under H₁ than under H₀. BF₀₁ is its inverse.
- Evidence labels (Lee & Wagenmakers, 2013): BF₁₀ 1–3 anecdotal, 3–10 moderate, 10–30 strong, 30–100 very strong, above 100 extreme evidence for H₁; the same ranges of BF₀₁ = 1/BF₁₀ give evidence for H₀.
- Unlike a p-value, a Bayes factor can show evidence *for* the null hypothesis.
- The posterior median of δ and its credible interval give the size of the difference (group 1 − group 2) in standard deviations.
- The robustness check shows whether the conclusion depends on the prior width; the sequential plot shows how the evidence grew as data came in.

**References**
- Rouder, J. N., Speckman, P. L., Sun, D., Morey, R. D., & Iverson, G. (2009). Bayesian t tests for accepting and rejecting the null hypothesis. *Psychonomic Bulletin & Review, 16*(2), 225–237.
- Lee, M. D., & Wagenmakers, E.-J. (2013). *Bayesian cognitive modeling: A practical course*. Cambridge University Press.
- Morey, R. D., & Rouder, J. N. (2024). *BayesFactor: Computation of Bayes factors for common designs* (R package).
