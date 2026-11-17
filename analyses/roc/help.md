# ROC Curve Analysis

Shows how well a continuous marker separates two outcome groups across all possible cut-offs, and finds the cut-off with the best balance of sensitivity and specificity.

**Assumptions**
- The outcome has two values and the reference classification is correct.
- Each marker is ordinal or continuous; the direction is detected automatically unless you set it.
- At least about 30 subjects in each outcome group for a stable AUC.

**Interpreting the output**
- *AUC*: probability that a random positive case scores higher than a random negative one. 0.5 is chance; 0.7–0.8 acceptable, 0.8–0.9 excellent, above 0.9 outstanding.
- The *Youden cut-off* maximises sensitivity + specificity − 1. It is optimistic on the same data; validate it elsewhere.
- The *DeLong test* compares the AUCs of markers measured on the same subjects.

**References**
- DeLong, E. R., DeLong, D. M., & Clarke-Pearson, D. L. (1988). Comparing the areas under two or more correlated ROC curves. *Biometrics, 44*(3), 837–845.
- Robin, X., et al. (2011). pROC: An open-source package for R and S+ to analyze and compare ROC curves. *BMC Bioinformatics, 12*, 77.
