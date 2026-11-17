/** @type {import('tailwindcss').Config} */
const v = (name) => `rgb(var(--${name}) / <alpha-value>)`;
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        canvas: v("canvas"), surface: v("surface"), surface2: v("surface-2"), line: v("line"),
        ink: v("ink"), muted: v("muted"), brand: v("brand"), accent: v("accent"),
        ok: v("ok"), warn: v("warn"), bad: v("bad"),
      },
      fontFamily: {
        sans: ["Inter Variable", "ui-sans-serif", "system-ui", "-apple-system", "Segoe UI", "sans-serif"],
        mono: ["JetBrains Mono Variable", "ui-monospace", "SFMono-Regular", "Menlo", "monospace"],
      },
      boxShadow: {
        card: "0 1px 2px rgb(16 24 40 / 0.04), 0 1px 3px rgb(16 24 40 / 0.06)",
        pop: "0 12px 32px -8px rgb(16 24 40 / 0.22), 0 2px 6px rgb(16 24 40 / 0.08)",
      },
      keyframes: { pop: { from: { opacity: 0, transform: "translateY(-4px) scale(0.98)" }, to: { opacity: 1, transform: "none" } } },
      animation: { pop: "pop 120ms ease-out" },
    },
  },
  plugins: [],
};
