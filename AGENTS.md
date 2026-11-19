# AGENTS.md — StatNext

Point-and-click statistics desktop app. Every result is computed by a local R and ships with the exact R code that produced it. Tool-neutral instructions for any coding agent; `CLAUDE.md` imports this file.

## Architecture (three layers, one JSON-RPC protocol)
| Layer | Path | Stack | Role |
|---|---|---|---|
| UI | `frontend/` | React 18, TypeScript, Tailwind 3, zustand, Vite | Dialogs are generated from each analysis `spec.json`. One RPC client for Tauri (`invoke`) and browser (`/bridge` HTTP). |
| Shell | `src-tauri/` | Rust, Tauri 2, tokio | Finds R, bootstraps the private R library, owns the R worker (cancel via SIGINT, crash replay), project files (`.statnext` zip), AI proxy with keychain. |
| Engine | `r-backend/` | R ≥ 4.4, package `statnextr` | Newline-delimited JSON-RPC 2.0 on stdio (`server.R`), module registry, runner, plots, reports. |
| Analyses | `analyses/<id>/` | `spec.json` + `<id>.R` + `help.md` | One folder per analysis; plugins use the identical format. |

Run path: `sn_run_analysis` (`r-backend/R/run.R`) = validate options → `codegen_<id>()` returns R code → that exact code is evaluated → `assemble_<id>()` builds tables/assumptions/plots/interpretation. The code shown to the user is the code that ran.

Other dirs: `schemas/` (module and result JSON schemas), `datasets/` (28 examples + `.meta.json`), `tests/fixtures/` (golden result JSON per module), `scripts/`, `site/` (static GitHub Pages site), `docs/`.

## Commands
Prereqs: R ≥ 4.4, Node 22 + pnpm 10, Rust stable. On Windows use Git Bash.
```sh
R CMD INSTALL r-backend && Rscript scripts/install-r-packages.R
cd frontend && pnpm install
cd frontend && pnpm bridge & pnpm dev        # browser UI at :5173 with real R
pnpm dev                                      # desktop app (from repo root)
# tests
STATNEXT_ROOT=$PWD Rscript -e 'testthat::test_dir("r-backend/tests/testthat")'
cd frontend && pnpm typecheck && pnpm test && pnpm e2e --trace off
STATNEXT_TEST_R=1 cargo test --manifest-path src-tauri/Cargo.toml
Rscript scripts/make-fixtures.R               # regenerate tests/fixtures after changing a module
Rscript scripts/option-sweep.R                # every option value of every analysis (~10 min)
```

## Adding or changing an analysis
1. Copy a similar folder in `analyses/`; no TypeScript or Rust change is needed.
2. `spec.json` must validate against `schemas/module.schema.json` (id `^[a-z][a-z0-9_]*$`, `r.fn` = `codegen_<id>`, roles, options, layout, optional `guide` and `example`).
3. `codegen_<id>(o, meta, ctx)` returns `list(code=, assemble=)`. Use the `sn_*` helpers (`sn_code`, `sn_lit`, `sn_name`, `sn_table`, `sn_col`, `sn_check`, `sn_get`, `sn_suffix`, `sn_plot_code`); never paste user values into code unquoted.
4. Add a testthat case with published reference values (see `r-backend/tests/testthat/test-ttest.R`), then run `Rscript scripts/make-fixtures.R` and review the fixture diff.
5. Write `help.md` (intro, Assumptions, Interpreting the output, References).

## Rules
- Generated code must be reproducible stand-alone: a test evaluates `res$code` in a clean env and compares to the result.
- Keep R stdout protocol-clean: analyses print into captured output (`sn_eval`); only JSON responses go to stdout, progress to stderr prefixed `SN_NOTIFY_PREFIX`.
- Privacy: the optional AI assistant only receives result tables/summaries and user questions, never data rows; API keys live in the OS keychain (`src-tauri/src/ai.rs`). Do not weaken this.
- R packages are installed from a date-pinned Posit Package Manager snapshot for reproducibility; do not unpin.
- Statistical changes need a cited reference value (R documentation, a textbook, or another package). Do not "fix" a golden fixture to make a test pass without explaining the numeric change.
- Do not commit secrets, `node_modules/`, `target/`, `dist/`.
- Authors, ORCIDs and licence (GPL-3) are in `CITATION.cff`, `.zenodo.json`, `DESCRIPTION`, README and site; keep them in sync if touched.

## Pull requests
Branch from `dev` (CI runs on `main`, `dev` and PRs). Keep CI green: testthat on Linux and Windows, vitest + typecheck, Playwright e2e against real R, cargo tests on three OSes. Releases: tag `v*` or run "Release installers"; version lives in `src-tauri/tauri.conf.json`, `src-tauri/Cargo.toml`, `frontend/package.json`, `r-backend/DESCRIPTION`, `CITATION.cff`, README download links.
