import { defineConfig } from "@playwright/test";

// e2e runs the real R backend through dev-bridge (needs Rscript + statnextr installed).
export default defineConfig({
  testDir: "tests/e2e",
  timeout: 60_000,
  use: { baseURL: "http://localhost:5173", trace: "off" },
  webServer: [
    { command: "node dev-bridge/server.mjs", port: 5174, reuseExistingServer: true, timeout: 60_000 },
    { command: "pnpm dev", port: 5173, reuseExistingServer: true, timeout: 60_000 },
  ],
});
