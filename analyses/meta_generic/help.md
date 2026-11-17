# Meta-Analysis (Effect Sizes)

Pools effect sizes that were already computed in each study, such as mean differences, correlations (Fisher z) or log ratios, using their standard errors. Choose 'Log ratios' to report odds, risk or hazard ratios on their natural scale.

**Assumptions**
- Studies estimate the same kind of effect in comparable populations.
- The random-effects model (default) allows the true effect to vary between studies; the common-effect model assumes one true effect.
- With few studies (under 5) the between-study variance is poorly estimated; the Hartung-Knapp adjustment gives safer intervals.

**Interpreting the output**
- The *forest plot* shows each study's estimate and interval; box size reflects its weight. The pooled estimate is at the bottom.
- *I²* is the share of variability due to real differences between studies: 25% low, 50% moderate, 75% high.
- The *prediction interval* shows where the effect of a new study is likely to fall.
- *Egger's test* and the funnel plot look for small-study effects such as publication bias; they need about 10 or more studies.
- A *moderator* (meta-regression) tests whether a study characteristic explains heterogeneity.

**References**
- Borenstein, M., Hedges, L. V., Higgins, J. P. T., & Rothstein, H. R. (2009). *Introduction to meta-analysis*. Wiley.
- Viechtbauer, W. (2010). Conducting meta-analyses in R with the metafor package. *Journal of Statistical Software, 36*(3), 1–48.
- Higgins, J. P. T., & Thompson, S. G. (2002). Quantifying heterogeneity in a meta-analysis. *Statistics in Medicine, 21*(11), 1539–1558.
