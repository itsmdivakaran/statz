// APA formatting for result tables. Raw values stay full precision in the JSON.
import type { Cell, Column } from "../types";

const MINUS = "−";

export function fmtNum(x: number | null | undefined, digits = 2): string {
  if (x === null || x === undefined || Number.isNaN(x)) return "";
  const s = x.toFixed(digits);
  // Avoid "-0.00".
  const z = Number(s) === 0 ? s.replace("-", "") : s;
  return z.replace("-", MINUS);
}

export function fmtP(p: number | null | undefined): string {
  if (p === null || p === undefined || Number.isNaN(p)) return "";
  if (p < 0.001) return "< .001";
  return p.toFixed(3).replace(/^0\./, ".");
}

export function fmtCell(value: Cell, col: Column): string {
  if (value === null || value === undefined) return "";
  switch (col.type) {
    case "text":
      return String(value);
    case "int":
      return typeof value === "number" ? String(Math.round(value)) : String(value);
    case "pvalue":
      return typeof value === "number" ? fmtP(value) : "";
    case "ci": {
      if (!Array.isArray(value) || value.length !== 2 || value.some((v) => v === null)) return "";
      return `[${fmtNum(value[0], col.digits ?? 2)}, ${fmtNum(value[1], col.digits ?? 2)}]`;
    }
    default:
      return typeof value === "number" ? fmtNum(value, col.digits ?? 2) : String(value);
  }
}

/** Tab-separated text for pasting into Excel/Word. */
export function tableToTsv(cols: Column[], rows: Record<string, Cell>[]): string {
  const head = cols.map((c) => c.label).join("\t");
  return [head, ...rows.map((r) => cols.map((c) => fmtCell(r[c.id], c)).join("\t"))].join("\n");
}
