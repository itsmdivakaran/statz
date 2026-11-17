import { FlaskConical, type LucideIcon, SlidersHorizontal, Table2 } from "lucide-react";
import { Fragment, type ReactNode, useEffect, useRef, useState } from "react";
import { AnalysisDialog } from "../dialogs/AnalysisDialog";
import { DataPanel } from "../grid/DataGrid";
import { ResultsPanel } from "../results/ResultsPanel";
import { type PaneId, useStore } from "../state/store";
import { PANE_TITLE } from "./Pane";

const PANES: { id: PaneId; Icon: LucideIcon; body: ReactNode }[] = [
  { id: "data", Icon: Table2, body: <DataPanel /> },
  { id: "analysis", Icon: SlidersHorizontal, body: <AnalysisDialog /> },
  { id: "results", Icon: FlaskConical, body: <ResultsPanel /> },
];
const STRIP = 40;
const MIN_W = 260;
const KEY = "statnext.paneWidths.v1";

function loadWidths(): Record<"data" | "analysis", number> {
  try {
    const w = JSON.parse(localStorage.getItem(KEY) ?? "null");
    if (w && typeof w.data === "number" && typeof w.analysis === "number") return w;
  } catch { /* storage unavailable */ }
  return { data: 0.62, analysis: 0.58 };
}

/** The three working panes, side by side with draggable dividers. Each can be collapsed to a strip or fill the window. */
export function Workspace() {
  const { paneMax, paneMin, togglePaneMin } = useStore();
  const [w, setW] = useState(loadWidths);
  const box = useRef<HTMLElement>(null);
  useEffect(() => { try { localStorage.setItem(KEY, JSON.stringify(w)); } catch { /* ignore */ } }, [w]);

  const width = (id: PaneId) => (paneMin.includes(id) ? `${STRIP}px` : id === "results" ? "minmax(320px,1fr)" : `minmax(${MIN_W}px,${w[id]}fr)`);
  const visible = PANES.filter((p) => !paneMax || p.id === paneMax);
  const cols: string[] = [];
  visible.forEach((p, i) => { if (i > 0) cols.push("1px"); cols.push(paneMax ? "1fr" : width(p.id)); });
  // Dragging the divider between two panes trades width between them. Widths are stored as fractions of the Output pane (1fr).
  const drag = (left: PaneId, right: PaneId) => (e: React.PointerEvent) => {
    const el = box.current;
    if (!el) return;
    const px = (id: PaneId) => el.querySelector<HTMLElement>(`[data-pane="${id}"]`)?.offsetWidth ?? 0;
    const w0 = { data: px("data"), analysis: px("analysis"), results: px("results") };
    const start = e.clientX;
    const move = (ev: PointerEvent) => {
      const minR = right === "results" ? 320 : MIN_W;
      const d = Math.max(MIN_W - w0[left], Math.min(ev.clientX - start, w0[right] - minR));
      const nw = { ...w0, [left]: w0[left] + d, [right]: w0[right] - d };
      setW((cur) => ({
        data: paneMin.includes("data") ? cur.data : nw.data / nw.results,
        analysis: paneMin.includes("analysis") ? cur.analysis : nw.analysis / nw.results,
      }));
    };
    const up = () => { window.removeEventListener("pointermove", move); window.removeEventListener("pointerup", up); document.body.style.cursor = ""; };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
    document.body.style.cursor = "col-resize";
    e.preventDefault();
  };

  return (
    <main ref={box} className="grid min-h-0 flex-1 bg-surface" style={{ gridTemplateColumns: cols.join(" ") }}>
      {PANES.map(({ id, Icon, body }, i) => {
        const title = PANE_TITLE[id];
        const min = paneMin.includes(id) && !paneMax;
        const max = paneMax === id;
        const hidden = paneMax !== null && !max;
        const prev = PANES[i - 1]?.id;
        const resizable = !!prev && !paneMin.includes(prev) && !min && !paneMax;
        return (
          <Fragment key={id}>
            {i > 0 && !hidden && !paneMax && (
              resizable
                ? <div role="separator" aria-orientation="vertical" aria-label={`Resize ${PANE_TITLE[prev!]} pane`} onPointerDown={drag(prev!, id)}
                    className="relative z-10 cursor-col-resize bg-line after:absolute after:inset-y-0 after:-left-1 after:-right-1 after:content-[''] hover:bg-brand/60" />
                : <div className="bg-line" aria-hidden="true" />
            )}
            <section aria-label={`${title} pane`} data-pane={id} data-state={max ? "max" : min ? "min" : "normal"}
              className={`relative min-h-0 min-w-0 overflow-hidden ${min ? "bg-canvas" : "bg-surface"} ${hidden ? "hidden" : ""}`}>
              {min && (
                <button onClick={() => togglePaneMin(id)} aria-label={`Show ${title} pane`} title={`Show ${title}`}
                  className="flex h-full w-full flex-col items-center gap-2 py-3 text-muted transition-colors hover:bg-brand/5 hover:text-brand">
                  <Icon size={15} aria-hidden="true" />
                  <span className="text-xs font-semibold tracking-wide [writing-mode:vertical-rl]">{title}</span>
                </button>
              )}
              {/* Kept mounted while collapsed so scroll position, tabs and edits survive. */}
              <div className={min ? "hidden" : "h-full"}>{body}</div>
            </section>
          </Fragment>
        );
      })}
    </main>
  );
}
