// JavaScript engine vs Prolog:   node --test tests_js
import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const CP = require("../website/engine.js");
const RESULTS = require("../website/results.json");

const outcomeOf = s => s.replace(/^allocate\((\w+),.*$/, "$1");
const prologMap = r => Object.fromEntries(r.got.map(g => [g.vehicle, g.outcome]));

test("knowledge base sizes", () => {
  assert.equal(CP.FACTS.length, 431);
  assert.equal(CP.RULES.length, 97);
  assert.equal(Math.max(...CP.STRATA.values()), 2);
});

for (const r of RESULTS) {
  test(`${r.id} decisions match Prolog`, () => {
    const day = CP.runDay(r);
    assert.deepEqual(CP.outcomes(day), prologMap(r));
  });
  test(`${r.id} derived facts and cycles match Prolog`, () => {
    const day = CP.runDay(r);
    assert.equal(day.phase1.length, r.n1);
    assert.equal(day.phase2.length, r.n2);
    assert.equal(day.cycles, r.cycles);
  });
  test(`${r.id} timeline, alerts, fees and constraints match Prolog`, () => {
    const day = CP.runDay(r);
    assert.deepEqual(day.events.map(e => [e.t, e.e[0], e.e[1]]), r.events.map(e => [e.t, e.e[0], e.e[1]]));
    const alerts = day.alerts.map(CP.fmtT).sort(), want = r.alerts.filter(a => a[0] !== "route").map(CP.fmtT).sort();
    assert.deepEqual(alerts, want);
    assert.deepEqual([...new Set(day.violations.map(v => v.ic))].sort(), [...new Set(r.violations.map(v => v.ic))].sort());
    const fees = day.m.of("fee/2").map(f => [f[1], f[2]]).sort((a, b) => (a[0] + a[1]).localeCompare(b[0] + b[1]));
    const wantFees = r.fees.slice().sort((a, b) => (a[0] + a[1]).localeCompare(b[0] + b[1]));
    assert.deepEqual(fees, wantFees);
  });
}

test("backward chaining agrees with forward chaining (baseline)", () => {
  const day = CP.runDay(null);
  for (const f of day.phase1) assert.ok(CP.holds(day.facts, f.fact), CP.fmtT(f.fact));
});
test("why-not reaches the failing comparison for Bushra", () => {
  const e = CP.whyNot(CP.FACTS, ["badge_valid", "bushra"]);
  assert.equal(e.why[0].sub.kind, "false_comparison");
  assert.equal(e.why[0].sub.goal, "ge(20261031,20261110)");
});
test("why-not reports the ban as a holding negation", () => {
  const e = CP.whyNot(CP.FACTS, ["cleared", "waqar"]);
  assert.ok(e.why.some(w => w.rule === "a3" && w.sub.kind === "holds"));
});
test("proof tree uses NAF and builtins", () => {
  const r = CP.prove(CP.FACTS, ["admitted", "wv_no"]);
  assert.ok(r.ok);
  const vias = []; (function walk(t) { vias.push(t.via); t.kids.forEach(walk); })(r.tree);
  assert.ok(vias.includes("naf") && vias.includes("builtin") && vias.includes("a7"));
});
