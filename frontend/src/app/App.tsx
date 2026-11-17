import { useEffect } from "react";
import { AnalysisDialog } from "../dialogs/AnalysisDialog";
import { DataPanel } from "../grid/DataGrid";
import { ResultsPanel } from "../results/ResultsPanel";
import { cancel } from "../rpc/client";
import { useStore } from "../state/store";
import { openDataFile, saveProject } from "./actions";
import { Ribbon } from "./Ribbon";
import { Startup } from "./Startup";

export function App() {
  const { status, init, theme, undo, redo, selected, runNow } = useStore();

  useEffect(() => { void init(); }, [init]);
  useEffect(() => { document.documentElement.classList.toggle("dark", theme === "dark"); }, [theme]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const mod = e.metaKey || e.ctrlKey;
      const typing = e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement;
      if (!mod) return;
      const k = e.key.toLowerCase();
      if (k === "z" && !typing) { e.preventDefault(); if (e.shiftKey) redo(); else undo(); }
      else if (k === "y" && !typing) { e.preventDefault(); redo(); }
      else if (k === "o") { e.preventDefault(); void openDataFile(); }
      else if (k === "s") { e.preventDefault(); void saveProject(); }
      else if (k === "." ) { e.preventDefault(); void cancel(); }
      else if (k === "enter" && !typing && selected) { e.preventDefault(); void runNow(selected); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [undo, redo, selected, runNow]);

  if (status !== "ready") return <Startup />;
  return (
    <div className="flex h-full flex-col">
      <Ribbon />
      <main className="grid min-h-0 flex-1 grid-cols-[minmax(320px,1fr)_minmax(340px,0.9fr)_minmax(420px,1.3fr)] divide-x divide-slate-200 dark:divide-slate-800">
        <DataPanel />
        <AnalysisDialog />
        <ResultsPanel />
      </main>
    </div>
  );
}
