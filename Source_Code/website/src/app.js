/* CarePark control room: page controller. Runs the rule engine (engine.js), renders every view
   and drives the 3D twin through window.CPAttachTwin. */
(function () {
  "use strict";
  const CP = window.CP, RES = window.CP_RESULTS, SITE = window.CP_SITE, KB = window.CP_KB;
  const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const hhmm = t => `${String(Math.floor(t / 60)).padStart(2, "0")}:${String(t % 60).padStart(2, "0")}`;
  const fmt = CP.fmtT;
  const PEOPLE = Object.fromEntries(SITE.people.map(p => [p.vehicle, p]));
  const NAME = v => PEOPLE[v] ? cap(PEOPLE[v].person) : ({ ev_zb: "Dr Zubair", car_hm: "Hamid", car_lb: "Lubna", car_qx: "Unknown car", car_qy: "Unknown car", taxi_1: "Taxi", amb_rz: "Raza (2nd ambulance)" }[v] || v);
  const cap = s => s.charAt(0).toUpperCase() + s.slice(1);
  const REASON = { plate_unreadable: "camera could not read the plate (under 90%)", security_ban: "on the security ban list", badge_invalid: "staff badge has expired",
    outside_delivery_slot: "arrived outside the delivery slot", unregistered: "vehicle not registered", not_cleared: "not cleared" };
  const ALERT_TEXT = { ambulance_bay_blocked: "Ambulance bay blocked", tow_request: "Tow request", charger_hog: "Charger hogged by a full EV", dropoff_overstay: "Drop-off overstay",
    manual_check: "Manual plate check", security_alert: "Security alert", notify_ward: "Ward notified", alert_trauma_team: "Trauma team alerted", height_warning: "Too tall for upper levels" };
  const ALERT_KIND = { ambulance_bay_blocked: "c-emerg", tow_request: "c-emerg", security_alert: "c-emerg", alert_trauma_team: "c-emerg", charger_hog: "c-amber", dropoff_overstay: "c-amber", manual_check: "c-amber", notify_ward: "c-info", height_warning: "c-info" };

  const state = { sc: null, day: null, t: 360, sel: null, playing: false, speed: 1 };
  let twin = null; const pending = [];
  window.CPAttachTwin = api => { twin = api; pending.splice(0).forEach(f => f()); };
  const withTwin = f => twin ? f() : pending.push(f);

  /* ---------------- theme ---------------- */
  (function () {
    const root = document.documentElement;
    try { const t = localStorage.getItem("cp-theme"); if (t) root.dataset.theme = t; } catch (e) { /* blocked */ }
    const dark = () => root.dataset.theme ? root.dataset.theme === "dark" : matchMedia("(prefers-color-scheme: dark)").matches;
    const label = () => { $("#themeBtn").textContent = dark() ? "Light theme" : "Dark theme"; };
    label();
    $("#themeBtn").addEventListener("click", () => { root.dataset.theme = dark() ? "light" : "dark"; try { localStorage.setItem("cp-theme", root.dataset.theme); } catch (e) { /* */ } label(); withTwin(() => twin.retheme()); });
    matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => { label(); withTwin(() => twin.retheme()); });
  })();

  /* ---------------- router ---------------- */
  const VIEWS = ["twin", "reasoning", "knowledge", "scenarios", "project"];
  function route() {
    const v = VIEWS.includes(location.hash.slice(1)) ? location.hash.slice(1) : "twin";
    VIEWS.forEach(x => { $(`#v-${x}`).hidden = x !== v; });
    $$(".rail a").forEach(a => a.setAttribute("aria-current", a.dataset.v === v ? "page" : "false"));
    if (v === "knowledge" && !netDone) drawNet();
    if (v === "twin") withTwin(() => twin.resize());
  }
  addEventListener("hashchange", route);

  /* ---------------- scenario loading ---------------- */
  function scenarioById(id) { return RES.find(r => r.id === id); }
  $("#scSel").innerHTML = RES.map(r => `<option value="${r.id}">${r.id.toUpperCase()} · ${esc(r.title)}</option>`).join("");
  $("#scSel").addEventListener("change", e => load(e.target.value === "custom" ? state.custom : scenarioById(e.target.value)));

  function load(sc, keepTime) {
    state.sc = sc; state.day = CP.runDay(sc.id === "tc01" ? null : sc);
    if (!keepTime) state.t = 360;
    state.sel = null;
    $("#twinLede").textContent = sc.story;
    renderTimeline(); renderFeed(); renderAlerts(); renderCard(); renderGrid(); renderRules(); renderDL(); renderFOL(); ask();
    withTwin(() => { twin.load(state.day); twin.setTime(state.t, false); });
    tick(false);
  }

  /* ---------------- twin side panels ---------------- */
  const decisionOf = v => state.day.decision.get(v);
  function presentAt(t) {
    const d = state.day, parked = d.alloc.filter(a => a.from <= t && t < a.to).length;
    const denied = d.events.filter(e => e.e[0] === "denied" && e.t <= t).length;
    return { parked, denied };
  }
  function tick(animate) {
    const t = state.t, p = presentAt(t);
    $("#clock").textContent = hhmm(t);
    $("#clockSub").textContent = `${p.parked} parked by the system · ${p.denied} denied`;
    $("#tlRange").value = t;
    $$("#feed button").forEach(b => { const et = +b.dataset.t; b.classList.toggle("past", et < t - 0); b.classList.toggle("now", Math.abs(et - t) < 1); });
    renderLevels(t);
    withTwin(() => twin.setTime(t, animate));
  }
  function renderLevels(t) {
    const d = state.day, m = d.m, levels = SITE.building.levels;
    const bayLevel = b => { const z = (m.find("bay_zone", b, undefined)[0] || [])[2]; return (m.find("zone_level", z, undefined)[0] || [])[2]; };
    const occ = {}; const tot = {};
    SITE.building.bays.forEach(([b]) => { const l = bayLevel(b); tot[l] = (tot[l] || 0) + 1; });
    const busy = new Set(d.alloc.filter(a => a.from <= t && t < a.to).map(a => a.b));
    m.of("occupies/2").forEach(f => { const s = (m.find("since", f[1], undefined)[0] || [0, 0, 0])[2], st = (m.find("stay", f[1], undefined)[0] || [0, 0, 99999])[2]; if (s <= t && t < s + st) busy.add(f[2]); });
    busy.forEach(b => { const l = bayLevel(b); occ[l] = (occ[l] || 0) + 1; });
    $("#levelBars").innerHTML = levels.slice().reverse().map(([l]) => {
      const o = occ[l] || 0, n = tot[l] || 1;
      return `<div class="lvl"><b>${l === "g" ? "G" : l === "roof" ? "R" : l.toUpperCase()}</b><div class="lvl__bar"><i style="width:${Math.round(100 * o / n)}%"></i></div><span>${o}/${n}</span></div>`;
    }).join("");
  }
  function renderTimeline() {
    const track = $("#tlTrack"), lo = 360, hi = 1200, X = t => `${(100 * (t - lo) / (hi - lo)).toFixed(2)}%`;
    track.querySelectorAll(".tl__ev,.tl__tick,.tl__vis").forEach(e => e.remove());
    const frag = document.createDocumentFragment();
    state.day.m.of("visiting_window/2").forEach(f => { const d = document.createElement("div"); d.className = "tl__vis"; d.style.left = X(Math.max(lo, f[1])); d.style.width = `${100 * (Math.min(hi, f[2]) - Math.max(lo, f[1])) / (hi - lo)}%`; frag.appendChild(d); });
    for (let h = 6; h <= 20; h += 2) { const d = document.createElement("div"); d.className = "tl__tick"; d.style.left = X(h * 60); d.textContent = `${String(h).padStart(2, "0")}:00`; frag.appendChild(d); }
    state.day.events.forEach(ev => {
      if (ev.t < lo || ev.t > hi) return;
      const b = document.createElement("button"); b.type = "button"; b.className = `tl__ev k-${ev.e[0]}`; b.style.left = X(ev.t);
      b.title = `${hhmm(ev.t)} ${NAME(ev.e[1])}: ${ev.e[0]}`; b.setAttribute("aria-label", b.title);
      b.addEventListener("click", () => { stop(); state.t = ev.t; select(ev.e[1]); tick(false); });
      frag.appendChild(b);
    });
    track.appendChild(frag);
  }
  function renderFeed() {
    $("#feed").innerHTML = state.day.events.filter(e => e.e[0] !== "leave").map(ev => {
      const [k, v] = ev.e, d = decisionOf(v);
      const what = k === "park" ? `<span class="chip c-sign">${ev.e[2]}</span>` : k === "denied" ? `<span class="chip c-emerg">denied</span>` : k === "wait" ? `<span class="chip c-amber">waits</span>` : `<span class="chip c-mute">${k}</span>`;
      return `<button type="button" data-t="${ev.t}" data-v="${v}"><time>${hhmm(ev.t)}</time><span>${esc(NAME(v))} <span class="muted">${esc(v)}</span></span>${what}</button>`;
    }).join("");
  }
  $("#feed").addEventListener("click", e => { const b = e.target.closest("button"); if (!b) return; stop(); state.t = +b.dataset.t; select(b.dataset.v); tick(false); });
  function renderAlerts() {
    const al = state.day.alerts;
    $("#alerts").innerHTML = al.length ? al.map(a => `<div style="display:flex;gap:8px;align-items:baseline"><span class="chip ${ALERT_KIND[a[0]] || "c-mute"}">${ALERT_TEXT[a[0]] || a[0]}</span><span class="mono">${esc(fmt(a).replace(a[0], ""))}</span></div>`).join("")
      : `<span class="muted">No alerts.</span>`;
    const v = state.day.violations;
    if (v.length) $("#alerts").insertAdjacentHTML("beforeend", v.map(x => `<div style="display:flex;gap:8px"><span class="chip c-emerg">${x.ic.toUpperCase()}</span><span>${esc(x.witness)}</span></div>`).join(""));
  }

  function steps(v) {
    const m = state.day.m, has = a => m.has(a), out = [];
    const d = (m.find("drives", undefined, v)[0] || [])[1];
    const anpr = (m.find("anpr", v, undefined)[0] || [])[2];
    if (has(["emergency_vehicle", v])) out.push(["ok", `emergency_vehicle(${v}): ambulance on a run`, "h17"]);
    if (has(["emergency_declared", v])) out.push(["ok", `emergency_declared(${v}) at the intercom`, "a6"]);
    out.push([has(["identified", v]) ? "ok" : "no", `plate read at ${anpr}%`, "s1"]);
    if (d) {
      if (has(["staff_member", d])) out.push([has(["badge_valid", d]) ? "ok" : "no", `badge_valid(${d})`, "s4"]);
      if (has(["banned", d])) out.push(["no", `banned(${d}): NAF in a1-a4 fails`, "s5"]);
      if (has(["supplier", d])) out.push([has(["delivery_window", d]) ? "ok" : "no", `delivery_window(${d})`, "t4"]);
      if (m.find("shift", d, undefined, undefined).length) out.push([has(["on_shift", d]) ? "ok" : "mid", `on_shift(${d})`, "t1"]);
      if (m.find("appointment", d, undefined, undefined).length) out.push([has(["in_appointment_window", d]) ? "ok" : "mid", `in_appointment_window(${d})`, "t2"]);
      if (has(["visitor", d])) out.push([has(["visiting_time", v]) ? "ok" : "mid", `visiting_time(${v})`, "t3"]);
    }
    out.push([has(["admitted", v]) ? "ok" : "no", `admitted(${v})`, has(["emergency_vehicle", v]) ? "a5" : has(["emergency_declared", v]) ? "a6" : "a7"]);
    if (m.find("too_tall", v, "l1").length) out.push(["mid", `too_tall(${v}, l1): ground floor only`, "f2"]);
    const zones = m.find("entitled", v, undefined).map(f => f[2]);
    if (zones.length) out.push(["ok", `entitled to ${zones.map(z => z.replace("z_", "")).join(", ")}`, "e*"]);
    return out;
  }
  function costRows(v) {
    const m = state.day.m, rows = new Map();
    m.find("cost", v, undefined, undefined).forEach(f => { if (!rows.has(f[2]) || rows.get(f[2]) > f[3]) rows.set(f[2], f[3]); });
    return [...rows.entries()].sort((a, b) => a[1] - b[1] || (a[0] < b[0] ? -1 : 1));
  }
  function renderCard() {
    const v = state.sel;
    if (!v) {
      $("#vehCard").innerHTML = `<h3>Select a vehicle</h3><p class="muted" style="margin:6px 0 0;font-size:13.5px">Click a car in the twin, a marker on the timeline or a row in the gate log to see how the rules decided its bay.</p>`;
      return;
    }
    const m = state.day.m, p = PEOPLE[v], d = decisionOf(v), dr = (m.find("drives", undefined, v)[0] || [])[1];
    const cls = (m.find("vclass", v, undefined)[0] || [])[2], h = (m.find("height", v, undefined)[0] || [])[2];
    const arr = (m.find("arrival", v, undefined)[0] || [])[2], stay = (m.find("stay", v, undefined)[0] || [])[2];
    const dest = dr ? (m.find("destination", dr, undefined)[0] || [])[2] : null;
    const fee = (m.find("fee", v, undefined)[0] || [])[2], route = state.day.routes.get(v);
    const pri = CP.bestPriority(m, v);
    let head = "", chips = "";
    if (!d) { head = "Parked before 06:00"; chips = `<span class="chip c-mute">overnight</span>`; }
    else if (d.kind === "allocate") { head = `Bay ${d.bay.toUpperCase()}`; chips = `<span class="chip c-sign">cost ${d.cost} m</span> <span class="chip ${pri === 0 ? "c-emerg" : "c-info"}">priority ${pri}</span>${d.wait ? ` <span class="chip c-amber">waited ${d.wait} min</span>` : ""}`; }
    else if (d.kind === "denied") { head = "Entry denied"; chips = `<span class="chip c-emerg">${esc(REASON[d.reason] || d.reason)}</span>`; }
    else { head = "Never placed"; chips = `<span class="chip c-amber">no bay all day</span>`; }
    const rows = costRows(v).slice(0, 6);
    const w = state.day.alloc.find(a => a.v === v);
    $("#vehCard").innerHTML = `<p class="eyebrow" style="margin:0">${esc(NAME(v))} · ${esc(p ? p.role : dr || "")}</p><h3>${head}</h3><div style="margin-top:6px;display:flex;gap:4px;flex-wrap:wrap">${chips}</div>
      <dl class="dlist"><dt>Vehicle</dt><dd class="mono">${v} · ${cls} · ${h} cm</dd>${arr !== undefined ? `<dt>Arrives</dt><dd>${hhmm(arr)} · stays ${stay} min</dd>` : ""}
      ${dest ? `<dt>Going to</dt><dd>${dest}</dd>` : ""}${w ? `<dt>In bay</dt><dd>${hhmm(w.from)} to ${hhmm(Math.min(w.to, 1439))}${route ? ` · ${route.replace(/_/g, " ")}` : ""}</dd>` : ""}
      ${fee !== undefined ? `<dt>Fee</dt><dd>PKR ${fee}</dd>` : ""}</dl>
      <ul class="reasons">${steps(v).map(([c, t, r]) => `<li><span class="${c}">${c === "ok" ? "✓" : c === "no" ? "✗" : "•"}</span><span>${esc(t)}</span><span class="rid">${r}</span></li>`).join("")}</ul>
      ${rows.length ? `<table class="t" style="margin-top:10px"><thead><tr><th>Candidate</th><th>Cost m</th></tr></thead><tbody>${rows.map(([b, c]) => `<tr><td class="m">${b}${d && d.bay === b ? " ← chosen" : ""}</td><td class="m">${c}</td></tr>`).join("")}</tbody></table>` : ""}
      <div style="display:flex;gap:6px;margin-top:10px;flex-wrap:wrap"><button class="btn" type="button" data-ask="${d && d.kind === "denied" ? `admitted(${v})` : `candidate(${v}, ${d && d.bay ? d.bay : "B"})`}">${d && d.kind === "denied" ? "Why denied?" : "Prove it"}</button></div>`;
  }
  $("#vehCard").addEventListener("click", e => { const b = e.target.closest("[data-ask]"); if (!b) return; $("#askIn").value = b.dataset.ask; location.hash = "reasoning"; ask(); });
  function select(v) { state.sel = v; renderCard(); withTwin(() => twin.select(v)); }

  /* ---------------- playback ---------------- */
  let timer = null;
  function stop() { state.playing = false; clearInterval(timer); $("#playBtn").textContent = state.t >= 1200 ? "Replay the day" : "Play the day"; }
  $("#playBtn").addEventListener("click", () => {
    if (state.playing) { stop(); return; }
    if (state.t >= 1200) state.t = 360;
    state.playing = true; $("#playBtn").textContent = "Pause";
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
    timer = setInterval(() => { state.t = Math.min(1200, state.t + (reduce ? 15 : 1) * state.speed); tick(!reduce); if (state.t >= 1200) stop(); }, reduce ? 400 : 90);
  });
  $("#speedBtn").addEventListener("click", () => { state.speed = state.speed === 1 ? 3 : state.speed === 3 ? 8 : 1; $("#speedBtn").textContent = `Speed ×${state.speed}`; });
  $("#endBtn").addEventListener("click", () => { stop(); state.t = 1200; tick(false); });
  $("#tlRange").addEventListener("input", e => { stop(); state.t = +e.target.value; tick(false); });
  $("#explodeBtn").addEventListener("click", e => { const on = e.currentTarget.getAttribute("aria-pressed") !== "true"; e.currentTarget.setAttribute("aria-pressed", on); withTwin(() => twin.explode(on)); });
  $("#resetCam").addEventListener("click", () => withTwin(() => twin.resetView()));
  $("#idsBtn").addEventListener("click", e => { const on = e.currentTarget.getAttribute("aria-pressed") !== "true"; e.currentTarget.setAttribute("aria-pressed", on); withTwin(() => twin.ids(on)); });

  /* ---------------- reasoning bench ---------------- */
  const EX = ["admitted(car_bu)", "admitted(car_wq)", "admitted(car_ya)", "fits(wv_no, pt1)", "candidate(ev_sa, ev1)", "cost(car_ru, mt1, C)", "entitled(car_ks, z_visit)", "fee(car_ru, F)", "priority(amb_fa, P)", "route(car_im, B, R)", "dropoff_overstay(car_ks)"];
  $("#examples").innerHTML = EX.map(g => `<button type="button">${g}</button>`).join("");
  $("#examples").addEventListener("click", e => { if (e.target.matches("button")) { $("#askIn").value = e.target.textContent; ask(); } });
  $("#askForm").addEventListener("submit", e => { e.preventDefault(); ask(); });
  function parse(t) {
    const mm = /^\s*([a-z_]\w*)\s*(?:\((.*)\))?\s*\.?\s*$/.exec(t);
    if (!mm) return null;
    return [mm[1], ...(mm[2] ? mm[2].split(",").map(s => s.trim()).filter(Boolean).map(a => /^-?\d+$/.test(a) ? +a : a) : [])];
  }
  function factsForProof() { return state.day.facts.concat(state.day.alloc.map(a => ["assigned", a.v, a.b])); }
  function ask() {
    const g = parse($("#askIn").value);
    if (!g) { $("#verdict").innerHTML = `<span class="chip c-emerg">syntax</span> write a goal such as admitted(car_bu); variables start with a capital letter`; $("#graph").innerHTML = ""; $("#trace").textContent = ""; return; }
    const r = CP.prove(factsForProof(), g);
    $("#trace").innerHTML = r.trace.slice(0, 900).map(l => `<span class="${l.port}">${esc("|  ".repeat(l.d) + (l.port === "TRY" ? "     try " : l.port.padEnd(5)) + " " + l.text)}</span>`).join("\n") + (r.trace.length > 900 ? `\n… ${r.trace.length - 900} more lines` : "");
    if (r.ok) {
      $("#verdict").innerHTML = `<span class="chip c-sign">proved</span> ${esc(fmt(r.answer))} <span class="muted">· ${r.trace.length} trace lines</span>`;
      drawTree(toNode(r.tree));
    } else {
      const w = CP.whyNot(factsForProof(), g);
      $("#verdict").innerHTML = `<span class="chip c-emerg">not provable</span> ${esc(fmt(g))} fails under negation as failure. The graph shows why, rule by rule.`;
      drawTree(whyNode(w, fmt(g)));
    }
  }
  const toNode = t => ({ label: fmt(t.goal), tag: t.via, kind: t.via === "fact" ? "fact" : t.via === "builtin" ? "builtin" : t.via === "naf" ? "naf" : "rule", kids: t.kids.map(toNode) });
  function whyNode(w, label) {
    if (!w || w.kind === "none") return { label, tag: "provable", kind: "rule", kids: [] };
    if (w.kind === "missing") return { label: w.goal, tag: "no such fact", kind: "bad", kids: [] };
    if (w.kind === "false_comparison") return { label: w.goal, tag: "false", kind: "bad", kids: [] };
    if (w.kind === "holds") return { label: `${w.goal} holds`, tag: "NAF fails", kind: "naf", kids: [] };
    if (w.kind === "too_deep") return { label: w.goal, tag: "stopped", kind: "bad", kids: [] };
    return { label: w.goal || label, tag: "blocked", kind: "bad", kids: w.why.map(x => ({ label: x.at, tag: x.rule, kind: "rule", kids: [whyNode(x.sub, x.at)] })) };
  }
  function drawTree(root) {
    const W = n => Math.max(90, n.label.length * 7.3 + 22), H = 30, gx = 14, gy = 30;
    let x = 0, maxD = 0;
    (function lay(n, d) { n.d = d; maxD = Math.max(maxD, d); if (!n.kids.length) { n.x = x + W(n) / 2; x += W(n) + gx; } else { n.kids.forEach(k => lay(k, d + 1)); n.x = (n.kids[0].x + n.kids[n.kids.length - 1].x) / 2; n.x = Math.max(n.x, x === 0 ? W(n) / 2 : n.x); } })(root, 0);
    let minX = Infinity, maxX = 0; (function b(n) { minX = Math.min(minX, n.x - W(n) / 2); maxX = Math.max(maxX, n.x + W(n) / 2); n.kids.forEach(b); })(root);
    const off = 12 - minX, wd = maxX - minX + 24, ht = (maxD + 1) * (H + gy) + 20, parts = [];
    (function draw(n) {
      const cx = n.x + off, cy = 14 + n.d * (H + gy);
      n.kids.forEach(k => { const kx = k.x + off, ky = 14 + k.d * (H + gy); parts.push(`<path class="lk" d="M${cx} ${cy + H} C${cx} ${cy + H + gy / 2} ${kx} ${ky - gy / 2} ${kx} ${ky}"/>`); draw(k); });
      parts.push(`<g class="nd v-${n.kind}"><rect x="${cx - W(n) / 2}" y="${cy}" width="${W(n)}" height="${H}" rx="5"/><text x="${cx}" y="${cy + 19}" text-anchor="middle">${esc(n.label)}</text>${n.tag ? `<text class="tag" x="${cx + W(n) / 2 - 4}" y="${cy - 3}" text-anchor="end" fill="currentColor" style="fill:var(--ink-2)">${esc(n.tag)}</text>` : ""}</g>`);
    })(root);
    $("#graph").innerHTML = `<svg width="${Math.max(wd, 300)}" height="${ht}" viewBox="0 0 ${Math.max(wd, 300)} ${ht}" role="img" aria-label="Proof graph">${parts.join("")}</svg>`;
  }

  // strata x cycles
  function renderGrid() {
    const logs = [["Phase 1", state.day.phase1], ["Phase 2", state.day.phase2.map(f => ({ ...f, cycle: f.cycle + state.day.cycles1 }))]];
    const all = logs.flatMap(([ph, l]) => l.map(f => ({ ...f, ph })));
    const maxC = state.day.cycles, rows = [];
    logs.forEach(([ph, l]) => { [...new Set(l.map(f => f.stratum))].sort().forEach(s => rows.push({ ph, s })); });
    const count = (ph, s, c) => all.filter(f => f.ph === ph && f.stratum === s && f.cycle === c).length;
    const mx = Math.max(1, ...rows.flatMap(r => Array.from({ length: maxC }, (_, i) => count(r.ph, r.s, i + 1))));
    let h = `<div class="grid-wrap"><div class="grid-sc" style="grid-template-columns:120px repeat(${maxC}, minmax(22px, 1fr))"><div></div>${Array.from({ length: maxC }, (_, i) => `<div class="hd">${i + 1}</div>`).join("")}`;
    rows.forEach(r => {
      h += `<div class="hd" style="justify-items:start">${r.ph} · stratum ${r.s}</div>`;
      for (let c = 1; c <= maxC; c++) { const n = count(r.ph, r.s, c); h += n ? `<button class="cell" type="button" data-ph="${r.ph}" data-s="${r.s}" data-c="${c}" style="background:color-mix(in srgb, var(--sign) ${Math.round(15 + 85 * Math.sqrt(n / mx))}%, var(--panel))" title="${n} new facts">${n}</button>` : `<div class="cell" style="background:var(--well);cursor:default"></div>`; }
    });
    h += `</div></div><p class="muted" style="font-size:12.5px;margin:10px 0 0">${state.day.facts.length} facts in · ${state.day.phase1.length} derived in phase 1 · ${state.day.phase2.length} in phase 2 · ${maxC} cycles in all</p>`;
    $("#scGrid").innerHTML = h;
    showFires("Phase 1", 0, 1);
  }
  function showFires(ph, s, c) {
    const l = ph === "Phase 1" ? state.day.phase1 : state.day.phase2.map(f => ({ ...f, cycle: f.cycle + state.day.cycles1 }));
    const f = l.filter(x => x.stratum === s && x.cycle === c);
    $("#fireHead").innerHTML = `<span class="chip c-sign">${ph} · stratum ${s} · cycle ${c}</span> ${f.length} new facts`;
    $("#fires").innerHTML = f.slice(0, 300).map(x => `<div><span class="rid">${x.rule}</span><span>${esc(fmt(x.fact))} <em>{${esc(x.binds)}}</em></span></div>`).join("") + (f.length > 300 ? `<div><span></span><em>… ${f.length - 300} more</em></div>` : "");
  }
  $("#scGrid").addEventListener("click", e => { const b = e.target.closest("button.cell"); if (b) showFires(b.dataset.ph, +b.dataset.s, +b.dataset.c); });

  /* ---------------- knowledge ---------------- */
  $$("#ktabs button").forEach(b => b.addEventListener("click", () => {
    $$("#ktabs button").forEach(x => x.setAttribute("aria-selected", x === b));
    $$(".kpane").forEach(p => { p.hidden = p.id !== b.dataset.k; });
    if (b.dataset.k === "k-net") drawNet();
  }));
  // frames
  const FR = Object.fromEntries(SITE.frames.map(f => [f.name, f]));
  const srcCls = h => h === "local value" || h.startsWith("value put") ? "c-sign" : h.startsWith("inherited") ? "c-amber" : h.startsWith("if-needed") ? "c-info" : "c-mute";
  function renderFrameList(sel) {
    const inst = SITE.frames.filter(f => f.kind === "instance"), cls = SITE.frames.filter(f => f.kind === "class");
    $("#frameList").innerHTML = `<h4>Instance frames (${inst.length})</h4>${inst.map(f => `<button type="button" data-f="${f.name}" aria-current="${f.name === sel}">${f.name}<span class="muted">${f.chain[1]}</span></button>`).join("")}
      <h4>Class frames (${cls.length})</h4>${cls.map(f => `<button type="button" data-f="${f.name}" aria-current="${f.name === sel}">${f.name}<span class="muted">${f.chain[1] || ""}</span></button>`).join("")}`;
  }
  function showFrame(n) {
    const f = FR[n]; renderFrameList(n);
    $("#frameHead").innerHTML = `<p class="eyebrow" style="margin:0">${f.kind} frame</p><h3 style="font-size:24px">${f.name}</h3><p class="mono muted" style="margin:6px 0 0">is-a order: ${f.chain.map(esc).join(" → ")}</p>`;
    $("#frameTable").innerHTML = `<thead><tr><th>Slot</th><th>Value</th><th>Where it came from</th><th>Facets</th><th>Declared in</th></tr></thead><tbody>${f.rows.map(([s, v, h, fa, own]) =>
      `<tr><td class="m">${s}</td><td class="m">${v === null ? '<span class="muted">-</span>' : esc(v)}</td><td>${v === null ? "" : `<span class="src ${srcCls(h)}">${esc(h)}</span>`}</td><td class="muted" style="font-size:12.5px">${esc(fa)}</td><td class="m">${own}</td></tr>`).join("")}</tbody>`;
  }
  $("#frameList").addEventListener("click", e => { const b = e.target.closest("button[data-f]"); if (b) showFrame(b.dataset.f); });
  showFrame("noor");

  // semantic network: deterministic force layout
  let netDone = false;
  function drawNet() {
    if (netDone || $("#k-net").hidden) return; netDone = true;
    const L = SITE.links, names = [...new Set(L.flatMap(l => [l[0], l[2]]))];
    const isInst = n => /^[a-z]/.test(n), N = names.map((n, i) => ({ n, x: 500 + 380 * Math.cos(i * 2.399), y: 320 + 260 * Math.sin(i * 2.399), vx: 0, vy: 0 }));
    const idx = Object.fromEntries(N.map((d, i) => [d.n, i])), E = L.map(([a, r, b]) => ({ a: idx[a], b: idx[b], r }));
    for (let it = 0; it < 420; it++) {
      const k = 1 - it / 420;
      for (let i = 0; i < N.length; i++) for (let j = i + 1; j < N.length; j++) { const dx = N[i].x - N[j].x, dy = N[i].y - N[j].y, d2 = Math.max(dx * dx + dy * dy, 30), f = 2600 / d2; N[i].vx += dx * f / Math.sqrt(d2); N[i].vy += dy * f / Math.sqrt(d2); N[j].vx -= dx * f / Math.sqrt(d2); N[j].vy -= dy * f / Math.sqrt(d2); }
      E.forEach(e => { const A = N[e.a], B = N[e.b], dx = B.x - A.x, dy = B.y - A.y, d = Math.sqrt(dx * dx + dy * dy) || 1, f = (d - 70) * 0.02; A.vx += dx / d * f * d * 0.05; A.vy += dy / d * f * d * 0.05; B.vx -= dx / d * f * d * 0.05; B.vy -= dy / d * f * d * 0.05; });
      E.forEach(e => { if (e.r === "is_a" || e.r === "instance_of") { N[e.b].vy -= 0.6; N[e.a].vy += 0.6; } });
      N.forEach(d => { d.vx += (500 - d.x) * 0.004; d.vy += (320 - d.y) * 0.004; d.x += Math.max(-12, Math.min(12, d.vx)) * k; d.y += Math.max(-12, Math.min(12, d.vy)) * k; d.vx *= 0.5; d.vy *= 0.5; });
    }
    let mnx = Infinity, mxx = -Infinity, mny = Infinity, mxy = -Infinity; N.forEach(d => { mnx = Math.min(mnx, d.x); mxx = Math.max(mxx, d.x); mny = Math.min(mny, d.y); mxy = Math.max(mxy, d.y); });
    const svg = $("#netSvg"); svg.setAttribute("viewBox", `${mnx - 70} ${mny - 30} ${mxx - mnx + 140} ${mxy - mny + 60}`);
    const color = n => isInst(n) ? "var(--ink-2)" : /Bay|Zone|Level|CarPark|Gate|Ramp|Hospital|Department|Charger|Sensor|Board|Clearance|Barrier|Camera/.test(n) ? "var(--info)" : /Vehicle|Car|Van|Ambulance|Motorcycle|SUV|Plate|Battery|Siren/.test(n) ? "var(--amber)" : "var(--sign)";
    function paint() {
      svg.innerHTML = E.map((e, i) => `<line class="lnk ${e.r}" data-i="${i}" x1="${N[e.a].x}" y1="${N[e.a].y}" x2="${N[e.b].x}" y2="${N[e.b].y}"/>`).join("") +
        N.map((d, i) => `<g class="nodeg" data-i="${i}" transform="translate(${d.x},${d.y})"><circle r="${isInst(d.n) ? 6 : 9}" fill="${color(d.n)}"/><text x="12" y="4">${esc(d.n)}</text></g>`).join("");
    }
    paint();
    $("#netLegend").innerHTML = `<span><i style="border-color:var(--ink-2)"></i>is_a / instance_of</span><span><i style="border-color:var(--rule);border-top-style:dashed"></i>part_of</span><span><i style="border-color:var(--sign)"></i>has_a</span><span><i style="border-color:var(--rule)"></i>named relation</span><span>● people</span><span style="color:var(--amber)">● vehicles</span><span style="color:var(--info)">● facility</span><span>${N.length} nodes · ${E.length} links</span>`;
    let drag = null;
    svg.addEventListener("pointerdown", e => { const g = e.target.closest(".nodeg"); if (!g) return; drag = +g.dataset.i; svg.setPointerCapture(e.pointerId); highlight(drag); });
    svg.addEventListener("pointermove", e => { if (drag === null) return; const pt = svg.createSVGPoint(); pt.x = e.clientX; pt.y = e.clientY; const p = pt.matrixTransform(svg.getScreenCTM().inverse()); N[drag].x = p.x; N[drag].y = p.y; paint(); highlight(drag); });
    svg.addEventListener("pointerup", () => { drag = null; });
    function highlight(i) {
      const n = N[i].n, up = [n], es = new Set();
      for (let q = 0; q < up.length; q++) E.forEach((e, k) => { if (N[e.a].n === up[q] && (e.r === "is_a" || e.r === "instance_of")) { es.add(k); if (!up.includes(N[e.b].n)) up.push(N[e.b].n); } });
      const parts = []; E.forEach((e, k) => { if (e.r === "has_a" && up.includes(N[e.a].n)) { es.add(k); parts.push(`${N[e.b].n} (from ${N[e.a].n})`); } });
      svg.querySelectorAll(".lnk").forEach(l => l.classList.toggle("hl", es.has(+l.dataset.i)));
      svg.querySelectorAll(".nodeg").forEach(g => g.classList.toggle("hl", up.includes(N[+g.dataset.i].n)));
      $("#netOut").textContent = up.length > 1 ? `${n} → ${up.slice(1).join(" → ")}${parts.length ? `. Inherited parts: ${parts.join(", ")}.` : "."}` : `${n} has no is-a parent.`;
    }
  }

  // FOL
  function renderFOL() {
    const r = state.sc && state.sc.fol ? Object.fromEntries(state.sc.fol) : {};
    $("#folTable").innerHTML = `<thead><tr><th>ID</th><th>Statement</th><th>Formula</th><th>Runs as</th><th>Check, ${esc(state.sc ? state.sc.id.toUpperCase() : "")}</th></tr></thead><tbody>${SITE.fol.map(f =>
      `<tr><td class="m">${f.id}</td><td>${esc(f.english)}</td><td class="m">${esc(f.formula)}</td><td>${esc(f.runs)}${f.horn ? "" : ' <span class="chip c-amber">beyond Horn</span>'}</td><td>${f.horn ? '<span class="muted">runs as rules</span>' : r[f.id] ? (r[f.id] === "holds" ? '<span class="chip c-sign">holds</span>' : '<span class="chip c-emerg">violated</span>') : '<span class="muted">Prolog only</span>'}</td></tr>`).join("")}</tbody>`;
  }
  // DL
  const SUB = SITE.tbox.subsumption.map(s => s.split(" ⊑ ")), DISJ = SITE.tbox.disjoint.map(s => s.replace(" ⊑ ⊥", "").split(" ⊓ "));
  const anc = c => { const out = [], q = [c]; while (q.length) { const x = q.shift(); SUB.forEach(([a, b]) => { if (a === x && !out.includes(b)) { out.push(b); q.push(b); } }); } return out; };
  $("#tbox").innerHTML = `<h4>Subsumption (${SITE.tbox.subsumption.length})</h4><ul>${SITE.tbox.subsumption.map(x => `<li>${esc(x)}</li>`).join("")}</ul>
    <h4>Disjointness (${SITE.tbox.disjoint.length})</h4><ul>${SITE.tbox.disjoint.map(x => `<li>${esc(x)}</li>`).join("")}</ul>
    <h4>Definitions and restrictions (${SITE.tbox.definitions.length})</h4><ul style="columns:1">${SITE.tbox.definitions.map(x => `<li>${esc(x)}</li>`).join("")}</ul>
    <h4>Inferred by transitivity (${SITE.tbox.inferred.length})</h4><ul>${SITE.tbox.inferred.map(x => `<li>${esc(x)}</li>`).join("")}</ul>`;
  const MAP = [["doctor", "Doctor"], ["nurse", "Nurse"], ["paramedic", "Paramedic"], ["admin", "AdminOfficer"], ["patient", "Patient"], ["visitor", "Visitor"], ["supplier", "Supplier"],
    ["disability_badge", "BadgeHolder"], ["expectant", "ExpectantMother"], ["cleared", "ClearedPerson"], ["banned", "BannedPerson"], ["on_shift", "OnShiftStaff"],
    ["emergency_vehicle", "EmergencyVehicle"], ["admitted", "AdmittedVehicle"], ["battery_low", "LowBatteryEV"], ["unregistered", "UnregisteredVehicle"], ["out_of_service", "ClosedBay"]];
  const VC = { car: "PetrolCar", suv: "SUV", ev: "ElectricCar", van: "Van", wheelchair_van: "WheelchairVan", ambulance: "Ambulance", motorcycle: "Motorcycle" };
  const BT = { amb: "AmbulanceBay", acc: "AccessibleBay", ev: "ChargerBay", load: "LoadingBay", drop: "DropOffBay", std: "StandardBay", family: "FamilyBay" };
  function renderDL() {
    const m = state.day.m, A = {}, add = (i, c) => { (A[i] = A[i] || new Set()).add(c); };
    MAP.forEach(([p, c]) => m.of(p + "/1").forEach(f => add(f[1], c)));
    m.of("vclass/2").forEach(f => add(f[1], VC[f[2]])); m.of("bay_type/2").forEach(f => add(f[1], BT[f[2]]));
    m.of("height/2").forEach(f => { if (f[2] > 210) add(f[1], "TallVehicle"); });
    m.of("on_call/1").forEach(f => add(f[1], "OnCallDoctor"));
    const spec = i => { const all = new Set([...A[i]].flatMap(c => [c, ...anc(c)])); return [...A[i]].filter(c => ![...A[i]].some(d => d !== c && anc(d).includes(c))); };
    const ids = Object.keys(A).filter(i => !/^(st|vs|rf|pt|oc|mc|dr|ac|ev|ld|fm|mt|amb)\d/.test(i) || ["amb1", "amb2", "ev2", "ac1", "dr1"].includes(i)).sort();
    $("#abox").innerHTML = `<thead><tr><th>Individual</th><th>Most specific concepts</th></tr></thead><tbody>${ids.map(i => `<tr><td class="m">${i}</td><td class="m">${spec(i).join(", ")}</td></tr>`).join("")}</tbody>`;
    const pro = state.sc && state.sc.dl;
    const clashes = [];
    Object.entries(A).forEach(([i, cs]) => { const all = new Set([...cs].flatMap(c => [c, ...anc(c)])); DISJ.forEach(([a, b]) => { if (all.has(a) && all.has(b)) clashes.push(`${i}: ${a} ⊓ ${b} ⊑ ⊥`); }); });
    const occ = m.of("occupies/2").map(f => [f[1], f[2]]).concat(state.day.alloc.map(a => [a.v, a.b]));
    occ.forEach(([v, b]) => { if ((A[b] || new Set()).has("AmbulanceBay") && !(A[v] || new Set()).has("EmergencyVehicle")) clashes.push(`${b}: AmbulanceBay ⊑ ∀occupiedBy.EmergencyVehicle, but ${v} is not one`); });
    $("#dlCons").innerHTML = clashes.length ? `<span class="chip c-emerg">inconsistent</span> <span style="font-size:13px">${esc(clashes.join("; "))}</span>` : `<span class="chip c-sign">consistent</span> <span class="muted" style="font-size:13px">no disjointness clash and no ∀-restriction broken${pro ? ` (Prolog agrees: ${pro.length ? esc(pro.join("; ")) : "consistent"})` : ""}</span>`;
  }
  // rules
  function renderRules() {
    const fired = {}; state.day.phase1.concat(state.day.phase2).forEach(f => { fired[f.rule] = (fired[f.rule] || 0) + 1; });
    const groups = {}; KB.rules.forEach(r => (groups[r.group] = groups[r.group] || []).push(r));
    const lit = a => fmt(a).replace(/^lt\((.*),(.*)\)$/, "$1 < $2").replace(/^le\((.*),(.*)\)$/, "$1 =< $2").replace(/^gt\((.*),(.*)\)$/, "$1 > $2").replace(/^ge\((.*),(.*)\)$/, "$1 >= $2");
    const viol = new Set(state.day.violations.map(v => v.ic));
    $("#rulesBox").innerHTML = Object.entries(groups).map(([g, rs]) => `<div class="rules-group"><h3>${esc(g)} <span class="muted" style="font:400 13px var(--body)">${rs.length} rules</span></h3>
      <div class="scroll"><table class="t"><thead><tr><th>ID</th><th>Clause</th><th>Meaning</th><th>Stratum</th><th>Fired</th></tr></thead><tbody>${rs.map(r =>
        `<tr><td class="m">${r.id}</td><td class="m">${esc(fmt(r.head))} :- ${esc(r.body.map(lit).join(", "))}.</td><td>${esc(r.text)}</td><td class="m">${CP.stratumOf(r)}</td><td class="m">${fired[r.id] || 0}</td></tr>`).join("")}</tbody></table></div></div>`).join("") +
      `<div class="rules-group"><h3>Integrity constraints <span class="muted" style="font:400 13px var(--body)">${KB.constraints.length} goal clauses</span></h3><div class="scroll"><table class="t"><thead><tr><th>ID</th><th>Goal clause</th><th>Forbids</th><th>Now</th></tr></thead><tbody>${KB.constraints.map(c =>
        `<tr><td class="m">${c.id}</td><td class="m">${esc(c.clause)}</td><td>${esc(c.text)}</td><td>${viol.has(c.id) ? '<span class="chip c-emerg">violated</span>' : '<span class="chip c-sign">holds</span>'}</td></tr>`).join("")}</tbody></table></div></div>`;
  }
  // script
  $("#scriptBox").innerHTML = `<p class="mono muted" style="margin:0 0 10px">${SITE.script.name}: roles driver, ANPR camera, gate controller, security office, barrier, allocation engine, display board, occupancy sensor, monitoring</p><div class="scene-strip">${SITE.script.scenes.map(s =>
    `<div class="panel scene"><b>${s.n}</b><h4>${esc(s.name)}</h4><p>${esc(s.what)}</p><p class="mono" style="font-size:11.5px">${esc(s.actor)} · ${s.rules.join(", ")}</p></div>`).join("")}</div>`;

  /* ---------------- scenario lab ---------------- */
  function renderScenarios() {
    const base = Object.fromEntries(RES[0].got.map(g => [g.vehicle, g.outcome]));
    let pass = 0;
    $("#scGridCards").innerHTML = RES.map(r => {
      const day = CP.runDay(r.id === "tc01" ? null : r), got = CP.outcomes(day), want = Object.fromEntries(r.expected.map(g => [g.vehicle, g.outcome]));
      const ok = JSON.stringify(Object.keys(want).sort().map(k => [k, want[k]])) === JSON.stringify(Object.keys(got).sort().map(k => [k, got[k]]));
      if (ok) pass++;
      const changed = Object.entries(got).filter(([v, o]) => base[v] !== o).slice(0, 5);
      const ics = [...new Set(day.violations.map(v => v.ic))];
      return `<article class="panel sc"><header><span class="mono muted">${r.id.toUpperCase()}</span><span class="chip ${ok ? "c-sign" : "c-emerg"}">${ok ? "pass" : "fail"}</span></header><h3>${esc(r.title)}</h3><p>${esc(r.story)}</p>
        <div class="chips">${changed.map(([v, o]) => `<span class="chip ${o.startsWith("denied") ? "c-emerg" : o === "unplaced" ? "c-amber" : "c-sign"}">${esc(NAME(v))} → ${esc(o.replace(/^denied\((.*)\)$/, "denied"))}</span>`).join("")}${ics.map(i => `<span class="chip c-emerg">${i.toUpperCase()}</span>`).join("")}${!changed.length && !ics.length && r.id !== "tc01" ? '<span class="chip c-mute">same bays, different alerts</span>' : ""}</div>
        <div><button class="btn" type="button" data-load="${r.id}">Open in the twin</button></div></article>`;
    }).join("");
    $("#scLede").textContent = `${pass} of ${RES.length} scenarios pass in this browser. Each one changes a few facts and states the outcome a duty manager would expect; the Prolog engine and its ${SITE.stats.find(s => s[0] === "Test scenarios")[1]} plunit cases agree.`;
  }
  $("#scGridCards").addEventListener("click", e => { const b = e.target.closest("[data-load]"); if (!b) return; $("#scSel").value = b.dataset.load; load(scenarioById(b.dataset.load)); location.hash = "twin"; });
  // builder
  const BASE = new Set(CP.FACTS.map(CP.key));
  const closable = SITE.building.bays.map(b => b[0]);
  $("#bayBtns").innerHTML = closable.map(b => `<button type="button" data-b="${b}" aria-pressed="${b === "vs4"}">${b}</button>`).join("");
  $("#bayBtns").addEventListener("click", e => { const b = e.target.closest("button"); if (!b) return; b.setAttribute("aria-pressed", b.getAttribute("aria-pressed") !== "true"); buildDelta(); });
  const outs = [["b-batt", "o-batt", v => v + "%"], ["b-anpr", "o-anpr", v => v + "%"], ["b-ju", "o-ju", hhmm], ["b-th", "o-th", hhmm], ["b-ks", "o-ks", hhmm]];
  function buildScenario() {
    const want = [], drop = [];
    const set = (on, f) => (on ? want : drop).push(f);
    const swap = (oldF, newF) => { drop.push(oldF); want.push(newF); };
    set($("#b-codered").checked, ["mode", "code_red"]); set(!$("#b-codered").checked, ["mode", "normal"]);
    set($("#b-rain").checked, ["weather", "rain"]); set(!$("#b-rain").checked, ["weather", "clear"]);
    set($("#b-ban").checked, ["security_ban", "waqar"]);
    set($("#b-oncall").checked, ["on_call", "saad"]);
    set($("#b-kids").checked, ["has_children", "sadia"]);
    if ($("#b-badge").checked) swap(["staff_badge", "bushra", 20241101, 20261031], ["staff_badge", "bushra", 20241101, 20271031]);
    swap(["battery", "ev_sa", 22], ["battery", "ev_sa", +$("#b-batt").value]);
    swap(["anpr", "car_ya", 64], ["anpr", "car_ya", +$("#b-anpr").value]);
    swap(["arrival", "van_ju", 520], ["arrival", "van_ju", +$("#b-ju").value]);
    swap(["arrival", "car_th", 840], ["arrival", "car_th", +$("#b-th").value]);
    swap(["arrival", "car_ks", 615], ["arrival", "car_ks", +$("#b-ks").value]);
    $$("#bayBtns button").forEach(b => set(b.getAttribute("aria-pressed") === "true", ["out_of_service", b.dataset.b]));
    const add = want.filter(f => !BASE.has(CP.key(f))), remove = drop.filter(f => BASE.has(CP.key(f)) && !want.some(w => CP.key(w) === CP.key(f)));
    return { id: "custom", title: "Your day", story: "A day you built in the scenario lab. The rule engine and the control layer ran in your browser.", add, remove };
  }
  function buildDelta() {
    outs.forEach(([i, o, f]) => { $("#" + o).textContent = f(+$("#" + i).value); });
    const s = buildScenario();
    $("#delta").innerHTML = s.add.length || s.remove.length ? s.add.map(f => `<span class="ok">+ ${esc(fmt(f))}</span>`).concat(s.remove.map(f => `<span class="no">− ${esc(fmt(f))}</span>`)).join("<br>") : "No changes from the baseline.";
  }
  $("#builder").addEventListener("input", buildDelta);
  $("#builder").addEventListener("submit", e => {
    e.preventDefault(); state.custom = buildScenario();
    if (!$("#scSel").querySelector('option[value="custom"]')) $("#scSel").insertAdjacentHTML("beforeend", '<option value="custom">Your day (scenario lab)</option>');
    $("#scSel").value = "custom"; load(state.custom); location.hash = "twin";
  });
  $("#bReset").addEventListener("click", () => { $("#builder").reset(); $$("#bayBtns button").forEach(b => b.setAttribute("aria-pressed", b.dataset.b === "vs4")); buildDelta(); });

  /* ---------------- project ---------------- */
  $("#statsBox").innerHTML = SITE.stats.concat([["Prolog plunit tests", 159], ["JavaScript engine tests", 71]]).map(([k, v]) => `<div class="stat"><b>${v}</b><span>${esc(k)}</span></div>`).join("");

  /* ---------------- boot ---------------- */
  window.CPApp = { select, state, NAME, hhmm, decisionOf };
  load(RES[0]);
  renderScenarios(); buildDelta(); route();
})();
