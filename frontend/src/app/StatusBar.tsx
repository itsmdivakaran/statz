import { AlertTriangle, CircleCheck, Loader2 } from "lucide-react";
import { useStore } from "../state/store";

/** Bottom bar: engine state, dataset and analysis counts. */
export function StatusBar() {
  const { hello, data, analyses, specs } = useStore();
  const running = analyses.find((a) => a.running);
  const missing = hello?.missing_packages.length ?? 0;
  return (
    <footer className="flex h-6 shrink-0 items-center gap-4 border-t border-line bg-surface px-3 text-[11.5px] text-muted" aria-label="Status">
      {running ? (
        <span className="flex items-center gap-1.5 text-brand" role="status"><Loader2 size={11} className="animate-spin" aria-hidden="true" />Running {specs[running.module]?.title ?? running.module}…</span>
      ) : (
        <span className="flex items-center gap-1.5"><CircleCheck size={11} className="text-ok" aria-hidden="true" />Ready</span>
      )}
      {data && <span className="truncate">{data.source}: {data.nrow.toLocaleString()} rows, {data.ncol} variables</span>}
      {data && <span>{analyses.length} {analyses.length === 1 ? "analysis" : "analyses"}</span>}
      <span className="ml-auto flex items-center gap-4">
        {missing > 0 && <span className="flex items-center gap-1 text-warn"><AlertTriangle size={11} aria-hidden="true" />{missing} R packages missing</span>}
        {hello && <span title={hello.rscript}>R {hello.r_version}</span>}
        {hello && <span>Plots: {hello.plot_engine}</span>}
        {hello && <span>statnextr {hello.statnextr}</span>}
      </span>
    </footer>
  );
}
