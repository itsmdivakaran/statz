import {
  Activity, AlarmClock, AreaChart, BarChart3, Binary, Boxes, BrainCircuit, Calculator, CalendarRange, ChartNoAxesCombined, CircleDot, ClipboardList, Combine, Database, Dices,
  FileCode2, FileDown, FileText, Filter, FolderOpen, Gauge, GitBranch, GitCompareArrows, GitFork, Grid3x3, HeartPulse, Layers, Layers2, LineChart, ListOrdered, type LucideIcon,
  Microscope, Moon, Network, PieChart, Radar, Repeat, Replace, Rocket, Save, Scale, ScatterChart, Shapes, ShieldAlert, Sigma, Split, Stethoscope, Sun, Table2, Target, TestTubes,
  Timer, TreePine, Trees, TrendingUp, Users, UsersRound, Waypoints,
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
  pca: Shapes, efa: Waypoints, cluster_kmeans: CircleDot, cluster_hier: GitFork,
  diag_2x2: Microscope, roc: AreaChart, meta_generic: Combine, meta_binary: Combine, meta_continuous: Combine,
  clin_table1: ClipboardList, clin_ae: ShieldAlert,
  ml_tree: TreePine, ml_forest: Trees, ml_boost: Rocket, ml_glmnet: Gauge, ml_svm: Radar, ml_nb: Dices, ml_lda: GitBranch,
  ts_explore: LineChart, ts_arima: CalendarRange, ts_ets: AlarmClock,
};
const MENU_ICON: Record<string, LucideIcon> = { Tests: TestTubes, Regression: TrendingUp, Survival: Activity, Multivariate: Network, "Machine Learning": BrainCircuit, "Time Series": LineChart, Clinical: Stethoscope };

/** Order of the group headings inside the analysis menus; unlisted groups (plugins) come last. */
const GROUP_ORDER = ["Descriptives", "Reliability", "T-Tests", "ANOVA", "Non-parametric", "Frequencies", "Correlation", "Linear models",
  "Generalized linear models", "Mixed models", "Survival analysis", "Dimension reduction", "Clustering", "Classification and regression", "Classification",
  "Explore", "Forecasting", "Clinical tables", "Diagnostic accuracy", "Meta-analysis"];
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
      hint: s.description, Icon: MODULE_ICON[s.id] ?? MENU_ICON[s.menu[0]] ?? BarChart3,
      disabled: !data, run: () => newAnalysis(s.id),
    })),
    { id: "theme", label: theme === "dark" ? "Switch to light theme" : "Switch to dark theme", group: "View", menu: "View", Icon: theme === "dark" ? Sun : Moon, run: toggleTheme },
  ], [specs, examples, data, theme, newAnalysis, loadExample, toggleTheme, openTransform]);
}
