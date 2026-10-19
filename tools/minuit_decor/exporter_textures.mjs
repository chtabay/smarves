// Exporte les textures procédurales de l'original (canvas) en PNG, et la liste des matériaux texturés de la scène.
import { createRequire } from 'module';
import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const require = createRequire(import.meta.url);
let pw; try { pw = require('playwright'); } catch (e) { pw = require('/opt/node-tools/node_modules/playwright'); }
const { chromium } = pw;
const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = '/mnt/project-files/casino-minuit/source', OUT = process.argv[2], PORT = 8766, VENDOR = process.env.MINUIT_VENDOR || path.join(HERE, 'vendor');
const MIME = { '.js': 'application/javascript', '.css': 'text/css', '.woff2': 'font/woff2' };
// Les polices sont demandées depuis la feuille de fonts.googleapis.com, donc d'une autre origine : sans cet
// en-tête, le navigateur les refuse et dessine les textes avec des polices de remplacement.
const vendorFile = f => ({ status: 200, contentType: MIME[path.extname(f)] || 'application/octet-stream', headers: { 'Access-Control-Allow-Origin': '*' }, body: fs.readFileSync(path.join(VENDOR, f)) });
function findChromium() { const base = '/opt/pw-browsers'; for (const d of fs.readdirSync(base).filter(d => /^chromium-\d+$/.test(d)).sort().reverse()) { const p = path.join(base, d, 'chrome-linux', 'chrome'); if (fs.existsSync(p)) return p; } }
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
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
    const out = {}, liste = [], vus = new Map();
    const url = img => { try { if (img.toDataURL) return img.toDataURL('image/png'); if (img.data) { const c = document.createElement('canvas'); c.width = img.width; c.height = img.height; const n = img.width * img.height, src = img.data, k = src.length / n, px = new Uint8ClampedArray(n * 4); for (let i = 0; i < n; i++) { px[i * 4] = src[i * k]; px[i * 4 + 1] = src[i * k + 1]; px[i * 4 + 2] = src[i * k + 2]; px[i * 4 + 3] = k === 4 ? src[i * 4 + 3] : 255; } c.getContext('2d').putImageData(new ImageData(px, img.width, img.height), 0, 0); return c.toDataURL('image/png'); } const c = document.createElement('canvas'); c.width = img.width; c.height = img.height; c.getContext('2d').drawImage(img, 0, 0); return c.toDataURL('image/png'); } catch (e) { return null; } };
    Casino.world.scene.traverse(o => { if (!o.material) return; [].concat(o.material).forEach(m => { ['map', 'emissiveMap', 'roughnessMap', 'metalnessMap'].forEach(k => { const t = m[k]; if (!t || !t.image) return;
      let id = vus.get(t.image); if (id === undefined) { id = 't' + vus.size; vus.set(t.image, id); out[id] = url(t.image); }
      liste.push([m.name || '', k, id, t.repeat ? [t.repeat.x, t.repeat.y] : null, o.name || '', (o.parent && o.parent.name) || '']); }); }); });
    return { out, liste };
  });
  for (const [id, d] of Object.entries(res.out)) if (d) fs.writeFileSync(path.join(OUT, id + '.png'), Buffer.from(d.split(',')[1], 'base64'));
  const uniq = {}; for (const l of res.liste) { const k = l[0] + '|' + l[1] + '|' + l[2]; uniq[k] = uniq[k] || { mat: l[0], k: l[1], tex: l[2], n: 0, ex: l[4] + '<' + l[5] }; uniq[k].n++; }
  fs.writeFileSync(path.join(OUT, 'materiaux.json'), JSON.stringify(Object.values(uniq), null, 1));
  console.log(Object.keys(res.out).length, 'textures', Object.keys(uniq).length, 'couples');
  await browser.close(); process.exit(0);
})();
