// One client for both runtimes: Tauri (invoke) and the browser dev bridge (HTTP).
import type { RpcErrorShape } from "../types";

export const isTauri = typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;

export class RpcError extends Error {
  code: number;
  data?: RpcErrorShape["data"];
  constructor(e: RpcErrorShape) {
    super(e.message);
    this.code = e.code;
    this.data = e.data;
  }
  get cancelled() { return this.code === ERR.cancelled; }
}

export const ERR = { rError: -32001, missingPackage: -32002, invalidOptions: -32003, cancelled: -32004, workerDied: -32005, notStarted: -32006 } as const;

async function tauriInvoke<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  const { invoke } = await import("@tauri-apps/api/core");
  try {
    return await invoke<T>(cmd, args);
  } catch (e) {
    throw new RpcError(typeof e === "object" && e && "code" in e ? (e as RpcErrorShape) : { code: ERR.rError, message: String(e) });
  }
}

export async function call<T = unknown>(method: string, params: Record<string, unknown> = {}): Promise<T> {
  if (isTauri) return tauriInvoke<T>("rpc", { method, params });
  const res = await fetch("/bridge/rpc", { method: "POST", body: JSON.stringify({ method, params }) });
  const body = await res.json();
  if (body.error) throw new RpcError(body.error);
  return body.result as T;
}

export async function cancel(): Promise<void> {
  if (isTauri) await tauriInvoke("rpc_cancel");
  else await fetch("/bridge/cancel", { method: "POST" });
}

/** Start R: in Tauri this detects R, installs packages and spawns the worker. */
export async function startBackend<T>(): Promise<T> {
  if (isTauri) return tauriInvoke<T>("backend_start");
  return call<T>("system.hello");
}

/** URL the webview can load for a file the R worker wrote. */
export async function fileUrl(path: string): Promise<string> {
  if (isTauri) {
    const { convertFileSrc } = await import("@tauri-apps/api/core");
    return convertFileSrc(path);
  }
  return `/bridge/file?path=${encodeURIComponent(path)}`;
}

export async function onEvent<T>(name: string, cb: (payload: T) => void): Promise<() => void> {
  if (!isTauri) return () => {};
  const { listen } = await import("@tauri-apps/api/event");
  return listen<T>(name, (e) => cb(e.payload));
}

export async function tauriCommand<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  return tauriInvoke<T>(cmd, args);
}
