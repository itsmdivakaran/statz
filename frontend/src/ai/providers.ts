// AI providers: request shape and reply parsing. The key header is added by the
// desktop shell (src-tauri/src/ai.rs), never here.

export type ProviderId = "anthropic" | "openai" | "gemini" | "compatible" | "ollama";
export interface ChatMsg { role: "user" | "assistant"; content: string }

export interface ProviderInfo {
  id: ProviderId;
  label: string;
  url: string;
  model: string;
  models: string[];
  needsKey: boolean;
  keyUrl?: string;
  note: string;
}

export const PROVIDERS: ProviderInfo[] = [
  { id: "anthropic", label: "Anthropic Claude", url: "https://api.anthropic.com/v1", model: "claude-opus-5-5",
    models: ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"], needsKey: true,
    keyUrl: "https://console.anthropic.com/settings/keys", note: "Uses your Anthropic API key." },
  { id: "openai", label: "OpenAI", url: "https://api.openai.com/v1", model: "gpt-4.1-mini", models: [], needsKey: true,
    keyUrl: "https://platform.openai.com/api-keys", note: "Uses your OpenAI API key." },
  { id: "gemini", label: "Google Gemini", url: "https://generativelanguage.googleapis.com/v1beta", model: "gemini-2.5-flash", models: [],
    needsKey: true, keyUrl: "https://aistudio.google.com/apikey", note: "Uses your Google AI Studio key." },
  { id: "compatible", label: "OpenAI-compatible server", url: "https://", model: "", models: [], needsKey: false,
    note: "Any service with an OpenAI-style /chat/completions endpoint (Azure, OpenRouter, Groq, LM Studio…). Key optional." },
  { id: "ollama", label: "Ollama (on this computer)", url: "http://localhost:11434/v1", model: "llama3.1", models: [], needsKey: false,
    note: "Runs a local model. Nothing leaves your computer." },
];

export const provider = (id: ProviderId) => PROVIDERS.find((p) => p.id === id) ?? PROVIDERS[0];

/** Claude models that accept server-side refusal fallbacks. */
const FALLBACK_MODELS = /^claude-(fable-5|opus-5|sonnet-5-5)/;

export function buildRequest(id: ProviderId, baseUrl: string, model: string, system: string, messages: ChatMsg[]): { url: string; body: unknown } {
  const base = baseUrl.replace(/\/+$/, "");
  if (id === "anthropic") {
    const body: Record<string, unknown> = { model, max_tokens: 16000, system, messages };
    if (FALLBACK_MODELS.test(model)) body.fallbacks = "default";
    return { url: `${base}/messages`, body };
  }
  if (id === "gemini") {
    return {
      url: `${base}/models/${encodeURIComponent(model)}:generateContent`,
      body: {
        systemInstruction: { parts: [{ text: system }] },
        contents: messages.map((m) => ({ role: m.role === "assistant" ? "model" : "user", parts: [{ text: m.content }] })),
      },
    };
  }
  return { url: `${base}/chat/completions`, body: { model, messages: [{ role: "system", content: system }, ...messages] } };
}

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any

export function parseReply(id: ProviderId, r: Json): string {
  let text = "";
  if (id === "anthropic") {
    if (r.stop_reason === "refusal") throw new Error("The model declined to answer this request.");
    text = (r.content ?? []).filter((b: Json) => b.type === "text").map((b: Json) => b.text).join("");
  } else if (id === "gemini") {
    text = (r.candidates?.[0]?.content?.parts ?? []).map((p: Json) => p.text ?? "").join("");
  } else {
    text = r.choices?.[0]?.message?.content ?? "";
  }
  if (!text.trim()) throw new Error("The AI service sent an empty reply.");
  return text.trim();
}

/** Best-effort message from a provider's error body. */
export function errorText(data: unknown): string | null {
  const b = (data as Json)?.body;
  if (!b) return null;
  if (typeof b === "string") return b.slice(0, 300);
  return b.error?.message ?? b.message ?? b.error ?? null;
}
