/* CarePark-KR rule engine in JavaScript: a faithful port of the Prolog engine (engine/*.pl)
   so the website can reason live. Stratified forward chaining with NAF and builtins, the
   day-replay control layer, backward chaining with a box-model trace, why-not explanations
   and the 13 integrity constraints. The tests in tests_js/ check it against Prolog's output. */
(function (root) {
  "use strict";
  const KB = (typeof module !== "undefined" && module.exports) ? require("./kb.json") : root.CP_KB;
  const BUILTINS = new Set(KB.builtins);
  const RULES = KB.rules;                          // {id, head, body, text, group, phase}
  const FACTS = KB.facts;

  const isVar = t => typeof t === "string" && /^[A-Z_]/.test(t);
  const key = a => JSON.stringify(a);
  const fmtT = t => Array.isArray(t) ? (t[0] === "not" ? "not " + fmtT(t[1]) : t.length === 1 ? t[0] : `${t[0]}(${t.slice(1).map(fmtT).join(",")})`) : String(t);
  const pk = a => a[0] + "/" + (a.length - 1);

  /* ---------------- unification over flat atoms (arguments are constants or variables) */
  function walk(t, s) { while (isVar(t) && s.has(t)) t = s.get(t); return t; }
  function subst(a, s) { return a[0] === "not" ? ["not", subst(a[1], s)] : a.map((t, i) => i === 0 ? t : walk(t, s)); }
  function unify(a, b, s) {
    if (a.length !== b.length || a[0] !== b[0]) return null;
    let r = null;
    for (let i = 1; i < a.length; i++) {
      const x = walk(a[i], r || s), y = walk(b[i], r || s);
      if (x === y) continue;
      if (!r) r = new Map(s);
      if (isVar(x)) r.set(x, y); else if (isVar(y)) r.set(y, x); else return null;
    }
    return r || s;
  }
  function builtin(a, s) {
    const g = subst(a, s), op = g[0], x = g[1], y = g[2];
    const num = v => typeof v === "number";
    switch (op) {
      case "lt": return num(x) && num(y) && x < y ? s : null;
      case "le": return num(x) && num(y) && x <= y ? s : null;
      case "gt": return num(x) && num(y) && x > y ? s : null;
      case "ge": return num(x) && num(y) && x >= y ? s : null;
      case "eq": return unify(["eq", x], ["eq", y], s);
      case "neq": return !isVar(x) && !isVar(y) && x !== y ? s : null;
      case "add": return num(x) && num(y) ? unify(["r", g[3]], ["r", x + y], s) : null;
      case "sub": return num(x) && num(y) ? unify(["r", g[3]], ["r", x - y], s) : null;
      case "mul": return num(x) && num(y) ? unify(["r", g[3]], ["r", x * y], s) : null;
      case "cdiv": return num(x) && num(y) && y > 0 ? unify(["r", g[3]], ["r", Math.max(0, Math.floor((x + y - 1) / y))], s) : null;
    }
    return null;
  }

  /* ---------------- model with an index by predicate */
  class Model {
    constructor(facts) { this.list = []; this.keys = new Set(); this.idx = new Map(); facts.forEach(f => this.add(f)); }
    add(f) { const k = key(f); if (this.keys.has(k)) return false; this.keys.add(k); this.list.push(f); const p = pk(f); if (!this.idx.has(p)) this.idx.set(p, []); this.idx.get(p).push(f); return true; }
    has(f) { return this.keys.has(key(f)); }
    of(p) { return this.idx.get(p) || []; }
    find(pred, ...args) { return (this.idx.get(pred + "/" + args.length) || []).filter(f => args.every((a, i) => a === undefined || f[i + 1] === a)); }
  }

  /* ---------------- stratification (same relaxation as core.pl) */
  function strata() {
    const st = new Map();
    RULES.forEach(r => st.set(pk(r.head), 0));
    let changed = true;
    while (changed) {
      changed = false;
      for (const r of RULES) {
        const h = pk(r.head);
        for (const l of r.body) {
          if (l[0] !== "not" && BUILTINS.has(l[0])) continue;
          const neg = l[0] === "not", b = pk(neg ? l[1] : l), nb = st.get(b) || 0, need = neg ? nb + 1 : nb;
          if (need > st.get(h) && need < 50) { st.set(h, need); changed = true; }
        }
      }
    }
    return st;
  }
  const STRATA = strata();
  const stratumOf = r => STRATA.get(pk(r.head));

  /* ---------------- forward chaining */
  function* match(body, i, m, s) {
    if (i === body.length) { yield s; return; }
    const l = body[i];
    if (l[0] === "not") { if (!m.has(subst(l[1], s))) yield* match(body, i + 1, m, s); return; }
    if (BUILTINS.has(l[0])) { const s2 = builtin(l, s); if (s2) yield* match(body, i + 1, m, s2); return; }
    const g = subst(l, s), pool = m.of(pk(g));
    for (let j = 0, n = pool.length; j < n; j++) { const s2 = unify(g, pool[j], s); if (s2) yield* match(body, i + 1, m, s2); }
  }
  function saturate(m, rules) {
    const ns = [...new Set(rules.map(stratumOf))].sort((a, b) => a - b), log = [];
    let cycle = 0;
    for (const n of ns) {
      const rs = rules.filter(r => stratumOf(r) === n);
      for (;;) {
        const c = cycle + 1, fires = [], seen = new Set();
        for (const r of rs) {
          for (const s of match(r.body, 0, m, new Map())) {
            const h = subst(r.head, s);
            if (h.some(isVar) || m.has(h)) continue;
            const k = key(h); if (seen.has(k)) continue; seen.add(k);
            const binds = [...s.entries()].filter(([v]) => !v.startsWith("_")).map(([v, x]) => `${v}=${x}`).join(", ");
            fires.push({ cycle: c, stratum: n, rule: r.id, fact: h, binds });
          }
        }
        if (!fires.length) break;
        cycle = c;
        fires.forEach(f => { m.add(f.fact); log.push(f); });
      }
    }
    return { log, cycles: cycle };
  }

  /* ---------------- scenarios */
  function applyScenario(sc) {
    if (!sc) return FACTS.slice();
    const rm = new Set((sc.remove || []).map(key));
    const out = FACTS.filter(f => !rm.has(key(f))), have = new Set(out.map(key));
    (sc.add || []).forEach(f => { if (!have.has(key(f))) { out.push(f); have.add(key(f)); } });
    return out;
  }

  /* ---------------- control layer (allocate.pl) */
  const cmpAtom = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
  function bestPriority(m, v) { const ps = m.find("priority", v, undefined).map(f => f[2]); return ps.length ? Math.min(...ps) : 9; }
  function denialReason(m, v) {
    if (!m.has(["identified", v])) return "plate_unreadable";
    const d = (m.find("drives", undefined, v)[0] || [])[1];
    if (d && m.has(["banned", d])) return "security_ban";
    if (d && m.has(["staff_member", d]) && !m.has(["badge_valid", d])) return "badge_invalid";
    if (d && m.has(["supplier", d]) && !m.has(["delivery_window", d])) return "outside_delivery_slot";
    if (!d) return "unregistered";
    return "not_cleared";
  }
  function simulate(m) {
    const busy = [], alloc = [], decision = new Map(), waiting = [], events = [];
    const log = (t, e) => events.push({ t, e });
    m.of("occupies/2").forEach(f => {
      const s = m.find("since", f[1], undefined)[0], st = m.find("stay", f[1], undefined)[0];
      busy.push({ b: f[2], v: f[1], u: s && st ? s[2] + st[2] : 99999 });
    });
    const arrivals = m.of("arrival/2").map(f => ({ t: f[2], v: f[1] })).sort((a, b) => a.t - b.t || cmpAtom(a.v, b.v));
    const keyed = arrivals.map((a, i) => ({ t: a.t, p: bestPriority(m, a.v), i, v: a.v }))
      .sort((a, b) => a.t - b.t || a.p - b.p || a.i - b.i || cmpAtom(a.v, b.v));
    const isBusy = b => busy.some(x => x.b === b);
    function place(now, v, arr) {
      const cs = m.find("cost", v, undefined, undefined).filter(f => !isBusy(f[2])).map(f => ({ c: f[3], b: f[2] }))
        .sort((a, b) => a.c - b.c || cmpAtom(a.b, b.b));
      if (!cs.length) return false;
      const { c, b } = cs[0], stay = m.find("stay", v, undefined)[0][2], until = now + stay;
      busy.push({ b, v, u: until }); alloc.push({ v, b, from: now, to: until });
      decision.set(v, { kind: "allocate", bay: b, cost: c, priority: bestPriority(m, v), wait: now - arr });
      log(now, ["park", v, b, c]);
      return true;
    }
    function retry(now) {
      waiting.slice().sort((a, b) => a.p - b.p || a.a - b.a || cmpAtom(a.v, b.v)).forEach(w => {
        if (place(now, w.v, w.a)) waiting.splice(waiting.indexOf(w), 1);
      });
    }
    function releaseUntil(t) {
      for (;;) {
        const due = busy.filter(x => x.u <= t).sort((a, b) => a.u - b.u || cmpAtom(a.b, b.b) || cmpAtom(a.v, b.v));
        if (!due.length) return;
        const d = due[0]; busy.splice(busy.indexOf(d), 1); log(d.u, ["leave", d.v, d.b]); retry(d.u);
      }
    }
    for (const a of keyed) {
      releaseUntil(a.t);
      if (!m.has(["admitted", a.v])) { const why = denialReason(m, a.v); decision.set(a.v, { kind: "denied", reason: why }); log(a.t, ["denied", a.v, why]); }
      else if (!place(a.t, a.v, a.t)) { waiting.push({ v: a.v, p: a.p, a: a.t }); log(a.t, ["wait", a.v]); }
    }
    releaseUntil(99998);
    waiting.forEach(w => { decision.set(w.v, { kind: "unplaced" }); log(1440, ["unplaced", w.v]); });
    return { alloc, decision, events };
  }

  /* ---------------- integrity constraints (rules.pl ic/4) */
  function violations(m, alloc) {
    const v = [], add = (id, w) => v.push({ ic: id, witness: w });
    for (let i = 0; i < alloc.length; i++) for (let j = 0; j < alloc.length; j++) {
      const a = alloc[i], b = alloc[j];
      if (a.b === b.b && a.v < b.v && a.from < b.to && b.from < a.to) add("ic1", `${a.v}/${b.v} in ${a.b}`);
      if (a.v === b.v && a.b < b.b) add("ic2", `${a.v} in ${a.b} and ${b.b}`);
    }
    alloc.forEach(a => {
      const h = (m.find("height", a.v, undefined)[0] || [])[2], z = (m.find("bay_zone", a.b, undefined)[0] || [])[2];
      const l = (m.find("zone_level", z, undefined)[0] || [])[2], c = (m.find("route_clearance", l, undefined)[0] || [])[2];
      if (h > c) add("ic3", `${a.v} in ${a.b}`);
      const vc = m.find("vclass", a.v, undefined).map(f => f[2]), bt = (m.find("bay_type", a.b, undefined)[0] || [])[2];
      vc.forEach(cl => { if (!m.has(["class_fits", cl, bt])) add("ic4", `${a.v} in ${a.b}`); });
    });
    const pairs = (pred, i, j) => { const by = new Map(); m.of(pred).forEach(f => { const k = f[i]; if (!by.has(k)) by.set(k, new Set()); by.get(k).add(f[j]); }); return by; };
    pairs("drives/2", 2, 1).forEach((s, k) => { if (s.size > 1) add("ic5", `${k} driven by ${[...s].join(", ")}`); });
    pairs("vclass/2", 1, 2).forEach((s, k) => { if (s.size > 1) add("ic6", `${k} is ${[...s].join(" and ")}`); });
    pairs("bay_zone/2", 1, 2).forEach((s, k) => { if (s.size > 1) add("ic7", `${k} in ${[...s].join(", ")}`); });
    m.of("shift/3").forEach(f => { if (f[3] <= f[2]) add("ic8", `${f[1]} shift ${f[2]}-${f[3]}`); });
    m.of("staff_badge/3").forEach(f => { if (f[3] < f[2]) add("ic9", `${f[1]} badge ${f[2]}-${f[3]}`); });
    m.of("appointment/3").forEach(f => { if (!m.has(["patient", f[1]])) add("ic10", `${f[1]} has an appointment`); });
    m.of("vclass/2").forEach(f => { if (f[2] === "ambulance") m.find("drives", undefined, f[1]).forEach(d => { if (!m.has(["paramedic", d[1]])) add("ic11", `${d[1]} drives ${f[1]}`); }); });
    m.of("occupies/2").forEach(f => { if (m.has(["out_of_service", f[2]])) add("ic12", `${f[1]} in ${f[2]}`); });
    m.of("staff_member/1").forEach(f => { if (m.has(["visitor", f[1]])) add("ic13", `${f[1]} is staff and visitor`); });
    return v;
  }

  const ALERTS = ["ambulance_bay_blocked/1", "tow_request/1", "charger_hog/2", "dropoff_overstay/1", "manual_check/1",
    "security_alert/1", "notify_ward/2", "alert_trauma_team/1", "height_warning/1"];

  function runDay(sc) {
    const facts = applyScenario(sc), m = new Model(facts);
    const p1 = saturate(m, RULES.filter(r => r.phase === 1));
    const sim = simulate(m);
    sim.alloc.forEach(a => m.add(["assigned", a.v, a.b]));
    const p2 = saturate(m, RULES.filter(r => r.phase === 2));
    const alerts = []; ALERTS.forEach(p => m.of(p).forEach(f => alerts.push(f)));
    const fees = new Map(); m.of("fee/2").forEach(f => { if (!fees.has(f[1])) fees.set(f[1], f[2]); });
    const routes = new Map(); m.of("route/3").forEach(f => routes.set(f[1], f[3]));
    return { facts, m, phase1: p1.log, phase2: p2.log, cycles: p1.cycles + p2.cycles, cycles1: p1.cycles, ...sim, alerts, fees, routes, violations: violations(m, sim.alloc) };
  }
  function outcomes(day) {
    const o = {}; day.decision.forEach((d, v) => { o[v] = d.kind === "allocate" ? d.bay : d.kind === "denied" ? `denied(${d.reason})` : "unplaced"; }); return o;
  }

  /* ---------------- backward chaining with box-model trace (backward.pl) */
  function prover(facts, opts) {
    const base = new Model(facts), limit = (opts && opts.limit) || 4000, trace = [];
    let fresh = 0;
    const log = (d, port, text) => { if (trace.length < limit) trace.push({ d, port, text }); };
    function rename(r) { const n = ++fresh, mp = new Map(); const rn = a => a[0] === "not" ? ["not", rn(a[1])] : a.map((t, i) => i && isVar(t) ? (mp.has(t) ? mp.get(t) : (mp.set(t, `${t}_${n}`), `${t}_${n}`)) : t); return { id: r.id, head: rn(r.head), body: r.body.map(rn) }; }
    function* solve(g, s, d) {
      g = subst(g, s);
      if (d > 40) { log(d, "FAIL", fmtT(g)); return; }
      if (g[0] === "not") {
        log(d, "CALL", fmtT(g));
        const it = solve(g[1], s, d + 1).next();
        if (!it.done) { log(d, "FAIL", fmtT(g)); return; }
        log(d, "EXIT", fmtT(g)); yield [s, { goal: g, via: "naf", kids: [] }]; return;
      }
      if (BUILTINS.has(g[0])) {
        log(d, "CALL", fmtT(g));
        const s2 = builtin(g, s);
        if (s2) { const gg = subst(g, s2); log(d, "EXIT", fmtT(gg)); yield [s2, { goal: gg, via: "builtin", kids: [] }]; }
        else log(d, "FAIL", fmtT(g));
        return;
      }
      log(d, "CALL", fmtT(g));
      for (const f of base.of(pk(g))) {
        const s2 = unify(g, f, s);
        if (s2) { log(d, "EXIT", fmtT(f)); yield [s2, { goal: f, via: "fact", kids: [] }]; log(d, "REDO", fmtT(g)); }
      }
      for (const r0 of RULES) {
        if (r0.head[0] !== g[0] || r0.head.length !== g.length) continue;
        const r = rename(r0), s2 = unify(g, r.head, s);
        if (!s2) continue;
        log(d, "TRY", `${r.id}: ${r.body.map(b => fmtT(subst(b, s2))).join(", ")}`);
        for (const [s3, kids] of solveAll(r.body, s2, d + 1)) {
          const gg = subst(g, s3); log(d, "EXIT", fmtT(gg)); yield [s3, { goal: gg, via: r.id, kids }]; log(d, "REDO", fmtT(g));
        }
      }
      log(d, "FAIL", fmtT(g));
    }
    function* solveAll(gs, s, d) { if (!gs.length) { yield [s, []]; return; } for (const [s2, t] of solve(gs[0], s, d)) for (const [s3, rest] of solveAll(gs.slice(1), s2, d)) yield [s3, [t, ...rest]]; }
    return { solve, trace, base };
  }
  function prove(facts, goal) {
    const p = prover(facts), it = p.solve(goal, new Map(), 0).next();
    return { ok: !it.done, answer: it.done ? null : subst(goal, it.value[0]), tree: it.done ? null : it.value[1], trace: p.trace };
  }
  function holds(facts, goal) { const p = prover(facts, { limit: 0 }); return !p.solve(goal, new Map(), 0).next().done; }

  function whyNot(facts, goal, depth) {
    depth = depth || 0;
    if (goal[0] !== "not" && !BUILTINS.has(goal[0]) && holds(facts, goal)) return depth ? null : { kind: "none" };
    if (BUILTINS.has(goal[0])) return { kind: "false_comparison", goal: fmtT(goal) };
    if (goal[0] === "not") return { kind: "holds", goal: fmtT(goal[1]) };
    const rules = RULES.filter(r => r.head[0] === goal[0] && r.head.length === goal.length && unify(goal, r.head, new Map()));
    if (!rules.length) return { kind: "missing", goal: fmtT(goal) };
    if (depth > 12) return { kind: "too_deep", goal: fmtT(goal) };
    const why = [];
    for (const r of rules) {
      let s = unify(goal, r.head, new Map());
      for (const l of r.body) {
        const g = subst(l, s);
        if (g[0] === "not") { if (!holds(facts, g[1])) continue; why.push({ rule: r.id, at: fmtT(g), sub: { kind: "holds", goal: fmtT(g[1]) } }); break; }
        if (BUILTINS.has(g[0])) { const s2 = builtin(g, s); if (s2) { s = s2; continue; } why.push({ rule: r.id, at: fmtT(g), sub: { kind: "false_comparison", goal: fmtT(g) } }); break; }
        const res = prove(facts, g);
        if (res.ok) { s = unify(g, res.answer, s) || s; continue; }
        why.push({ rule: r.id, at: fmtT(g), sub: whyNot(facts, g, depth + 1) }); break;
      }
    }
    return { kind: "blocked", goal: fmtT(goal), why };
  }

  const API = { KB, RULES, FACTS, STRATA, fmtT, key, isVar, unify, builtin, Model, saturate, applyScenario, simulate,
    runDay, outcomes, prove, holds, whyNot, violations, bestPriority, denialReason, stratumOf };
  if (typeof module !== "undefined" && module.exports) module.exports = API; else root.CP = API;
})(typeof window !== "undefined" ? window : globalThis);
