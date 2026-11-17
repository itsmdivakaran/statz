import { useStore } from "../state/store";
import { Logo } from "./Logo";

interface RStatusData {
  too_old?: { rscript: string; version: string }[];
  install_hint?: { url: string; command: string | null; text: string };
}

export function Startup() {
  const { status, setup, statusDetail, rStatus, init } = useStore();
  const st = (rStatus ?? {}) as RStatusData;
  return (
    <div className="flex h-full items-center justify-center bg-[radial-gradient(50rem_26rem_at_50%_0%,rgb(var(--brand)/0.14),transparent)] p-8">
      <div className="card w-full max-w-lg space-y-4 p-7 shadow-pop">
        <h1 className="flex items-center gap-3 text-xl font-bold tracking-tight"><Logo size={36} />Stat<span className="-ml-3 text-brand">Next</span></h1>
        {status === "starting" && <p className="flex items-center gap-2 text-sm text-muted"><span className="h-3.5 w-3.5 animate-spin rounded-full border-2 border-brand border-t-transparent" />Starting R…</p>}
        {status === "setup" && setup && (
          <div className="space-y-2" role="status">
            <p className="text-sm">Setting up R packages (first run only). This can take a few minutes.</p>
            <div className="h-2 overflow-hidden rounded-full bg-surface2">
              <div className="h-full rounded-full bg-gradient-to-r from-brand to-accent transition-all" style={{ width: `${setup.pct}%` }} />
            </div>
            <p className="text-xs text-muted">{setup.message}</p>
          </div>
        )}
        {status === "no-r" && (
          <div className="space-y-3 text-sm">
            <p className="font-medium">R 4.4 or later is required.</p>
            {st.too_old?.length ? (
              <p className="text-muted">Found R {st.too_old.map((r) => r.version).join(", ")}, which is too old.</p>
            ) : null}
            <p>{st.install_hint?.text}</p>
            {st.install_hint?.command && (
              <pre className="rounded bg-surface2 p-2 font-mono text-xs">{st.install_hint.command}</pre>
            )}
            <div className="flex gap-2">
              {st.install_hint?.url && (
                <a className="btn-primary" href={st.install_hint.url} target="_blank" rel="noreferrer">Download R</a>
              )}
              <button className="btn" onClick={() => void init()}>Check again</button>
            </div>
          </div>
        )}
        {status === "error" && (
          <div className="space-y-3 text-sm">
            <p className="font-medium text-bad">R could not start.</p>
            <pre className="max-h-60 overflow-auto whitespace-pre-wrap rounded bg-surface2 p-2 font-mono text-xs">{statusDetail}</pre>
            <button className="btn" onClick={() => void init()}>Retry</button>
          </div>
        )}
      </div>
    </div>
  );
}
