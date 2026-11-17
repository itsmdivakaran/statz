# Generalized Linear Mixed Model

Models a binary (yes/no) or count outcome when observations are grouped, for example repeated visits per patient. The model is a logistic or Poisson regression with a random intercept (and optional random slopes) for the grouping variable.

**Assumptions**
- Groups are independent; observations within a group share the group's random effect.
- Random effects are normally distributed on the model scale (log odds or log counts).
- For counts, the variance is close to the mean given the predictors (see the overdispersion check).

**Interpreting the output**
- *Fixed Effects*: odds ratios (binary) or rate ratios (counts) above 1 mean a higher probability or rate. They describe the effect for a typical group (conditional on the random effects).
- *Random Effects*: the variance of the group baselines on the model scale.
- A *singular fit* warning means a random-effect variance is estimated as zero; simplify the random effects.

**References**
- Bates, D., Mächler, M., Bolker, B., & Walker, S. (2015). Fitting linear mixed-effects models using lme4. *Journal of Statistical Software, 67*(1), 1–48.
- Bolker, B. M., et al. (2009). Generalized linear mixed models: A practical guide for ecology and evolution. *Trends in Ecology & Evolution, 24*(3), 127–135.
