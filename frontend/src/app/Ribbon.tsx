import {
  BrainCircuit, Compass, Database, FolderOpen, HeartPulse, LineChart, type LucideIcon, Moon, Network, Puzzle, Redo2, Save, Scale, Search,
  Settings2, Sigma, Sparkles, Stethoscope, Sun, TestTubes, TrendingUp, Undo2,
} from "lucide-react";
import { useAi } from "../ai/store";
import { useEffect, useRef, useState } from "react";
import { useStore } from "../state/store";
import { openDataFile, saveProject } from "./actions";
import { type Command, useCommands } from "./commands";
import { Wordmark } from "./Logo";

/** Ribbon groups: data, core statistics, advanced methods, extensions. */
const GROUPS: { name: string; label?: string; Icon: LucideIcon }[][] = [
  [{ name: "Data", Icon: Database }],
  [
    { name: "Descriptives", Icon: Sigma },
    { name: "Tests", Icon: TestTubes },
    { name: "Bayesian", Icon: Scale },
    { name: "Regression", Icon: TrendingUp },
  ],
  [
    { name: "Multivariate", Icon: Network },
    { name: "Machine Learning", label: "ML", Icon: BrainCircuit },
    { name: "Time Series", Icon: LineChart },
    { name: "Survival", Icon: HeartPulse },
    { name: "Clinical", Icon: Stethoscope },
  ],
  [{ name: "Plugins", Icon: Puzzle }],
];
const MENU_COUNT = GROUPS.flat().length;

function useDropdown() {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const close = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false);
    const esc = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", close);
    document.addEventListener("keydown", esc);
    return () => { document.removeEventListener("mousedown", close); document.removeEventListener("keydown", esc); };
  }, []);
  return { open, setOpen, ref };
}

const TAB = "flex h-[50px] min-w-[64px] shrink-0 flex-col items-center justify-center gap-1 whitespace-nowrap rounded-md px-2 text-[11.5px] font-medium text-ink/75 transition-colors hover:bg-surface2 hover:text-ink aria-expanded:bg-brand/10 aria-expanded:text-brand";
const POP = "absolute left-0 z-30 mt-1.5 max-h-[calc(100vh-5rem)] w-80 origin-top-left animate-pop overflow-y-auto rounded-xl border border-line bg-surface p-1.5 shadow-pop";

