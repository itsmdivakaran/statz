import { describe, expect, it } from "vitest";
import { fmtCell, fmtNum, fmtP, tableToTsv } from "../../src/results/format";

describe("APA formatting", () => {
  it("formats p-values without a leading zero", () => {
    expect(fmtP(0.0004)).toBe("< .001");
    expect(fmtP(0.001374)).toBe(".001");
    expect(fmtP(0.0496)).toBe(".050");
    expect(fmtP(null)).toBe("");
  });

  it("uses a true minus sign and avoids negative zero", () => {
    expect(fmtNum(-3.7671)).toBe("−3.77");
    expect(fmtNum(-0.001)).toBe("0.00");
    expect(fmtNum(18.332, 2)).toBe("18.33");
  });

  it("formats confidence intervals and ints", () => {
    expect(fmtCell([-11.2802, -3.2097], { id: "ci", label: "95% CI", type: "ci", digits: 2 })).toBe("[−11.28, −3.21]");
    expect(fmtCell([null, null], { id: "ci", label: "", type: "ci" })).toBe("");
    expect(fmtCell(19, { id: "n", label: "N", type: "int" })).toBe("19");
  });

  it("copies tables as TSV", () => {
    const cols = [{ id: "g", label: "Group", type: "text" as const }, { id: "p", label: "p", type: "pvalue" as const }];
    expect(tableToTsv(cols, [{ g: "A", p: 0.5 }])).toBe("Group\tp\nA\t.500");
  });
});
