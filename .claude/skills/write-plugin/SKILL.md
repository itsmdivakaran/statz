---
name: write-plugin
description: Create or debug a StatNext plugin (user-installed analysis in the same spec.json + R + help.md format). Use when asked to build a plugin or when plugin install/validation fails.
---
# Write a plugin
- Start from `r-backend/inst/plugin-template/` (a working `coef_variation` example with README). The same folder shape as `analyses/<id>/`.
- Rules enforced by `sn_plugin_check` in `r-backend/R/plugin.R`: required keys `id version title menu r roles options`; id matches `^[a-z][a-z0-9_]{1,40}$` and must not equal a built-in id (it is skipped with a message otherwise); `r.file` must exist; menu `["Plugins","<group>"]` or an existing built-in menu.
- Available helpers inside plugin R: `sn_table`, `sn_col`, `sn_result`, `sn_lit`, `sn_ref`, `sn_gg`, `ctx$plot()`.
- Test by pointing the dev bridge at it: `STATNEXT_PLUGINS=/path/to/plugins pnpm bridge`, or via UI Plugins › Install from folder, then Reload plugins.
- Security: plugins execute arbitrary R on the user's machine. Never auto-install a plugin; keep the confirmation prompt.
