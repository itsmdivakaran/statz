import { useState } from "react";
import { useStore } from "../state/store";
import { MeasureIcon } from "../app/MeasureIcon";
import type { Measure, ValueLabel } from "../types";

const MEASURES: Measure[] = ["continuous", "nominal", "ordinal", "date"];

function parseValueLabels(text: string): ValueLabel[] {
  // "0=Automatic; 1=Manual"
  return text
    .split(/[;\n]/)
    .map((p) => p.split("="))
    .filter((p) => p.length === 2 && p[0].trim() !== "" && !Number.isNaN(Number(p[0])))
    .map(([v, l]) => ({ value: Number(v), label: l.trim() }));
}

function parseMissing(text: string): number[] {
  return text.split(/[,;\s]+/).filter(Boolean).map(Number).filter((n) => !Number.isNaN(n));
}

export function VariableView() {
  const { data, setMeta } = useStore();
  const [draft, setDraft] = useState<Record<string, string>>({});
  if (!data) return null;
  const field = (name: string, f: string, initial: string) => {
    const key = `${name}:${f}`;
    return {
      value: draft[key] ?? initial,
      onChange: (e: React.ChangeEvent<HTMLInputElement>) => setDraft({ ...draft, [key]: e.target.value }),
      onBlur: () => {
        const v = draft[key];
        if (v === undefined || v === initial) return;
        const value = f === "value_labels" ? parseValueLabels(v) : f === "missing" ? parseMissing(v) : v;
        void setMeta(name, f, value);
        setDraft(({ [key]: _, ...rest }) => rest);
      },
      className: "w-full bg-transparent px-1 outline-none focus:bg-brand/10",
    };
  };
  return (
    <div className="flex-1 overflow-auto">
      <table className="w-full text-sm">
        <thead className="sticky top-0 bg-surface2 text-left text-[11px] uppercase tracking-wider text-muted">
          <tr>{["Name", "Label", "Type", "Measure", "Value labels", "Missing codes"].map((h) => <th key={h} className="px-2 py-1.5 font-semibold">{h}</th>)}</tr>
        </thead>
        <tbody>
          {data.variables.map((v) => (
            <tr key={v.name} className="border-t border-line">
              <td className="px-2 py-1.5 font-medium"><span className="flex items-center gap-1.5"><MeasureIcon measure={v.measure} />{v.name}</span></td>
              <td><input aria-label={`${v.name} label`} {...field(v.name, "label", v.label)} /></td>
              <td className="px-2 text-muted">{v.type}</td>
              <td>
                <select aria-label={`${v.name} measure`} value={v.measure} className="bg-transparent"
                  onChange={(e) => void setMeta(v.name, "measure", e.target.value)}>
                  {MEASURES.map((m) => <option key={m}>{m}</option>)}
                </select>
              </td>
              <td><input aria-label={`${v.name} value labels`} placeholder="0=No; 1=Yes"
                {...field(v.name, "value_labels", v.value_labels.map((l) => `${l.value}=${l.label}`).join("; "))} /></td>
              <td><input aria-label={`${v.name} missing codes`} placeholder="-99, 999"
                {...field(v.name, "missing", (v.missing ?? []).join(", "))} /></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
