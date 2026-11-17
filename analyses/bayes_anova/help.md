# Bayesian ANOVA

Compares every model built from the chosen factors (and their interactions) with a null model, and averages over models to judge each effect. Add a subject variable for repeated measures: it enters every model as a random factor.

**Assumptions**
- Residuals are independent (within subjects once the subject effect is included), roughly normal, with equal variances.
- Fixed effects get a Cauchy prior with scale r (medium r = 0.5).

**Interpreting the output**
- *Model comparison*: P(M|data) is the posterior probability of each model when all models were equally likely beforehand; BF₁₀ compares each model with the null model; BF vs best compares it with the top model.
- *Analysis of effects*: the inclusion Bayes factor compares all models that contain an effect with all models that do not.
- Evidence labels (Lee & Wagenmakers, 2013): BF₁₀ 1–3 anecdotal, 3–10 moderate, 10–30 strong, 30–100 very strong, above 100 extreme evidence for H₁; the same ranges of BF₀₁ = 1/BF₁₀ give evidence for H₀.
- Unlike a p-value, a Bayes factor can show evidence *for* the null hypothesis.
- Posterior estimates give each level's deviation from the grand mean with a credible interval.

**References**
- Rouder, J. N., Morey, R. D., Speckman, P. L., & Province, J. M. (2012). Default Bayes factors for ANOVA designs. *Journal of Mathematical Psychology, 56*(5), 356–374.
- van den Bergh, D., et al. (2020). A tutorial on conducting and interpreting a Bayesian ANOVA in JASP. *L'Année psychologique, 120*(1), 73–96.
- Lee, M. D., & Wagenmakers, E.-J. (2013). *Bayesian cognitive modeling: A practical course*. Cambridge University Press.
- Morey, R. D., & Rouder, J. N. (2024). *BayesFactor: Computation of Bayes factors for common designs* (R package).
