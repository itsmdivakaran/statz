import { useState } from "react";
import { ArrowRight, ChevronDown, ChevronRight, MousePointerClick, SlidersHorizontal, X } from "lucide-react";
import { MeasureIcon } from "../app/MeasureIcon";
import { useStore } from "../state/store";
import type { ModuleSpec, OptionSpec, Options, RoleSpec, VariableMeta } from "../types";

/** Can `v` go into `role`? Mirrors the R-side check in sn_validate(). */
export function accepts(role: RoleSpec, v: VariableMeta): boolean {
  return role.measure.length === 0 || role.measure.includes(v.measure);
}

export function AnalysisDialog() {
  const { analyses, selected, specs, data, setOptions } = useStore();
  const a = analyses.find((x) => x.instance === selected);
  if (!a || !data) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-2 p-6 text-center">
        <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-brand/10 text-brand"><MousePointerClick size={20} aria-hidden="true" /></span>
        <p className="text-sm font-medium">Choose an analysis</p>
        <p className="max-w-56 text-xs text-muted">Pick one from the menu above, or press Ctrl/⌘ K to search.</p>
      </div>
    );
  }
  const spec = specs[a.module];
  return (
    <div className="flex h-full flex-col overflow-hidden" data-testid="analysis-dialog">
      <div className="border-b border-line px-3 py-2.5">
        <h2 className="flex items-center gap-2 font-semibold"><SlidersHorizontal size={15} className="text-brand" aria-hidden="true" />{spec.title}</h2>
        {a.error && a.error.code === -32003 && (
          <p role="alert" className="mt-1 text-xs text-warn">{a.error.message}</p>
        )}
      </div>
      <div className="flex-1 overflow-auto p-3">
        <Dialog spec={spec} options={a.options} vars={data.variables} errorRole={a.error?.role}
          onChange={(patch) => setOptions(a.instance, patch)} />
      </div>
    </div>
  );
}

interface DialogProps {
  spec: ModuleSpec;
  options: Options;
  vars: VariableMeta[];
  errorRole?: string;
  onChange: (patch: Options) => void;
}

