@AGENTS.md

# Claude Code notes for StatNext

## Where things are
- Project skills: `.claude/skills/` (custom: `add-analysis`, `update-golden-fixtures`, `write-plugin`, `tauri-r-bridge-debug`, `release-installers`, `site-update`; vendored third-party listed in `.claude/skills/THIRD_PARTY.md`). `.agents/skills` is a symlink to the same folder.
- Subagents: `.claude/agents/` (`r-stats-reviewer`, `frontend-reviewer`, `tauri-rust-reviewer`).
- Slash commands: `/add-analysis`, `/regen-fixtures`, `/test-all`, `/release-check`.

## Working agreements
- Prefer the narrowest test first: one testthat file (`test_file`) before the whole suite; the full R suite and `option-sweep.R` are slow.
- R tests need the installed package: run `R CMD INSTALL r-backend` after editing `r-backend/R/`. Analyses in `analyses/` are read from disk via `STATNEXT_ROOT`, no reinstall needed.
- Frontend changes: run `pnpm typecheck` and `pnpm test` in `frontend/`; use the dev bridge + Playwright for anything touching dialogs or results.
- Before saying a UI change works, run it (use the `run` skill or `webapp-testing`).
- Ask before regenerating all fixtures or changing numeric tolerances.
