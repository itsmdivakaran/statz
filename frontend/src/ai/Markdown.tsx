import { Fragment, type ReactNode } from "react";

/** Minimal Markdown for AI replies: paragraphs, bullet and numbered lists, **bold**, *italic*, `code`. */
function inline(s: string): ReactNode[] {
  return s.split(/(\*\*[^*]+\*\*|`[^`]+`|\*[^*\s][^*]*\*)/g).map((p, i) =>
    p.startsWith("**") && p.endsWith("**") && p.length > 4 ? <strong key={i}>{p.slice(2, -2)}</strong>
      : p.startsWith("`") && p.endsWith("`") && p.length > 2 ? <code key={i} className="rounded bg-surface2 px-1 font-mono text-[0.92em]">{p.slice(1, -1)}</code>
        : p.startsWith("*") && p.endsWith("*") && p.length > 2 ? <em key={i}>{p.slice(1, -1)}</em>
          : <Fragment key={i}>{p}</Fragment>);
}

export function Markdown({ text }: { text: string }) {
  const blocks = text.replace(/\r/g, "").split(/\n{2,}/);
  return (
    <div className="space-y-2">
      {blocks.map((b, i) => {
        const lines = b.split("\n").filter((l) => l.trim());
        if (lines.length && lines.every((l) => /^\s*([-*•]|\d+[.)])\s+/.test(l))) {
          const ordered = /^\s*\d/.test(lines[0]);
          const items = lines.map((l, j) => <li key={j}>{inline(l.replace(/^\s*([-*•]|\d+[.)])\s+/, ""))}</li>);
          return ordered ? <ol key={i} className="list-decimal space-y-0.5 pl-5">{items}</ol> : <ul key={i} className="list-disc space-y-0.5 pl-5">{items}</ul>;
        }
        const h = /^#{1,4}\s+(.*)$/.exec(lines[0] ?? "");
        if (h && lines.length === 1) return <p key={i} className="font-semibold">{inline(h[1])}</p>;
        return <p key={i}>{lines.map((l, j) => <Fragment key={j}>{j > 0 && <br />}{inline(l.replace(/^#{1,4}\s+/, ""))}</Fragment>)}</p>;
      })}
    </div>
  );
}
