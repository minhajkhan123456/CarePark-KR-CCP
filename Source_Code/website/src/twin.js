/* CarePark digital twin (three.js r160): a four-level open car park beside the hospital block.
   Vehicles appear, drive in and leave according to the day computed by the rule engine. */
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { CSS2DRenderer, CSS2DObject } from "three/addons/renderers/CSS2DRenderer.js";

const host = document.getElementById("twin3d");
const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const reduce = matchMedia("(prefers-reduced-motion: reduce)");
const SITE = window.CP_SITE;
const LEVELS = ["g", "l1", "l2", "roof"];
const AISLE_Z = 1.6, BAY_Z = -4.2, BAY_D = 5.0, RAMP_X = 23.2;
const BAY_W = { amb: 3.6, drop: 2.9, acc: 3.6, load: 4.2, ev: 2.7, moto: 1.5, std: 2.6, family: 3.3 };
const ZONE_NAME = { ambulance: "Amb", dropoff: "Drop", accessible: "Access", loading: "Load", ev_charging: "EV", moto: "Moto",
  oncall: "On-call", staff: "Staff", patient: "Patient", maternity: "Mat", visitor: "Visitor", family: "Family", overflow: "Roof" };
const DEPT_X = { emergency: -30, opd: -18, pharmacy: -8, admin: 2, cardiology: 10, dialysis: 18, oncology: 26, maternity: 34 };
const PALETTE = [0x2f6db5, 0xb5452f, 0x6b5bb0, 0x4f8a3a, 0xc1902a, 0x7a4e3a, 0x2f8f86, 0x9c3f6e, 0x55606b, 0x3a7bd5, 0xa4552c, 0x3f6f4f];

let renderer, labels, scene, camera, controls, mats = {};
const deptTags = {};
let spacing = 7.5, showIds = false, bays = {}, vehicles = new Map(), day = null, selected = null, walkLine = null, walkTag = null;
const zoneLabels = [], levelGroups = {};
const tweens = new Set();

function mat(k, c, o) { mats[k] = new THREE.MeshStandardMaterial(Object.assign({ color: c, roughness: 0.85, metalness: 0.03 }, o || {})); return mats[k]; }
function mesh(geo, m, x, y, z, parent) { const o = new THREE.Mesh(geo, m); o.position.set(x, y, z); o.castShadow = true; o.receiveShadow = true; (parent || scene).add(o); return o; }
function box(w, h, d, m, x, y, z, parent) { return mesh(new THREE.BoxGeometry(w, h, d), m, x, y, z, parent); }
function tag(text, cls, x, y, z, parent) { const el = document.createElement("div"); el.className = "tl3 " + cls; el.textContent = text; const o = new CSS2DObject(el); o.position.set(x, y, z); (parent || scene).add(o); return o; }
const levelY = l => LEVELS.indexOf(l) * spacing;

