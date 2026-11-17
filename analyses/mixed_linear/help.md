# Linear Mixed Model

Models a continuous outcome when observations are grouped, for example repeated measurements on the same person or pupils within schools. A random intercept lets each group have its own baseline; a random slope lets the effect of a predictor differ between groups.

**Assumptions**
- Residuals are roughly normal with constant variance.
- Random effects are normally distributed.
- Groups are independent of each other; observations within a group may be correlated.
- Enough groups (ideally 5 or more, better 20+) to estimate the random-effect variances.

**Interpreting the output**
- *Fixed Effects*: *B* is the average change in the outcome per unit of the predictor; tests use Satterthwaite degrees of freedom.
- *Random Effects*: how much groups differ in their baseline (intercept) and in the effect of a predictor (slope).
- Marginal *R²* is the variance explained by the fixed effects; conditional *R²* adds the random effects. The ICC is the share of variance that lies between groups.
- A *singular fit* warning means the random-effects structure is too complex for the data; remove a random slope.

**References**
- Bates, D., Mächler, M., Bolker, B., & Walker, S. (2015). Fitting linear mixed-effects models using lme4. *Journal of Statistical Software, 67*(1), 1–48.
- Kuznetsova, A., Brockhoff, P. B., & Christensen, R. H. B. (2017). lmerTest package: Tests in linear mixed effects models. *Journal of Statistical Software, 82*(13), 1–26.
- Nakagawa, S., Johnson, P. C. D., & Schielzeth, H. (2017). The coefficient of determination R² and intra-class correlation coefficient from generalized linear mixed-effects models. *Journal of the Royal Society Interface, 14*, 20170213.
