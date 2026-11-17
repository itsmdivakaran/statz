# K-Means Clustering

Splits cases into k groups so that cases within a group are as similar as possible on the chosen variables.

**Assumptions**
- Clusters are roughly spherical and of similar size; k-means struggles with elongated or nested groups.
- Variables on different scales should be standardized (the default).
- The result depends on random starts; several starts (default 25) and a fixed seed make it stable and reproducible.

**Interpreting the output**
- *Cluster means* describe each group in the original units.
- *Between / total* is the share of variance explained by the clustering.
- *Silhouette width* (−1 to 1): above .70 strong, .50 reasonable, .25 weak structure.
- Use the elbow plot to choose k: the point where adding clusters stops reducing the within-cluster sum of squares much.

**References**
- Hartigan, J. A., & Wong, M. A. (1979). A k-means clustering algorithm. *Applied Statistics, 28*(1), 100–108.
- Rousseeuw, P. J. (1987). Silhouettes: A graphical aid to the interpretation and validation of cluster analysis. *Journal of Computational and Applied Mathematics, 20*, 53–65.
