import { create } from "zustand";
import { call, cancel, onEvent, RpcError, startBackend, ERR } from "../rpc/client";
import type { AnalysisResult, DataInfo, Hello, ModuleSpec, Options } from "../types";

export interface Analysis {
  instance: string;
  module: string;
  options: Options;
  result?: AnalysisResult;
  error?: { code: number; message: string; hint?: string; role?: string };
  running: boolean;
}

type Command =
  | { kind: "options"; instance: string; before: Options; after: Options }
  | { kind: "cell"; row: number; column: string; before: unknown; after: unknown }
  | { kind: "transform"; ops: TransformOp[] };

export type TransformMode = "compute" | "recode" | "filter";
export type TransformOp =
  | { op: "compute"; name: string; expr: string; label?: string }
  | { op: "recode"; column: string; into: string; label?: string; unmatched: "keep" | "missing"; rules: { from: string[]; to: string }[] }
  | { op: "filter"; expr: string };

export type Status = "starting" | "setup" | "ready" | "no-r" | "error";

interface State {
  status: Status;
  statusDetail: string | null;
  rStatus: unknown;
  setup: { pct: number; message: string } | null;
  hello: Hello | null;
  specs: Record<string, ModuleSpec>;
  data: DataInfo | null;
  dataVersion: number;
  analyses: Analysis[];
  selected: string | null;
  undoStack: Command[];
  redoStack: Command[];
  theme: "light" | "dark";
  transformMode: TransformMode | null;
  openTransform(mode: TransformMode): void;
  closeTransform(): void;
  transform(ops: TransformOp[], record?: boolean): Promise<void>;
  init(): Promise<void>;
  loadExample(name: string): Promise<void>;
  importFile(path: string): Promise<void>;
  newAnalysis(module: string, options?: Options): string;
  select(instance: string | null): void;
  setOptions(instance: string, patch: Options, record?: boolean): void;
  removeAnalysis(instance: string): void;
  editCell(row: number, column: string, value: unknown, before: unknown, record?: boolean): Promise<void>;
  setMeta(column: string, field: string, value: unknown): Promise<void>;
  undo(): void;
  redo(): void;
  runNow(instance: string): Promise<void>;
  toggleTheme(): void;
  restore(ui: { analyses: Pick<Analysis, "instance" | "module" | "options">[] }, data: DataInfo | null): void;
}

let seq = 0;
const timers = new Map<string, ReturnType<typeof setTimeout>>();
let inflight: string | null = null;
const latestRun = new Map<string, number>();
let runSeq = 0;
const DEBOUNCE_MS = 300;

export function defaultOptions(spec: ModuleSpec): Options {
  const o: Options = {};
  for (const r of spec.roles) o[r.id] = [];
  for (const [k, v] of Object.entries(spec.options)) {
    if (v.type === "interactions") continue; // unset = backend default
    if (v.type === "subset") { o[k] = []; continue; }
    o[k] = Array.isArray(v.default) ? [...v.default] : v.default;
  }
  return o;
}

/** True when every required role has enough variables. */
export function rolesFilled(spec: ModuleSpec, o: Options): boolean {
  return spec.roles.every((r) => ((o[r.id] as string[] | undefined)?.length ?? 0) >= r.min);
}

const prefersDark = typeof window !== "undefined" && window.matchMedia?.("(prefers-color-scheme: dark)").matches;

