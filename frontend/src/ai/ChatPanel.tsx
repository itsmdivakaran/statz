import { ChevronDown, ChevronRight, Eraser, Loader2, Paperclip, SendHorizontal, Settings2, Sparkles, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Markdown } from "./Markdown";
import { provider } from "./providers";
import { type Attachment, modelOf, useAi } from "./store";

const STARTERS = [
  "Which analysis should I run to compare three groups?",
  "How do I report a t-test in APA style?",
  "What does a p-value of .03 actually mean?",
];

function AttachmentView({ a, onRemove }: { a: Attachment; onRemove?: () => void }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="rounded-lg border border-pink/30 bg-pink/5 text-xs">
      <div className="flex items-center gap-1.5 px-2 py-1.5">
        <button type="button" className="flex min-w-0 flex-1 items-center gap-1.5 text-left font-medium text-pink" onClick={() => setOpen(!open)} aria-expanded={open}>
          {open ? <ChevronDown size={12} aria-hidden="true" /> : <ChevronRight size={12} aria-hidden="true" />}
          <Paperclip size={12} aria-hidden="true" /><span className="truncate">{a.title}</span>
        </button>
        {onRemove && <button type="button" className="text-muted hover:text-ink" aria-label="Remove attachment" onClick={onRemove}><X size={12} aria-hidden="true" /></button>}
      </div>
      {open && <pre className="max-h-56 overflow-auto whitespace-pre-wrap border-t border-pink/20 px-2 py-1.5 font-mono text-[10.5px] text-muted">{a.text}</pre>}
    </div>
  );
}

/** Right-hand chat with the configured AI provider. */
export function ChatPanel() {
  const s = useAi();
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => { end.current?.scrollIntoView({ block: "end" }); }, [s.messages.length, s.busy]);
  if (!s.chatOpen) return null;
  const p = provider(s.provider);
  const ready = s.aiEnabled && (s.hasKey || !p.needsKey);
  return (
    <aside aria-label="AI assistant" className="flex h-full w-[24rem] max-w-[40vw] shrink-0 flex-col border-l border-line bg-surface">
      <div className="pane-header">
        <span className="pane-title"><Sparkles size={15} className="text-pink" aria-hidden="true" />AI assistant</span>
        <span className="truncate text-[11px] text-muted">{p.label} · {modelOf(s)}</span>
        <span className="ml-auto flex gap-0.5">
          <button className="pane-btn" title="New chat" aria-label="New chat" onClick={s.clear}><Eraser size={14} aria-hidden="true" /></button>
          <button className="pane-btn" title="AI settings" aria-label="AI settings" onClick={() => s.setSettingsOpen(true)}><Settings2 size={14} aria-hidden="true" /></button>
          <button className="pane-btn" title="Close" aria-label="Close AI assistant" onClick={() => s.setChatOpen(false)}><X size={14} aria-hidden="true" /></button>
        </span>
      </div>
      <div className="flex-1 space-y-3 overflow-auto p-3 text-[13px] leading-relaxed">
        {!ready && (
          <div className="space-y-2 rounded-lg border border-line bg-surface2 p-3 text-xs">
            <p className="font-medium text-ink">{s.aiEnabled ? `Add your ${p.label} API key to start.` : "The AI assistant is off."}</p>
            <p className="text-muted">Bring your own key from Anthropic, OpenAI or Google, or run a local model with Ollama.</p>
            <button className="btn-primary py-1" onClick={() => s.setSettingsOpen(true)}><Settings2 size={13} aria-hidden="true" />Open AI settings</button>
          </div>
        )}
        {ready && s.messages.length === 0 && !s.pending && (
          <div className="space-y-2">
            <p className="text-xs text-muted">Ask about statistics, or press <b>Explain</b> on a result to attach it.</p>
            {STARTERS.map((q) => (
              <button key={q} className="block w-full rounded-lg border border-line px-2.5 py-1.5 text-left text-xs transition-colors hover:border-brand/50 hover:bg-brand/5" onClick={() => s.setDraft(q)}>{q}</button>
            ))}
          </div>
        )}
        {s.messages.map((m, i) => m.role === "user" ? (
          <div key={i} className="ml-6 space-y-1.5">
            {m.attachment && <AttachmentView a={m.attachment} />}
            <div className="rounded-lg rounded-tr-sm bg-gradient-to-br from-brand to-accent px-3 py-2 text-white">{m.content}</div>
          </div>
        ) : (
          <div key={i} className={`mr-4 rounded-lg rounded-tl-sm border px-3 py-2 ${m.error ? "border-bad/30 bg-bad/5 text-bad" : "border-line bg-surface2"}`}>
            {m.error ? <p>{m.content}</p> : <Markdown text={m.content} />}
          </div>
        ))}
        {s.busy && <p className="flex items-center gap-1.5 text-xs text-muted" role="status"><Loader2 size={12} className="animate-spin" aria-hidden="true" />Thinking…</p>}
        <div ref={end} />
      </div>
      <form className="space-y-2 border-t border-line p-2.5" onSubmit={(e) => { e.preventDefault(); void s.send(); }}>
        {s.pending && <AttachmentView a={s.pending} onRemove={() => s.attach(null)} />}
        <div className="flex items-end gap-2">
          <textarea className="field max-h-40 min-h-[2.25rem] flex-1 resize-none py-1.5" rows={2} value={s.draft} disabled={!ready}
            placeholder={ready ? "Ask a question…" : "Set up the assistant first"} aria-label="Message"
            onChange={(e) => s.setDraft(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); void s.send(); } }} />
          <button type="submit" className="btn-primary h-9 px-2.5" disabled={!ready || s.busy || (!s.draft.trim() && !s.pending)} aria-label="Send"><SendHorizontal size={15} aria-hidden="true" /></button>
        </div>
        <p className="text-[10.5px] text-muted">Sent to {p.label}: your message and any attachment shown above. AI can be wrong, so check before use.</p>
      </form>
    </aside>
  );
}
