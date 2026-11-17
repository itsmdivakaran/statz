# Bayesian Binomial Test

For each level of a categorical variable, weighs the evidence that its proportion differs from a test value (H₁) against it equalling the test value (H₀).

**Assumptions**
- Cases are independent and each is either in the level or not.
- Logistic prior on the log odds, centred on the test value, with scale r (medium r = 0.5).

**Interpreting the output**
- BF₁₀ for each level.
- Evidence labels (Lee & Wagenmakers, 2013): BF₁₀ 1–3 anecdotal, 3–10 moderate, 10–30 strong, 30–100 very strong, above 100 extreme evidence for H₁; the same ranges of BF₀₁ = 1/BF₁₀ give evidence for H₀.
- Unlike a p-value, a Bayes factor can show evidence *for* the null hypothesis.
- The posterior median proportion and its credible interval estimate the population proportion.

**References**
- Lee, M. D., & Wagenmakers, E.-J. (2013). *Bayesian cognitive modeling: A practical course*. Cambridge University Press.
- Morey, R. D., & Rouder, J. N. (2024). *BayesFactor: Computation of Bayes factors for common designs* (R package).
