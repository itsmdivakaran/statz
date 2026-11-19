# StatNext

Point-and-click statistics desktop app. Every result is computed by a local R and comes with the exact R code that produced it.

Website and user guide: <https://itsmdivakaran.github.io/statz/>

- **Shell:** Tauri 2 (Rust) · React 18 + TypeScript + Tailwind
- **Engine:** local R ≥ 4.4 (`r-backend/`, package `statnextr`) over JSON-RPC on stdio
- **Plots:** ggnext (SVG + interactive HTML), ggplot2 fallback flagged in the UI
- **Platforms:** Windows 10/11, macOS (Apple silicon and Intel), Linux, all built from the same tree

![Independent t-test](docs/screenshots/main.png)

## Download and install

Latest: [v0.5.1](https://github.com/itsmdivakaran/statz/releases/tag/v0.5.1). Install [R 4.4 or later](https://cloud.r-project.org/) first (or let StatNext's setup screen take you there).

| Computer | Installer |
|---|---|
| Windows 10/11 (64-bit) | [StatNext_0.5.1_x64-setup.exe](https://github.com/itsmdivakaran/statz/releases/download/v0.5.1/StatNext_0.5.1_x64-setup.exe) (or [.msi](https://github.com/itsmdivakaran/statz/releases/download/v0.5.1/StatNext_0.5.1_x64_en-US.msi)) |
| Mac, Apple silicon | [StatNext_0.5.1_aarch64.dmg](https://github.com/itsmdivakaran/statz/releases/download/v0.5.1/StatNext_0.5.1_aarch64.dmg) |
| Mac, Intel | [StatNext_0.5.1_x64.dmg](https://github.com/itsmdivakaran/statz/releases/download/v0.5.1/StatNext_0.5.1_x64.dmg) |
| Linux | [.AppImage](https://github.com/itsmdivakaran/statz/releases/download/v0.5.1/StatNext_0.5.1_amd64.AppImage) or [.deb](https://github.com/itsmdivakaran/statz/releases/download/v0.5.1/StatNext_0.5.1_amd64.deb) |

**Windows:** double-click the `setup.exe`. If SmartScreen says "Windows protected your PC", click **More info › Run anyway** (the installer is not code-signed yet). StatNext appears in the Start menu. On first launch it finds R (from the registry or `Program Files\R`) and installs its R packages into its own library, which takes 3 to 10 minutes and needs internet.

**macOS:** open the `.dmg` and drag StatNext into Applications. The build is not notarized yet, so the first time open System Settings › Privacy & Security and click **Open Anyway**.

## What is in it

| Area | Contents |
|---|---|
| Data | CSV/TSV, Excel, SPSS, Stata, SAS, Parquet; virtual grid; variable view (labels, measure, value labels, missing codes); compute, recode and filter with undo/redo |
| Descriptives | Descriptives, frequencies, normality; reliability: Cronbach's α, ICC, Cohen's kappa |
| T-tests, ANOVA | One-sample, paired, independent; one-way (Fisher, Welch, Kruskal-Wallis; Tukey, Games-Howell, Dunn), factorial, ANCOVA, repeated measures, mixed |
| Non-parametric | Wilcoxon signed-rank, sign test, Friedman |
| Frequencies | Chi-square / Fisher, goodness of fit, binomial, McNemar, Cochran's Q |
| Regression | Correlation (Pearson, Spearman, Kendall, partial); linear, logistic, ordinal, multinomial, Poisson / negative binomial; linear and generalized mixed models |
| Survival | Kaplan-Meier with log-rank test, Cox regression with proportional-hazards check |
| Multivariate | PCA, exploratory factor analysis (KMO, Bartlett, rotations), k-means and hierarchical clustering (silhouette) |
| Machine learning | Decision tree, random forest, gradient boosting, elastic net, SVM, naive Bayes, LDA; classification or regression, train/test split, confusion matrix, ROC/AUC, permutation importance, SHAP |
| Time series | Explore (decomposition, ACF/PACF, stationarity tests), ARIMA and ETS forecasting with hold-out accuracy |
| Clinical | Diagnostic accuracy (2×2, ROC with DeLong), meta-analysis (generic, binary, continuous; forest, funnel, Egger, trim-and-fill, leave-one-out, moderators), Table 1 and adverse-event tables |
| Bayesian | T-tests (one-sample, paired, independent), ANOVA (incl. repeated measures), correlation, contingency tables, linear regression, binomial test; Bayes factors with evidence labels, posterior estimates, prior/posterior, robustness and sequential plots (BayesFactor) |
| Guide | "Which analysis should I use?": a few plain questions (or your own variables) pick the test, with alternatives and a Bayesian option, and open it ready to run |
| Plugins | Add analyses in the same format as the built-in ones (spec.json + R file + help.md): install from a folder or .zip, update, remove, starter plugin to copy |
| Workspace | Green, blue and pink theme (light and dark); drag and drop variables between the list and role boxes (or double-click); toolbar (open, save, undo, redo, search), labelled ribbon of analysis menus, resizable data / analysis / output panes that can each be maximized or minimized, status bar; start page with one-click worked examples and 28 example datasets |
| Interpretation | Plain-language summary under each test and model from easystats `report()` (offline, included in the R code and exports; can be turned off in Settings) |
| AI assistant (optional, off by default) | Bring your own key: Anthropic Claude, OpenAI, Google Gemini, any OpenAI-compatible server, or Ollama on your own computer. Chat panel plus an Explain button on each result. Keys are kept in the system keychain; only result tables, summaries and your questions are sent, never data rows, and each attachment can be reviewed before sending |
| Output | APA tables, assumption checks, auto interpretation, plots (SVG/PNG/PDF/HTML/CSV); all results to Word (.docx), PDF or HTML |
| R code | Per analysis, editable and re-runnable; whole session exports as `.R`, `.Rmd` or `.qmd` |
| Projects | `.statnext` = zip of manifest, UI state and `data.rds` |

## Screenshots (v0.4.1)

| | |
|---|---|
| ![Start page](docs/screenshots/welcome.png) | ![Kaplan-Meier survival](docs/screenshots/survival.png) |
| Start page: open data, worked examples, example datasets | Kaplan-Meier survival with log-rank test |
| ![Bayesian t-test](docs/screenshots/bayesian.png) | ![Analysis guide](docs/screenshots/guide.png) |
| Bayesian independent t-test | "Which test should I use?" guide |
| ![Regression menu](docs/screenshots/regression-menu.png) | ![R code](docs/screenshots/code.png) |
| Analysis ribbon and menus | Editable R code behind every result |
| ![Recode](docs/screenshots/recode.png) | ![Dark theme](docs/screenshots/dark.png) |
| Recode a variable (undoable) | Dark theme |

Sample results export: [Word](docs/samples/sample-results.docx) · [PDF](docs/samples/sample-results.pdf)

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

Adding an analysis = new folder in `analyses/`; no TypeScript or Rust changes. The same folder installed through **Plugins › Manage plugins** works as a plugin; **Create a starter plugin** writes a working example with a README (template in `r-backend/inst/plugin-template/`).

## Develop

Requires R ≥ 4.4, Node 22 + pnpm, Rust stable.

```sh
R CMD INSTALL r-backend
Rscript scripts/install-r-packages.R
cd frontend && pnpm install

pnpm bridge & pnpm dev          # UI in a browser at :5173, real R via the dev bridge
cd .. && pnpm dev               # desktop app (run from the repo root)
```

Tests:

```sh
STATNEXT_ROOT=$PWD Rscript -e 'testthat::test_dir("r-backend/tests/testthat")'
cd frontend && pnpm typecheck && pnpm test && pnpm e2e --trace off
STATNEXT_TEST_R=1 cargo test --manifest-path src-tauri/Cargo.toml
Rscript scripts/make-fixtures.R   # regenerate tests/fixtures after changing a module
Rscript scripts/option-sweep.R    # run every option value of every analysis (about 10 minutes)
```

On Windows, run the commands above in Git Bash (PowerShell reads `R` as its own command; use `R.exe CMD INSTALL r-backend` there). Building the desktop app needs the Visual Studio C++ build tools and WebView2 (preinstalled on Windows 10/11). CI runs the R tests and the desktop worker tests against real R on Windows for every push.

Installers: run the "Release installers" workflow (or push a `v*` tag); `.github/workflows/release.yml` builds `.dmg`, Windows `setup.exe` and `.msi`, `.AppImage`, `.deb` (unsigned until Apple signing secrets are set).

On first launch the app installs missing R packages into a private library from a date-pinned Posit Package Manager snapshot, so results are reproducible across machines.

## Website

`site/` is the static website (landing page, downloads, user guide). The "Website" workflow (`.github/workflows/pages.yml`) publishes it to GitHub Pages on every push to `site/`. Download buttons read the newest release from the GitHub API, so they need no update per release.

## Credits

Authors: Mahesh Divakaran ([ORCID](https://orcid.org/0000-0002-3488-0857)), Prof. Dr. Jayadevan Sreedharan ([ORCID](https://orcid.org/0000-0001-5350-2408)), Dr. Rasin R S ([ORCID](https://orcid.org/0000-0002-8393-5869)), Rakesh Podhuval, Dr. Rahul T, Prashanth V P.

## Cite

See [CITATION.cff](CITATION.cff) (GitHub shows it as **Cite this repository**). Releases are archived on Zenodo.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
