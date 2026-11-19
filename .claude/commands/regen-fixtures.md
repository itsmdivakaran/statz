---
description: Regenerate golden fixtures and show the diff for review
---
Use the `update-golden-fixtures` skill. Run `Rscript scripts/make-fixtures.R`, then `git diff --stat tests/fixtures` and summarise every numeric change and whether it is expected. Do not commit.
