import { ArrowRight, Check, Compass, Play, RotateCcw, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { call } from "../rpc/client";
import { useStore } from "../state/store";
import type { Options } from "../types";
import { type Answers, GOALS, type Pick, assignRoles, hasBayesian, outcomeOf, questions, recommend } from "./guide";

const CHIP = "rounded-lg border px-3 py-1.5 text-left text-sm transition-colors";
const chip = (on: boolean) => `${CHIP} ${on ? "border-brand bg-brand/10 text-brand" : "border-line bg-surface hover:border-brand/50"}`;

/** "Which analysis should I use?" — asks a few questions and opens the recommended analysis. */
export function GuideDialog() {
  const { modal, setModal, specs, data, newAnalysis, runExample } = useStore();
  const [a, setA] = useState<Answers>({});
  const [outcomeVar, setOutcomeVar] = useState("");
  const [groupVar, setGroupVar] = useState("");
  const open = modal === "guide";
  useEffect(() => { if (open) { setA({}); setOutcomeVar(""); setGroupVar(""); } }, [open]);
  useEffect(() => {
    if (!open) return;
    const esc = (e: KeyboardEvent) => e.key === "Escape" && setModal(null);
    document.addEventListener("keydown", esc);
    return () => document.removeEventListener("keydown", esc);
  }, [open, setModal]);

  const qs = useMemo(() => questions(a), [a]);
  const rec = useMemo(() => recommend(a), [a]);
  if (!open) return null;
  const close = () => setModal(null);

  /** Keep the answers to the questions before this one; later ones may no longer apply. */
  const answer = (id: keyof Answers, value: string) => {
    if (id === "goal") return setA({ goal: value as Answers["goal"], approach: a.approach });
    const keep: Answers = { goal: a.goal, approach: a.approach };
    for (const q of qs) { if (q.id === id) break; (keep as Record<string, unknown>)[q.id] = a[q.id]; }
    setA({ ...keep, [id]: value });
  };

  /** Fill the outcome (and group) answers from the variables the user picked. */
  const useVariables = async (outcome: string, group: string) => {
    setOutcomeVar(outcome); setGroupVar(group);
    const v = data?.variables.find((x) => x.name === outcome);
    if (!v) return;
    const distinct = async (name: string) => (await call<{ distinct: number }>("data.values", { column: name }).catch(() => ({ distinct: 0 }))).distinct;
    const next: Answers = { goal: a.goal, approach: a.approach, outcome: outcomeOf(v, await distinct(outcome)) };
    if (a.goal === "compare" && group) {
      const k = await distinct(group);
      next.groups = k <= 2 ? "two" : "many";
      next.design = "independent";
    }
    if (a.goal === "relate") {
      const g = data?.variables.find((x) => x.name === group);
      const ms = [v.measure, g?.measure];
      next.kind = ms.every((m) => m === "continuous") ? "continuous" : ms.every((m) => m === "nominal") ? "categorical" : "ordinal";
      delete next.outcome;
    }
    setA(next);
  };

  const openPick = (p: Pick) => {
    const spec = specs[p.module];
    if (!spec) return;
    close();
    if (!data) { void runExample(p.module); return; }
    const roles = assignRoles(spec, data, outcomeVar || undefined, groupVar || undefined);
    newAnalysis(p.module, { ...roles, ...(p.options as Options | undefined) });
  };

  const showVars = !!data && (a.goal === "compare" || a.goal === "predict" || a.goal === "relate");
  const title = (id: string) => specs[id]?.title ?? id;

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/30 pt-[6vh] backdrop-blur-[2px]" onMouseDown={close}>
      <div role="dialog" aria-label="Analysis guide" className="flex max-h-[88vh] w-[60rem] max-w-[96vw] animate-pop flex-col overflow-hidden rounded-2xl border border-line bg-surface shadow-pop" onMouseDown={(e) => e.stopPropagation()}>
        <header className="flex items-center gap-2.5 border-b border-line px-4 py-3">
          <span className="flex h-7 w-7 items-center justify-center rounded-md bg-brand/10 text-brand"><Compass size={15} aria-hidden="true" /></span>
          <div>
            <h2 className="text-[15px] font-semibold tracking-tight">Which analysis should I use?</h2>
            <p className="text-xs text-muted">Answer a few questions; the guide picks the test and opens it for you.</p>
          </div>
          <button className="btn-ghost ml-auto px-2 text-xs" onClick={() => { setA({}); setOutcomeVar(""); setGroupVar(""); }}><RotateCcw size={13} aria-hidden="true" />Start over</button>
          <button className="btn-ghost px-1.5" aria-label="Close" onClick={close}><X size={15} aria-hidden="true" /></button>
        </header>
        <div className="grid min-h-0 flex-1 grid-cols-1 overflow-auto md:grid-cols-[1fr_20rem]">
          <div className="space-y-5 p-4">
            <section>
              <h3 className="panel-title mb-2">1 · What do you want to do?</h3>
              <div className="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
                {GOALS.map((g) => (
                  <button key={g.value} className={chip(a.goal === g.value)} aria-pressed={a.goal === g.value} onClick={() => answer("goal", g.value)}>
                    <span className="block font-medium">{g.label}</span>
                    <span className="block text-xs text-muted">{g.hint}</span>
                  </button>
                ))}
              </div>
            </section>

            {showVars && (
              <section className="rounded-xl border border-dashed border-line bg-surface2/50 p-3">
                <h3 className="panel-title mb-2">Optional · pick your variables and the guide answers for you</h3>
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  <label className="text-xs text-muted">{a.goal === "relate" ? "First variable" : "Outcome"}
                    <select className="field mt-1 w-full" value={outcomeVar} aria-label="Outcome variable" onChange={(e) => void useVariables(e.target.value, groupVar)}>
                      <option value="">Choose…</option>
                      {data!.variables.map((v) => <option key={v.name} value={v.name}>{v.name}</option>)}
                    </select>
                  </label>
                  {a.goal !== "predict" && (
                    <label className="text-xs text-muted">{a.goal === "relate" ? "Second variable" : "Groups (optional)"}
                      <select className="field mt-1 w-full" value={groupVar} aria-label="Group variable" onChange={(e) => void useVariables(outcomeVar, e.target.value)}>
                        <option value="">None</option>
                        {data!.variables.map((v) => <option key={v.name} value={v.name}>{v.name}</option>)}
                      </select>
                    </label>
                  )}
                </div>
              </section>
            )}

            {qs.map((q, i) => (
              <section key={q.id}>
                <h3 className="panel-title mb-2">{i + 2} · {q.text}</h3>
                <div className="flex flex-wrap gap-1.5">
                  {q.choices.map((c) => (
                    <button key={c.value} className={chip(a[q.id] === c.value)} aria-pressed={a[q.id] === c.value} onClick={() => answer(q.id, c.value)}>
                      <span className="block font-medium">{c.label}</span>
                      {c.hint && <span className="block text-xs text-muted">{c.hint}</span>}
                    </button>
                  ))}
                </div>
              </section>
            ))}
          </div>

          <aside className="border-t border-line bg-surface2/40 p-4 md:border-l md:border-t-0" aria-live="polite">
            {!rec ? (
              <div className="flex h-full flex-col items-center justify-center gap-2 py-10 text-center text-sm text-muted">
                <Compass size={28} className="text-line" aria-hidden="true" />
                {a.goal ? "Answer the questions to see the recommendation." : "Start by choosing what you want to do."}
              </div>
            ) : (
              <div className="space-y-4">
                {hasBayesian(a) && (
                  <div className="flex rounded-lg border border-line bg-surface p-0.5 text-xs" role="group" aria-label="Approach">
                    {(["frequentist", "bayesian"] as const).map((k) => (
                      <button key={k} aria-pressed={(a.approach ?? "frequentist") === k} onClick={() => setA({ ...a, approach: k })}
                        className={`flex-1 rounded-md px-2 py-1 font-medium ${(a.approach ?? "frequentist") === k ? "bg-brand text-white" : "text-muted hover:text-ink"}`}>
                        {k === "frequentist" ? "Frequentist" : "Bayesian"}
                      </button>
                    ))}
                  </div>
                )}
                <div className="card p-3.5">
                  <div className="panel-title mb-1 flex items-center gap-1.5 text-ok"><Check size={13} aria-hidden="true" />Recommended</div>
                  <div className="text-base font-semibold leading-snug" data-testid="guide-pick">{title(rec.module)}</div>
                  <p className="mt-1 text-xs leading-relaxed text-muted">{rec.why}</p>
                  <button className="btn-primary mt-3 w-full justify-center" onClick={() => openPick(rec)}>
                    {data ? <><ArrowRight size={15} aria-hidden="true" />Open this analysis</> : <><Play size={14} aria-hidden="true" />Try it on example data</>}
                  </button>
                  {!data && <p className="mt-1.5 text-center text-[11px] text-muted">Or open your data file first, then come back.</p>}
                </div>
                {rec.alternatives.length > 0 && (
                  <div>
                    <div className="panel-title mb-1.5">Also consider</div>
                    <ul className="space-y-1">
                      {rec.alternatives.map((p, i) => (
                        <li key={`${p.module}-${i}`}>
                          <button className="w-full rounded-lg px-2.5 py-1.5 text-left transition-colors hover:bg-brand/10" onClick={() => openPick(p)}>
                            <span className="block text-sm font-medium">{title(p.module)}</span>
                            <span className="block text-xs text-muted">{p.why}</span>
                          </button>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </div>
            )}
          </aside>
        </div>
      </div>
    </div>
  );
}
