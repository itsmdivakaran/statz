import { Check, Copy, Download, RefreshCw } from "lucide-react";
import { useEffect, useState } from "react";
import { isTauri, tauriCommand } from "../rpc/client";
import { useStore } from "../state/store";
import { Logo } from "./Logo";

interface RStatusData {
  too_old?: { rscript: string; version: string }[];
  install_hint?: { url: string; command: string | null; text: string; download_label?: string; steps?: string[] };
}

type StepState = "done" | "active" | "todo";
function Step({ n, state, title, children }: { n: number; state: StepState; title: string; children?: React.ReactNode }) {
  return (
    <li className="flex gap-3">
      <span className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold ${
        state === "done" ? "bg-ok text-white" : state === "active" ? "bg-brand text-white" : "bg-surface2 text-muted"}`}>
        {state === "done" ? <Check size={13} aria-hidden="true" /> : n}
      </span>
      <div className="min-w-0 flex-1 pb-1">
        <div className={`text-sm font-medium ${state === "todo" ? "text-muted" : ""}`}>{title}</div>
        {children}
      </div>
    </li>
  );
}

function useElapsed(active: boolean) {
  const [s, setS] = useState(0);
  useEffect(() => {
    if (!active) { setS(0); return; }
    const t = setInterval(() => setS((x) => x + 1), 1000);
    return () => clearInterval(t);
  }, [active]);
  return s >= 60 ? `${Math.floor(s / 60)} min ${s % 60} s` : `${s} s`;
}

const openLink = (url: string) => (isTauri ? void tauriCommand("open_cran", { url }) : void window.open(url, "_blank", "noopener"));

export function Startup() {
  const { status, setup, statusDetail, rStatus, init } = useStore();
  const st = (rStatus ?? {}) as RStatusData;
  const hint = st.install_hint;
  const elapsed = useElapsed(status === "setup");
  const [copied, setCopied] = useState(false);

  // While R is missing, look for it again every few seconds so the app continues by itself once it is installed.
  useEffect(() => {
    if (status !== "no-r") return;
    const t = setInterval(() => void init(), 6000);
    return () => clearInterval(t);
  }, [status, init]);

  const pkgStep: StepState = status === "setup" ? "active" : "todo";
  return (
    <div className="flex h-full items-center justify-center overflow-auto bg-[radial-gradient(50rem_26rem_at_50%_0%,rgb(var(--brand)/0.14),transparent)] p-8">
      <div className="card w-full max-w-xl space-y-5 p-7 shadow-pop">
        <h1 className="flex items-center gap-3 text-xl font-bold tracking-tight"><Logo size={36} />Stat<span className="-ml-3 text-brand">Next</span></h1>

        {(status === "starting" || status === "setup") && (
          <ol className="space-y-3" role="status" aria-label="Setup progress">
            <Step n={1} state={status === "starting" && !setup ? "active" : "done"} title="Find R on this computer" />
            <Step n={2} state={pkgStep} title="Install the statistics packages (first launch only)">
              {status === "setup" && setup && (
                <div className="mt-2 space-y-1.5">
                  <div className="h-2 overflow-hidden rounded-full bg-surface2">
                    <div className="h-full rounded-full bg-gradient-to-r from-brand via-accent to-pink transition-all" style={{ width: `${Math.max(3, setup.pct)}%` }} />
                  </div>
                  <div className="flex justify-between text-xs text-muted"><span>{setup.message}</span><span>{setup.pct}% · {elapsed}</span></div>
                  <p className="text-xs text-muted">This needs an internet connection and usually takes 3 to 10 minutes. Keep StatNext open; next time it starts at once.</p>
                </div>
              )}
            </Step>
            <Step n={3} state="todo" title="Start the statistics engine">
              {status === "starting" && <p className="mt-1 flex items-center gap-2 text-xs text-muted"><span className="h-3 w-3 animate-spin rounded-full border-2 border-brand border-t-transparent" />Starting R…</p>}
            </Step>
          </ol>
        )}

        {status === "no-r" && (
          <div className="space-y-4 text-sm">
            <div>
              <p className="text-base font-semibold">One more step: install R</p>
              <p className="mt-1 text-muted">{hint?.text ?? "StatNext uses R, the free statistics engine."} StatNext needs R 4.4 or later.</p>
              {st.too_old?.length ? (
                <p className="mt-1 text-warn">Found R {st.too_old.map((r) => r.version).join(", ")}, which is too old. Install the latest R; the old one can stay.</p>
              ) : null}
            </div>
            {hint?.steps && (
              <ol className="space-y-3">
                {hint.steps.map((s, i) => <Step key={s} n={i + 1} state="todo" title={s} />)}
              </ol>
            )}
            <div className="flex flex-wrap items-center gap-2">
              {hint?.url && (
                <button className="btn-primary" onClick={() => openLink(hint.url)}><Download size={15} aria-hidden="true" />{hint.download_label ?? "Download R"}</button>
              )}
              <button className="btn px-3 py-2" onClick={() => void init()}><RefreshCw size={14} aria-hidden="true" />Check again</button>
            </div>
            <p className="flex items-center gap-2 text-xs text-muted">
              <span className="h-2 w-2 animate-pulse rounded-full bg-brand" />Waiting for R… StatNext checks every few seconds.
            </p>
            {hint?.command && (
              <details className="text-xs text-muted">
                <summary className="cursor-pointer">Prefer a package manager?</summary>
                <pre className="mt-1.5 rounded bg-surface2 p-2 font-mono">{hint.command}</pre>
              </details>
            )}
          </div>
        )}

        {status === "error" && (
          <div className="space-y-3 text-sm">
            <p className="font-medium text-bad">R could not start.</p>
            <p className="text-xs text-muted">Check the internet connection (the first launch downloads R packages) and try again. If it keeps failing, copy the details and send them with your report.</p>
            <pre className="max-h-60 overflow-auto whitespace-pre-wrap rounded bg-surface2 p-2 font-mono text-xs">{statusDetail}</pre>
            <div className="flex gap-2">
              <button className="btn-primary" onClick={() => void init()}><RefreshCw size={14} aria-hidden="true" />Try again</button>
              <button className="btn px-3 py-2" onClick={() => { void navigator.clipboard?.writeText(statusDetail ?? ""); setCopied(true); }}>
                <Copy size={14} aria-hidden="true" />{copied ? "Copied" : "Copy details"}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
