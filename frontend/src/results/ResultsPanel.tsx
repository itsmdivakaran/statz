import { useEffect, useState } from "react";
import { exportPlot } from "../app/actions";
import { call, fileUrl } from "../rpc/client";
import { type Analysis, useStore } from "../state/store";
import type { Check, Plot, Table } from "../types";
import { fmtCell, tableToTsv } from "./format";

type Tab = "output" | "code" | "assumptions" | "interpretation";
const TABS: [Tab, string][] = [["output", "Output"], ["code", "R Code"], ["assumptions", "Assumptions"], ["interpretation", "Interpretation"]];

export function ResultsPanel() {
  const { analyses, selected, select, removeAnalysis } = useStore();
  const [tab, setTab] = useState<Tab>("output");
  return (
    <section className="flex h-full min-w-0 flex-col">
      <div role="tablist" className="flex gap-1 border-b border-slate-200 px-2 py-1 dark:border-slate-800">
        {TABS.map(([id, label]) => (
          <button key={id} role="tab" aria-selected={tab === id} onClick={() => setTab(id)}
            className={`rounded px-2 py-0.5 text-sm ${tab === id ? "bg-slate-200 dark:bg-slate-800" : "text-slate-500"}`}>{label}</button>
        ))}
      </div>
      <div className="flex-1 space-y-4 overflow-auto p-3">
        {analyses.length === 0 && <p className="text-sm text-slate-500">Results appear here.</p>}
        {analyses.map((a) => (
          <article key={a.instance} onClick={() => select(a.instance)} data-testid={`result-${a.module}`}
            className={`rounded-lg border p-3 ${selected === a.instance ? "border-blue-400" : "border-slate-200 dark:border-slate-800"}`}>
            <header className="mb-2 flex items-center gap-2">
              <h3 className="font-semibold">{a.result?.title ?? a.module}</h3>
              {a.running && <span className="text-xs text-slate-400" role="status">Running…</span>}
              {a.result?.status === "warn" && <span className="rounded bg-amber-100 px-1.5 text-xs text-amber-800 dark:bg-amber-900/40 dark:text-amber-300">warnings</span>}
              <button className="ml-auto text-xs text-slate-400 hover:text-red-500" aria-label="Remove analysis"
                onClick={(e) => { e.stopPropagation(); removeAnalysis(a.instance); }}>Remove</button>
            </header>
            <div className={a.running ? "opacity-50 transition-opacity" : ""}>
              <AnalysisBody a={a} tab={tab} />
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}

function AnalysisBody({ a, tab }: { a: Analysis; tab: Tab }) {
  if (a.error && a.error.code !== -32003) {
    return <div role="alert" className="text-sm text-red-600">{a.error.message}{a.error.hint && <p className="text-slate-500">{a.error.hint}</p>}</div>;
  }
  const r = a.result;
  if (!r) return <p className="text-sm text-slate-500">Assign variables to run this analysis.</p>;
  if (tab === "code") return <CodeView code={r.code} />;
  if (tab === "assumptions") return r.assumptions.length ? <>{r.assumptions.map((c) => <CheckView key={c.id} c={c} />)}</> :
    <p className="text-sm text-slate-500">No assumption checks selected.</p>;
  if (tab === "interpretation") return r.interpretation ? (
    <div className="space-y-2 text-sm">
      <p className="text-xs font-medium uppercase text-slate-400">Auto-generated · check before use</p>
      {r.interpretation.text.split("\n\n").map((p, i) => <p key={i}>{p}</p>)}
    </div>) : <p className="text-sm text-slate-500">No interpretation for this analysis.</p>;
  return (
    <div className="space-y-4">
      {r.tables.map((t) => <TableView key={t.id} t={t} />)}
      {r.plots.map((p) => <PlotView key={p.id} p={p} />)}
      {r.warnings.length > 0 && (
        <ul className="list-disc pl-5 text-xs text-amber-700 dark:text-amber-400">{r.warnings.map((w) => <li key={w}>{w}</li>)}</ul>
      )}
    </div>
  );
}

export function TableView({ t }: { t: Table }) {
  const copy = () => void navigator.clipboard?.writeText(tableToTsv(t.columns, t.rows));
  return (
    <figure>
      <figcaption className="mb-1 flex items-center text-sm font-medium italic">
        {t.title}
        <button className="ml-auto text-xs font-normal not-italic text-slate-400 hover:text-blue-600" onClick={copy}>Copy</button>
      </figcaption>
      <div className="overflow-x-auto">
        <table className="apa-table">
          <thead><tr>{t.columns.map((c) => <th key={c.id} className={c.type === "text" ? "" : "text-right"}>{c.label === "p" ? <i>p</i> : c.label}</th>)}</tr></thead>
          <tbody>
            {t.rows.map((row, i) => (
              <tr key={i}>{t.columns.map((c) => <td key={c.id} className={c.type === "text" ? "" : "whitespace-nowrap text-right"}>{fmtCell(row[c.id], c)}</td>)}</tr>
            ))}
          </tbody>
        </table>
      </div>
      {t.notes.length > 0 && <p className="mt-1 text-xs text-slate-500"><i>Note.</i> {t.notes.join(" ")}</p>}
    </figure>
  );
}

function CheckView({ c }: { c: Check }) {
  const color = c.status === "ok" ? "text-emerald-600" : c.status === "warn" ? "text-amber-600" : "text-red-600";
  return (
    <div className="mb-3 space-y-1">
      <p className="text-sm"><span className={`font-medium ${color}`}>{c.status === "ok" ? "✓" : "!"} {c.test}.</span> {c.message}</p>
      {c.table && <TableView t={c.table} />}
    </div>
  );
}

function PlotView({ p }: { p: Plot }) {
  const [src, setSrc] = useState<{ svg: string; html: string | null } | null>(null);
  const [interactive, setInteractive] = useState(true);
  useEffect(() => {
    void Promise.all([fileUrl(p.svg), p.html ? fileUrl(p.html) : Promise.resolve(null)]).then(([svg, html]) => setSrc({ svg, html }));
  }, [p.svg, p.html]);
  if (!src) return null;
  return (
    <figure className="space-y-1">
      <div className="flex items-center gap-2 text-xs text-slate-500">
        <span className="font-medium">{p.title}</span>
        {p.fallback && <span className="rounded bg-amber-100 px-1.5 text-amber-800" title={p.fallback_reason ?? ""}>ggplot2 fallback</span>}
        {src.html && <button className="hover:text-blue-600" onClick={() => setInteractive(!interactive)}>{interactive ? "Static" : "Interactive"}</button>}
        <span className="ml-auto flex gap-2">
          {(["svg", "png", "pdf", ...(p.html ? ["html"] : []), ...(p.data_csv ? ["csv"] : [])] as const).map((f) => (
            <button key={f} className="uppercase hover:text-blue-600" onClick={() => void exportPlot(p.id, f as "svg")}>{f}</button>
          ))}
        </span>
      </div>
      {interactive && src.html
        ? <iframe title={p.title} src={src.html} sandbox="allow-scripts" className="aspect-[640/545] w-full rounded border border-slate-200 bg-white dark:border-slate-800" />
        : <img alt={p.title} src={src.svg} className="w-full rounded bg-white" />}
    </figure>
  );
}

function CodeView({ code }: { code: string }) {
  const [text, setText] = useState(code);
  const [out, setOut] = useState<{ console: string; warnings: string[] } | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => { setText(code); setOut(null); }, [code]);
  const run = async () => {
    setErr(null);
    try { setOut(await call<{ console: string; warnings: string[] }>("code.run", { code: text })); }
    catch (e) { setErr((e as Error).message); }
  };
  return (
    <div className="space-y-2">
      <div className="flex gap-2">
        <button className="btn" onClick={() => void navigator.clipboard?.writeText(text)}>Copy</button>
        <button className="btn" onClick={() => void run()} title="Run edited code in R (Ctrl/Cmd+Enter)">Run</button>
        {text !== code && <button className="btn" onClick={() => setText(code)}>Reset</button>}
      </div>
      <textarea aria-label="R code" spellCheck={false} value={text} onChange={(e) => setText(e.target.value)}
        onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) void run(); }}
        wrap="off" className="w-full resize-y rounded border border-slate-200 bg-slate-50 p-2 font-mono text-xs leading-4 dark:border-slate-800 dark:bg-slate-900"
        rows={Math.min(48, text.split("\n").length + 1)} />
      {err && <pre className="whitespace-pre-wrap text-xs text-red-600">{err}</pre>}
      {out && <pre className="max-h-60 overflow-auto whitespace-pre-wrap rounded bg-slate-100 p-2 font-mono text-xs dark:bg-slate-900">{out.console || "(no printed output)"}{out.warnings.length ? `\nWarnings:\n${out.warnings.join("\n")}` : ""}</pre>}
    </div>
  );
}
