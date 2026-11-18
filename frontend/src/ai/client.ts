import { RpcError, isTauri } from "../rpc/client";
import type { RpcErrorShape } from "../types";
import { type ChatMsg, type ProviderId, buildRequest, errorText, parseReply } from "./providers";

async function invoke<T>(cmd: string, args: Record<string, unknown>): Promise<T> {
  if (isTauri) {
    const { invoke } = await import("@tauri-apps/api/core");
    try { return await invoke<T>(cmd, args); }
    catch (e) { throw new RpcError(typeof e === "object" && e && "code" in e ? (e as RpcErrorShape) : { code: -32001, message: String(e) }); }
  }
  const res = await fetch("/bridge/ai", { method: "POST", body: JSON.stringify({ cmd, args }) });
  const body = await res.json();
  if (body.error) throw new RpcError(body.error);
  return body.result as T;
}

export const keyStatus = (provider: ProviderId) => invoke<boolean>("ai_key_status", { provider });
export const keySet = (provider: ProviderId, key: string) => invoke<null>("ai_key_set", { provider, key });
export const keyDelete = (provider: ProviderId) => invoke<null>("ai_key_delete", { provider });

export async function chat(provider: ProviderId, baseUrl: string, model: string, system: string, messages: ChatMsg[]): Promise<string> {
  const { url, body } = buildRequest(provider, baseUrl, model, system, messages);
  try {
    return parseReply(provider, await invoke<Record<string, unknown>>("ai_post", { provider, url, body }));
  } catch (e) {
    if (e instanceof RpcError) {
      const detail = errorText(e.data);
      throw new Error(detail ? `${e.message}: ${detail}` : e.message);
    }
    throw e;
  }
}