function init() {
  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  host.appendChild(renderer.domElement);
  labels = new CSS2DRenderer(); labels.domElement.style.cssText = "position:absolute;inset:0;pointer-events:none"; host.appendChild(labels.domElement);
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(36, 1, 0.5, 600);
  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true; controls.maxPolarAngle = 1.45; controls.minDistance = 18; controls.maxDistance = 160;
  scene.add(new THREE.HemisphereLight(0xffffff, 0x8f9c95, 1.1));
  const sun = new THREE.DirectionalLight(0xffffff, 1.7); sun.position.set(-30, 60, 40); sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048); Object.assign(sun.shadow.camera, { left: -70, right: 70, top: 50, bottom: -50, near: 1, far: 200 }); scene.add(sun);

  mat("ground", 0xcbd5cf); mat("slab", 0xb8c4bd); mat("line", 0xffffff); mat("road", 0x8f9a94); mat("col", 0xdfe6e2); mat("wall", 0xeef2f0);
  mat("sign", 0x0a6b4e); mat("emerg", 0xc8283b); mat("amber", 0x9a6400); mat("glass", 0x1b2a33, { roughness: 0.2, metalness: 0.4 }); mat("tyre", 0x15181a);
  mat("dark", 0x2a3330); mat("white", 0xf4f6f5, { roughness: 0.5 }); mat("closed", 0x9a6400); mat("hosp", 0xe9eeeb); mat("hospglass", 0x9fb9c4, { roughness: 0.2, metalness: 0.2 });
  mat("light", 0xc8283b, { emissive: 0xc8283b, emissiveIntensity: 0.9 });

  const g = new THREE.Mesh(new THREE.PlaneGeometry(240, 160), mats.ground); g.rotation.x = -Math.PI / 2; g.receiveShadow = true; scene.add(g);
  box(60, 0.05, 5, mats.road, -50, 0.02, AISLE_Z);                       // entry road
  for (let x = -78; x < -22; x += 3.4) box(1.8, 0.06, 0.16, mats.line, x, 0.05, AISLE_Z);
  box(16, 0.05, 7, mats.road, -36, 0.02, 10.5);                           // turned-away pad
  tag("Turned away", "lvlname", -36, 0.4, 14.5);
  box(14, 0.05, 4.6, mats.road, -12, 0.02, 9.2);                          // waiting lane
  tag("Waiting lane", "lvlname", -12, 0.4, 12.2);
  // gate
  box(2.2, 2.6, 2.4, mats.wall, -24, 1.3, -2.2); box(2.3, 0.2, 2.5, mats.sign, -24, 2.7, -2.2);
  box(0.36, 1.1, 0.36, mats.dark, -24, 0.55, -0.6);
  const barrier = new THREE.Group(); barrier.position.set(-24, 1.0, -0.6); scene.add(barrier);
  const arm = box(0.16, 0.16, 4.6, mats.emerg, 0, 0, 2.3, barrier); for (let i = 0; i < 3; i++) box(0.17, 0.17, 0.6, mats.white, 0, 0, 1 + i * 1.4, barrier);
  mats.barrier = barrier; arm.castShadow = true;
  box(0.14, 4, 0.14, mats.dark, -27, 2, -1.2); box(1.6, 0.12, 0.12, mats.dark, -26.3, 3.95, -1.2); box(0.5, 0.32, 0.34, mats.dark, -25.6, 3.8, -1.0);
  tag("Gate G1 · ANPR", "zone", -25.5, 4.7, -2.2);
  // hospital block behind the car park
  box(78, 9, 12, mats.hosp, 2, 4.5, -28); box(78, 0.6, 12.4, mats.sign, 2, 9.3, -28);
  for (let x = -34; x <= 38; x += 4) for (let y = 3; y <= 7; y += 3.2) box(2.6, 1.6, 0.1, mats.hospglass, x, y, -21.95);
  box(10, 0.4, 7, mats.emerg, -30, 4.6, -19); box(0.3, 4.4, 0.3, mats.dark, -34.6, 2.2, -16); box(0.3, 4.4, 0.3, mats.dark, -25.4, 2.2, -16);
  Object.entries(DEPT_X).forEach(([d, x]) => { box(3, 3.4, 0.4, mats.glass, x, 1.7, -21.8); deptTags[d] = tag(d.charAt(0).toUpperCase() + d.slice(1), "dept", x, 3.9, -21.8); });
  box(110, 0.05, 6, mats.road, 4, 0.02, -15.5);                            // walkway along the hospital
  buildLevels();
  retheme();
  new ResizeObserver(resize).observe(host); resize(); resetView();
  renderer.domElement.addEventListener("pointerup", pick);
  renderer.setAnimationLoop(frame);
}

