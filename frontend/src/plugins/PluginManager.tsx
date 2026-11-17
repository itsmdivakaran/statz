import { AlertTriangle, FolderOpen, FolderPlus, Package, Puzzle, RefreshCw, Trash2, X } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { call, isTauri } from "../rpc/client";
import { useStore } from "../state/store";

export interface PluginInfo {
  id: string; title: string; version: string; author: string; description: string;
  menu: string[]; dir: string; missing_packages: string[];
}
interface Check { ok: boolean; errors: string[]; id: string | null; title: string | null; builtin: boolean }

/** Ask for a folder or a .zip (native dialog in the app, a path prompt in the browser). */
async function pickPath(kind: "folder" | "zip" | "dest"): Promise<string | null> {
  if (!isTauri) return window.prompt(kind === "dest" ? "Folder to create the starter plugin in:" : `Path to the plugin ${kind}:`);
  const { open } = await import("@tauri-apps/plugin-dialog");
  const p = kind === "zip"
    ? await open({ multiple: false, filters: [{ name: "Plugin (.zip)", extensions: ["zip"] }] })
    : await open({ directory: true, multiple: false });
  return typeof p === "string" ? p : null;
}

export function PluginManager() {
  const { modal, setModal, reloadSpecs, newAnalysis, data } = useStore();
  const [plugins, setPlugins] = useState<PluginInfo[]>([]);
  const [pending, setPending] = useState<{ path: string; check: Check } | null>(null);
  const [confirmRemove, setConfirmRemove] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ kind: "ok" | "error"; text: string } | null>(null);
  const open = modal === "plugins";

  const refresh = useCallback(async () => setPlugins(await call<PluginInfo[]>("plugin.list")), []);
  useEffect(() => { if (open) { setPending(null); setMsg(null); void refresh().catch((e) => setMsg({ kind: "error", text: (e as Error).message })); } }, [open, refresh]);
  useEffect(() => {
    if (!open) return;
    const esc = (e: KeyboardEvent) => e.key === "Escape" && setModal(null);
    document.addEventListener("keydown", esc);
    return () => document.removeEventListener("keydown", esc);
  }, [open, setModal]);
  if (!open) return null;
  const close = () => setModal(null);

  const run = async (key: string, fn: () => Promise<void>) => {
    setBusy(key); setMsg(null);
    try { await fn(); } catch (e) { setMsg({ kind: "error", text: (e as Error).message }); } finally { setBusy(null); }
  };
  const choose = (kind: "folder" | "zip") => run("pick", async () => {
    const path = await pickPath(kind);
    if (!path) return;
    setPending({ path, check: await call<Check>("plugin.check", { path }) });
  });
  const install = (path: string) => run("install", async () => {
    const p = await call<PluginInfo & { updated: boolean }>("plugin.install", { path });
    setPending(null);
    await Promise.all([refresh(), reloadSpecs()]);
    setMsg({ kind: "ok", text: `${p.updated ? "Updated" : "Installed"} "${p.title}". Find it under ${p.menu.join(" › ")}.` });
  });
  const template = () => run("template", async () => {
    const dest = await pickPath("dest");
    if (!dest) return;
    const { path } = await call<{ path: string }>("plugin.template", { path: dest });
    setPending({ path, check: await call<Check>("plugin.check", { path }) });
    setMsg({ kind: "ok", text: `Starter plugin written to ${path}. Edit its files, or install it now to try it.` });
  });

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/30 pt-[8vh] backdrop-blur-[2px]" onMouseDown={close}>
      <div role="dialog" aria-label="Plugins" className="flex max-h-[84vh] w-[44rem] max-w-[96vw] animate-pop flex-col overflow-hidden rounded-2xl border border-line bg-surface shadow-pop" onMouseDown={(e) => e.stopPropagation()}>
        <header className="flex items-center gap-2.5 border-b border-line px-4 py-3">
          <span className="flex h-7 w-7 items-center justify-center rounded-md bg-brand/10 text-brand"><Puzzle size={15} aria-hidden="true" /></span>
          <div>
            <h2 className="text-[15px] font-semibold tracking-tight">Plugins</h2>
            <p className="text-xs text-muted">Add analyses written by you or others. A plugin is a folder with spec.json, an R file and help.md.</p>
          </div>
          <button className="btn-ghost ml-auto px-1.5" aria-label="Close" onClick={close}><X size={15} aria-hidden="true" /></button>
        </header>
        <div className="space-y-4 overflow-auto p-4 text-sm">
          <div className="flex flex-wrap gap-2">
            <button className="btn-primary" disabled={busy !== null} onClick={() => void choose("folder")}><FolderOpen size={15} aria-hidden="true" />Install from folder</button>
            <button className="btn px-3 py-2" disabled={busy !== null} onClick={() => void choose("zip")}><Package size={15} aria-hidden="true" />Install from .zip</button>
            <button className="btn px-3 py-2" disabled={busy !== null} onClick={() => void template()}><FolderPlus size={15} aria-hidden="true" />Create a starter plugin</button>
            <button className="btn-ghost ml-auto" disabled={busy !== null} onClick={() => void run("reload", async () => { await call("plugin.reload"); await Promise.all([refresh(), reloadSpecs()]); setMsg({ kind: "ok", text: "Plugins reloaded from disk." }); })}>
              <RefreshCw size={14} className={busy === "reload" ? "animate-spin" : ""} aria-hidden="true" />Reload
            </button>
          </div>

          {msg && <p role="status" className={`rounded-lg px-3 py-2 text-xs ${msg.kind === "ok" ? "bg-ok/10 text-ok" : "bg-bad/10 text-bad"}`}>{msg.text}</p>}

          {pending && (
            <div className="rounded-xl border border-warn/40 bg-warn/5 p-3">
              {pending.check.ok ? (
                <>
                  <p className="font-medium">Install "{pending.check.title}" ({pending.check.id})?</p>
                  <p className="mt-1 flex gap-1.5 text-xs text-muted"><AlertTriangle size={14} className="shrink-0 text-warn" aria-hidden="true" />
                    Plugins run R code on this computer with your permissions. Install only plugins from people you trust.</p>
                  <div className="mt-2.5 flex gap-2">
                    <button className="btn-primary" disabled={busy !== null} onClick={() => void install(pending.path)}>Install plugin</button>
                    <button className="btn" onClick={() => setPending(null)}>Cancel</button>
                  </div>
                </>
              ) : (
                <>
                  <p className="font-medium text-bad">This plugin cannot be installed</p>
                  <ul className="mt-1 list-disc pl-5 text-xs">{pending.check.errors.map((e) => <li key={e}>{e}</li>)}</ul>
                  <button className="btn mt-2" onClick={() => setPending(null)}>Close</button>
                </>
              )}
            </div>
          )}

          <section>
            <h3 className="panel-title mb-2">Installed ({plugins.length})</h3>
            {plugins.length === 0 ? (
              <p className="rounded-xl border border-dashed border-line px-4 py-6 text-center text-xs text-muted">
                No plugins yet. Create a starter plugin to see how one is built, or install one someone shared with you.
              </p>
            ) : (
              <ul className="divide-y divide-line rounded-xl border border-line">
                {plugins.map((p) => (
                  <li key={p.id} className="flex items-start gap-3 p-3">
                    <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-accent/10 text-accent"><Puzzle size={15} aria-hidden="true" /></span>
                    <div className="min-w-0 flex-1">
                      <div className="font-medium">{p.title} <span className="text-xs font-normal text-muted">v{p.version}{p.author && ` · ${p.author}`}</span></div>
                      {p.description && <div className="text-xs text-muted">{p.description}</div>}
                      <div className="mt-0.5 truncate font-mono text-[11px] text-muted" title={p.dir}>{p.menu.join(" › ")} · {p.dir}</div>
                      {p.missing_packages.length > 0 && (
                        <div className="mt-1.5 flex flex-wrap items-center gap-2 text-xs text-warn">
                          Needs R packages: {p.missing_packages.join(", ")}
                          <button className="btn py-0.5 text-xs" disabled={busy !== null} onClick={() => void run("pkgs", async () => {
                            await call("pkg.install", { packages: p.missing_packages }); await refresh(); setMsg({ kind: "ok", text: "Packages installed." });
                          })}>{busy === "pkgs" ? "Installing…" : "Install packages"}</button>
                        </div>
                      )}
                    </div>
                    <div className="flex shrink-0 gap-1.5">
                      <button className="btn py-1 text-xs" disabled={!data} title={data ? "" : "Open a data file first"} onClick={() => { close(); newAnalysis(p.id); }}>Open</button>
                      {confirmRemove === p.id ? (
                        <button className="btn border-bad/50 py-1 text-xs text-bad" onClick={() => void run("remove", async () => {
                          await call("plugin.remove", { id: p.id }); setConfirmRemove(null); await Promise.all([refresh(), reloadSpecs()]);
                          setMsg({ kind: "ok", text: `Removed "${p.title}".` });
                        })}>Confirm remove</button>
                      ) : (
                        <button className="btn-ghost px-1.5" aria-label={`Remove ${p.title}`} onClick={() => setConfirmRemove(p.id)}><Trash2 size={14} aria-hidden="true" /></button>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </section>
          <p className="text-xs text-muted">
            Plugins use the same format as StatNext's own analyses: the starter plugin includes a README describing spec.json, the R code generator and the help page.
          </p>
        </div>
      </div>
    </div>
  );
}
