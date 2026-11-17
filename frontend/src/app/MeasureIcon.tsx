import { BarChart3, Calendar, Hash, Tags } from "lucide-react";
import type { Measure } from "../types";

const MAP = {
  continuous: { Icon: Hash, cls: "text-brand", label: "Continuous" },
  nominal: { Icon: Tags, cls: "text-accent", label: "Nominal" },
  ordinal: { Icon: BarChart3, cls: "text-warn", label: "Ordinal" },
  date: { Icon: Calendar, cls: "text-muted", label: "Date" },
} as const;

export function MeasureIcon({ measure, className = "" }: { measure?: Measure | string; className?: string }) {
  const m = MAP[(measure ?? "nominal") as keyof typeof MAP] ?? MAP.nominal;
  return <span title={m.label} className={`inline-flex shrink-0 ${m.cls} ${className}`}><m.Icon size={13} strokeWidth={2.2} aria-hidden="true" /></span>;
}
