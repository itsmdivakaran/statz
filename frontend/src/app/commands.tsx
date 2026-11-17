import {
  BarChart3, Database, FileCode2, FileDown, FolderOpen, Grid3x3, type LucideIcon, Moon, Save, Sigma, Sun, Table2, TestTubes,
  GitCompareArrows, Target, Users, Layers,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { call } from "../rpc/client";
import { useStore } from "../state/store";
import { exportScript, openDataFile, openProject, saveProject } from "./actions";

export interface Command {
  id: string;
  label: string;
  group: string;
  menu: string;
  hint?: string;
  shortcut?: string;
  Icon: LucideIcon;
  disabled?: boolean;
  run: () => void;
}

/** Icon + one-line description per analysis id. Unknown modules (plugins) fall back to a generic icon. */
const MODULE_UI: Record<string, { Icon: LucideIcon; hint: string }> = {
  descriptives: { Icon: Sigma, hint: "Mean, SD, quantiles, frequencies, normality" },
  ttest_one: { Icon: Target, hint: "Compare one mean with a fixed value" },
  ttest_ind: { Icon: Users, hint: "Compare two independent groups" },
  ttest_paired: { Icon: GitCompareArrows, hint: "Compare two related measurements" },
  anova_oneway: { Icon: Layers, hint: "Compare three or more groups, with post hoc tests" },
  chisq: { Icon: Grid3x3, hint: "Association between two categorical variables" },
};

const mod = typeof navigator !== "undefined" && /Mac/.test(navigator.platform) ? "⌘" : "Ctrl+";

export function useCommands(): Command[] {
  const { specs, newAnalysis, loadExample, theme, toggleTheme, data } = useStore();
  const [examples, setExamples] = useState<{ name: string; title: string }[]>([]);
  useEffect(() => { void call<{ name: string; title: string }[]>("data.examples").then(setExamples).catch(() => {}); }, []);

  return useMemo(() => [
    { id: "open-data", label: "Open data file…", group: "File", menu: "Data", hint: "CSV, Excel, SPSS, Stata, SAS, Parquet", shortcut: `${mod}O`, Icon: FolderOpen, run: () => void openDataFile() },
    { id: "open-project", label: "Open project…", group: "File", menu: "Data", hint: ".statnext file", Icon: Database, run: () => void openProject() },
    { id: "save-project", label: "Save project…", group: "File", menu: "Data", shortcut: `${mod}S`, Icon: Save, disabled: !data, run: () => void saveProject() },
    { id: "export-r", label: "Export R script", group: "Export", menu: "Data", hint: "Standalone, reproducible .R", Icon: FileCode2, disabled: !data, run: () => void exportScript("R") },
    { id: "export-rmd", label: "Export R Markdown", group: "Export", menu: "Data", Icon: FileDown, disabled: !data, run: () => void exportScript("Rmd") },
    { id: "export-qmd", label: "Export Quarto", group: "Export", menu: "Data", Icon: FileDown, disabled: !data, run: () => void exportScript("qmd") },
    ...examples.map((e) => ({ id: `ex-${e.name}`, label: e.title, group: "Example data", menu: "Data", Icon: Table2, run: () => void loadExample(e.name) })),
    ...Object.values(specs).map((s) => ({
      id: `an-${s.id}`, label: s.title, group: s.menu[1] ?? s.menu[0], menu: s.menu[0],
      hint: MODULE_UI[s.id]?.hint, Icon: MODULE_UI[s.id]?.Icon ?? (s.menu[0] === "Tests" ? TestTubes : BarChart3),
      disabled: !data, run: () => newAnalysis(s.id),
    })),
    { id: "theme", label: theme === "dark" ? "Switch to light theme" : "Switch to dark theme", group: "View", menu: "View", Icon: theme === "dark" ? Sun : Moon, run: toggleTheme },
  ], [specs, examples, data, theme, newAnalysis, loadExample, toggleTheme]);
}
