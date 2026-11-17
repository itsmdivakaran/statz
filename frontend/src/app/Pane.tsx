import { type LucideIcon, Maximize2, Minimize2, Minus } from "lucide-react";
import type { ReactNode } from "react";
import { type PaneId, useStore } from "../state/store";

export const PANE_TITLE: Record<PaneId, string> = { data: "Data", analysis: "Analysis", results: "Output" };

/** Uniform pane title bar: icon, title, pane-specific tools, then minimize / maximize. */
export function PaneHeader({ id, Icon, title, children, compact }: { id: PaneId; Icon: LucideIcon; title?: ReactNode; children?: ReactNode; compact?: boolean }) {
  const { paneMax, togglePaneMax, togglePaneMin } = useStore();
  const name = PANE_TITLE[id];
  const max = paneMax === id;
  return (
    <div className="pane-header">
      <h2 className="pane-title min-w-0"><Icon size={14} className="shrink-0 text-muted" aria-hidden="true" /><span className={compact ? "sr-only 2xl:not-sr-only 2xl:truncate" : "truncate"}>{title ?? name}</span></h2>
      <div className="flex min-w-0 flex-1 items-center gap-2">{children}</div>
      <div className="-mr-1 flex shrink-0 items-center">
        {!max && (
          <button className="pane-btn" onClick={() => togglePaneMin(id)} aria-label={`Minimize ${name} pane`} title="Minimize">
            <Minus size={14} aria-hidden="true" />
          </button>
        )}
        <button className="pane-btn" onClick={() => togglePaneMax(id)} aria-label={`${max ? "Restore" : "Maximize"} ${name} pane`} title={max ? "Restore" : "Maximize"}>
          {max ? <Minimize2 size={13} aria-hidden="true" /> : <Maximize2 size={12} aria-hidden="true" />}
        </button>
      </div>
    </div>
  );
}