function buildLevels() {
  Object.values(levelGroups).forEach(g => { g.traverse(o => { if (o.isCSS2DObject) o.element.remove(); }); scene.remove(g); });
  bays = {};
  const byLevel = {};
  SITE.building.bays.forEach(([b, z, t]) => { const zl = SITE.building.zones.find(x => x[0] === z); (byLevel[zl[1]] = byLevel[zl[1]] || []).push({ b, z, t, kind: zl[2] }); });
  LEVELS.forEach((l, i) => {
    const grp = new THREE.Group(); grp.position.y = i * spacing; scene.add(grp); levelGroups[l] = grp;
    if (i > 0) { box(44, 0.35, 15, mats.slab, 0, -0.18, -1.5, grp); for (const x of [-20, -10, 0, 10, 20]) box(0.5, spacing - 0.35, 0.5, mats.col, x, -spacing / 2, -8.6, grp); }
    else box(44, 0.12, 15, mats.slab, 0, 0.06, -1.5, grp);
    box(44, 0.9, 0.2, mats.wall, 0, 0.45, -9.05, grp);
    box(40, 0.02, 4.6, mats.road, -1, 0.14, AISLE_Z, grp);
    tag(l === "g" ? "Ground · 4.0 m" : l === "roof" ? "Roof" : `${l.toUpperCase()} · 2.1 m`, "lvlname", -22, 0.6, 5.5, grp);
    const list = byLevel[l] || [];
    const total = list.reduce((a, x) => a + BAY_W[x.t], 0) + 0.9 * new Set(list.map(x => x.z)).size;
    let x = -total / 2 - 1, lastZ = null;
    list.forEach(item => {
      if (lastZ !== item.z) { x += 0.9; lastZ = item.z; }
      const w = BAY_W[item.t], cx = x + w / 2; x += w;
      const g2 = new THREE.Group(); g2.position.set(cx, 0.16, BAY_Z); grp.add(g2);
      const fill = new THREE.Mesh(new THREE.PlaneGeometry(w - 0.18, BAY_D - 0.2), new THREE.MeshStandardMaterial({ color: 0x0a6b4e, transparent: true, opacity: 0, roughness: 1 }));
      fill.rotation.x = -Math.PI / 2; fill.position.y = 0.012; g2.add(fill);
      for (const s of [-1, 1]) box(0.1, 0.02, BAY_D, mats.line, s * w / 2, 0.01, 0, g2);
      if (item.t === "amb") { const h = box(w - 0.6, 0.02, 0.5, mats.emerg, 0, 0.02, 1.6, g2); h.castShadow = false; }
      if (item.t === "acc") { const h = box(1.3, 0.02, 1.3, mats.sign, 0, 0.02, 0.4, g2); h.castShadow = false; }
      if (item.t === "ev") { box(0.4, 1.3, 0.4, mats.dark, w / 2 - 0.4, 0.65, -BAY_D / 2 + 0.4, g2); box(0.3, 0.3, 0.06, mats.sign, w / 2 - 0.4, 1.05, -BAY_D / 2 + 0.62, g2); }
      const cone = new THREE.Group(); const c = mesh(new THREE.ConeGeometry(0.3, 0.75, 14), mats.closed, 0, 0.38, 0.8, cone); c.castShadow = true; g2.add(cone); cone.visible = false;
      const id = tag(item.b, "", 0, 0.15, BAY_D / 2 - 0.3, g2); id.visible = showIds;
      bays[item.b] = { level: l, x: cx, w, type: item.t, zone: item.z, kind: item.kind, group: g2, fill, cone, id };
    });
    // zone banners
    const zs = {}; list.forEach(it => (zs[it.z] = zs[it.z] || []).push(bays[it.b]));
    Object.entries(zs).forEach(([z, bs]) => { const mx = bs.reduce((a, b) => a + b.x, 0) / bs.length; tag(ZONE_NAME[bs[0].kind] || z, "zone", mx, 2.6, -8.8, grp); });
    // ramp to the next level
    if (i < LEVELS.length - 1) {
      const len = Math.hypot(spacing, 10), ramp = box(4.2, 0.3, len, mats.slab, RAMP_X, spacing / 2, -1, grp);
      ramp.rotation.x = Math.atan2(spacing, 10) * (i % 2 ? -1 : 1);
    }
  });
}

