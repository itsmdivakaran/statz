# Intraclass Correlation (ICC)

Measures how well raters (or repeated measurements) agree on a continuous score. Put each rater in its own column and each rated subject in its own row.

**Assumptions**
- Subjects are a random sample.
- Ratings are roughly normal.
- Choose the model that matches the design: one-way when each subject is rated by a different set of raters, two-way random when the same raters are a sample of possible raters, two-way mixed when these raters are the only raters of interest.

**Interpreting the output**
- *Single rater* forms (ICC(1,1), ICC(2,1), ICC(3,1)) describe the reliability of one rater; *mean of raters* forms describe the reliability of the average rating.
- ICC(2,·) measures absolute agreement (raters give the same score); ICC(3,·) measures consistency (raters rank subjects the same way).
- Below .50 poor, .50 to .75 moderate, .75 to .90 good, above .90 excellent (Koo & Li, 2016). Judge by the confidence interval, not only the estimate.

**References**
- Shrout, P. E., & Fleiss, J. L. (1979). Intraclass correlations: Uses in assessing rater reliability. *Psychological Bulletin, 86*(2), 420–428.
- Koo, T. K., & Li, M. Y. (2016). A guideline of selecting and reporting intraclass correlation coefficients for reliability research. *Journal of Chiropractic Medicine, 15*(2), 155–163.
