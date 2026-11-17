import { useVirtualizer } from "@tanstack/react-virtual";
import { useCallback, useEffect, useRef, useState } from "react";
import { call } from "../rpc/client";
import { useStore } from "../state/store";
import type { DataSlice, VariableMeta } from "../types";
import { MeasureIcon } from "../app/MeasureIcon";
import { VariableView } from "./VariableView";
import { PaneHeader } from "../app/Pane";
import { Table2 } from "lucide-react";

const PAGE = 200;
const ROW_H = 26;
const COL_W = 110;
type Page = DataSlice["columns"];


function display(v: unknown, meta: VariableMeta): string {
  if (v === null || v === undefined) return "";
  const vl = meta.value_labels?.find((l) => l.value === v);
  if (vl) return vl.label;
  return typeof v === "number" && !Number.isInteger(v) ? String(Math.round(v * 1e6) / 1e6) : String(v);
}

export function DataPanel() {
  const [tab, setTab] = useState<"data" | "vars">("data");
  const data = useStore((s) => s.data);
  return (
    <section className="flex h-full min-w-0 flex-col">
      <PaneHeader id="data" Icon={Table2}>
        <div className="seg" role="tablist" aria-label="Data view">
          {(["data", "vars"] as const).map((t) => (
            <button key={t} role="tab" aria-selected={tab === t} onClick={() => setTab(t)}>
              {t === "data" ? "Grid" : "Variables"}
            </button>
          ))}
        </div>
        {data && <span className="ml-auto truncate text-xs text-muted" title={`${data.nrow} rows, ${data.ncol} variables`}>{data.source} · {data.nrow} × {data.ncol}</span>}
      </PaneHeader>
      {!data ? (
        <p className="p-4 text-sm text-muted">Open a data file or pick an example from the Data menu.</p>
      ) : tab === "data" ? <DataGrid /> : <VariableView />}
    </section>
  );
}

function DataGrid() {
  const { data, dataVersion, editCell } = useStore();
  const pages = useRef(new Map<number, Page>());
  const loading = useRef(new Set<number>());
  const [, force] = useState(0);
  const [editing, setEditing] = useState<{ row: number; col: string; value: string } | null>(null);
  const parent = useRef<HTMLDivElement>(null);
  const vars = data?.variables ?? [];

  useEffect(() => { pages.current.clear(); force((n) => n + 1); }, [dataVersion]);

  const rows = useVirtualizer({ count: data?.nrow ?? 0, getScrollElement: () => parent.current, estimateSize: () => ROW_H, overscan: 20 });

  const ensurePage = useCallback((p: number) => {
    if (pages.current.has(p) || loading.current.has(p)) return;
    loading.current.add(p);
    void call<DataSlice>("data.slice", { offset: p * PAGE, limit: PAGE })
      .then((s) => { pages.current.set(p, s.columns); force((n) => n + 1); })
      .finally(() => loading.current.delete(p));
  }, []);

  const cell = (row: number, col: string) => pages.current.get(Math.floor(row / PAGE))?.[col]?.[row % PAGE];

  const commit = async () => {
    if (!editing) return;
    const before = cell(editing.row, editing.col);
    setEditing(null);
    if (String(before ?? "") !== editing.value) await editCell(editing.row, editing.col, editing.value, before ?? null);
  };

  const items = rows.getVirtualItems();
  items.forEach((it) => ensurePage(Math.floor(it.index / PAGE)));
  const width = 56 + vars.length * COL_W;

  return (
    <div ref={parent} className="relative flex-1 overflow-auto text-sm" data-testid="data-grid">
      <div style={{ width }} className="sticky top-0 z-10 flex border-b border-line bg-surface2 text-[12px]">
        <div className="sticky left-0 z-10 w-14 shrink-0 bg-surface2" />
        {vars.map((v) => (
          <div key={v.name} style={{ width: COL_W }} title={v.label || v.name}
            className="flex shrink-0 items-center gap-1.5 truncate border-r border-line px-2 py-1.5 font-semibold">
            <MeasureIcon measure={v.measure} /><span className="truncate">{v.name}</span>
          </div>
        ))}
      </div>
      <div style={{ height: rows.getTotalSize(), width, position: "relative" }}>
        {items.map((it) => (
          <div key={it.key} className={`group absolute left-0 flex hover:bg-brand/5 ${it.index % 2 ? "bg-surface2/50" : ""}`} style={{ top: it.start, height: ROW_H }}>
            <div className="sticky left-0 w-14 shrink-0 border-r border-line bg-surface2 px-2 text-right font-mono text-[11px] leading-[26px] text-muted group-hover:text-ink">{it.index + 1}</div>
            {vars.map((v) => {
              const isEdit = editing?.row === it.index && editing.col === v.name;
              const val = cell(it.index, v.name);
              return (
                <div key={v.name} style={{ width: COL_W }}
                  className={`shrink-0 truncate border-r border-line/60 px-2 text-[12.5px] leading-[26px] ${v.measure === "continuous" ? "text-right tabular-nums" : ""}`}
                  onDoubleClick={() => setEditing({ row: it.index, col: v.name, value: val === null || val === undefined ? "" : String(val) })}>
                  {isEdit ? (
                    <input autoFocus className="w-full rounded bg-brand/10 outline-none ring-2 ring-brand/40" value={editing.value}
                      onChange={(e) => setEditing({ ...editing, value: e.target.value })}
                      onBlur={() => void commit()}
                      onKeyDown={(e) => { if (e.key === "Enter") void commit(); if (e.key === "Escape") setEditing(null); }} />
                  ) : display(val, v)}
                </div>
              );
            })}
          </div>
        ))}
      </div>
    </div>
  );
}
