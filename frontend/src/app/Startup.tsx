import { useStore } from "../state/store";

interface RStatusData {
  too_old?: { rscript: string; version: string }[];
  install_hint?: { url: string; command: string | null; text: string };
}

export function Startup() {
  const { status, setup, statusDetail, rStatus, init } = useStore();
  const st = (rStatus ?? {}) as RStatusData;
  return (
    <div className="flex h-full items-center justify-center p-8">
      <div className="w-full max-w-lg space-y-4 rounded-xl border border-slate-200 p-6 shadow-sm dark:border-slate-800">
        <h1 className="text-xl font-semibold">StatNext</h1>
        {status === "starting" && <p className="text-sm text-slate-500">Starting R…</p>}
        {status === "setup" && setup && (
          <div className="space-y-2" role="status">
            <p className="text-sm">Setting up R packages (first run only). This can take a few minutes.</p>
            <div className="h-2 overflow-hidden rounded bg-slate-200 dark:bg-slate-800">
              <div className="h-full bg-blue-600 transition-all" style={{ width: `${setup.pct}%` }} />
            </div>
            <p className="text-xs text-slate-500">{setup.message}</p>
          </div>
        )}
        {status === "no-r" && (
          <div className="space-y-3 text-sm">
            <p className="font-medium">R 4.4 or later is required.</p>
            {st.too_old?.length ? (
              <p className="text-slate-500">Found R {st.too_old.map((r) => r.version).join(", ")}, which is too old.</p>
            ) : null}
            <p>{st.install_hint?.text}</p>
            {st.install_hint?.command && (
              <pre className="rounded bg-slate-100 p-2 font-mono text-xs dark:bg-slate-900">{st.install_hint.command}</pre>
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
            <p className="font-medium text-red-600">R could not start.</p>
            <pre className="max-h-60 overflow-auto whitespace-pre-wrap rounded bg-slate-100 p-2 font-mono text-xs dark:bg-slate-900">{statusDetail}</pre>
            <button className="btn" onClick={() => void init()}>Retry</button>
          </div>
        )}
      </div>
    </div>
  );
}