export const useStore = create<State>((set, get) => {
  const patchAnalysis = (instance: string, patch: Partial<Analysis>) =>
    set((s) => ({ analyses: s.analyses.map((a) => (a.instance === instance ? { ...a, ...patch } : a)) }));

  const schedule = (instance: string) => {
    clearTimeout(timers.get(instance));
    timers.set(instance, setTimeout(() => void get().runNow(instance), DEBOUNCE_MS));
  };

  const rerunAll = () => get().analyses.forEach((a) => schedule(a.instance));

  const applyCommand = async (c: Command, dir: "undo" | "redo") => {
    if (c.kind === "options") {
      get().setOptions(c.instance, dir === "undo" ? c.before : c.after, false);
      set({ selected: c.instance });
    } else if (c.kind === "cell") {
      await get().editCell(c.row, c.column, dir === "undo" ? c.before : c.after, null, false);
    } else if (dir === "redo") {
      await get().transform(c.ops, false);
    } else {
      const data = await call<DataInfo>("data.undo");
      set((s) => ({ data, dataVersion: s.dataVersion + 1 }));
      rerunAll();
    }
  };

  return {
    status: "starting",
    statusDetail: null,
    rStatus: null,
    setup: null,
    hello: null,
    specs: {},
    data: null,
    dataVersion: 0,
    analyses: [],
    selected: null,
    undoStack: [],
    redoStack: [],
    theme: prefersDark ? "dark" : "light",
    transformMode: null,
    openTransform(mode) { set({ transformMode: mode }); },
    closeTransform() { set({ transformMode: null }); },

    async transform(ops, record = true) {
      const data = await call<DataInfo>("data.patch", { ops });
      if (record) set((s) => ({ undoStack: [...s.undoStack, { kind: "transform", ops }], redoStack: [] }));
      set((s) => ({ data, dataVersion: s.dataVersion + 1 }));
      rerunAll();
    },

    async init() {
      const off = await onEvent<{ pct: number; message: string }>("setup://progress", (p) =>
        set({ status: "setup", setup: p }),
      );
      try {
        const hello = await startBackend<Hello>();
        const list = await call<ModuleSpec[]>("analysis.list");
        set({ hello, status: "ready", setup: null, specs: Object.fromEntries(list.map((s) => [s.id, s])) });
      } catch (e) {
        const err = e as RpcError;
        if (err.code === ERR.notStarted) set({ status: "no-r", rStatus: err.data ?? null, statusDetail: err.message });
        else set({ status: "error", statusDetail: err.message });
      } finally {
        off();
      }
    },

    async loadExample(name) {
      const data = await call<DataInfo>("data.example", { name });
      set((s) => ({ data, dataVersion: s.dataVersion + 1, undoStack: [], redoStack: [] }));
      rerunAll();
    },

    async importFile(path) {
      const data = await call<DataInfo>("data.import", { path });
      set((s) => ({ data, dataVersion: s.dataVersion + 1, undoStack: [], redoStack: [] }));
      rerunAll();
    },

    newAnalysis(module, options) {
      const spec = get().specs[module];
      const instance = `a${++seq}`;
      set((s) => ({
        analyses: [...s.analyses, { instance, module, options: { ...defaultOptions(spec), ...options }, running: false }],
        selected: instance,
      }));
      schedule(instance);
      return instance;
    },

    select(instance) {
      set({ selected: instance });
    },

    setOptions(instance, patch, record = true) {
      const a = get().analyses.find((x) => x.instance === instance);
      if (!a) return;
      const after = { ...a.options, ...patch };
      if (record)
        set((s) => ({ undoStack: [...s.undoStack, { kind: "options", instance, before: a.options, after }], redoStack: [] }));
      patchAnalysis(instance, { options: after });
      schedule(instance);
    },

    removeAnalysis(instance) {
      clearTimeout(timers.get(instance));
      void call("analysis.remove", { instance }).catch(() => {});
      set((s) => {
        const analyses = s.analyses.filter((a) => a.instance !== instance);
        return { analyses, selected: s.selected === instance ? (analyses.at(-1)?.instance ?? null) : s.selected };
      });
    },

    async editCell(row, column, value, before, record = true) {
      const data = await call<DataInfo>("data.patch", { ops: [{ op: "set_cell", row, column, value }] });
      if (record)
        set((s) => ({ undoStack: [...s.undoStack, { kind: "cell", row, column, before, after: value }], redoStack: [] }));
      set((s) => ({ data, dataVersion: s.dataVersion + 1 }));
      rerunAll();
    },

    async setMeta(column, field, value) {
      const data = await call<DataInfo>("data.patch", { ops: [{ op: "set_meta", column, field, value }] });
      set((s) => ({ data, dataVersion: s.dataVersion + 1 }));
      rerunAll();
    },

    undo() {
      const c = get().undoStack.at(-1);
      if (!c) return;
      set((s) => ({ undoStack: s.undoStack.slice(0, -1), redoStack: [...s.redoStack, c] }));
      void applyCommand(c, "undo");
    },

    redo() {
      const c = get().redoStack.at(-1);
      if (!c) return;
      set((s) => ({ redoStack: s.redoStack.slice(0, -1), undoStack: [...s.undoStack, c] }));
      void applyCommand(c, "redo");
    },

    async runNow(instance) {
      const a = get().analyses.find((x) => x.instance === instance);
      const spec = a && get().specs[a.module];
      if (!a || !spec || !get().data) return;
      if (!rolesFilled(spec, a.options)) {
        patchAnalysis(instance, { running: false, error: undefined, result: undefined });
        return;
      }
      // Live update: a newer run of the same analysis supersedes the one in flight.
      const token = ++runSeq;
      latestRun.set(instance, token);
      if (inflight === instance) await cancel();
      inflight = instance;
      patchAnalysis(instance, { running: true });
      try {
        const result = await call<AnalysisResult>("analysis.run", { module: a.module, options: a.options, instance });
        patchAnalysis(instance, { result, error: undefined, running: false });
      } catch (e) {
        const err = e as RpcError;
        if (err.cancelled) {
          // Superseded by a newer run, or a stray interrupt hit this one: rerun if it is still the latest.
          if (latestRun.get(instance) === token) schedule(instance);
          return;
        }
        patchAnalysis(instance, {
          running: false,
          error: { code: err.code, message: err.message, hint: err.data?.hint as string | undefined, role: err.data?.role as string | undefined },
        });
      } finally {
        if (inflight === instance) inflight = null;
      }
    },

    toggleTheme() {
      set((s) => ({ theme: s.theme === "dark" ? "light" : "dark" }));
    },

    restore(ui, data) {
      const analyses = ui.analyses.map((a) => ({ ...a, running: false }));
      seq = Math.max(seq, ...analyses.map((a) => Number(a.instance.slice(1)) || 0));
      set((s) => ({ analyses, data, dataVersion: s.dataVersion + 1, selected: analyses[0]?.instance ?? null, undoStack: [], redoStack: [] }));
      rerunAll();
    },
  };
});
