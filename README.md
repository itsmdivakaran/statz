# StatNext

Point-and-click statistics desktop app. Every result is computed by a local R and comes with the exact R code that produced it.

- **Shell:** Tauri 2 (Rust) · React 18 + TypeScript + Tailwind
- **Engine:** local R ≥ 4.4 (`r-backend/`, package `statnextr`) over JSON-RPC on stdio
- **Plots:** ggnext (SVG + interactive HTML), ggplot2 fallback flagged in the UI
- **Platforms:** macOS first; Windows and Linux builds from the same tree

![Independent t-test](docs/screenshots/main.png)

## Phase 1 status

| Area | Contents |
|---|---|
| Data | CSV/TSV, Excel, SPSS, Stata, SAS, Parquet; virtual grid; variable view (labels, measure, value labels, missing codes); undo/redo |
| Analyses | Descriptives, one-sample / paired / independent t-test, one-way ANOVA (Fisher, Welch, Kruskal-Wallis, post hoc), chi-square / Fisher |
| Output | APA tables, assumption checks, auto interpretation, plots (SVG/PNG/PDF/HTML/CSV export) |
| R code | Per analysis, editable and re-runnable; whole session exports as `.R`, `.Rmd` or `.qmd` |
| Projects | `.statnext` = zip of manifest, UI state and `data.rds` |

## Layout

```
analyses/      one folder per analysis: spec.json (UI + options) · <id>.R (codegen) · help.md
r-backend/     statnextr: JSON-RPC server, data, registry, runner, plots, formatting, tests
src-tauri/     R detection, package bootstrap, worker lifecycle (cancel, crash replay), project files
frontend/      React UI, dev bridge (browser ↔ Rscript), unit + Playwright tests
schemas/       module.schema.json, result.schema.json
datasets/      example data + metadata
tests/fixtures golden result JSON per module
```

Adding an analysis = new folder in `analyses/`; no TypeScript or Rust changes.

## Develop

Requires R ≥ 4.4, Node 22 + pnpm, Rust stable.

```sh
R CMD INSTALL r-backend
Rscript -e 'install.packages(c("jsonlite","glue","effectsize","car","ggnext","ggplot2","rsvg","readxl","haven","arrow"))'
cd frontend && pnpm install

pnpm bridge & pnpm dev          # UI in a browser at :5173, real R via the dev bridge
cd .. && pnpm dev               # desktop app (run from the repo root)
```

Tests:

```sh
STATNEXT_ROOT=$PWD Rscript -e 'testthat::test_dir("r-backend/tests/testthat")'
cd frontend && pnpm typecheck && pnpm test && pnpm e2e --trace off
STATNEXT_TEST_R=1 cargo test --manifest-path src-tauri/Cargo.toml
```

Installers: push a `v*` tag; `.github/workflows/release.yml` builds `.dmg`, `.msi`, `.AppImage`, `.deb` (unsigned until Apple signing secrets are set).

On first launch the app installs missing R packages into a private library from a date-pinned Posit Package Manager snapshot, so results are reproducible across machines.
