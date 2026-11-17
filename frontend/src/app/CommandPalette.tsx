import { Search } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { useCommands } from "./commands";

export function CommandPalette({ open, onClose }: { open: boolean; onClose: () => void }) {
  const commands = useCommands();
  const [q, setQ] = useState("");
  const [idx, setIdx] = useState(0);
  useEffect(() => { if (open) { setQ(""); setIdx(0); } }, [open]);

  const hits = useMemo(() => {
    const words = q.toLowerCase().split(/\s+/).filter(Boolean);
    return commands.filter((c) => {
      const hay = `${c.label} ${c.group} ${c.menu} ${c.hint ?? ""}`.toLowerCase();
      return words.every((w) => hay.includes(w));
    });
  }, [commands, q]);

  if (!open) return null;
  const run = (i: number) => { const c = hits[i]; if (c && !c.disabled) { onClose(); c.run(); } };
  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/30 pt-[14vh] backdrop-blur-[2px]" onMouseDown={onClose}>
      <div role="dialog" aria-label="Command palette" className="w-[34rem] max-w-[92vw] animate-pop overflow-hidden rounded-2xl border border-line bg-surface shadow-pop" onMouseDown={(e) => e.stopPropagation()}>
        <div className="flex items-center gap-2.5 border-b border-line px-4 py-3">
          <Search size={16} className="text-muted" aria-hidden="true" />
          <input autoFocus value={q} placeholder="Search analyses, data and actions…" aria-label="Search commands"
            className="flex-1 bg-transparent text-[15px] outline-none focus-visible:outline-none placeholder:text-muted"
            onChange={(e) => { setQ(e.target.value); setIdx(0); }}
            onKeyDown={(e) => {
              if (e.key === "ArrowDown") { e.preventDefault(); setIdx((i) => Math.min(i + 1, hits.length - 1)); }
              else if (e.key === "ArrowUp") { e.preventDefault(); setIdx((i) => Math.max(i - 1, 0)); }
              else if (e.key === "Enter") { e.preventDefault(); run(idx); }
              else if (e.key === "Escape") onClose();
            }} />
          <span className="kbd">Esc</span>
        </div>
        <ul className="max-h-80 overflow-auto p-1.5" role="listbox">
          {hits.length === 0 && <li className="px-3 py-6 text-center text-sm text-muted">No matches.</li>}
          {hits.map((c, i) => (
            <li key={c.id} role="option" aria-selected={i === idx} aria-disabled={c.disabled}
              ref={(el) => { if (i === idx) el?.scrollIntoView?.({ block: "nearest" }); }}
              onMouseEnter={() => setIdx(i)} onClick={() => run(i)}
              className={`flex cursor-pointer items-center gap-2.5 rounded-lg px-2.5 py-2 ${i === idx ? "bg-brand/10" : ""} ${c.disabled ? "opacity-40" : ""}`}>
              <span className={`flex h-7 w-7 items-center justify-center rounded-md ${i === idx ? "bg-brand text-white" : "bg-surface2 text-muted"}`}><c.Icon size={15} aria-hidden="true" /></span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-medium">{c.label}</span>
                {c.hint && <span className="block truncate text-xs text-muted">{c.hint}</span>}
              </span>
              <span className="text-xs text-muted">{c.disabled ? "Needs data" : c.group}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
