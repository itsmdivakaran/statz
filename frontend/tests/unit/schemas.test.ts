// Contract tests: every module spec and every R result fixture matches the shared schemas.
import Ajv2020 from "ajv/dist/2020";
import { readdirSync, readFileSync, existsSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

const root = path.resolve(__dirname, "../../..");
const read = (p: string) => JSON.parse(readFileSync(path.join(root, p), "utf8"));
const ajv = new Ajv2020({ allErrors: true, strict: false });
const moduleSchema = ajv.compile(read("schemas/module.schema.json"));
const resultSchema = ajv.compile(read("schemas/result.schema.json"));

const modules = readdirSync(path.join(root, "analyses")).filter((d) => existsSync(path.join(root, "analyses", d, "spec.json")));

describe("module specs", () => {
  it.each(modules)("%s/spec.json is valid", (m) => {
    const spec = read(`analyses/${m}/spec.json`);
    const ok = moduleSchema(spec);
    expect(moduleSchema.errors ?? []).toEqual([]);
    expect(ok).toBe(true);
    expect(spec.id).toBe(m);
    expect(existsSync(path.join(root, "analyses", m, spec.r.file))).toBe(true);
    // Every layout item must be a role or an option, and every role/option must be placed.
    const known = new Set([...spec.roles.map((r: { id: string }) => r.id), ...Object.keys(spec.options)]);
    const placed = spec.layout.flatMap((s: { items: string[] }) => s.items);
    expect(placed.filter((i: string) => !known.has(i))).toEqual([]);
    expect([...known].filter((i) => !placed.includes(i))).toEqual([]);
  });

  it("the starter plugin template is a valid module", () => {
    const spec = read("r-backend/inst/plugin-template/spec.json");
    expect(moduleSchema(spec)).toBe(true);
    expect(moduleSchema.errors ?? []).toEqual([]);
  });
});

describe("result fixtures", () => {
  const fixtures = readdirSync(path.join(root, "tests/fixtures")).filter((f) => f.endsWith(".result.json"));
  it.each(fixtures)("%s matches result.schema.json", (f) => {
    const ok = resultSchema(read(`tests/fixtures/${f}`));
    expect(resultSchema.errors ?? []).toEqual([]);
    expect(ok).toBe(true);
  });
});
