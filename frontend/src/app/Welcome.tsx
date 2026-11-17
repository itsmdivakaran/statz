import {
  AreaChart, ArrowRight, BrainCircuit, ClipboardList, Code2, Combine, FileDown, Compass, FolderClosed, FolderOpen, HeartPulse, LineChart, type LucideIcon, Puzzle, Scale,
  Search, ShieldCheck, Table2, TrendingUp, Users,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { call } from "../rpc/client";
import { useStore } from "../state/store";
import { openDataFile, openProject } from "./actions";
import { Logo } from "./Logo";

/** One-click tours: each loads the module's example dataset and opens the analysis with its example options. */
const TOURS: { module: string; area: string; Icon: LucideIcon; tone: string }[] = [
  { module: "ttest_ind", area: "Tests", Icon: Users, tone: "bg-brand/10 text-brand" },
  { module: "reg_logistic", area: "Regression", Icon: TrendingUp, tone: "bg-accent/10 text-accent" },
  { module: "surv_km", area: "Survival", Icon: HeartPulse, tone: "bg-bad/10 text-bad" },
  { module: "ml_forest", area: "Machine learning", Icon: BrainCircuit, tone: "bg-brand/10 text-brand" },
  { module: "ts_arima", area: "Time series", Icon: LineChart, tone: "bg-accent/10 text-accent" },
  { module: "bayes_ttest_ind", area: "Bayesian", Icon: Scale, tone: "bg-warn/10 text-warn" },
  { module: "roc", area: "Diagnostic accuracy", Icon: AreaChart, tone: "bg-bad/10 text-bad" },
  { module: "meta_binary", area: "Meta-analysis", Icon: Combine, tone: "bg-warn/10 text-warn" },
  { module: "clin_table1", area: "Clinical", Icon: ClipboardList, tone: "bg-ok/10 text-ok" },
];

const FEATURES: { Icon: LucideIcon; title: string; text: string }[] = [
  { Icon: ShieldCheck, title: "Assumptions checked", text: "Every analysis reports the checks it relies on." },
  { Icon: Code2, title: "R code for everything", text: "The exact, editable R behind each result." },
  { Icon: FileDown, title: "Word and PDF export", text: "APA tables, plots and interpretation in one file." },
  { Icon: Puzzle, title: "Plugins", text: "Add your own analyses in the same format." },
];

interface Example { name: string; title: string; description: string }

export function Welcome() {
  const { specs, loadExample, runExample, hello, setModal } = useStore();
  const [examples, setExamples] = useState<Example[]>([]);
  const [query, setQuery] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  useEffect(() => { void call<Example[]>("data.examples").then(setExamples).catch(() => {}); }, []);

  const tours = TOURS.filter((t) => specs[t.module]?.example);
  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    return q ? examples.filter((e) => `${e.title} ${e.description}`.toLowerCase().includes(q)) : examples;
  }, [examples, query]);
  const go = async (key: string, fn: () => Promise<void>) => { setBusy(key); try { await fn(); } finally { setBusy(null); } };

  const ACTIONS: { label: string; text: string; Icon: LucideIcon; run: () => void; primary?: boolean }[] = [
    { label: "Open data file", text: "CSV, Excel, SPSS, Stata, SAS or Parquet", Icon: FolderOpen, run: () => void openDataFile(), primary: true },
    { label: "Open project", text: "Data, analyses and options (.statnext)", Icon: FolderClosed, run: () => void openProject() },
    { label: "Which test should I use?", text: "Answer a few questions to get a recommendation", Icon: Compass, run: () => setModal("guide") },
  ];

  return (
    <div className="h-full overflow-auto bg-canvas">
      <div className="mx-auto grid w-full max-w-[76rem] gap-6 px-6 py-7 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <div className="min-w-0 space-y-7">
          <section className="flex items-center gap-4">
            <Logo size={48} />
            <div className="min-w-0">
              <h1 className="text-[22px] font-bold leading-tight tracking-tight">Welcome to Stat<span className="text-brand">Next</span></h1>
              <p className="mt-0.5 text-[13.5px] text-muted">Point-and-click statistics with reproducible R code, running on your own computer.</p>
            </div>
          </section>

          <section aria-label="Get started" className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            {ACTIONS.map((x) => (
              <button key={x.label} onClick={x.run} aria-label={x.label}
                className={`group flex items-start gap-3 rounded-lg border p-3.5 text-left transition ${x.primary ? "border-brand bg-brand text-white shadow-sm hover:brightness-110" : "border-line bg-surface shadow-card hover:border-brand/50"}`}>
                <span className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-md ${x.primary ? "bg-white/15" : "bg-brand/10 text-brand"}`}><x.Icon size={17} aria-hidden="true" /></span>
                <span className="min-w-0">
                  <span className="block text-[13.5px] font-semibold">{x.label}</span>
                  <span className={`mt-0.5 block text-xs leading-snug ${x.primary ? "text-white/80" : "text-muted"}`}>{x.text}</span>
                </span>
              </button>
            ))}
          </section>

          <section aria-labelledby="tours">
            <div className="mb-2.5 flex items-baseline gap-2">
              <h2 id="tours" className="text-[14px] font-semibold tracking-tight">Start with a worked example</h2>
              <span className="text-xs text-muted">Loads example data and runs the analysis</span>
            </div>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {tours.map(({ module, area, Icon, tone }) => {
                const s = specs[module];
                return (
                  <button key={module} disabled={busy !== null} onClick={() => void go(module, () => runExample(module))}
                    className="group flex h-full flex-col rounded-lg border border-line bg-surface p-3.5 text-left shadow-card transition hover:border-brand/50 hover:shadow-pop disabled:opacity-60">
                    <span className="flex w-full items-center gap-2">
                      <span className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-md ${tone}`}><Icon size={15} aria-hidden="true" /></span>
                      <span className="text-[11px] font-semibold uppercase tracking-wider text-muted">{area}</span>
                      <ArrowRight size={14} className="ml-auto text-muted opacity-0 transition group-hover:translate-x-0.5 group-hover:text-brand group-hover:opacity-100" aria-hidden="true" />
                    </span>
                    <span className="mt-2.5 block text-[13.5px] font-semibold leading-snug">{s.title}</span>
                    <span className="mt-0.5 line-clamp-2 text-xs leading-relaxed text-muted">{s.description}</span>
                  </button>
                );
              })}
            </div>
          </section>

          <section aria-label="Features" className="grid grid-cols-1 gap-x-6 gap-y-4 border-t border-line pt-5 sm:grid-cols-2 xl:grid-cols-4">
            {FEATURES.map((f) => (
              <div key={f.title} className="flex gap-2.5">
                <f.Icon size={16} className="mt-0.5 shrink-0 text-accent" aria-hidden="true" />
                <div>
                  <div className="text-[13px] font-semibold">{f.title}</div>
                  <p className="mt-0.5 text-xs leading-relaxed text-muted">{f.text}</p>
                </div>
              </div>
            ))}
          </section>
          {hello && (
            <p className="text-xs text-muted">
              {Object.keys(specs).length} analyses · R {hello.r_version} · plots by {hello.plot_engine}
              {hello.missing_packages.length > 0 && <span className="text-warn"> · {hello.missing_packages.length} R packages missing</span>}
            </p>
          )}
        </div>

        <aside aria-labelledby="datasets" className="flex max-h-[calc(100vh-9rem)] min-h-80 flex-col overflow-hidden rounded-lg border border-line bg-surface shadow-card lg:sticky lg:top-0">
          <div className="border-b border-line p-3">
            <h2 id="datasets" className="mb-2 flex items-baseline text-[13.5px] font-semibold tracking-tight">Example datasets<span className="ml-auto text-xs font-normal text-muted">{examples.length}</span></h2>
            <label className="flex items-center gap-2 rounded-md border border-line bg-canvas px-2.5 py-1.5 text-[13px] focus-within:border-brand/60">
              <Search size={14} className="text-muted" aria-hidden="true" />
              <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Filter datasets" aria-label="Filter datasets"
                className="w-full bg-transparent outline-none placeholder:text-muted" />
            </label>
          </div>
          <ul className="flex-1 divide-y divide-line/70 overflow-auto">
            {shown.map((e) => (
              <li key={e.name}>
                <button aria-label={e.title} disabled={busy !== null} onClick={() => void go(e.name, () => loadExample(e.name))} title={e.description}
                  className="group flex w-full items-start gap-2.5 px-3 py-2 text-left transition-colors hover:bg-brand/5 disabled:opacity-60">
                  <Table2 size={14} className="mt-0.5 shrink-0 text-muted group-hover:text-brand" aria-hidden="true" />
                  <span className="min-w-0">
                    <span className="block truncate text-[13px] font-medium">{e.title}</span>
                    <span className="block truncate text-xs text-muted">{e.description}</span>
                  </span>
                </button>
              </li>
            ))}
            {shown.length === 0 && <li className="px-3 py-6 text-center text-sm text-muted">No dataset matches.</li>}
          </ul>
        </aside>
      </div>
    </div>
  );
}
