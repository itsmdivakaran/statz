// Mirrors schemas/module.schema.json and schemas/result.schema.json.

export type Measure = "continuous" | "nominal" | "ordinal" | "date";

export interface RoleSpec {
  id: string;
  label: string;
  min: number;
  max: number | null;
  measure: Measure[];
  levels?: { exactly?: number; min?: number };
}

export type OptionSpec =
  | { type: "enum"; label: string; values: string[]; labels?: string[]; multiple?: boolean; default: string | string[] }
  | { type: "number"; label: string; min?: number; max?: number; step?: number; default: number }
  | { type: "bool"; label: string; default: boolean }
  | { type: "text"; label: string; placeholder?: string; default: string }
  | { type: "interactions"; label: string; from: string[]; interact?: string[]; default?: undefined };

export interface ModuleSpec {
  id: string;
  version: string;
  title: string;
  description?: string;
  menu: string[];
  r: { file: string; fn: string; packages: string[] };
  roles: RoleSpec[];
  options: Record<string, OptionSpec>;
  layout: { section: string; items: string[]; collapsed?: boolean }[];
  guide?: Record<string, unknown>;
  example?: { dataset: string; options: Record<string, unknown> };
}

export type Options = Record<string, unknown>;

export interface ValueLabel { value: number; label: string }

export interface VariableMeta {
  name: string;
  label: string;
  type: string;
  measure: Measure;
  value_labels: ValueLabel[];
  missing: number[];
}

export interface DataInfo {
  id: string;
  source: string | null;
  nrow: number;
  ncol: number;
  variables: VariableMeta[];
}

export interface DataSlice {
  id: string;
  offset: number;
  nrow: number;
  columns: Record<string, (string | number | boolean | null)[]>;
}

export type ColumnType = "number" | "int" | "text" | "pvalue" | "ci";
export interface Column { id: string; label: string; type: ColumnType; digits?: number }
export type Cell = string | number | null | (number | null)[];
export interface Table { id: string; title: string; columns: Column[]; rows: Record<string, Cell>[]; notes: string[] }

export interface Check {
  id: string;
  test: string;
  status: "ok" | "warn" | "fail";
  message: string | null;
  table: Table | null;
}

export interface Plot {
  id: string;
  title: string;
  engine: "ggnext" | "ggplot2";
  fallback: boolean;
  fallback_reason: string | null;
  svg: string;
  html: string | null;
  data_csv: string | null;
}

export interface AnalysisResult {
  module: string;
  module_version: string;
  title: string;
  status: "ok" | "warn";
  tables: Table[];
  assumptions: Check[];
  plots: Plot[];
  interpretation: { auto_generated: true; text: string } | null;
  notes: string[];
  warnings: string[];
  code: string;
  console: string;
  meta: { r_version: string; packages: Record<string, string>; dataset: string };
}

export interface RpcErrorShape { code: number; message: string; data?: Record<string, unknown> & { hint?: string } }

export interface Hello {
  protocol: number;
  r_version: string;
  statnextr: string;
  plot_engine: "ggnext" | "ggplot2";
  modules: string[];
  missing_packages: string[];
  rscript?: string;
}
