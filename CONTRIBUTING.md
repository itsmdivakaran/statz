# Contributing to StatNext

Thanks for helping. StatNext is GPL-3 licensed; contributions are accepted under the same licence.

## Setup
Install R ≥ 4.4, Node 22 with pnpm 10, and Rust stable (Windows: Git Bash, Visual Studio C++ build tools, WebView2).
```sh
R CMD INSTALL r-backend
Rscript scripts/install-r-packages.R
cd frontend && pnpm install
```
See `AGENTS.md` for the full command list.

## Workflow
1. Branch from `dev` (`feature/<topic>`, `fix/<topic>`, or `review/<name>`).
2. Make a focused change with tests. A new or changed analysis needs a testthat case with a published reference value, regenerated fixtures (`Rscript scripts/make-fixtures.R`) and an updated `help.md`.
3. Run locally: testthat, `pnpm typecheck && pnpm test`, and Playwright for UI changes; `cargo test` for Rust.
4. Open a PR against `dev` describing what changed and how it was verified. CI must pass.

## Adding an analysis or plugin
An analysis is a folder with `spec.json`, `<id>.R` and `help.md` (format: `schemas/module.schema.json`, example: `r-backend/inst/plugin-template/`). Built-in analyses go in `analyses/`; community plugins are installed through Plugins › Manage plugins.

## Code style
R: tidyverse style, `sn_` prefix for internal helpers. TypeScript: strict mode, functional components, zustand store in `frontend/src/state/store.ts`. Rust: `cargo fmt` and `cargo clippy` clean.

## Reporting bugs
Open a GitHub issue with the analysis, options, a small dataset or example name, StatNext and R versions, and the generated R code.
