import { useEffect, useState } from "react";
import { AnalysisDialog } from "../dialogs/AnalysisDialog";
import { DataPanel } from "../grid/DataGrid";
import { ResultsPanel } from "../results/ResultsPanel";
import { cancel } from "../rpc/client";
import { useStore } from "../state/store";
import { openDataFile, saveProject } from "./actions";
import { CommandPalette } from "./CommandPalette";
import { Ribbon } from "./Ribbon";
import { TransformDialog } from "../transform/TransformDialog";
import { Welcome } from "./Welcome";
import { Startup } from "./Startup";

export function App() {
  const { status, init, theme, undo, redo, selected, runNow, data } = useStore();
  const [palette, setPalette] = useState(false);

  useEffect(() => { void init(); }, [init]);
  useEffect(() => { document.documentElement.classList.toggle("dark", theme === "dark"); }, [theme]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const mod = e.metaKey || e.ctrlKey;
      const typing = e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement;
      if (!mod) return;
      const k = e.key.toLowerCase();
      if (k === "k") { e.preventDefault(); setPalette((p) => !p); }
      else if (k === "z" && !typing) { e.preventDefault(); if (e.shiftKey) redo(); else undo(); }
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
      <Ribbon onSearch={() => setPalette(true)} />
      {!data ? <main className="min-h-0 flex-1"><Welcome /></main> : (
        <main className="grid min-h-0 flex-1 grid-cols-[minmax(320px,1fr)_minmax(340px,0.9fr)_minmax(420px,1.3fr)] gap-2.5 p-2.5">
          <div className="card min-h-0 overflow-hidden"><DataPanel /></div>
          <div className="card min-h-0 overflow-hidden"><AnalysisDialog /></div>
          <div className="card min-h-0 overflow-hidden"><ResultsPanel /></div>
        </main>
      )}
      <TransformDialog />
      <CommandPalette open={palette} onClose={() => setPalette(false)} />
    </div>
  );
}
