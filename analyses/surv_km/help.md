# Kaplan-Meier Survival

Estimates the probability of remaining event-free over time when some cases are censored (still event-free when last seen), and compares survival curves between groups with the log-rank test.

**Assumptions**
- Censoring is unrelated to the risk of the event.
- Survival probabilities are the same for cases recruited early and late.
- The log-rank test has most power when the curves do not cross (proportional hazards).

**Interpreting the output**
- *Median survival* is the time at which half of the cases have had the event; it is not reached when the curve stays above 50%.
- *Survival at selected times* gives the estimated probability of being event-free at the times you enter.
- The *log-rank test* asks whether the curves differ overall. Use Cox regression to adjust for other variables.

**References**
- Kaplan, E. L., & Meier, P. (1958). Nonparametric estimation from incomplete observations. *Journal of the American Statistical Association, 53*(282), 457–481.
- Therneau, T. M., & Grambsch, P. M. (2000). *Modeling survival data: Extending the Cox model*. Springer.
