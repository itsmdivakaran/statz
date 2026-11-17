# Exploratory Factor Analysis

Looks for a small number of latent factors that explain the correlations among a set of items, for example the traits behind a questionnaire.

**Assumptions**
- Items are continuous or ordinal with at least five categories, and related linearly.
- Several items per factor (three or more) and a sample of 200 or more for stable results.
- KMO of .60 or more and a significant Bartlett test.

**Interpreting the output**
- *Loadings* show how strongly each item reflects each factor. With oblique rotation (oblimin, promax) they are pattern coefficients and the factors may correlate.
- *Communality* is the variance an item shares with the factors; *uniqueness* is the rest.
- Fit: RMSEA below .05 good and below .08 acceptable; TLI above .90 (better .95).
- Choose the number of factors with the scree plot, theory and interpretability; items that load on no factor, or on two, are candidates for removal.

**References**
- Fabrigar, L. R., Wegener, D. T., MacCallum, R. C., & Strahan, E. J. (1999). Evaluating the use of exploratory factor analysis in psychological research. *Psychological Methods, 4*(3), 272–299.
- Revelle, W. (2024). *psych: Procedures for psychological, psychometric, and personality research* [R package].
