import {
  AreaChart, ArrowRight, BrainCircuit, ClipboardList, Code2, Combine, FileDown, Compass, FolderOpen, HeartPulse, LineChart, type LucideIcon, Puzzle, Scale,
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

  return (
    <div className="h-full overflow-auto">
      <div className="pointer-events-none fixed inset-x-0 top-0 h-[28rem] bg-[radial-gradient(60rem_24rem_at_30%_-20%,rgb(var(--brand)/0.16),transparent),radial-gradient(40rem_20rem_at_90%_0%,rgb(var(--accent)/0.12),transparent)]" />
      <div className="relative mx-auto grid w-full max-w-6xl gap-6 px-6 py-8 lg:grid-cols-[1fr_22rem]">
        <div className="space-y-6">
          <section className="flex items-center gap-5">
            <Logo size={64} />
            <div className="min-w-0">
              <h1 className="text-[28px] font-bold leading-tight tracking-tight">Welcome to Stat<span className="text-brand">Next</span></h1>
              <p className="mt-1 text-[15px] text-muted">Point-and-click statistics, powered by R on your own machine.</p>
            </div>
          </section>
          <section className="flex flex-wrap gap-2.5">
            <button className="btn-primary" onClick={() => void openDataFile()}><FolderOpen size={16} aria-hidden="true" />Open data file</button>
            <button className="btn px-3.5 py-2" onClick={() => void openProject()}>Open project</button>
            <button className="btn px-3.5 py-2" onClick={() => setModal("guide")}><Compass size={15} className="text-brand" aria-hidden="true" />Which test should I use?</button>
            <span className="self-center text-xs text-muted">CSV, Excel, SPSS, Stata, SAS and Parquet</span>
          </section>

          <section aria-labelledby="tours">
            <h2 id="tours" className="panel-title mb-2">Start with a worked example</h2>
            <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2 2xl:grid-cols-3">
              {tours.map(({ module, area, Icon, tone }) => {
                const s = specs[module];
                return (
                  <button key={module} disabled={busy !== null} onClick={() => void go(module, () => runExample(module))}
                    className="card group flex items-start gap-3 p-3.5 text-left transition hover:-translate-y-px hover:border-brand/60 hover:shadow-pop disabled:opacity-60">
                    <span className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg ${tone}`}><Icon size={17} aria-hidden="true" /></span>
                    <span className="min-w-0 flex-1">
                      <span className="block text-[11px] font-semibold uppercase tracking-wider text-muted">{area}</span>
                      <span className="block text-sm font-semibold leading-snug">{s.title}</span>
                      <span className="mt-0.5 line-clamp-2 text-xs text-muted">{s.description}</span>
                    </span>
                    <ArrowRight size={15} className="mt-1 shrink-0 text-muted transition group-hover:translate-x-0.5 group-hover:text-brand" aria-hidden="true" />
                  </button>
                );
              })}
            </div>
          </section>

          <section className="grid grid-cols-1 gap-2.5 sm:grid-cols-2 xl:grid-cols-4">
            {FEATURES.map((f) => (
              <div key={f.title} className="rounded-xl border border-line bg-surface/60 p-3.5">
                <f.Icon size={18} className="mb-2 text-accent" aria-hidden="true" />
                <div className="text-sm font-semibold">{f.title}</div>
                <p className="mt-0.5 text-xs leading-relaxed text-muted">{f.text}</p>
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

        <aside aria-labelledby="datasets" className="card flex max-h-[calc(100vh-7rem)] min-h-80 flex-col overflow-hidden lg:sticky lg:top-8">
          <div className="border-b border-line p-3">
            <h2 id="datasets" className="panel-title mb-2">Example datasets ({examples.length})</h2>
            <label className="flex items-center gap-2 rounded-lg border border-line bg-surface2 px-2.5 py-1.5 text-sm focus-within:border-brand/60">
              <Search size={14} className="text-muted" aria-hidden="true" />
              <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Filter datasets" aria-label="Filter datasets"
                className="w-full bg-transparent outline-none placeholder:text-muted" />
            </label>
          </div>
          <ul className="flex-1 overflow-auto p-1.5">
            {shown.map((e) => (
              <li key={e.name}>
                <button aria-label={e.title} disabled={busy !== null} onClick={() => void go(e.name, () => loadExample(e.name))}
                  className="group flex w-full items-start gap-2.5 rounded-lg px-2.5 py-2 text-left transition-colors hover:bg-brand/10 disabled:opacity-60">
                  <Table2 size={15} className="mt-0.5 shrink-0 text-muted group-hover:text-brand" aria-hidden="true" />
                  <span className="min-w-0">
                    <span className="block truncate text-sm font-medium">{e.title}</span>
                    <span className="line-clamp-2 text-xs text-muted">{e.description}</span>
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
