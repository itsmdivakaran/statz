import {
  Activity, BarChart3, Binary, Boxes, Calculator, ChartNoAxesCombined, Database, Dices, FileCode2, FileDown, FileText, Filter, FolderOpen,
  GitCompareArrows, Grid3x3, HeartPulse, Layers, Layers2, ListOrdered, type LucideIcon, Moon, Network, PieChart, Repeat, Replace, Save,
  Scale, ScatterChart, Sigma, Split, Sun, Table2, Target, TestTubes, Timer, TrendingUp, Users, UsersRound,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { call } from "../rpc/client";
import { useStore } from "../state/store";
import { exportReport, exportScript, openDataFile, openProject, saveProject } from "./actions";

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

/** Icon per analysis id. Unknown modules (plugins) fall back to a generic icon; hints come from spec.description. */
const MODULE_ICON: Record<string, LucideIcon> = {
  descriptives: Sigma, ttest_one: Target, ttest_ind: Users, ttest_paired: GitCompareArrows,
  anova_oneway: Layers, anova_factorial: Layers2, anova_rm: Repeat,
  chisq: Grid3x3, chisq_gof: PieChart, binomial_test: Dices, mcnemar: Split, cochran_q: Boxes,
  wilcoxon_paired: GitCompareArrows, friedman: Repeat, correlation: ScatterChart,
  reg_linear: TrendingUp, reg_logistic: Binary, reg_ordinal: ListOrdered, reg_multinomial: Network, reg_count: ChartNoAxesCombined,
  mixed_linear: UsersRound, mixed_glmm: UsersRound, surv_km: HeartPulse, surv_cox: Timer,
  reliability_alpha: Scale, reliability_icc: Scale, reliability_kappa: Scale,
};
const MODULE_HINT: Record<string, string> = {
  descriptives: "Mean, SD, quantiles, frequencies, normality",
  ttest_one: "Compare one mean with a fixed value",
  ttest_ind: "Compare two independent groups",
  ttest_paired: "Compare two related measurements",
  anova_oneway: "Compare three or more groups, with post hoc tests",
  chisq: "Association between two categorical variables",
};
const MENU_ICON: Record<string, LucideIcon> = { Tests: TestTubes, Regression: TrendingUp, Survival: Activity };

/** Order of the group headings inside the analysis menus; unlisted groups (plugins) come last. */
const GROUP_ORDER = ["Descriptives", "Reliability", "T-Tests", "ANOVA", "Non-parametric", "Frequencies", "Correlation", "Linear models",
  "Generalized linear models", "Mixed models", "Survival analysis"];
const groupRank = (s: { menu: string[] }) => { const i = GROUP_ORDER.indexOf(s.menu[1] ?? s.menu[0]); return i < 0 ? GROUP_ORDER.length : i; };

const mod = typeof navigator !== "undefined" && /Mac/.test(navigator.platform) ? "⌘" : "Ctrl+";

export function useCommands(): Command[] {
  const { specs, newAnalysis, loadExample, theme, toggleTheme, data, openTransform } = useStore();
  const [examples, setExamples] = useState<{ name: string; title: string }[]>([]);
  useEffect(() => { void call<{ name: string; title: string }[]>("data.examples").then(setExamples).catch(() => {}); }, []);

  return useMemo(() => [
    { id: "open-data", label: "Open data file…", group: "File", menu: "Data", hint: "CSV, Excel, SPSS, Stata, SAS, Parquet", shortcut: `${mod}O`, Icon: FolderOpen, run: () => void openDataFile() },
    { id: "open-project", label: "Open project…", group: "File", menu: "Data", hint: ".statnext file", Icon: Database, run: () => void openProject() },
    { id: "save-project", label: "Save project…", group: "File", menu: "Data", shortcut: `${mod}S`, Icon: Save, disabled: !data, run: () => void saveProject() },
    { id: "export-r", label: "Export R script", group: "Export code", menu: "Data", hint: "Standalone, reproducible .R", Icon: FileCode2, disabled: !data, run: () => void exportScript("R") },
    { id: "export-rmd", label: "Export R Markdown", group: "Export code", menu: "Data", Icon: FileDown, disabled: !data, run: () => void exportScript("Rmd") },
    { id: "export-qmd", label: "Export Quarto", group: "Export code", menu: "Data", Icon: FileDown, disabled: !data, run: () => void exportScript("qmd") },
    { id: "tr-compute", label: "Compute variable…", group: "Transform", menu: "Data", hint: "New variable from a formula", Icon: Calculator, disabled: !data, run: () => openTransform("compute") },
    { id: "tr-recode", label: "Recode variable…", group: "Transform", menu: "Data", hint: "Merge or rename categories", Icon: Replace, disabled: !data, run: () => openTransform("recode") },
    { id: "tr-filter", label: "Filter rows…", group: "Transform", menu: "Data", hint: "Keep rows that match a condition", Icon: Filter, disabled: !data, run: () => openTransform("filter") },
    { id: "export-docx", label: "Export results to Word", group: "Export results", menu: "Data", hint: "APA tables, plots, interpretation (.docx)", Icon: FileText, disabled: !data, run: () => void exportReport("docx") },
    { id: "export-pdf", label: "Export results to PDF", group: "Export results", menu: "Data", Icon: FileText, disabled: !data, run: () => void exportReport("pdf") },
    { id: "export-html", label: "Export results to HTML", group: "Export results", menu: "Data", Icon: FileText, disabled: !data, run: () => void exportReport("html") },
    ...examples.map((e) => ({ id: `ex-${e.name}`, label: e.title, group: "Example data", menu: "Data", Icon: Table2, run: () => void loadExample(e.name) })),
    ...Object.values(specs).sort((a, b) => groupRank(a) - groupRank(b)).map((s) => ({
      id: `an-${s.id}`, label: s.title, group: s.menu[1] ?? s.menu[0], menu: s.menu[0],
      hint: s.description ?? MODULE_HINT[s.id], Icon: MODULE_ICON[s.id] ?? MENU_ICON[s.menu[0]] ?? BarChart3,
      disabled: !data, run: () => newAnalysis(s.id),
    })),
    { id: "theme", label: theme === "dark" ? "Switch to light theme" : "Switch to dark theme", group: "View", menu: "View", Icon: theme === "dark" ? Sun : Moon, run: toggleTheme },
  ], [specs, examples, data, theme, newAnalysis, loadExample, toggleTheme, openTransform]);
}
