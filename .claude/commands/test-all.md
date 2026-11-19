---
description: Run the full local test suite (R, frontend, Rust)
---
Run in order and report each result: `R CMD INSTALL r-backend`; `STATNEXT_ROOT=$PWD Rscript -e 'testthat::test_dir("r-backend/tests/testthat")'`; `pnpm --dir frontend typecheck`; `pnpm --dir frontend test`; `pnpm --dir frontend e2e --trace off`; `STATNEXT_TEST_R=1 cargo test --manifest-path src-tauri/Cargo.toml`. Stop at the first failure and show its output.