export function Dialog({ spec, options, vars, errorRole, onChange }: DialogProps) {
  const [picked, setPicked] = useState<string | null>(null);
  const used = new Set(spec.roles.flatMap((r) => (options[r.id] as string[]) ?? []));
  const free = vars.filter((v) => !used.has(v.name));
  const byName = Object.fromEntries(vars.map((v) => [v.name, v]));

  const addTo = (role: RoleSpec, name: string) => {
    const v = byName[name];
    if (!v || !accepts(role, v)) return;
    const patch: Options = {};
    // Move out of any other role first.
    for (const r of spec.roles) {
      const cur = (options[r.id] as string[]) ?? [];
      if (cur.includes(name)) patch[r.id] = cur.filter((x) => x !== name);
    }
    const cur = ((patch[role.id] ?? options[role.id]) as string[]) ?? [];
    patch[role.id] = role.max === 1 ? [name] : [...cur.filter((x) => x !== name), name];
    onChange(patch);
    setPicked(null);
  };
  const removeFrom = (role: RoleSpec, name: string) =>
    onChange({ [role.id]: ((options[role.id] as string[]) ?? []).filter((x) => x !== name) });

  return (
    <div className="space-y-4">
      {spec.layout.map((sec) => {
        const roleItems = sec.items.map((id) => spec.roles.find((r) => r.id === id)).filter(Boolean) as RoleSpec[];
        if (roleItems.length) {
          return (
            <div key={sec.section} className="grid grid-cols-[minmax(0,1fr)_minmax(0,1.2fr)] gap-3">
              <div>
                <div className="panel-title mb-1">Variables</div>
                <ul className="h-64 overflow-auto rounded-lg border border-line bg-surface2/50 p-1 text-sm" aria-label="Available variables">
                  {free.map((v) => (
                    <li key={v.name} data-var={v.name} draggable onDragStart={(e) => e.dataTransfer.setData("text/plain", v.name)}
                      onClick={() => setPicked(v.name)} title={v.label || v.name}
                      className={`flex cursor-grab items-center gap-1.5 truncate rounded-md px-2 py-1 ${picked === v.name ? "bg-brand/15 text-brand" : "hover:bg-surface2"}`}>
                      <MeasureIcon measure={v.measure} />{v.name}
                    </li>
                  ))}
                </ul>
              </div>
              <div className="space-y-2">
                {roleItems.map((role) => {
                  const cur = (options[role.id] as string[]) ?? [];
                  const ok = picked ? accepts(role, byName[picked]) : false;
                  return (
                    <div key={role.id}>
                      <div className="mb-1 flex items-center gap-2">
                        <button className={`flex h-6 w-6 items-center justify-center rounded-md border transition-colors disabled:opacity-40 ${ok ? "border-brand bg-brand text-white" : "border-line bg-surface text-muted"}`} disabled={!ok} aria-label={`Add to ${role.label}`}
                          onClick={() => picked && addTo(role, picked)}><ArrowRight size={13} aria-hidden="true" /></button>
                        <span className="panel-title">{role.label}</span>
                        {role.measure.length > 0 && <span className="ml-auto flex gap-1 opacity-70">{role.measure.map((m) => <MeasureIcon key={m} measure={m} />)}</span>}
                      </div>
                      <ul data-role={role.id} aria-label={role.label}
                        onDragOver={(e) => e.preventDefault()}
                        onDrop={(e) => { e.preventDefault(); addTo(role, e.dataTransfer.getData("text/plain")); }}
                        className={`min-h-9 rounded-lg border border-dashed p-1 text-sm transition-colors ${errorRole === role.id ? "border-warn bg-warn/5" : ok ? "border-brand/60 bg-brand/5" : "border-line"} ${role.max === 1 ? "" : "min-h-16"}`}>
                        {cur.map((name) => (
                          <li key={name} className="flex items-center justify-between rounded-md bg-surface px-2 py-1 shadow-card">
                            <span className="flex items-center gap-1.5"><MeasureIcon measure={byName[name]?.measure} />{name}</span>
                            <button className="text-muted hover:text-bad" aria-label={`Remove ${name}`} onClick={() => removeFrom(role, name)}><X size={13} aria-hidden="true" /></button>
                          </li>
                        ))}
                      </ul>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        }
        return <Section key={sec.section} title={sec.section} collapsed={sec.collapsed}>
          {sec.items.map((id) => spec.options[id] && (
            <OptionControl key={id} id={id} spec={spec.options[id]} value={options[id]} onChange={(v) => onChange({ [id]: v })} />
          ))}
        </Section>;
      })}
    </div>
  );
}

function Section({ title, collapsed, children }: { title: string; collapsed?: boolean; children: React.ReactNode }) {
  const [open, setOpen] = useState(!collapsed);
  return (
    <div className="rounded-lg border border-line">
      <button className="flex w-full items-center justify-between rounded-lg px-2.5 py-2 text-sm font-semibold hover:bg-surface2" onClick={() => setOpen(!open)} aria-expanded={open}>
        {title}<span className="text-muted">{open ? <ChevronDown size={15} aria-hidden="true" /> : <ChevronRight size={15} aria-hidden="true" />}</span>
      </button>
      {open && <div className="space-y-2.5 border-t border-line p-2.5">{children}</div>}
    </div>
  );
}

function OptionControl({ id, spec, value, onChange }: { id: string; spec: OptionSpec; value: unknown; onChange: (v: unknown) => void }) {
  if (spec.type === "bool") {
    return (
      <label className="flex items-center gap-2 text-sm">
        <input type="checkbox" checked={!!value} onChange={(e) => onChange(e.target.checked)} />{spec.label}
      </label>
    );
  }
  if (spec.type === "number") {
    return (
      <label className="flex items-center justify-between gap-2 text-sm">
        {spec.label}
        <input type="number" className="field w-24"
          value={value as number} min={spec.min} max={spec.max} step={spec.step ?? "any"}
          onChange={(e) => e.target.value !== "" && onChange(Number(e.target.value))} />
      </label>
    );
  }
  const labels = spec.labels ?? spec.values;
  if (spec.multiple) {
    const cur = (value as string[]) ?? [];
    return (
      <fieldset className="text-sm">
        <legend className="mb-1 text-xs text-muted">{spec.label}</legend>
        {spec.values.map((v, i) => (
          <label key={v} className="mr-3 inline-flex items-center gap-1">
            <input type="checkbox" checked={cur.includes(v)}
              onChange={(e) => onChange(e.target.checked ? [...cur, v] : cur.filter((x) => x !== v))} />
            {labels[i]}
          </label>
        ))}
      </fieldset>
    );
  }
  return (
    <label className="flex items-center justify-between gap-2 text-sm">
      {spec.label}
      <select className="field" value={value as string}
        onChange={(e) => onChange(e.target.value)} name={id}>
        {spec.values.map((v, i) => <option key={v} value={v}>{labels[i]}</option>)}
      </select>
    </label>
  );
}
