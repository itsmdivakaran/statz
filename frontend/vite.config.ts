/// <reference types="vitest" />
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// In a plain browser (no Tauri), /bridge is proxied to dev-bridge/server.mjs,
// which runs the same R worker over stdio. Used for development and e2e tests.
export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: {
    port: 5173,
    strictPort: true,
    proxy: { "/bridge": { target: "http://127.0.0.1:5174", rewrite: (p) => p.replace(/^\/bridge/, "") } },
  },
  test: { environment: "jsdom", include: ["tests/unit/**/*.test.ts?(x)"] },
});
