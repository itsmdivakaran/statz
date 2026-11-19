---
name: release-installers
description: Prepare and verify a StatNext release (version bump consistency, CI status, installers workflow, Zenodo/citation metadata). Use when bumping the version, tagging, or checking release readiness.
---
# Release checklist
Version must match in: `src-tauri/tauri.conf.json`, `src-tauri/Cargo.toml` (and `Cargo.lock` entry), `frontend/package.json`, `r-backend/DESCRIPTION`, `CITATION.cff` (also `date-released`), README download links, and `.zenodo.json` if it carries a version. Check with `grep -rn "0\.5\.3" --include=*.json --include=*.toml --include=*.cff --include=DESCRIPTION --include=README.md .` (substitute current version; ignore lockfiles of other packages).
1. CI green on `dev`: `gh run list --branch dev --limit 5`.
2. Bump version everywhere, update README links and the website needs no change (it reads the GitHub API).
3. Release workflow `.github/workflows/release.yml` runs on tag `v*` or manual dispatch; builds macOS (aarch64; Intel built in-job), Windows (.exe/.msi), Linux (.AppImage/.deb); unsigned unless Apple secrets are set; releases are published as full releases so Zenodo archives them.
4. Never tag or push without explicit user approval.
