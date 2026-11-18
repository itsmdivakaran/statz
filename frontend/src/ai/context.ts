// What the AI assistant is sent about a result: tables, summaries and checks,
// never the data itself.
import { fmtCell } from "../results/format";
import type { AnalysisResult, Table } from "../types";

const MAX_ROWS = 40;

function tableText(t: Table): string {
  const head = `| ${t.columns.map((c) => c.label).join(" | ")} |`;
  const sep = `| ${t.columns.map(() => "---").join(" | ")} |`;
  const rows = t.rows.slice(0, MAX_ROWS).map((r) => `| ${t.columns.map((c) => fmtCell(r[c.id], c)).join(" | ")} |`);
  const more = t.rows.length > MAX_ROWS ? [`(${t.rows.length - MAX_ROWS} more rows not shown)`] : [];
  return [`**${t.title}**`, head, sep, ...rows, ...more, ...(t.notes.length ? [`Note. ${t.notes.join(" ")}`] : [])].join("\n");
}

export function resultContext(r: AnalysisResult, menu?: string[]): string {
  const parts = [`Analysis: ${r.title}${menu?.length ? ` (${menu.join(" › ")})` : ""}`];
  for (const t of r.tables) parts.push(tableText(t));
  if (r.summary?.length) parts.push("Plain-language summary (easystats report):\n" + r.summary.map((s) => s.text).join("\n\n"));
  if (r.interpretation) parts.push("StatNext interpretation:\n" + r.interpretation.text);
  const checks = r.assumptions.filter((c) => c.message).map((c) => `- ${c.test} (${c.status}): ${c.message}`);
  if (checks.length) parts.push("Assumption checks:\n" + checks.join("\n"));
  if (r.warnings.length) parts.push("R warnings:\n" + r.warnings.map((w) => `- ${w}`).join("\n"));
  return parts.join("\n\n");
}

export const SYSTEM_PROMPT = `You are the statistics assistant inside StatNext, a point-and-click statistics app that runs analyses in R.
Users are applied researchers and students. When given analysis results:
- Explain what the results mean in plain language, then the key numbers (estimates, confidence intervals, p-values, effect sizes).
- Use only numbers that appear in the results. Never invent values or claim to see raw data you were not given.
- Point out failed or borderline assumption checks and what to do about them.
- Note limits of the design (for example, correlation is not causation) when relevant.
- When asked to write for a paper, use APA 7 style.
Keep answers under about 250 words unless the user asks for more. Use short paragraphs and simple Markdown (bold, bullet lists).`;
