// Development bridge: runs the R worker over stdio (same protocol as the Tauri shell)
// and exposes it over HTTP so the UI can run in a plain browser and in Playwright.
//   POST /rpc     {method, params}  -> {result} | {error}
//   POST /cancel                    -> SIGINT the worker
//   GET  /file?path=...             -> files the worker wrote into its session dir
import http from "node:http";
import { spawn } from "node:child_process";
import { createReadStream, existsSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import readline from "node:readline";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const workDir = mkdtempSync(path.join(tmpdir(), "statnext-dev-"));
const rscript = process.env.STATNEXT_RSCRIPT || "Rscript";
const port = Number(process.env.STATNEXT_BRIDGE_PORT || 5174);

const r = spawn(
  rscript,
  ["--vanilla", "-e", "statnextr::sn_main()", "--args",
   `--modules=${path.join(root, "analyses")}`, `--datasets=${path.join(root, "datasets")}`, `--workdir=${workDir}`,
   `--plugins=${process.env.STATNEXT_PLUGINS || path.join(workDir, "plugins")}`],
  { env: { ...process.env, LC_ALL: process.platform === "darwin" ? "en_US.UTF-8" : "C.UTF-8" } },
);
const pending = new Map();
let nextId = 1;
readline.createInterface({ input: r.stdout }).on("line", (line) => {
  let msg;
  try { msg = JSON.parse(line); } catch { return console.warn("R stdout:", line); }
  const cb = pending.get(msg.id);
  if (cb) { pending.delete(msg.id); cb(msg); }
});
readline.createInterface({ input: r.stderr }).on("line", (line) => {
  if (!line.startsWith("\x1eSN ")) console.error("R:", line);
});
r.on("exit", (code) => { console.error(`R exited (${code})`); process.exit(1); });

const types = { ".svg": "image/svg+xml", ".html": "text/html", ".csv": "text/csv", ".png": "image/png", ".pdf": "application/pdf" };

http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  if (req.method === "POST" && url.pathname === "/rpc") {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      const { method, params } = JSON.parse(body || "{}");
      const id = nextId++;
      pending.set(id, (msg) => {
        res.writeHead(200, { "content-type": "application/json" });
        res.end(JSON.stringify(msg.error ? { error: msg.error } : { result: msg.result }));
      });
      r.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params: params ?? {} }) + "\n");
    });
    return;
  }
  if (req.method === "POST" && url.pathname === "/cancel") {
    r.kill("SIGINT");
    res.end("{}");
    return;
  }
  if (req.method === "GET" && url.pathname === "/file") {
    const file = path.resolve(url.searchParams.get("path") || "");
    if (!file.startsWith(workDir) || !existsSync(file)) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { "content-type": types[path.extname(file)] || "application/octet-stream" });
    createReadStream(file).pipe(res);
    return;
  }
  res.writeHead(404); res.end();
}).listen(port, "127.0.0.1", () => console.log(`StatNext dev bridge on http://127.0.0.1:${port} (R work dir ${workDir})`));
