# Hierarchical Clustering

Builds a tree (dendrogram) by repeatedly merging the two most similar cases or clusters, then cuts it into k groups.

**Assumptions**
- The linkage defines similarity between clusters: Ward (default) finds compact groups; single linkage tends to chain.
- Standardize variables on different scales.
- Works best for up to a few thousand cases; the distance matrix grows with the square of N.

**Interpreting the output**
- The *dendrogram* height shows how different merged clusters are; the dashed line marks the cut that gives k clusters.
- *Agglomerative coefficient* near 1 indicates clear cluster structure.
- *Silhouette width* above .50 indicates reasonable separation.

**References**
- Murtagh, F., & Legendre, P. (2014). Ward's hierarchical agglomerative clustering method. *Journal of Classification, 31*, 274–295.
- Kaufman, L., & Rousseeuw, P. J. (1990). *Finding groups in data*. Wiley.