/* ---------------- vehicles ---------------- */
function classOf(v) { const f = day.m.find("vclass", v, undefined)[0]; return f ? f[2] : "car"; }
function makeVehicle(v) {
  const cls = classOf(v), g = new THREE.Group(), color = PALETTE[[...v].reduce((a, c) => a + c.charCodeAt(0), 0) % PALETTE.length];
  const body = new THREE.MeshStandardMaterial({ color, roughness: 0.45, metalness: 0.2 });
  const wheel = (x, z, r) => { const w = mesh(new THREE.CylinderGeometry(r, r, 0.26, 16), mats.tyre, x, r, z, g); w.rotation.z = Math.PI / 2; };
  if (cls === "motorcycle") {
    box(0.4, 0.45, 1.8, body, 0, 0.62, 0, g); wheel(0, -0.7, 0.34); wheel(0, 0.7, 0.34); box(0.45, 0.7, 0.4, mats.dark, 0, 1.2, -0.15, g);
  } else if (cls === "van" || cls === "wheelchair_van" || cls === "ambulance") {
    const H = cls === "ambulance" ? 2.5 : cls === "van" ? 2.35 : 2.05, bm = cls === "ambulance" ? mats.white : body;
    box(1.95, H - 0.4, 4.8, bm, 0, 0.4 + (H - 0.4) / 2, 0, g); box(1.7, 0.5, 0.06, mats.glass, 0, H - 0.6, 2.42, g);
    [-0.9, 0.9].forEach(x => { wheel(x, -1.6, 0.38); wheel(x, 1.6, 0.38); });
    if (cls === "ambulance") { box(1.97, 0.3, 4.82, mats.emerg, 0, 1.2, 0, g); box(1.2, 0.18, 0.4, mats.light, 0, H + 0.08, 1.4, g); }
    if (cls === "wheelchair_van") box(1.2, 1.2, 0.05, mats.sign, 0, 1.2, -2.42, g);
  } else {
    const suv = cls === "suv", hb = suv ? 0.8 : 0.62;
    box(1.8, hb, 4.2, body, 0, 0.36 + hb / 2, 0, g); box(1.62, 0.55, 2.2, mats.glass, 0, 0.36 + hb + 0.27, -0.2, g);
    box(1.64, 0.06, 2.0, body, 0, 0.36 + hb + 0.57, -0.2, g);
    [-0.86, 0.86].forEach(x => { wheel(x, -1.35, 0.36); wheel(x, 1.35, 0.36); });
    if (cls === "ev") box(0.5, 0.05, 1.6, mats.sign, 0, 0.36 + hb + 0.62, -0.2, g);
  }
  g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.userData.vehicle = v; } });
  const el = document.createElement("div"); el.className = "tl3 veh"; el.textContent = (window.CPApp && window.CPApp.NAME(v)) || v;
  const lab = new CSS2DObject(el); lab.position.set(0, 3.2, 0); g.add(lab); lab.visible = false;
  g.visible = false; scene.add(g);
  return { v, g, el, lab, cls, state: "off", pose: null };
}

function bayPose(b) { const B = bays[b]; return new THREE.Vector3(B.x, levelY(B.level) + 0.16, BAY_Z); }
function stateAt(v, t) {
  const m = day.m, a = day.alloc.find(x => x.v === v), d = day.decision.get(v);
  const arr = (m.find("arrival", v, undefined)[0] || [])[2];
  const occ = m.find("occupies", v, undefined)[0];
  if (occ) { const s = m.find("since", v, undefined)[0][2], st = m.find("stay", v, undefined)[0][2]; return s <= t && t < s + st ? { k: "bay", b: occ[2] } : { k: "off" }; }
  if (a) { if (a.from <= t && t < a.to) return { k: "bay", b: a.b }; if (arr !== undefined && arr <= t && t < a.from) return { k: "wait" }; return { k: "off" }; }
  if (d && d.kind === "denied") return arr <= t && t < arr + 30 ? { k: "denied" } : { k: "off" };
  if (d && d.kind === "unplaced") return arr <= t ? { k: "wait" } : { k: "off" };
  return { k: "off" };
}
function pathTo(b) {
  const B = bays[b], li = LEVELS.indexOf(B.level), pts = [new THREE.Vector3(-46, 0, AISLE_Z), new THREE.Vector3(-21, 0, AISLE_Z)];
  if (li === 0) pts.push(new THREE.Vector3(B.x, 0.16, AISLE_Z));
  else {
    pts.push(new THREE.Vector3(RAMP_X - 2.5, 0.16, AISLE_Z));
    for (let i = 0; i < li; i++) { const dir = i % 2 ? -1 : 1; pts.push(new THREE.Vector3(RAMP_X, i * spacing + 0.16, -1 - dir * 5), new THREE.Vector3(RAMP_X, (i + 1) * spacing + 0.16, -1 + dir * 5)); }
    pts.push(new THREE.Vector3(RAMP_X - 2.5, li * spacing + 0.16, AISLE_Z), new THREE.Vector3(B.x, li * spacing + 0.16, AISLE_Z));
  }
  pts.push(new THREE.Vector3(B.x, levelY(B.level) + 0.16, BAY_Z + 1.2), bayPose(b));
  return pts;
}
function drive(veh, pts, ms, then) {
  const seg = [], P = [veh.g.position.clone(), ...pts]; let len = 0;
  for (let i = 1; i < P.length; i++) { const l = P[i].distanceTo(P[i - 1]); seg.push(l); len += l; }
  const tw = { t0: performance.now(), ms, fn: k => {
    let d = k * len, i = 0; while (i < seg.length - 1 && d > seg[i]) { d -= seg[i]; i++; }
    const a = P[i], b = P[i + 1] || a, f = seg[i] ? Math.min(1, d / seg[i]) : 1;
    veh.g.position.lerpVectors(a, b, f);
    const dx = b.x - a.x, dz = b.z - a.z; if (Math.abs(dx) + Math.abs(dz) > 0.01) veh.g.rotation.y = Math.atan2(dx, dz);
  }, done: then, veh };
  [...tweens].forEach(t => { if (t.veh === veh) tweens.delete(t); });
  tweens.add(tw);
}

