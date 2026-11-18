import { Check, ExternalLink, KeyRound, Settings2, ShieldCheck, Sparkles, Trash2, X } from "lucide-react";
import { useEffect, useState } from "react";
import { isTauri } from "../rpc/client";
import { keyDelete, keySet } from "./client";
import { PROVIDERS, provider } from "./providers";
import { modelOf, urlOf, useAi } from "./store";

const openLink = async (url: string) => {
  if (!isTauri) return void window.open(url, "_blank", "noopener");
  const { invoke } = await import("@tauri-apps/api/core");
  await invoke("open_cran", { url }).catch(() => undefined);
};

const LABEL = "mb-1 block text-xs font-medium text-muted";

/** Settings: plain-language summaries and the optional AI assistant. */
export function AiSettings() {
  const s = useAi();
  const [key, setKey] = useState("");
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  useEffect(() => { setKey(""); setMsg(null); }, [s.provider, s.settingsOpen]);
  useEffect(() => {
    if (!s.settingsOpen) return;
    const esc = (e: KeyboardEvent) => e.key === "Escape" && s.setSettingsOpen(false);
    document.addEventListener("keydown", esc);
    return () => document.removeEventListener("keydown", esc);
  }, [s]);
  if (!s.settingsOpen) return null;
  const p = provider(s.provider);
  const close = () => s.setSettingsOpen(false);
  const saveKey = async () => {
    try { await keySet(s.provider, key); setKey(""); setMsg({ ok: true, text: "Key saved to your system keychain." }); await s.refreshKey(); }
    catch (e) { setMsg({ ok: false, text: e instanceof Error ? e.message : String(e) }); }
  };
  const removeKey = async () => { await keyDelete(s.provider).catch(() => undefined); setMsg(null); await s.refreshKey(); };

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/30 pt-[6vh] backdrop-blur-[2px]" onMouseDown={close}>
      <div role="dialog" aria-label="Settings" className="flex max-h-[88vh] w-[40rem] max-w-[96vw] animate-pop flex-col overflow-hidden rounded-xl border border-line bg-surface shadow-pop" onMouseDown={(e) => e.stopPropagation()}>
        <header className="flex items-center gap-2.5 border-b border-line px-4 py-3">
          <span className="flex h-7 w-7 items-center justify-center rounded-md bg-brand/10 text-brand"><Settings2 size={15} aria-hidden="true" /></span>
          <div><h2 className="text-[15px] font-semibold tracking-tight">Settings</h2><p className="text-xs text-muted">Result interpretation and the AI assistant</p></div>
          <button className="btn-ghost ml-auto px-1.5" aria-label="Close" onClick={close}><X size={15} aria-hidden="true" /></button>
        </header>
        <div className="space-y-5 overflow-auto p-4">
          <section>
            <h3 className="panel-title mb-2">Interpretation</h3>
            <label className="flex items-start gap-2.5 text-sm">
              <input type="checkbox" className="mt-0.5" checked={s.summaries} onChange={(e) => s.setPrefs({ summaries: e.target.checked })} />
              <span><span className="font-medium">Plain-language summaries</span>
                <span className="block text-xs text-muted">Adds an easystats <code>report()</code> summary to each test and model. Works offline; the code is included in R Code and exports. Applies to analyses you run next.</span></span>
            </label>
          </section>
          <section className="space-y-3">
            <h3 className="panel-title">AI assistant</h3>
            <label className="flex items-start gap-2.5 text-sm">
              <input type="checkbox" className="mt-0.5" checked={s.aiEnabled} onChange={(e) => s.setPrefs({ aiEnabled: e.target.checked })} />
              <span><span className="font-medium">Turn on the AI assistant</span>
                <span className="block text-xs text-muted">Adds an Ask AI chat and an Explain button on each result. Off by default.</span></span>
            </label>
            <fieldset disabled={!s.aiEnabled} className="space-y-3 disabled:opacity-50">
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <label><span className={LABEL}>Provider</span>
                  <select className="field w-full" value={s.provider} onChange={(e) => s.setPrefs({ provider: e.target.value as typeof s.provider })}>
                    {PROVIDERS.map((x) => <option key={x.id} value={x.id}>{x.label}</option>)}
                  </select></label>
                <label><span className={LABEL}>Model</span>
                  <input className="field w-full" list="ai-models" value={modelOf(s)} placeholder="Model name"
                    onChange={(e) => s.setPrefs({ models: { ...s.models, [s.provider]: e.target.value } })} />
                  <datalist id="ai-models">{p.models.map((m) => <option key={m} value={m} />)}</datalist></label>
              </div>
              <label className="block"><span className={LABEL}>Endpoint URL</span>
                <input className="field w-full font-mono text-xs" value={urlOf(s)} onChange={(e) => s.setPrefs({ urls: { ...s.urls, [s.provider]: e.target.value } })} /></label>
              <p className="text-xs text-muted">{p.note}</p>
              <div>
                <span className={LABEL}>API key{p.needsKey ? "" : " (optional)"}</span>
                <div className="flex items-center gap-2">
                  <input className="field flex-1 font-mono text-xs" type="password" autoComplete="off" value={key} onChange={(e) => setKey(e.target.value)}
                    placeholder={s.hasKey ? "A key is saved. Paste a new one to replace it." : "Paste your API key"} aria-label="API key" />
                  <button className="btn" disabled={!key.trim()} onClick={() => void saveKey()}><KeyRound size={13} aria-hidden="true" />Save key</button>
                  {s.hasKey && <button className="btn hover:text-bad" onClick={() => void removeKey()} aria-label="Remove key"><Trash2 size={13} aria-hidden="true" /></button>}
                </div>
                <p className="mt-1 flex items-center gap-1.5 text-xs">
                  {s.hasKey ? <span className="flex items-center gap-1 text-ok"><Check size={12} aria-hidden="true" />Key saved</span> : <span className="text-muted">No key saved</span>}
                  {p.keyUrl && <button className="ml-auto flex items-center gap-1 text-accent hover:underline" onClick={() => void openLink(p.keyUrl!)}>Get a key<ExternalLink size={11} aria-hidden="true" /></button>}
                </p>
                {msg && <p className={`mt-1 text-xs ${msg.ok ? "text-ok" : "text-bad"}`}>{msg.text}</p>}
              </div>
            </fieldset>
            <div className="flex gap-2.5 rounded-lg border border-line bg-surface2 p-3 text-xs text-muted">
              <ShieldCheck size={16} className="mt-px shrink-0 text-brand" aria-hidden="true" />
              <p>Keys are stored in your system keychain, never in project files. The assistant is sent only result tables, summaries and your questions, never your data rows, and you see each attachment before sending. The provider's own terms and charges apply.</p>
            </div>
          </section>
        </div>
        <footer className="flex justify-end border-t border-line px-4 py-2.5">
          <button className="btn-primary" onClick={close}><Sparkles size={14} aria-hidden="true" />Done</button>
        </footer>
      </div>
    </div>
  );
}
