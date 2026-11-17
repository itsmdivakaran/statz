// File-level actions (open data, projects, script export). Native dialogs in Tauri.
import { call, isTauri, tauriCommand } from "../rpc/client";
import { useStore } from "../state/store";
import type { DataInfo } from "../types";

const DATA_EXT = ["csv", "tsv", "txt", "xlsx", "xls", "sav", "zsav", "sas7bdat", "xpt", "dta", "parquet", "rds"];

async function dialog() {
  return import("@tauri-apps/plugin-dialog");
}

export async function openDataFile() {
  if (!isTauri) {
    const path = window.prompt("Path to a data file on this machine:");
    if (path) await useStore.getState().importFile(path);
    return;
  }
  const { open } = await dialog();
  const path = await open({ multiple: false, filters: [{ name: "Data", extensions: DATA_EXT }] });
  if (typeof path === "string") await useStore.getState().importFile(path);
}

export async function saveProject() {
  if (!isTauri) return alert("Saving projects needs the desktop app.");
  const { save } = await dialog();
  const path = await save({ filters: [{ name: "StatNext project", extensions: ["statnext"] }] });
  if (!path) return;
  const { analyses } = useStore.getState();
  const ui = { analyses: analyses.map(({ instance, module, options }) => ({ instance, module, options })) };
  await tauriCommand("project_save", { path, uiState: ui });
}

export async function openProject() {
  if (!isTauri) return alert("Opening projects needs the desktop app.");
  const { open } = await dialog();
  const path = await open({ multiple: false, filters: [{ name: "StatNext project", extensions: ["statnext"] }] });
  if (typeof path !== "string") return;
  const out = await tauriCommand<{ ui: { analyses: [] }; datasets: DataInfo[] }>("project_load", { path });
  useStore.getState().restore(out.ui, out.datasets[0] ?? null);
}

export async function exportScript(format: "R" | "Rmd" | "qmd") {
  const { script } = await call<{ script: string }>("session.script", { format });
  if (isTauri) {
    const { save } = await dialog();
    const path = await save({ defaultPath: `analysis.${format}`, filters: [{ name: format, extensions: [format] }] });
    if (!path) return;
    await call("code.run", { code: `writeLines(${JSON.stringify(script)}, ${JSON.stringify(path)})` });
    return;
  }
  const blob = new Blob([script], { type: "text/plain" });
  const a = Object.assign(document.createElement("a"), { href: URL.createObjectURL(blob), download: `analysis.${format}` });
  a.click();
  URL.revokeObjectURL(a.href);
}

export async function exportPlot(plotId: string, format: "svg" | "png" | "pdf" | "html" | "csv") {
  if (!isTauri) return alert("Plot export needs the desktop app; right-click the plot to save it here.");
  const { save } = await dialog();
  const path = await save({ defaultPath: `${plotId}.${format}`, filters: [{ name: format.toUpperCase(), extensions: [format] }] });
  if (path) await call("plot.export", { plot_id: plotId, format, path, width: 2400 });
}

/** Tables, plots and interpretation of every analysis as an APA-style Word, PDF or HTML document. */
export async function exportReport(format: "docx" | "pdf" | "html") {
  const instances = useStore.getState().analyses.filter((a) => a.result).map((a) => a.instance);
  if (!instances.length) return alert("Run an analysis first; there are no results to export yet.");
  if (!isTauri) return alert("Exporting results needs the desktop app.");
  const { save } = await dialog();
  const path = await save({ defaultPath: `results.${format}`, filters: [{ name: format === "docx" ? "Word document" : format.toUpperCase(), extensions: [format] }] });
  if (!path) return;
  try { await call("report.export", { path, format, instances }); }
  catch (e) { alert((e as Error).message); }
}