function setTime(t, animate) {
  if (!day) return;
  const recent = new Set(day.events.filter(e => e.t <= t && e.t > t - 20).map(e => e.e[1]));
  let w = 0, dn = 0;
  vehicles.forEach(veh => {
    const s = stateAt(veh.v, t), prev = veh.state;
    veh.state = s.k + (s.b || "");
    veh.lab.visible = veh.v === selected || (s.k !== "off" && recent.has(veh.v)) || s.k === "denied";
    veh.el.className = "tl3 veh " + (s.k === "bay" ? "go" : s.k === "denied" ? "stop" : s.k === "wait" ? "wait" : "") + (veh.v === selected ? " sel" : "");
    if (s.k === "off") { veh.g.visible = false; return; }
    veh.g.visible = true;
    let target, heading = Math.PI;
    if (s.k === "bay") { target = bayPose(s.b); heading = Math.PI; }
    else if (s.k === "wait") { target = new THREE.Vector3(-17 + (w++) * 3.2, 0, 9.2); heading = Math.PI / 2; }
    else { target = new THREE.Vector3(-41 + (dn++) * 3.4, 0, 10.5); heading = 0; }
    if (animate && !reduce.matches && prev !== veh.state && prev.startsWith("off")) {
      veh.g.position.set(-46, 0, AISLE_Z); veh.g.rotation.y = Math.PI / 2;
      const pts = s.k === "bay" ? pathTo(s.b) : s.k === "wait" ? [new THREE.Vector3(-21, 0, AISLE_Z), new THREE.Vector3(target.x, 0, AISLE_Z), target] : [new THREE.Vector3(-25.5, 0, AISLE_Z), new THREE.Vector3(-30, 0, 6), target];
      drive(veh, pts, s.k === "bay" ? 2600 : 1600, () => { veh.g.rotation.y = heading; });
      if (s.k !== "denied") openBarrier();
    } else if (!animate || prev !== veh.state) {
      [...tweens].forEach(tw => { if (tw.veh === veh) tweens.delete(tw); });
      veh.g.position.copy(target); veh.g.rotation.y = heading;
    }
  });
  paintBays(t);
  drawWalk();
}
function idsVisible() {
  const closed = new Set(day ? day.m.of("out_of_service/1").map(f => f[1]) : []);
  const selBay = selected && vehicles.get(selected) && vehicles.get(selected).state.startsWith("bay") ? vehicles.get(selected).state.slice(3) : null;
  Object.entries(bays).forEach(([b, B]) => { B.id.visible = showIds || closed.has(b) || b === selBay; B.id.element.textContent = closed.has(b) ? b + " closed" : b; });
}
function paintBays(t) {
  idsVisible();
  const busy = new Map();
  vehicles.forEach(veh => { if (veh.state.startsWith("bay")) busy.set(veh.state.slice(3), veh.v); });
  const closed = new Set(day.m.of("out_of_service/1").map(f => f[1]));
  Object.entries(bays).forEach(([b, B]) => {
    B.cone.visible = closed.has(b);
    const v = busy.get(b);
    B.fill.material.opacity = v ? 0.5 : closed.has(b) ? 0.25 : 0;
    B.fill.material.color.set(v ? (v === selected ? css("--info") : css("--sign")) : css("--amber"));
  });
}
let barrierT = 0;
function openBarrier() { barrierT = performance.now(); }

