// Exporte les stations de jeu de l'original (C.stations : tables, machines, roues, comptoirs) avec leurs places,
// en coordonnées du monde : le portage y pose les jeux du socle (tables.gd).
// Usage : node exporter_tables.mjs SORTIE.json   (MINUIT_VENDOR : le dossier vendor/, par défaut ./vendor)
import { createRequire } from 'module';
import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const require = createRequire(import.meta.url);
let pw; try { pw = require('playwright'); } catch (e) { pw = require('/opt/node-tools/node_modules/playwright'); }
const { chromium } = pw;
const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = '/mnt/project-files/casino-minuit/source', OUT = process.argv[2], PORT = 8768;
const VENDOR = process.env.MINUIT_VENDOR || path.join(HERE, 'vendor');
const MIME = { '.js': 'application/javascript', '.css': 'text/css', '.woff2': 'font/woff2' };
// Les polices sont demandées depuis la feuille de fonts.googleapis.com, donc d'une autre origine : sans cet
// en-tête, le navigateur les refuse et dessine les textes avec des polices de remplacement.
const vendorFile = f => ({ status: 200, contentType: MIME[path.extname(f)] || 'application/octet-stream', headers: { 'Access-Control-Allow-Origin': '*' }, body: fs.readFileSync(path.join(VENDOR, f)) });
function findChromium() { const base = '/opt/pw-browsers'; for (const d of fs.readdirSync(base).filter(d => /^chromium-\d+$/.test(d)).sort().reverse()) { const p = path.join(base, d, 'chrome-linux', 'chrome'); if (fs.existsSync(p)) return p; } }
(async () => {
  const srv = spawn('python3', ['-I', '-m', 'http.server', '--bind', '127.0.0.1', '--directory', SRC, String(PORT)], { cwd: HERE, stdio: 'ignore' });
  process.on('exit', () => { try { srv.kill(); } catch (e) {} });
  await new Promise(r => setTimeout(r, 1500));
  const browser = await chromium.launch({ headless: true, executablePath: findChromium(), args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await (await browser.newContext({ viewport: { width: 640, height: 360 } })).newPage();
  await page.route('**/*', route => { const u = route.request().url();
    if (u.includes('three.js/r128/three.min.js')) return route.fulfill(vendorFile('three.min.js'));
    if (u.includes('loaders/GLTFLoader.js')) return route.fulfill(vendorFile('GLTFLoader.js'));
    if (u.includes('utils/SkeletonUtils.js')) return route.fulfill(vendorFile('SkeletonUtils.js'));
    if (u.includes('cannon.js/0.6.2/cannon.min.js')) return route.fulfill(vendorFile('cannon.min.js'));
    // Les polices d'abord : leurs adresses passent aussi par fonts.googleapis.com, qui sert la feuille de style.
    const v = /\/__vendor\/(fonts\/f\d+\.woff2)$/.exec(u); if (v) return route.fulfill(vendorFile(v[1]));
    if (u.startsWith('https://fonts.googleapis.com/')) return route.fulfill(vendorFile('fonts.css'));
    if (u.startsWith(`http://127.0.0.1:${PORT}/`)) return route.continue(); return route.abort(); });
  await page.addInitScript(() => { let s = 0x9e3779b9; Math.random = () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return (s >>> 0) / 4294967296; }; });
  await page.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: 'load', timeout: 120000 });
  await page.waitForFunction(() => window.Casino && Casino.world && Casino.world.ready, null, { timeout: 180000 });
  const res = await page.evaluate(() => {
    const THREE = window.THREE, v = new THREE.Vector3();
    const p3 = o => ({ x: +o.x.toFixed(4), y: +o.y.toFixed(4), z: +o.z.toFixed(4) });
    // Un cadrage local au groupe de la station ({ x, y, z, w, d | h }) : son centre dans le monde.
    const vue = (st, q) => q ? Object.assign({}, q, { centre: p3(st.group.localToWorld(v.set(q.x || 0, q.y || 0, q.z || 0))) }) : null;
    return Casino.stations.map(st => ({
      id: st.id, type: st.type, zone: st.zone, niveau: st.level, tags: st.tags, fermee: !!st.closed,
      position: p3(st.position), rotation: st.rotationY, lecture: st.readingYaw,
      dessus: vue(st, st.topView), face: vue(st, st.frontView),
      croupier: st.staff ? { position: p3(st.staff.position), cap: st.staff.facing } : null,
      places: st.seats.map(s => { const r = { index: s.index }; for (const [k, x] of Object.entries(s)) { if (typeof x === 'number' || typeof x === 'boolean') r[k] = x; else if (x && x.isVector3) r[k] = p3(x); else if (x && typeof x.x === 'number' && typeof x.z === 'number' && Object.keys(x).length <= 3) r[k] = x; } return r; }),
    }));
  });
  fs.writeFileSync(OUT, JSON.stringify(res, null, 1));
  console.log(res.length, 'stations :', [...new Set(res.map(s => s.type))].join(', '));
  await browser.close(); process.exit(0);
})();
