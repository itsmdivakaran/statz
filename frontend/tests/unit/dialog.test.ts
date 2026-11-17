import { describe, expect, it } from "vitest";
import { accepts } from "../../src/dialogs/AnalysisDialog";
import { defaultOptions, rolesFilled } from "../../src/state/store";
import type { ModuleSpec, VariableMeta } from "../../src/types";
import spec from "../../../analyses/ttest_ind/spec.json";
import mixed from "../../../analyses/mixed_linear/spec.json";

const s = spec as unknown as ModuleSpec;
const v = (name: string, measure: VariableMeta["measure"]): VariableMeta =>
  ({ name, label: "", type: "double", measure, value_labels: [], missing: [] });

describe("dialog rules", () => {
  it("fills defaults from the spec", () => {
    const o = defaultOptions(s);
    expect(o.dv).toEqual([]);
    expect(o.test).toEqual(["welch"]);
    expect(o.conf_level).toBe(0.95);
  });

  it("checks measurement level per role", () => {
    const [dv, group] = s.roles;
    expect(accepts(dv, v("mpg", "continuous"))).toBe(true);
    expect(accepts(dv, v("am", "nominal"))).toBe(false);
    expect(accepts(group, v("am", "nominal"))).toBe(true);
  });

  it("runs only when required roles are filled", () => {
    expect(rolesFilled(s, { dv: ["mpg"], group: [] })).toBe(false);
    expect(rolesFilled(s, { dv: ["mpg"], group: ["am"] })).toBe(true);
  });

  it("leaves interaction terms unset and starts subsets empty", () => {
    const o = defaultOptions(mixed as unknown as ModuleSpec);
    expect("interactions" in o).toBe(false);
    expect(o.random_slopes).toEqual([]);
    expect(o.method).toBe("REML");
  });
});
