---
name: tauri-r-bridge-debug
description: Debug the R worker bridge (Tauri shell ↔ R over JSON-RPC stdio, or the browser dev bridge). Use for hangs, "worker died", cancel not working, garbled responses, missing-package errors or R-not-found on a platform.
---
# Debug the R bridge
Protocol: one JSON-RPC 2.0 request per line on R's stdin, one response per line on stdout; progress notifications on stderr prefixed `\x1eSN `; cancel = SIGINT (R turns it into error -32004 and stays alive). Codes: -32001 R error, -32002 missing package, -32003 invalid options, -32004 cancelled, -32005 worker died, -32006 not started.

Triage:
1. Reproduce in R directly: `echo '{"jsonrpc":"2.0","id":1,"method":"system.hello"}' | Rscript --vanilla -e 'statnextr::sn_main()' --args --modules=analyses --datasets=datasets --workdir=$(mktemp -d)` (method names: the `switch(method, ...)` in `r-backend/R/server.R`).
2. Stray stdout from an analysis breaks framing: look for `print`/`cat` outside `sn_eval` capture.
3. Browser path: `cd frontend && pnpm bridge` logs R stderr (`R:` lines) and exits if R exits; port from `STATNEXT_BRIDGE_PORT` (default 5174); `STATNEXT_RSCRIPT` selects Rscript.
4. Desktop path: `src-tauri/src/r_worker.rs` (lifecycle, pending map, crash replay), `r_detect.rs` (registry/Program Files/PATH lookup), `setup.rs` (private library, date-pinned snapshot install).
5. Automated check: `STATNEXT_TEST_R=1 cargo test --manifest-path src-tauri/Cargo.toml --test worker` (detection, run, cancel, restart).
Windows notes: paths go through `r_path`; run shell commands in Git Bash.
