import { describe, expect, it } from "vitest";
import { type Answers, BAYES, GOALS, assignRoles, hasBayesian, outcomeOf, questions, recommend } from "../../src/guide/guide";
import type { DataInfo, ModuleSpec, VariableMeta } from "../../src/types";

const specs = Object.fromEntries(
  Object.values(import.meta.glob("../../../analyses/*/spec.json", { eager: true, import: "default" }))
    .map((s) => [(s as ModuleSpec).id, s as ModuleSpec]),
);

/** Every complete path through the questions for a goal. */
function leaves(a: Answers): Answers[] {
  const open = questions(a).find((q) => a[q.id] === undefined);
  if (!open) return [a];
  return open.choices.flatMap((c) => leaves({ ...a, [open.id]: c.value }));
}

describe("analysis guide", () => {
  const all = GOALS.flatMap((g) => leaves({ goal: g.value as Answers["goal"] }))
    .flatMap((a) => [a, { ...a, approach: "bayesian" as const }]);

  it("recommends an existing analysis, with valid options, for every path", () => {
    expect(all.length).toBeGreaterThan(60);
    for (const a of all) {
      const r = recommend(a);
      expect(r, JSON.stringify(a)).not.toBeNull();
      for (const p of [r!, ...r!.alternatives]) {
        const spec = specs[p.module];
        expect(spec, `${p.module} for ${JSON.stringify(a)}`).toBeDefined();
        for (const [k, v] of Object.entries(p.options ?? {})) {
          const o = spec.options[k];
          expect(o?.type, `${p.module}.${k}`).toBe("enum");
          for (const x of [v].flat()) expect((o as { values: string[] }).values).toContain(x);
        }
        expect(p.why.length).toBeGreaterThan(10);
      }
    }
  });

  it("has no recommendation until the questions are answered", () => {
    expect(recommend({})).toBeNull();
    expect(recommend({ goal: "compare", outcome: "continuous" })).toBeNull();
  });

  it("follows the textbook choices", () => {
    expect(recommend({ goal: "compare", outcome: "continuous", groups: "two", design: "independent", normal: "yes" })!.module).toBe("ttest_ind");
    expect(recommend({ goal: "compare", outcome: "continuous", groups: "two", design: "independent", normal: "no" })!.options).toEqual({ test: ["mann_whitney"] });
    expect(recommend({ goal: "compare", outcome: "continuous", groups: "many", design: "paired", normal: "no" })!.module).toBe("friedman");
    expect(recommend({ goal: "compare", outcome: "binary", groups: "two", design: "paired" })!.module).toBe("mcnemar");
    expect(recommend({ goal: "predict", outcome: "binary", clustered: "no", purpose: "explain" })!.module).toBe("reg_logistic");
    expect(recommend({ goal: "predict", outcome: "binary", clustered: "no", purpose: "predict" })!.module).toBe("ml_forest");
    expect(recommend({ goal: "survival", survival: "adjust" })!.module).toBe("surv_cox");
  });

  it("puts the Bayesian version first when asked", () => {
    const a: Answers = { goal: "compare", outcome: "continuous", groups: "two", design: "independent", normal: "yes" };
    expect(hasBayesian(a)).toBe(true);
    expect(recommend({ ...a, approach: "bayesian" })!.module).toBe("bayes_ttest_ind");
    expect(recommend({ ...a, normal: "no", approach: "bayesian" })!.module).toBe("ttest_ind");
    for (const b of Object.values(BAYES)) expect(specs[b]).toBeDefined();
  });

  const v = (name: string, measure: VariableMeta["measure"]): VariableMeta => ({ name, label: "", type: "double", measure, value_labels: [], missing: [] });
  it("reads the outcome type from a variable", () => {
    expect(outcomeOf(v("x", "continuous"), 40)).toBe("continuous");
    expect(outcomeOf(v("x", "nominal"), 2)).toBe("binary");
    expect(outcomeOf(v("x", "nominal"), 4)).toBe("nominal");
    expect(outcomeOf(v("x", "ordinal"), 5)).toBe("ordinal");
  });

  it("assigns chosen variables to matching roles", () => {
    const data = { id: "d", source: null, nrow: 1, ncol: 2, variables: [v("mpg", "continuous"), v("am", "nominal")] } as DataInfo;
    expect(assignRoles(specs.ttest_ind, data, "mpg", "am")).toEqual({ dv: ["mpg"], group: ["am"] });
    expect(assignRoles(specs.chisq, data, "am", "am")).toEqual({ rows: ["am"], cols: ["am"] });
    expect(assignRoles(specs.reg_logistic, data, "am", "mpg")).toEqual({ dv: ["am"], covariates: ["mpg"] });
  });
});
