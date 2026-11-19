# Vendored third-party skills

Copied unmodified after reading their contents (no network/exec instructions beyond local Playwright scripts). Refresh by re-copying from upstream.

| Skill | Upstream | Commit | Licence | Why |
|---|---|---|---|---|
| webapp-testing | https://github.com/anthropics/skills | e4bb5d9 | Apache-2.0 (`webapp-testing/LICENSE.txt`) | Drive the Vite UI with Playwright |
| r-testthat | https://github.com/posit-dev/skills (r-lib/) | 9519594 | MIT | testthat 3 practice for `r-backend/tests` |
| r-package-development | https://github.com/posit-dev/skills (r-lib/) | 9519594 | MIT | devtools/roxygen workflow for `statnextr` |
| r-tidyverse-style | https://github.com/posit-dev/skills (r-lib/) | 9519594 | MIT | R style pass |
| rust-dev | https://github.com/tenequm/skills | 746da58 | MIT | Rust guidance for `src-tauri` |

Considered and skipped: `tenequm/skills` typescript-dev (targets React 19, Tailwind 4, Biome; this repo is React 18, Tailwind 3, tsc+vitest). No maintained Tauri skill was found; `tauri-r-bridge-debug` is custom.
