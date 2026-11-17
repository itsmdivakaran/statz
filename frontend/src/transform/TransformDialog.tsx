import { Calculator, Filter, Replace, X } from "lucide-react";
import { useEffect, useState } from "react";
import { call } from "../rpc/client";
import { type TransformMode, useStore } from "../state/store";

interface Values { distinct: number; missing: number; values: { value: string; n: number; label: string | null }[] }

const META: Record<TransformMode, { title: string; Icon: typeof Calculator; help: string }> = {
  compute: { title: "Compute variable", Icon: Calculator, help: "Any R expression using your variables, for example weight / height^2, log(income), rowMeans(cbind(q1, q2, q3)) or ifelse(age >= 65, \"65+\", \"under 65\")." },
  recode: { title: "Recode variable", Icon: Replace, help: "Type a new value next to each old value. Values given the same new value are merged; leave a box empty to keep the old value." },
  filter: { title: "Filter rows", Icon: Filter, help: "Keep only the rows where the condition is true, for example age >= 18 & group == \"A\". Undo brings the rows back." },
};

export function TransformDialog() {
  const { transformMode: mode, closeTransform, data, transform } = useStore();
  const [name, setName] = useState("");
  const [label, setLabel] = useState("");
  const [expr, setExpr] = useState("");
  const [column, setColumn] = useState("");
  const [values, setValues] = useState<Values | null>(null);
  const [map, setMap] = useState<Record<string, string>>({});
  const [unmatched, setUnmatched] = useState<"keep" | "missing">("keep");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => { setName(""); setLabel(""); setExpr(""); setColumn(""); setValues(null); setMap({}); setError(null); setUnmatched("keep"); }, [mode]);
  useEffect(() => {
    setValues(null); setMap({});
    if (mode === "recode" && column) void call<Values>("data.values", { column }).then(setValues).catch((e) => setError((e as Error).message));
  }, [mode, column]);

  if (!mode || !data) return null;
  const { title, Icon, help } = META[mode];

  const apply = async () => {
    setError(null); setBusy(true);
    try {
      if (mode === "compute") await transform([{ op: "compute", name, expr, label }]);
      else if (mode === "filter") await transform([{ op: "filter", expr }]);
      else {
        const groups = new Map<string, string[]>();
        for (const [from, to] of Object.entries(map)) if (to.trim() !== "") groups.set(to.trim(), [...(groups.get(to.trim()) ?? []), from]);
        await transform([{ op: "recode", column, into: name, label, unmatched, rules: [...groups].map(([to, from]) => ({ from, to })) }]);
      }
      closeTransform();
    } catch (e) { setError((e as Error).message); }
    finally { setBusy(false); }
  };
  const ready = mode === "compute" ? name.trim() !== "" && expr.trim() !== "" : mode === "filter" ? expr.trim() !== "" : column !== "" && Object.values(map).some((v) => v.trim() !== "");

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/30 pt-[10vh] backdrop-blur-[2px]" onMouseDown={closeTransform}>
      <div role="dialog" aria-label={title} className="flex max-h-[80vh] w-[36rem] max-w-[94vw] animate-pop flex-col overflow-hidden rounded-2xl border border-line bg-surface shadow-pop" onMouseDown={(e) => e.stopPropagation()}>
        <header className="flex items-center gap-2.5 border-b border-line px-4 py-3">
          <span className="flex h-7 w-7 items-center justify-center rounded-md bg-brand/10 text-brand"><Icon size={15} aria-hidden="true" /></span>
          <h2 className="text-[15px] font-semibold tracking-tight">{title}</h2>
          <button className="btn-ghost ml-auto px-1.5" aria-label="Close" onClick={closeTransform}><X size={15} aria-hidden="true" /></button>
        </header>
        <div className="space-y-3 overflow-auto p-4 text-sm">
          <p className="text-xs leading-relaxed text-muted">{help}</p>
          {mode === "recode" && (
            <label className="block"><span className="mb-1 block text-xs text-muted">Variable to recode</span>
              <select aria-label="Variable to recode" className="field w-full" value={column} onChange={(e) => { setColumn(e.target.value); setName(e.target.value ? `${e.target.value}_r` : ""); }}>
                <option value="">Choose…</option>
                {data.variables.map((v) => <option key={v.name}>{v.name}</option>)}
              </select>
            </label>
          )}
          {mode !== "filter" && (
            <div className="grid grid-cols-2 gap-3">
              <label className="block"><span className="mb-1 block text-xs text-muted">{mode === "recode" ? "Save as (same name overwrites)" : "New variable name"}</span>
                <input aria-label="New variable name" className="field w-full font-mono" value={name} placeholder="bmi" onChange={(e) => setName(e.target.value)} /></label>
              <label className="block"><span className="mb-1 block text-xs text-muted">Label (optional)</span>
                <input aria-label="Variable label" className="field w-full" value={label} onChange={(e) => setLabel(e.target.value)} /></label>
            </div>
          )}
          {mode !== "recode" && (
            <>
              <label className="block"><span className="mb-1 block text-xs text-muted">{mode === "compute" ? "Expression" : "Keep rows where"}</span>
                <textarea aria-label="Expression" rows={3} spellCheck={false} className="field w-full resize-y font-mono text-[13px]" value={expr}
                  placeholder={mode === "compute" ? "weight / (height / 100)^2" : "age >= 18"} onChange={(e) => setExpr(e.target.value)} /></label>
              <div className="flex max-h-24 flex-wrap gap-1 overflow-auto">
                {data.variables.map((v) => (
                  <button key={v.name} className="rounded-md border border-line px-1.5 py-0.5 font-mono text-xs text-muted hover:border-brand/60 hover:text-brand"
                    title={v.label || v.name} onClick={() => setExpr((x) => (x && !/[\s(]$/.test(x) ? `${x} ${v.name}` : `${x}${v.name}`))}>{v.name}</button>
                ))}
              </div>
            </>
          )}
          {mode === "recode" && values && (
            <>
              {values.distinct > values.values.length && <p className="text-xs text-warn">Showing the first {values.values.length} of {values.distinct} values. For ranges, use Compute with cut().</p>}
              <table className="w-full text-sm">
                <thead className="text-left text-[11px] uppercase tracking-wider text-muted"><tr><th className="py-1 font-semibold">Old value</th><th className="font-semibold">N</th><th className="font-semibold">New value</th></tr></thead>
                <tbody>
                  {values.values.map((v) => (
                    <tr key={v.value} className="border-t border-line">
                      <td className="py-1 font-mono text-[13px]">{v.value}{v.label && <span className="ml-1.5 font-sans text-xs text-muted">{v.label}</span>}</td>
                      <td className="text-muted">{v.n}</td>
                      <td><input aria-label={`New value for ${v.value}`} className="field w-full py-0.5" value={map[v.value] ?? ""} onChange={(e) => setMap({ ...map, [v.value]: e.target.value })} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <label className="flex items-center gap-2 text-xs"><input type="checkbox" checked={unmatched === "missing"} onChange={(e) => setUnmatched(e.target.checked ? "missing" : "keep")} />
                Set values without a new value to missing</label>
            </>
          )}
          {error && <p role="alert" className="rounded-lg bg-bad/10 px-3 py-2 text-xs text-bad">{error}</p>}
        </div>
        <footer className="flex justify-end gap-2 border-t border-line px-4 py-3">
          <button className="btn" onClick={closeTransform}>Cancel</button>
          <button className="btn-primary" disabled={!ready || busy} onClick={() => void apply()}>{mode === "filter" ? "Filter" : mode === "compute" ? "Compute" : "Recode"}</button>
        </footer>
      </div>
    </div>
  );
}
