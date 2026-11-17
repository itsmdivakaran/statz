# Chi-Square Test of Association

Tests whether two categorical variables are associated, using a contingency table of counts.

**Assumptions**
- Each case contributes to one cell only (independent observations).
- Expected counts are at least 5 in at least 80% of cells and none is below 1. Otherwise use Fisher's exact test.

**Interpreting the output**
- χ², *df* and *p* test whether row and column variables are independent.
- Cramér's *V* (0 to 1) measures the strength of association.
- Row and column percentages show where the association lies.

**References**
- Agresti, A. (2018). *An introduction to categorical data analysis* (3rd ed.). Wiley.
