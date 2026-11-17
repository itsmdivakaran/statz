# Diagnostic Test Accuracy

Compares a binary test result with a reference standard (the truth) and reports how well the test finds people with and without the condition.

**Assumptions**
- The reference standard is accurate and applied to everyone.
- Subjects are representative of those the test will be used on.
- Predictive values depend on prevalence: enter the expected prevalence to get them for another setting.

**Interpreting the output**
- *Sensitivity*: share of diseased people who test positive. *Specificity*: share of healthy people who test negative.
- *PPV / NPV*: chance that a positive / negative result is correct, at the sample prevalence.
- *Likelihood ratios*: LR+ above 10 or LR− below 0.1 change the probability of disease substantially.
- Confidence intervals for proportions are exact (Clopper-Pearson).

**References**
- Altman, D. G., & Bland, J. M. (1994). Diagnostic tests 1: Sensitivity and specificity. *BMJ, 308*, 1552.
- Deeks, J. J., & Altman, D. G. (2004). Diagnostic tests 4: Likelihood ratios. *BMJ, 329*, 168–169.
