---
name: add-analysis
description: Add or modify a StatNext analysis module (analyses/<id>/ with spec.json, <id>.R, help.md), including its testthat case and golden fixture. Use when asked to add a statistical test, model or report to the app.
---
# Add an analysis

1. Pick the closest existing module (`ttest_ind` for tests, `reg_linear` for models, `meta_binary` for clinical) and copy its folder to `analyses/<id>/`, renaming files and `codegen_`/`assemble_` functions to the new id.
2. Edit `spec.json`: `id`, `version` 1.0.0, `title`, `menu` (existing menu names: see other specs), `r.file`/`r.fn`/`r.packages`, `roles` (measure types, min/max, `levels`), `options` (types `enum`, `number`, `bool`, `text`, `subset`, `interactions`), `layout` sections, optional `guide` (feeds the "Which analysis?" wizard in `frontend/src/guide/guide.ts` data) and `example` (`dataset` + `options`; the dataset must exist in `datasets/`). Validate against `schemas/module.schema.json`.
3. Edit `<id>.R`: `codegen_<id>(o, meta, ctx)` builds code strings with `sn_code`, `sn_lit`, `sn_name`, `sn_suffix`; returns `list(code =, assemble = assemble_<id>)`. `assemble_<id>(env, o, ctx)` reads objects from `env` (`sn_get`) and returns `sn_result` parts: tables (`sn_table`/`sn_col`), assumptions (`sn_check`), plots (`ctx$plot_engine`, `sn_plot_code`), interpretation.
4. `help.md`: intro, **Assumptions**, **Interpreting the output**, **References**.
5. Test: add `r-backend/tests/testthat/test-<area>.R` using `new_session("<dataset>")` and `row_of()` against a published reference value; include the "generated code reproduces the result" check.
6. Fixture: `Rscript scripts/make-fixtures.R` rewrites all fixtures; keep only `tests/fixtures/<id>.result.json` plus any intended diffs (`git status`).
7. Run: `STATNEXT_ROOT=$PWD Rscript -e 'testthat::test_file("r-backend/tests/testthat/test-<area>.R")'`, then `pnpm --dir frontend test` (schema tests iterate all specs) and the UI e2e if the menu changed.
No TypeScript or Rust edits are required. Ask for the reference source if none is known.
