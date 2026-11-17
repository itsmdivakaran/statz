import { AlertTriangle, CheckCircle2, ClipboardCopy, FlaskConical, Loader2, Play, RotateCcw, Sparkles, Trash2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";
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
      <div className="flex items-center border-b border-line px-2.5 py-2">
        <div role="tablist" className="seg">
          {TABS.map(([id, label]) => (
            <button key={id} role="tab" aria-selected={tab === id} onClick={() => setTab(id)}>{label}</button>
          ))}
        </div>
      </div>
      <div className="flex-1 space-y-4 overflow-auto p-3">
        {analyses.length === 0 && (
          <div className="flex h-full flex-col items-center justify-center gap-2 text-center">
            <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-accent/10 text-accent"><FlaskConical size={20} aria-hidden="true" /></span>
            <p className="text-sm font-medium">No results yet</p>
            <p className="max-w-60 text-xs text-muted">Results update live as you assign variables and change options.</p>
          </div>
        )}
        {analyses.map((a) => (
          <article key={a.instance} onClick={() => select(a.instance)} data-testid={`result-${a.module}`}
            className={`rounded-xl border bg-surface p-4 transition-shadow ${selected === a.instance ? "border-brand/70 shadow-[0_0_0_3px_rgb(var(--brand)/0.12)]" : "border-line"}`}>
            <header className="mb-3 flex items-center gap-2">
              <h3 className="text-[15px] font-semibold tracking-tight">{a.result?.title ?? a.module}</h3>
              {a.running && <span className="chip bg-brand/10 text-brand" role="status"><Loader2 size={11} className="animate-spin" aria-hidden="true" />Running…</span>}
              {a.result?.status === "warn" && <span className="chip bg-warn/15 text-warn"><AlertTriangle size={11} aria-hidden="true" />warnings</span>}
              <button className="btn-ghost ml-auto px-1.5 hover:text-bad" aria-label="Remove analysis" title="Remove analysis"
                onClick={(e) => { e.stopPropagation(); removeAnalysis(a.instance); }}><Trash2 size={14} aria-hidden="true" /></button>
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
    return <div role="alert" className="text-sm text-bad">{a.error.message}{a.error.hint && <p className="text-muted">{a.error.hint}</p>}</div>;
  }
  const r = a.result;
  if (!r) return <p className="text-sm text-muted">Assign variables to run this analysis.</p>;
  if (tab === "code") return <CodeView code={r.code} />;
  if (tab === "assumptions") return r.assumptions.length ? <>{r.assumptions.map((c) => <CheckView key={c.id} c={c} />)}</> :
    <p className="text-sm text-muted">No assumption checks selected.</p>;
  if (tab === "interpretation") return r.interpretation ? (
    <div className="space-y-2.5 text-sm leading-relaxed">
      <p className="chip bg-accent/10 text-accent"><Sparkles size={11} aria-hidden="true" />Auto-generated · check before use</p>
      {r.interpretation.text.split("\n\n").map((p, i) => <p key={i}>{p}</p>)}
    </div>) : <p className="text-sm text-muted">No interpretation for this analysis.</p>;
  return (
    <div className="space-y-4">
      {r.tables.map((t) => <TableView key={t.id} t={t} />)}
      {r.plots.map((p) => <PlotView key={p.id} p={p} />)}
      {r.warnings.length > 0 && (
        <ul className="list-disc pl-5 text-xs text-warn">{r.warnings.map((w) => <li key={w}>{w}</li>)}</ul>
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
        <button className="btn-ghost ml-auto px-1.5 py-0.5 text-xs font-normal not-italic" onClick={copy} title="Copy table"><ClipboardCopy size={12} aria-hidden="true" />Copy</button>
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
      {t.notes.length > 0 && <p className="mt-1 text-xs text-muted"><i>Note.</i> {t.notes.join(" ")}</p>}
    </figure>
  );
}

function CheckView({ c }: { c: Check }) {
  const color = c.status === "ok" ? "text-ok" : c.status === "warn" ? "text-warn" : "text-bad";
  return (
    <div className="mb-3 space-y-1">
      <p className="flex items-start gap-1.5 text-sm"><span className={`mt-0.5 ${color}`}>{c.status === "ok" ? <CheckCircle2 size={15} aria-hidden="true" /> : <AlertTriangle size={15} aria-hidden="true" />}</span><span><span className={`font-semibold ${color}`}>{c.test}.</span> {c.message}</span></p>
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
      <div className="flex items-center gap-2 text-xs text-muted">
        <span className="font-medium">{p.title}</span>
        {p.fallback && <span className="chip bg-warn/15 text-warn" title={p.fallback_reason ?? ""}>ggplot2 fallback</span>}
        {src.html && <button className="chip bg-surface2 hover:text-brand" onClick={() => setInteractive(!interactive)}>{interactive ? "Static" : "Interactive"}</button>}
        <span className="ml-auto flex gap-0.5">
          {(["svg", "png", "pdf", ...(p.html ? ["html"] : []), ...(p.data_csv ? ["csv"] : [])] as const).map((f) => (
            <button key={f} className="rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide hover:bg-brand/10 hover:text-brand" onClick={() => void exportPlot(p.id, f as "svg")}>{f}</button>
          ))}
        </span>
      </div>
      {interactive && src.html
        ? <ScaledFrame title={p.title} src={src.html} />
        : <img alt={p.title} src={src.svg} className="w-full rounded-lg border border-line bg-white" />}
    </figure>
  );
}

/** ggnext HTML is a fixed 640x480 canvas; scale it to the panel width. */
const PLOT_W = 640, PLOT_H = 480;
function ScaledFrame({ title, src }: { title: string; src: string }) {
  const box = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);
  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const fit = () => setScale(el.clientWidth / PLOT_W || 1);
    fit();
    if (typeof ResizeObserver === "undefined") return;
    const ro = new ResizeObserver(fit);
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return (
    <div ref={box} className="overflow-hidden rounded-lg border border-line bg-white" style={{ height: PLOT_H * scale }}>
      <iframe title={title} src={src} sandbox="allow-scripts" scrolling="no"
        style={{ width: PLOT_W, height: PLOT_H, border: 0, transform: `scale(${scale})`, transformOrigin: "0 0" }} />
    </div>
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
        <button className="btn" onClick={() => void navigator.clipboard?.writeText(text)}><ClipboardCopy size={13} aria-hidden="true" />Copy</button>
        <button className="btn" onClick={() => void run()} title="Run edited code in R (Ctrl/Cmd+Enter)"><Play size={13} className="text-ok" aria-hidden="true" />Run</button>
        {text !== code && <button className="btn" onClick={() => setText(code)}><RotateCcw size={13} aria-hidden="true" />Reset</button>}
      </div>
      <textarea aria-label="R code" spellCheck={false} value={text} onChange={(e) => setText(e.target.value)}
        onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) void run(); }}
        wrap="off" className="w-full resize-y rounded-lg border border-line bg-surface2 p-3 font-mono text-[12px] leading-[1.55] outline-none focus:border-brand/60"
        rows={Math.min(48, text.split("\n").length + 1)} />
      {err && <pre className="whitespace-pre-wrap text-xs text-bad">{err}</pre>}
      {out && <pre className="max-h-60 overflow-auto whitespace-pre-wrap rounded bg-surface2 p-2 font-mono text-xs">{out.console || "(no printed output)"}{out.warnings.length ? `\nWarnings:\n${out.warnings.join("\n")}` : ""}</pre>}
    </div>
  );
}
