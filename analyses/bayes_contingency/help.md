# Bayesian Contingency Table

Weighs the evidence for an association between two categorical variables (H₁) against independence (H₀).

**Assumptions**
- Each case falls in exactly one cell and cases are independent.
- Choose the sampling plan that matches how the data were collected: only the total fixed (most surveys), row or column totals fixed by design (for example a set number of patients per arm), or nothing fixed (counts over a period).
- Dirichlet prior on the cell probabilities with concentration a (1 = uniform).

**Interpreting the output**
- BF₁₀ above 1 favours association, below 1 favours independence.
- Evidence labels (Lee & Wagenmakers, 2013): BF₁₀ 1–3 anecdotal, 3–10 moderate, 10–30 strong, 30–100 very strong, above 100 extreme evidence for H₁; the same ranges of BF₀₁ = 1/BF₁₀ give evidence for H₀.
- Unlike a p-value, a Bayes factor can show evidence *for* the null hypothesis.
- For 2 × 2 tables the posterior log odds ratio and its credible interval measure the strength of the association.

**References**
- Gunel, E., & Dickey, J. (1974). Bayes factors for independence in contingency tables. *Biometrika, 61*(3), 545–557.
- Jamil, T., Ly, A., Morey, R. D., Love, J., Marsman, M., & Wagenmakers, E.-J. (2017). Default "Gunel and Dickey" Bayes factors for contingency tables. *Behavior Research Methods, 49*(2), 638–652.
- Lee, M. D., & Wagenmakers, E.-J. (2013). *Bayesian cognitive modeling: A practical course*. Cambridge University Press.
- Morey, R. D., & Rouder, J. N. (2024). *BayesFactor: Computation of Bayes factors for common designs* (R package).