function Menu({ name, label, Icon, items, empty, alignRight }: { name: string; label?: string; Icon: LucideIcon; items: Command[]; empty?: string; alignRight?: boolean }) {
  const { open, setOpen, ref } = useDropdown();
  let lastGroup: string | undefined;
  return (
    <div ref={ref} className="relative">
      <button className={TAB} aria-expanded={open} aria-haspopup="menu" aria-label={name} title={name} onClick={() => setOpen((o) => !o)}>
        <Icon size={18} strokeWidth={1.75} aria-hidden="true" /><span>{label ?? name}</span>
      </button>
      {open && (
        <div role="menu" className={alignRight ? `${POP} left-auto right-0 origin-top-right` : POP}>
          {items.length === 0 && <p className="px-3 py-4 text-center text-sm text-muted">{empty}</p>}
          {items.map((it) => {
            const header = it.group !== lastGroup ? it.group : null;
            lastGroup = it.group;
            return (
              <div key={it.id}>
                {header && <div className="panel-title px-2.5 pb-1 pt-2.5">{header}</div>}
                <button role="menuitem" disabled={it.disabled} aria-label={it.label}
                  className="group flex w-full items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-left transition-colors hover:bg-brand/10 disabled:opacity-40 disabled:hover:bg-transparent"
                  onClick={() => { setOpen(false); it.run(); }}>
                  <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-surface2 text-muted group-hover:bg-brand group-hover:text-white group-disabled:group-hover:bg-surface2 group-disabled:group-hover:text-muted">
                    <it.Icon size={15} aria-hidden="true" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-medium">{it.label}</span>
                    {it.hint && <span className="block truncate text-xs text-muted">{it.hint}</span>}
                  </span>
                  {it.shortcut && <span className="kbd">{it.shortcut}</span>}
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

/** Top of the window: a toolbar (file actions, search, guide) above the analysis ribbon. */
export function Ribbon({ onSearch }: { onSearch: () => void }) {
  const { theme, toggleTheme, data, setModal, undo, redo, undoStack, redoStack } = useStore();
  const ai = useAi();
  const commands = useCommands();
  const itemsFor = (menu: string) => commands.filter((c) => c.menu === menu);
  const isMac = typeof navigator !== "undefined" && /Mac/.test(navigator.platform);
  const mod = isMac ? "⌘" : "Ctrl+";
  let n = 0;

  return (
    <header className="shrink-0 border-b border-line bg-surface">
      <div className="flex h-11 items-center gap-1 border-b border-line/70 px-3">
        <span className="mr-2 shrink-0"><Wordmark /></span>
        <span className="vsep" />
        <button className="tool-btn" onClick={() => void openDataFile()} title={`Open data file (${mod}O)`}><FolderOpen size={15} aria-hidden="true" /><span className="hidden lg:inline">Open</span></button>
        <button className="tool-btn" disabled={!data} onClick={() => void saveProject()} title={`Save project (${mod}S)`}><Save size={15} aria-hidden="true" /><span className="hidden lg:inline">Save</span></button>
        <span className="vsep" />
        <button className="tool-btn" disabled={!undoStack.length} onClick={undo} aria-label="Undo" title={`Undo (${mod}Z)`}><Undo2 size={15} aria-hidden="true" /></button>
        <button className="tool-btn" disabled={!redoStack.length} onClick={redo} aria-label="Redo" title={`Redo (${isMac ? "⇧⌘Z" : "Ctrl+Y"})`}><Redo2 size={15} aria-hidden="true" /></button>
        <div className="mx-auto flex min-w-0 justify-center px-3">
          <button onClick={onSearch} aria-label="Search commands" title={`Search analyses (${isMac ? "⌘K" : "Ctrl K"})`}
            className="flex h-8 w-[min(26rem,36vw)] items-center gap-2 rounded-md border border-line bg-canvas px-2.5 text-[13px] text-muted transition-colors hover:border-brand/50">
            <Search size={14} aria-hidden="true" /><span className="flex-1 truncate text-left">Search analyses, data and actions…</span>
            <span className="kbd">{isMac ? "⌘K" : "Ctrl K"}</span>
          </button>
        </div>
        <button onClick={() => setModal("guide")} title="Which analysis should I use?" aria-label="Analysis guide"
          className="flex h-8 shrink-0 items-center gap-1.5 whitespace-nowrap rounded-md border border-brand/30 bg-brand/[0.07] px-2.5 text-[13px] font-semibold text-brand transition-colors hover:bg-brand/15">
          <Compass size={15} aria-hidden="true" /><span className="hidden md:inline">Which test?</span>
        </button>
        <button onClick={() => ai.setChatOpen(!ai.chatOpen)} title="Ask the AI assistant" aria-label="AI assistant" aria-pressed={ai.chatOpen}
          className="ml-1.5 flex h-8 shrink-0 items-center gap-1.5 whitespace-nowrap rounded-md border border-pink/30 bg-pink/[0.07] px-2.5 text-[13px] font-semibold text-pink transition-colors hover:bg-pink/15 aria-pressed:bg-pink/15">
          <Sparkles size={15} aria-hidden="true" /><span className="hidden md:inline">Ask AI</span>
        </button>
        <button className="tool-btn ml-1 px-1.5" onClick={() => ai.setSettingsOpen(true)} aria-label="Settings" title="Settings"><Settings2 size={16} aria-hidden="true" /></button>
        <button className="tool-btn px-1.5" onClick={toggleTheme} aria-label="Toggle theme" title="Toggle theme">
          {theme === "dark" ? <Sun size={16} aria-hidden="true" /> : <Moon size={16} aria-hidden="true" />}
        </button>
      </div>
      <nav aria-label="Analyses" className="flex items-center gap-0.5 px-2 py-1">
        {GROUPS.map((g, gi) => (
          <div key={gi} className="flex items-center gap-0.5">
            {gi > 0 && <span className="mx-1.5 h-9 w-px bg-line" aria-hidden="true" />}
            {g.map((m) => {
              const i = n++;
              return <Menu key={m.name} name={m.name} label={m.label} Icon={m.Icon} items={itemsFor(m.name)} alignRight={i >= MENU_COUNT - 2}
                empty={data ? "Nothing here yet." : "Open a data file first."} />;
            })}
          </div>
        ))}
      </nav>
    </header>
  );
}
