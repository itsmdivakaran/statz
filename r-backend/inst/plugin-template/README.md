# A StatNext plugin

This folder is a complete, working analysis. Edit it, then install it from **Plugins > Manage plugins > Install from folder** (or zip the folder and share the .zip).

| File | What it holds |
|---|---|
| `spec.json` | id, title, menu, the variable boxes (`roles`) and the options. StatNext builds the dialog from it. |
| `coef_variation.R` | `codegen_<id>()`: writes the R code, and `assemble` turns the results into tables and text. |
| `help.md` | The help page: intro, **Assumptions**, **Interpreting the output**, **References**. |

- `id`: lower case letters, digits and underscores. It must not be the id of a built-in analysis.
- `menu`: `["Plugins", "<group>"]` puts it in the Plugins menu; a built-in menu name (for example `"Tests"`) puts it there.
- Role `measure`: any of `continuous`, `ordinal`, `nominal`. Option types: `enum`, `number`, `bool`, `text`, `subset`, `interactions`.
- `r.packages`: CRAN packages the code needs; StatNext offers to install missing ones.
- Helpers from StatNext's R backend are available: `sn_table()`, `sn_col()`, `sn_result()`, `sn_lit()`, `sn_ref()`, `sn_gg()`, `ctx$plot()` for plots.
- After editing an installed plugin's files, choose **Reload plugins**.

Plugins run R code on your computer. Share and install only plugins you trust.
