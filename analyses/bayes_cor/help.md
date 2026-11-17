# Bayesian Correlation

Weighs the evidence for a linear correlation between each pair of variables (H₁: ρ ≠ 0) against no correlation (H₀: ρ = 0).

**Assumptions**
- Pairs of observations are independent.
- The relationship is linear and the variables are roughly bivariate normal.
- The prior on ρ is a stretched beta distribution; width 1/3 (medium) expects modest correlations, width 1 treats all values of ρ as equally likely.

**Interpreting the output**
- BF₁₀ for each pair, with the sample Pearson r.
- Evidence labels (Lee & Wagenmakers, 2013): BF₁₀ 1–3 anecdotal, 3–10 moderate, 10–30 strong, 30–100 very strong, above 100 extreme evidence for H₁; the same ranges of BF₀₁ = 1/BF₁₀ give evidence for H₀.
- Unlike a p-value, a Bayes factor can show evidence *for* the null hypothesis.
- The posterior median ρ and its credible interval estimate the population correlation.

**References**
- Ly, A., Verhagen, J., & Wagenmakers, E.-J. (2016). Harold Jeffreys's default Bayes factor hypothesis tests. *Journal of Mathematical Psychology, 72*, 19–32.
- Lee, M. D., & Wagenmakers, E.-J. (2013). *Bayesian cognitive modeling: A practical course*. Cambridge University Press.
- Morey, R. D., & Rouder, J. N. (2024). *BayesFactor: Computation of Bayes factors for common designs* (R package).
