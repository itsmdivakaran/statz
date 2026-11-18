import { create } from "zustand";
import { chat, keyStatus } from "./client";
import { type ChatMsg, type ProviderId, provider } from "./providers";
import { SYSTEM_PROMPT } from "./context";

export interface Attachment { title: string; text: string }
export interface UiMsg extends ChatMsg { attachment?: Attachment; error?: boolean }

interface Prefs {
  /** easystats report() summaries under each result. */
  summaries: boolean;
  aiEnabled: boolean;
  provider: ProviderId;
  models: Partial<Record<ProviderId, string>>;
  urls: Partial<Record<ProviderId, string>>;
}

interface AiState extends Prefs {
  settingsOpen: boolean;
  chatOpen: boolean;
  hasKey: boolean | null;
  messages: UiMsg[];
  draft: string;
  pending: Attachment | null;
  busy: boolean;
  setPrefs(p: Partial<Prefs>): void;
  setSettingsOpen(open: boolean): void;
  setChatOpen(open: boolean): void;
  refreshKey(): Promise<void>;
  setDraft(t: string): void;
  attach(a: Attachment | null, question?: string): void;
  send(): Promise<void>;
  clear(): void;
}

const KEY = "statnext.ai";
const DEFAULTS: Prefs = { summaries: true, aiEnabled: false, provider: "anthropic", models: {}, urls: {} };

function load(): Prefs {
  try { return { ...DEFAULTS, ...JSON.parse(localStorage.getItem(KEY) ?? "{}") }; } catch { return DEFAULTS; }
}

export const modelOf = (s: Prefs) => s.models[s.provider] || provider(s.provider).model;
export const urlOf = (s: Prefs) => s.urls[s.provider] || provider(s.provider).url;

/** Turns sent to the model: the attachment is folded into the user message it came with. */
const wire = (m: UiMsg): ChatMsg => ({ role: m.role, content: m.attachment ? `${m.content}\n\n---\n${m.attachment.text}` : m.content });

export const useAi = create<AiState>((set, get) => ({
  ...load(),
  settingsOpen: false,
  chatOpen: false,
  hasKey: null,
  messages: [],
  draft: "",
  pending: null,
  busy: false,
  setPrefs(p) {
    set(p);
    const { summaries, aiEnabled, provider: pr, models, urls } = get();
    try { localStorage.setItem(KEY, JSON.stringify({ summaries, aiEnabled, provider: pr, models, urls })); } catch { /* ignore */ }
    if (p.provider) void get().refreshKey();
  },
  setSettingsOpen: (settingsOpen) => { set({ settingsOpen }); if (settingsOpen) void get().refreshKey(); },
  setChatOpen: (chatOpen) => { set({ chatOpen }); if (chatOpen) void get().refreshKey(); },
  async refreshKey() {
    const p = get().provider;
    try { const k = await keyStatus(p); if (get().provider === p) set({ hasKey: k }); } catch { set({ hasKey: false }); }
  },
  setDraft: (draft) => set({ draft }),
  attach(pending, question) {
    set({ pending, chatOpen: true, ...(question !== undefined ? { draft: question } : {}) });
    void get().refreshKey();
  },
  async send() {
    const s = get();
    const content = s.draft.trim();
    if (s.busy || (!content && !s.pending)) return;
    const msg: UiMsg = { role: "user", content: content || "Explain these results.", ...(s.pending ? { attachment: s.pending } : {}) };
    const history = [...s.messages.filter((m) => !m.error), msg];
    set({ messages: [...s.messages, msg], draft: "", pending: null, busy: true });
    try {
      const reply = await chat(s.provider, urlOf(s), modelOf(s), SYSTEM_PROMPT, history.map(wire));
      set((x) => ({ messages: [...x.messages, { role: "assistant", content: reply }] }));
    } catch (e) {
      set((x) => ({ messages: [...x.messages, { role: "assistant", content: e instanceof Error ? e.message : String(e), error: true }] }));
    } finally {
      set({ busy: false });
    }
  },
  clear: () => set({ messages: [], pending: null, draft: "" }),
}));
