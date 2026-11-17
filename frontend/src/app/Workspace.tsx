import { FlaskConical, type LucideIcon, Maximize2, Minimize2, Minus, SlidersHorizontal, Table2 } from "lucide-react";
import type { ReactNode } from "react";
import { AnalysisDialog } from "../dialogs/AnalysisDialog";
import { DataPanel } from "../grid/DataGrid";
import { ResultsPanel } from "../results/ResultsPanel";
import { type PaneId, useStore } from "../state/store";

const PANES: { id: PaneId; title: string; Icon: LucideIcon; width: string; body: ReactNode }[] = [
  { id: "data", title: "Data", Icon: Table2, width: "minmax(300px,1fr)", body: <DataPanel /> },
  { id: "analysis", title: "Analysis", Icon: SlidersHorizontal, width: "minmax(320px,0.9fr)", body: <AnalysisDialog /> },
  { id: "results", title: "Output", Icon: FlaskConical, width: "minmax(380px,1.3fr)", body: <ResultsPanel /> },
];
const STRIP = "44px";

/** The three working panes. Each can be collapsed to a strip or enlarged to fill the window. */
export function Workspace() {
  const { paneMax, paneMin, togglePaneMax, togglePaneMin } = useStore();
  const columns = paneMax ? "1fr" : PANES.map((p) => (paneMin.includes(p.id) ? STRIP : p.width)).join(" ");
  return (
    <main className="grid min-h-0 flex-1 gap-2.5 p-2.5" style={{ gridTemplateColumns: columns }}>
      {PANES.map(({ id, title, Icon, body }) => {
        const min = paneMin.includes(id) && !paneMax;
        const max = paneMax === id;
        const hidden = paneMax !== null && !max;
        return (
          <section key={id} aria-label={`${title} pane`} data-pane={id} data-state={max ? "max" : min ? "min" : "normal"}
            className={`card relative min-h-0 min-w-0 overflow-hidden ${hidden ? "hidden" : ""}`}>
            {min && (
              <button onClick={() => togglePaneMin(id)} aria-label={`Show ${title} pane`} title={`Show ${title}`}
                className="flex h-full w-full flex-col items-center gap-2 py-3 text-muted transition-colors hover:bg-brand/5 hover:text-brand">
                <Icon size={16} aria-hidden="true" />
                <span className="text-xs font-semibold tracking-wide [writing-mode:vertical-rl]">{title}</span>
              </button>
            )}
            {/* Kept mounted while collapsed so scroll position, tabs and edits survive. */}
            <div className={min ? "hidden" : "h-full"}>{body}</div>
            {!min && (
              <div className="absolute right-1.5 top-[7px] z-20 flex items-center rounded-lg bg-surface/90 backdrop-blur">
                {!max && (
                  <button className="pane-btn" onClick={() => togglePaneMin(id)} aria-label={`Minimize ${title} pane`} title="Minimize">
                    <Minus size={14} aria-hidden="true" />
                  </button>
                )}
                <button className="pane-btn" onClick={() => togglePaneMax(id)} aria-label={`${max ? "Restore" : "Maximize"} ${title} pane`} title={max ? "Restore" : "Maximize"}>
                  {max ? <Minimize2 size={14} aria-hidden="true" /> : <Maximize2 size={13} aria-hidden="true" />}
                </button>
              </div>
            )}
          </section>
        );
      })}
    </main>
  );
}
