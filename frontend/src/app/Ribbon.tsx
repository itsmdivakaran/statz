import {
  Activity, BarChart3, BrainCircuit, ChevronDown, Compass, Database, HeartPulse, LineChart, type LucideIcon, Moon, Network, Search,
  Sigma, Sparkles, Stethoscope, Sun, TestTubes, TrendingUp,
} from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { useStore } from "../state/store";
import { type Command, useCommands } from "./commands";
import { Wordmark } from "./Logo";

const MENUS: { name: string; label?: string; Icon: LucideIcon }[] = [
  { name: "Data", Icon: Database },
  { name: "Descriptives", Icon: Sigma },
  { name: "Tests", Icon: TestTubes },
  { name: "Regression", Icon: TrendingUp },
  { name: "Multivariate", Icon: Network },
  { name: "Machine Learning", label: "ML", Icon: BrainCircuit },
  { name: "Time Series", Icon: LineChart },
  { name: "Survival", Icon: HeartPulse },
  { name: "Clinical", Icon: Stethoscope },
];
const UPCOMING: { name: string; Icon: LucideIcon; phase: string; hint: string }[] = [
  { name: "Bayesian", Icon: BarChart3, phase: "Phase 4", hint: "Bayesian tests and models" },
  { name: "Guide", Icon: Compass, phase: "Phase 4", hint: "Which test should I use?" },
  { name: "Plugins", Icon: Sparkles, phase: "Phase 4", hint: "Add your own analyses" },
];

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

const TAB = "flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-lg px-2.5 py-1.5 text-sm font-medium text-muted transition-colors hover:bg-surface2 hover:text-ink aria-expanded:bg-brand/10 aria-expanded:text-brand";
const POP = "absolute left-0 z-30 mt-1.5 max-h-[calc(100vh-5rem)] w-80 origin-top-left animate-pop overflow-y-auto rounded-xl border border-line bg-surface p-1.5 shadow-pop";

function Menu({ name, label, Icon, items, empty }: { name: string; label?: string; Icon: LucideIcon; items: Command[]; empty?: string }) {
  const { open, setOpen, ref } = useDropdown();
  let lastGroup: string | undefined;
  return (
    <div ref={ref} className="relative">
      <button className={TAB} aria-expanded={open} aria-haspopup="menu" aria-label={name} title={name} onClick={() => setOpen((o) => !o)}>
        <Icon size={15} aria-hidden="true" /><span className="hidden xl:inline">{label ?? name}</span>
      </button>
      {open && (
        <div role="menu" className={POP}>
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

function MoreMenu() {
  const { open, setOpen, ref } = useDropdown();
  return (
    <div ref={ref} className="relative">
      <button className={TAB} aria-expanded={open} onClick={() => setOpen((o) => !o)}>
        <Sparkles size={15} aria-hidden="true" /><span className="hidden xl:inline">More</span><ChevronDown size={13} aria-hidden="true" />
      </button>
      {open && (
        <div className={POP}>
          <div className="panel-title px-2.5 pb-1 pt-2">On the roadmap</div>
          {UPCOMING.map((u) => (
            <div key={u.name} className="flex items-center gap-2.5 rounded-lg px-2.5 py-1.5 opacity-80">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md bg-surface2 text-muted"><u.Icon size={15} aria-hidden="true" /></span>
              <span className="min-w-0 flex-1">
                <span className="block text-sm font-medium">{u.name}</span>
                <span className="block truncate text-xs text-muted">{u.hint}</span>
              </span>
              <span className="chip bg-brand/10 text-brand">{u.phase}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export function Ribbon({ onSearch }: { onSearch: () => void }) {
  const { theme, toggleTheme, hello, data } = useStore();
  const commands = useCommands();
  const itemsFor = (menu: string) => commands.filter((c) => c.menu === menu);
  const isMac = typeof navigator !== "undefined" && /Mac/.test(navigator.platform);

  return (
    <header className="flex items-center gap-1 border-b border-line bg-surface px-3 py-1.5">
      <span className="mr-3 shrink-0"><Wordmark /></span>
      <nav className="flex min-w-0 items-center gap-0.5">
        {MENUS.map((m) => (
          <Menu key={m.name} name={m.name} label={m.label} Icon={m.Icon} items={itemsFor(m.name)}
            empty={data ? "Nothing here yet." : "Open a data file first."} />
        ))}
        <MoreMenu />
      </nav>
      <div className="ml-auto flex shrink-0 items-center gap-2 pl-2">
        <button onClick={onSearch} aria-label="Search commands" title={`Search analyses (${isMac ? "⌘K" : "Ctrl K"})`}
          className="flex items-center gap-2 whitespace-nowrap rounded-lg border border-line bg-surface2 px-2.5 py-1.5 text-sm text-muted transition-colors hover:border-brand/50 2xl:w-52">
          <Search size={14} aria-hidden="true" /><span className="hidden flex-1 text-left 2xl:inline">Search analyses…</span>
          <span className="kbd hidden 2xl:inline">{isMac ? "⌘K" : "Ctrl K"}</span>
        </button>
        {hello && (
          <span title={hello.rscript} className="chip hidden whitespace-nowrap border border-line bg-surface2 py-1 text-muted 2xl:inline-flex">
            <span className="relative flex h-2 w-2"><span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-ok opacity-50" /><span className="relative inline-flex h-2 w-2 rounded-full bg-ok" /></span>
            R {hello.r_version}<span className="text-line">|</span><Activity size={11} aria-hidden="true" />{hello.plot_engine}
          </span>
        )}
        <button className="btn-ghost px-1.5 py-1.5" onClick={toggleTheme} aria-label="Toggle theme" title="Toggle theme">
          {theme === "dark" ? <Sun size={16} aria-hidden="true" /> : <Moon size={16} aria-hidden="true" />}
        </button>
      </div>
    </header>
  );
}
