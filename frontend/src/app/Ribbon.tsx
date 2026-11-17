import { useEffect, useRef, useState } from "react";
import { call } from "../rpc/client";
import { useStore } from "../state/store";
import { exportScript, openDataFile, openProject, saveProject } from "./actions";

const MENUS = ["Data", "Descriptives", "Tests", "Regression", "ML", "Survival", "Clinical", "Multivariate", "Plots", "Guide"] as const;
const LATER: Record<string, string> = {
  Regression: "Phase 2", Survival: "Phase 2", ML: "Phase 3", Clinical: "Phase 3", Multivariate: "Phase 3", Guide: "Phase 4",
};

interface Item { label: string; onClick: () => void; group?: string }

function Menu({ name, items, disabled }: { name: string; items: Item[]; disabled?: string }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const close = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false);
    document.addEventListener("mousedown", close);
    return () => document.removeEventListener("mousedown", close);
  }, []);
  let lastGroup: string | undefined;
  return (
    <div ref={ref} className="relative">
      <button
        className="rounded px-3 py-1.5 text-sm hover:bg-slate-100 disabled:text-slate-400 disabled:hover:bg-transparent dark:disabled:text-slate-600 dark:hover:bg-slate-800"
        disabled={!!disabled}
        title={disabled ? `Coming in ${disabled}` : undefined}
        onClick={() => setOpen((o) => !o)}
      >
        {name}
      </button>
      {open && items.length > 0 && (
        <div role="menu" className="absolute left-0 z-30 mt-1 min-w-56 rounded-md border border-slate-200 bg-white py-1 shadow-lg dark:border-slate-700 dark:bg-slate-900">
          {items.map((it) => {
            const header = it.group && it.group !== lastGroup ? it.group : null;
            lastGroup = it.group;
            return (
              <div key={it.label}>
                {header && <div className="px-3 pb-0.5 pt-2 text-[11px] font-semibold uppercase text-slate-400">{header}</div>}
                <button role="menuitem" className="block w-full px-3 py-1.5 text-left text-sm hover:bg-slate-100 dark:hover:bg-slate-800"
                  onClick={() => { setOpen(false); it.onClick(); }}>
                  {it.label}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

export function Ribbon() {
  const { specs, newAnalysis, loadExample, theme, toggleTheme, hello, data } = useStore();
  const [examples, setExamples] = useState<{ name: string; title: string }[]>([]);
  useEffect(() => { void call<{ name: string; title: string }[]>("data.examples").then(setExamples).catch(() => {}); }, []);

  const analysisItems = (menu: string): Item[] =>
    Object.values(specs)
      .filter((s) => s.menu[0] === menu)
      .map((s) => ({ label: s.title, group: s.menu[1], onClick: () => newAnalysis(s.id) }));

  const dataItems: Item[] = [
    { label: "Open data file…", group: "File", onClick: () => void openDataFile() },
    { label: "Open project…", group: "File", onClick: () => void openProject() },
    { label: "Save project…", group: "File", onClick: () => void saveProject() },
    { label: "Export R script", group: "Export", onClick: () => void exportScript("R") },
    { label: "Export R Markdown", group: "Export", onClick: () => void exportScript("Rmd") },
    { label: "Export Quarto", group: "Export", onClick: () => void exportScript("qmd") },
    ...examples.map((e) => ({ label: e.title, group: "Example data", onClick: () => void loadExample(e.name) })),
  ];

  return (
    <header className="flex items-center gap-1 border-b border-slate-200 px-2 py-1 dark:border-slate-800">
      <span className="mr-3 px-2 font-semibold text-blue-600">StatNext</span>
      {MENUS.map((m) => (
        <Menu key={m} name={m} disabled={LATER[m]}
          items={m === "Data" ? dataItems : !data ? [] : m === "Plots" ? analysisItems("Descriptives") : analysisItems(m)} />
      ))}
      <div className="ml-auto flex items-center gap-3 text-xs text-slate-500">
        {hello && <span title={hello.rscript}>R {hello.r_version} · plots: {hello.plot_engine}</span>}
        <button className="btn" onClick={toggleTheme} aria-label="Toggle theme">{theme === "dark" ? "Light" : "Dark"}</button>
      </div>
    </header>
  );
}