function drawWalk() {
  if (walkLine) { scene.remove(walkLine); walkLine = null; }
  if (walkTag) { walkTag.element.remove(); scene.remove(walkTag); walkTag = null; }
  Object.values(deptTags).forEach(t => t.element.classList.remove("on"));
  if (!selected) return;
  const veh = vehicles.get(selected); if (!veh || !veh.state.startsWith("bay")) return;
  const b = veh.state.slice(3), B = bays[b], d = day.m.find("drives", undefined, selected)[0];
  const dest = d ? (day.m.find("destination", d[1], undefined)[0] || [])[2] : "emergency";
  const dx = DEPT_X[dest || "emergency"] ?? 0, y = levelY(B.level);
  if (deptTags[dest]) deptTags[dest].element.classList.add("on");
  const pts = [new THREE.Vector3(B.x, y + 0.3, BAY_Z), new THREE.Vector3(B.x, y + 0.3, -7.5), new THREE.Vector3(-2, y + 0.3, -7.5), new THREE.Vector3(-2, 0.3, -7.5), new THREE.Vector3(-2, 0.3, -15.5), new THREE.Vector3(dx, 0.3, -15.5), new THREE.Vector3(dx, 0.3, -21)];
  if (B.level === "g") pts.splice(2, 2);
  const geo = new THREE.BufferGeometry().setFromPoints(pts);
  walkLine = new THREE.Line(geo, new THREE.LineDashedMaterial({ color: css("--info"), dashSize: 0.8, gapSize: 0.5, linewidth: 2 }));
  walkLine.computeLineDistances(); scene.add(walkLine);
  const w = day.m.find("walk", B.zone, dest, undefined)[0];
  walkTag = tag(`${w ? w[3] : "?"} m to ${dest}`, "zone", (B.x + dx) / 2, 1.2, -15.5);
}

function pick(e) {
  if (e.button !== 0) return;
  const r = renderer.domElement.getBoundingClientRect(), p = new THREE.Vector2(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
  const ray = new THREE.Raycaster(); ray.setFromCamera(p, camera);
  const hit = ray.intersectObjects([...vehicles.values()].filter(v => v.g.visible).map(v => v.g), true)[0];
  if (hit && hit.object.userData.vehicle && window.CPApp) window.CPApp.select(hit.object.userData.vehicle);
}

function frame(now) {
  for (const tw of [...tweens]) { const k = Math.min(1, (now - tw.t0) / tw.ms); tw.fn(k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2); if (k >= 1) { tweens.delete(tw); tw.done && tw.done(); } }
  const bk = Math.min(1, (now - barrierT) / 500), open = now - barrierT < 1800 ? (now - barrierT < 1300 ? bk : 1 - Math.min(1, (now - barrierT - 1300) / 500)) : 0;
  mats.barrier.rotation.x = -1.35 * open;
  controls.update(); renderer.render(scene, camera); labels.render(scene, camera);
}
function resize() { const w = host.clientWidth, h = host.clientHeight; if (!w || !h) return; renderer.setSize(w, h, false); labels.setSize(w, h); camera.aspect = w / h; camera.updateProjectionMatrix(); }
function resetView() { const n = host.clientWidth < 700; camera.position.set(n ? -10 : -8, n ? 46 : 36, n ? 92 : 66); controls.target.set(-4, spacing * 1.3, -5); controls.update(); }
function retheme() {
  scene.background = new THREE.Color(css("--twin-sky"));
  mats.ground.color.set(css("--twin-ground")); mats.slab.color.set(css("--twin-slab")); mats.line.color.set(css("--twin-line"));
  const dark = getComputedStyle(document.documentElement).colorScheme.includes("dark");
  mats.road.color.set(dark ? 0x2c3833 : 0x8f9a94); mats.col.color.set(dark ? 0x3a4842 : 0xdfe6e2); mats.wall.color.set(dark ? 0x34423c : 0xeef2f0);
  mats.hosp.color.set(dark ? 0x26332d : 0xe9eeeb);
}

const api = {
  load(d) {
    day = d; selected = null;
    vehicles.forEach(v => { v.g.traverse(o => { if (o.isCSS2DObject) o.element.remove(); }); scene.remove(v.g); }); vehicles.clear();
    const ids = new Set([...d.m.of("arrival/2").map(f => f[1]), ...d.m.of("occupies/2").map(f => f[1])]);
    ids.forEach(v => vehicles.set(v, makeVehicle(v)));
  },
  setTime, resize, resetView, retheme,
  select(v) { selected = v; if (day) setTime(+document.getElementById("tlRange").value, false); },
  explode(on) { spacing = on ? 4.2 : 7.5; buildLevels(); if (day) setTime(+document.getElementById("tlRange").value, false); },
  ids(on) { showIds = on; idsVisible(); }
};
try { init(); window.CPAttachTwin(api); }
catch (err) { console.warn("3D twin unavailable", err); host.innerHTML = '<div class="nogl"><div><b>The 3D twin needs WebGL.</b><br>The gate log, the timeline and every other view still work.</div></div>'; }
