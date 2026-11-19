---
name: update-golden-fixtures
description: Regenerate tests/fixtures/*.result.json after changing an analysis, and review the numeric diff. Use when golden/fixture tests fail or after editing codegen/assemble code.
---
# Update golden fixtures

1. `R CMD INSTALL r-backend` (if `r-backend/R` changed).
2. `Rscript scripts/make-fixtures.R` (repo root; runs every module on its `example`, plot paths reduced to basenames).
3. `git diff --stat tests/fixtures` then inspect each changed file with `git diff`. Classify every change: formatting/ordering, new field, or numeric change. Numeric changes need an explanation (package upgrade, intended fix) and a matching reference value in a testthat file.
4. Never edit fixtures by hand. If only unrelated fixtures changed, the cause is usually an R package version drift: check `scripts/install-r-packages.R` snapshot date before accepting.
5. Report the list of changed modules and your verdict; leave committing to the user.
