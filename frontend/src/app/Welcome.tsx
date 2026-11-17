import { ArrowRight, Code2, FolderOpen, LineChart, ShieldCheck, Table2 } from "lucide-react";
import { openDataFile, openProject } from "./actions";
import { useCommands } from "./commands";
import { Logo } from "./Logo";

const FEATURES = [
  { Icon: ShieldCheck, title: "Assumptions checked", text: "Normality and variance checks run alongside every test." },
  { Icon: Code2, title: "R code for everything", text: "Each result ships with the exact, editable R that produced it." },
  { Icon: LineChart, title: "Publication plots", text: "Interactive ggnext figures, exported as SVG, PNG or PDF." },
];

export function Welcome() {
  const examples = useCommands().filter((c) => c.group === "Example data");
  return (
    <div className="relative flex h-full items-center justify-center overflow-auto p-8">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(60rem_30rem_at_50%_-10%,rgb(var(--brand)/0.14),transparent)]" />
      <div className="relative w-full max-w-3xl space-y-8">
        <div className="space-y-3 text-center">
          <div className="flex justify-center"><Logo size={56} /></div>
          <h1 className="text-3xl font-bold tracking-tight">Welcome to Stat<span className="text-brand">Next</span></h1>
          <p className="text-[15px] text-muted">Point-and-click statistics, powered by R on your own machine.</p>
          <div className="flex justify-center gap-2 pt-2">
            <button className="btn-primary" onClick={() => void openDataFile()}><FolderOpen size={16} aria-hidden="true" />Open data file</button>
            <button className="btn px-3.5 py-2" onClick={() => void openProject()}>Open project</button>
          </div>
        </div>
        <section>
          <h2 className="panel-title mb-2">Try an example dataset</h2>
          <div className="grid grid-cols-2 gap-2.5">
            {examples.map((e) => (
              <button key={e.id} onClick={e.run} className="card group flex items-center gap-3 p-3 text-left transition hover:-translate-y-px hover:border-brand/60 hover:shadow-pop">
                <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-brand/10 text-brand"><Table2 size={17} aria-hidden="true" /></span>
                <span className="flex-1 text-sm font-medium">{e.label}</span>
                <ArrowRight size={15} className="text-muted transition group-hover:translate-x-0.5 group-hover:text-brand" aria-hidden="true" />
              </button>
            ))}
          </div>
        </section>
        <section className="grid grid-cols-3 gap-2.5">
          {FEATURES.map((f) => (
            <div key={f.title} className="rounded-xl border border-line bg-surface/60 p-3.5">
              <f.Icon size={18} className="mb-2 text-accent" aria-hidden="true" />
              <div className="text-sm font-semibold">{f.title}</div>
              <p className="mt-0.5 text-xs leading-relaxed text-muted">{f.text}</p>
            </div>
          ))}
        </section>
      </div>
    </div>
  );
}
