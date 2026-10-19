// Exporte de l'original ce que lisent ses PNJ (js/npc.js, js/npc-vie.js) : niveaux et dalles, obstacles de la
// navigation, graphe (nœuds, arêtes, treillis par niveau), liaisons, ascenseurs, points de routine, apparitions,
// caméras, portes, zones, stations et leurs places, gabarits des personnages (vitesse de marche mesurée, assise,
// axes de la tête et du buste), teintes des rôles du manifeste, plan du Strip. Le portage (pnj/) rejoue ces données.
// Usage : node exporter_pnj.mjs SORTIE.json   (MINUIT_VENDOR : le dossier vendor/, par défaut ./vendor)
import { createRequire } from 'module';
import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const require = createRequire(import.meta.url);
let pw; try { pw = require('playwright'); } catch (e) { pw = require('/opt/node-tools/node_modules/playwright'); }
const { chromium } = pw;
const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = '/mnt/project-files/casino-minuit/source', OUT = process.argv[2], PORT = 8769;
const VENDOR = process.env.MINUIT_VENDOR || path.join(HERE, 'vendor');
const MIME = { '.js': 'application/javascript', '.css': 'text/css', '.woff2': 'font/woff2' };
const vendorFile = f => ({ status: 200, contentType: MIME[path.extname(f)] || 'application/octet-stream', headers: { 'Access-Control-Allow-Origin': '*' }, body: fs.readFileSync(path.join(VENDOR, f)) });
function findChromium() { const base = '/opt/pw-browsers'; for (const d of fs.readdirSync(base).filter(d => /^chromium-\d+$/.test(d)).sort().reverse()) { const p = path.join(base, d, 'chrome-linux', 'chrome'); if (fs.existsSync(p)) return p; } }
(async () => {
  const srv = spawn('python3', ['-I', '-m', 'http.server', '--bind', '127.0.0.1', '--directory', SRC, String(PORT)], { cwd: HERE, stdio: 'ignore' });
  process.on('exit', () => { try { srv.kill(); } catch (e) {} });
  await new Promise(r => setTimeout(r, 1500));
  const browser = await chromium.launch({ headless: true, executablePath: findChromium(), args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await (await browser.newContext({ viewport: { width: 640, height: 360 } })).newPage();
  page.on('console', m => { if (m.type() === 'error') console.log('[page]', m.text()); });
  await page.route('**/*', route => { const u = route.request().url();
    if (u.includes('three.js/r128/three.min.js')) return route.fulfill(vendorFile('three.min.js'));
    if (u.includes('loaders/GLTFLoader.js')) return route.fulfill(vendorFile('GLTFLoader.js'));
    if (u.includes('utils/SkeletonUtils.js')) return route.fulfill(vendorFile('SkeletonUtils.js'));
    if (u.includes('cannon.js/0.6.2/cannon.min.js')) return route.fulfill(vendorFile('cannon.min.js'));
    const v = /\/__vendor\/(fonts\/f\d+\.woff2)$/.exec(u); if (v) return route.fulfill(vendorFile(v[1]));
    if (u.startsWith('https://fonts.googleapis.com/')) return route.fulfill(vendorFile('fonts.css'));
    if (u.startsWith(`http://127.0.0.1:${PORT}/`)) return route.continue(); return route.abort(); });
  await page.addInitScript(() => { let s = 0x9e3779b9; Math.random = () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return (s >>> 0) / 4294967296; }; });
  await page.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: 'load', timeout: 120000 });
  await page.waitForFunction(() => window.Casino && Casino.world && Casino.world.ready && Casino.npc && Casino.npc.ready, null, { timeout: 180000 });
  await page.evaluate(() => Casino.npc.ready);
  const res = await page.evaluate(() => {
    const C = Casino, W = C.world, Z = C.zones, K = C.npc._k, THREE = window.THREE, v = new THREE.Vector3();
    const r4 = x => +(+x).toFixed(4);
    /* une valeur de donnée : nombres, textes, booléens, tableaux de ceux-ci, points { x, z } ; le reste (objets 3D, fonctions, liens) est laissé */
    const val = x => {
      if (x === null || x === undefined) return undefined;
      if (typeof x === 'number') return isFinite(x) ? r4(x) : undefined;
      if (typeof x === 'string' || typeof x === 'boolean') return x;
      if (Array.isArray(x)) { const a = x.map(val); return a.every(e => e !== undefined) ? a : undefined; }
      if (x.isVector3) return { x: r4(x.x), y: r4(x.y), z: r4(x.z) };
      if (typeof x === 'object' && typeof x.x === 'number' && typeof x.z === 'number' && !x.isObject3D) { const o = { x: r4(x.x), z: r4(x.z) }; if (typeof x.y === 'number') o.y = r4(x.y); if (typeof x.level === 'number') o.level = x.level; return o; }
      return undefined;
    };
    const plain = (o, skip) => { const out = {}; Object.keys(o).forEach(k => { if (skip && skip.indexOf(k) >= 0) return; if (k.charAt(0) === '_') return; const x = val(o[k]); if (x !== undefined) out[k] = x; }); return out; };
    const levels = Z.levels().map(id => { const L = Z.defineLevel(id, {}); return { id, y: L.y, name: L.name, walk: L.walk.map(r => ({ x0: r4(r.x0), x1: r4(r.x1), z0: r4(r.z0), z1: r4(r.z1), nav: r.nav !== false })), holes: L.holes.map(h => ({ x0: r4(h.x0), x1: r4(h.x1), z0: r4(h.z0), z1: r4(h.z1) })), links: L.links.map(k => k.id), grid: L.grid.map(n => n.id) }; });
    /* obstacles vus par la navigation (nav ≠ false) ; les portes et les portes d'ascenseur sont nav: false */
    const colliders = W.colliders.filter(c => c.nav !== false).map(c => {
      const o = { t: c.type, level: c.level || 0, tag: c.tag || '' };
      if (c.type === 'circle') { o.x = r4(c.x); o.z = r4(c.z); o.r = r4(c.r); }
      else if (c.type === 'seg') { o.x0 = r4(c.x0); o.z0 = r4(c.z0); o.x1 = r4(c.x1); o.z1 = r4(c.z1); o.r = r4(c.r); }
      else { o.minX = r4(c.minX); o.maxX = r4(c.maxX); o.minZ = r4(c.minZ); o.maxZ = r4(c.maxZ); }
      if (c.off) o.off = true; if (c.edge) { o.edge = true; o.ox = c.ox || 0; o.oz = c.oz || 0; } if (c.link) o.link = c.link.id; if (c.player === false) o.player = false; if (c.zone) o.zone = c.zone;
      return o;
    });
    const nodes = W.nav.nodes.map(n => { const o = { id: n.id, x: r4(n.x), z: r4(n.z), level: n.level, y: n.y }; ['grid', 'seam', 'spawn', 'point', 'link'].forEach(k => { if (n[k] !== undefined) o[k] = n[k]; }); if (n.seat) o.seat = n.seat; return o; });
    const links = W.links.map(k => plain(k));
    const elevators = Object.keys(W.elevators).map(id => { const E = W.elevators[id]; return { id, x: E.x, z: E.z, w: E.w, d: E.d, facing: r4(E.facing), label: E.label, cur: E.cur ? E.cur.level : null,
      stops: E.stops.map(S => ({ level: S.level, y: S.y, zone: S.zone, name: S.name, outside: val(S.outside), inside: val(S.inside), doorAt: val(S.doorAt), dw: S.dw, navNode: S.navNode })) }; });
    const points = {}; Object.keys(W.points).forEach(k => { points[k] = W.points[k].map(p => plain(p)); });
    const spawns = W.spawnPoints.map(p => ({ x: r4(p.x), y: r4(p.y), z: r4(p.z), level: p.level || 0 }));
    const cameras = (W.cameraSpots || []).map(c => plain(c));
    const doors = (W.interactables || []).filter(it => it.tags && it.tags.indexOf('door') >= 0).map(it => ({ id: it.id, x: r4(it.position.x), z: r4(it.position.z), level: it.level, zone: it.zone, tags: it.tags.slice() }));
    const zones = Z.list().map(z => ({ id: z.id, level: z.level, y: z.y, height: z.height, bounds: z.bounds, sees: z.sees === undefined ? null : z.sees, enclosed: !!z.enclosed, scene: z.scene, group: z.vgroup }));
    const anchor = o => { if (!o || !o.getWorldPosition) return null; o.getWorldPosition(v); return { x: r4(v.x), y: r4(v.y), z: r4(v.z) }; };
    const stations = C.stations.map(st => {
      const o = { id: st.id, type: st.type, zone: st.zone, level: st.level || 0, tags: (st.tags || []).slice(), closed: !!st.closed, position: val(st.position), rotationY: r4(st.rotationY || 0) };
      if (st.staff) o.staff = { position: val(st.staff.position), facing: r4(st.staff.facing || 0) };
      if (st.serves !== undefined) o.serves = [].concat(st.serves);
      if (typeof st.spin === 'function') o.spin = true;
      const an = st.anchors || {}; o.anchors = {};
      if (an.top) o.anchors.top = anchor(an.top);
      if (an.staffWalk) o.anchors.staffWalk = an.staffWalk.map(anchor);
      o.seats = st.seats.map(s => { const r = plain(s, ['occupant']); r.index = s.index; return r; });
      return o;
    });
    const tpls = Object.keys(K.templates).map(k => { const t = K.templates[k]; const ax = a => a ? { yaw: val(a.yaw), pitch: val(a.pitch) } : null;
      return { name: t.name, human: t.human, female: t.female, scale: t.scale, names: t.names, libs: t.libs, natural: t.natural, measured: t.measured, sitKey: t.sitKey, sitOnce: t.sitOnce, seatH: t.seatH, hipsZ: t.hipsZ, settle: t.settle, height: t.height, head: ax(t.head), torso: ax(t.torso) }; });
    const E = C.lotE, LAY = E && E.LAY ? plain(E.LAY) : null;
    return { levels, colliders, nodes, edges: W.nav.edges, links, elevators, points, spawns, cameras, doors, zones, stations, templates: tpls, roles: C.npc.manifestRoles, lay: LAY,
      stats: { nodes: W.nav.nodes.length, edges: W.nav.edges.length, npcs: C.npc.list.length } };
  });
  fs.writeFileSync(OUT, JSON.stringify(res));
  console.log('niveaux', res.levels.length, 'obstacles', res.colliders.length, 'nœuds', res.nodes.length, 'arêtes', res.edges.length, 'stations', res.stations.length, 'gabarits', res.templates.length, 'points', Object.keys(res.points).map(k => k + ':' + res.points[k].length).join(' '));
  await browser.close(); process.exit(0);
})();
