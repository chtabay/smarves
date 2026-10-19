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
const SRC = '/mnt/project-files/casino-minuit/source', OUT = process.argv[2], ZONES = (process.argv[3]||'').split(','), PORT = 8766, VENDOR = process.env.MINUIT_VENDOR || path.join(HERE, 'vendor');
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
  await page.addScriptTag({ content: fs.readFileSync(path.join(VENDOR, 'GLTFExporter.js'), 'utf8') });
  // Prépare la scène : ce que le portage anime lui-même sort ; les instances sont cuites en maillages ;
  // les textures qui défilent sont marquées (nom du matériau « anim|genre|vx|vy »).
  const bilan = await page.evaluate(() => {
    const EXCLUS = /^(halos|jets|e-jets|f-crowd-.*|f-faisceaux|e-faisceaux|e-glows|e-led|ecran-led|door|camera-wall|e-vehicules-.*)$/;
    // Les instances que minuit.gd anime (MultiMesh) : un groupe, un enfant par instance (« i<k> » ou « i<k>_<couleur linéaire> »).
    const ANIMEES = /^(lustre-pendeloques|roulette-roues|carpes|totem-ampoules|marquise-chenillard|roulettes|flammes)$/;
    const sc = Casino.world.scene, n = { exclus: 0, cuits: 0, anim: 0 };
    const zones = sc.children.filter(o => /^zone-/.test(o.name));
    // textures animées connues (kit.js l. 1302-1304, a-escalier.js l. 117, b-salon.js, c-pit.js, kit.js l. 1561)
    const anim = new Map();
    sc.traverse(o => [].concat(o.material || []).forEach(m => { const t = m.map; if (!t) return;
      if (m.name === 'da.eau' || m.name === 'a.eau' || m.name === 'e.eau' || o.name === 'water' || o.name === 'e-eau') anim.set(m, 'eau|0.02|0.013');
      else if (o.name === 'nappe') anim.set(m, 'defile|0|-0.62');
      else if (/jet/.test(m.name)) anim.set(m, 'defile|0|-1.1');
      else if (m.name === 'lotB.flamme' || o.name === 'flammes') anim.set(m, 'defile|0.23|0');
      else if (o.name === 'escalators-tapis') anim.set(m, 'defile|0|-2.75');
      else if (m.name === 'e.ampoules') anim.set(m, 'pas|-0.25|0|6');
      else if (o.name === 'slot-deco-reels') anim.set(m, 'rouleaux|0|0');
      else if (m.name === 'c.bandeau') anim.set(m, 'defile|0.035|0');
    }));
    for (const z of zones) {
      const morts = []; z.traverse(o => { if (o !== z && EXCLUS.test(o.name)) morts.push(o); });
      morts.forEach(o => { o.parent && o.parent.remove(o); n.exclus++; });
      const inst = []; z.traverse(o => { if (o.isInstancedMesh) inst.push(o); });
      for (const im of inst) {
        if (ANIMEES.test(im.name)) {
          const grp = new THREE.Group(), M = new THREE.Matrix4(), col = new THREE.Color();
          grp.name = im.name; grp.position.copy(im.position); grp.quaternion.copy(im.quaternion); grp.scale.copy(im.scale);
          for (let i = 0; i < im.count; i++) { const c = new THREE.Mesh(im.geometry, im.material); im.getMatrixAt(i, M); M.decompose(c.position, c.quaternion, c.scale);
            c.name = 'i' + i; if (im.instanceColor) { im.getColorAt(i, col); c.name += '_' + [col.r, col.g, col.b].map(v => Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, '0')).join(''); } grp.add(c); }
          im.parent.add(grp); im.parent.remove(im); n.animees = (n.animees || 0) + 1; continue; }
        const g0 = im.geometry.index ? im.geometry.toNonIndexed() : im.geometry, cnt = im.count, nv = g0.attributes.position.count;
        const P = new Float32Array(nv * 3 * cnt), N = g0.attributes.normal ? new Float32Array(nv * 3 * cnt) : null, U = g0.attributes.uv ? new Float32Array(nv * 2 * cnt) : null;
        const C = im.instanceColor ? new Float32Array(nv * 3 * cnt) : null, paint = g0.attributes.aPaint;
        const M = new THREE.Matrix4(), NM = new THREE.Matrix3(), v = new THREE.Vector3(), col = new THREE.Color();
        for (let i = 0; i < cnt; i++) { im.getMatrixAt(i, M); NM.getNormalMatrix(M); if (C) im.getColorAt(i, col);
          for (let k = 0; k < nv; k++) { const j = i * nv + k;
            v.fromBufferAttribute(g0.attributes.position, k).applyMatrix4(M); P.set([v.x, v.y, v.z], j * 3);
            if (N) { v.fromBufferAttribute(g0.attributes.normal, k).applyMatrix3(NM).normalize(); N.set([v.x, v.y, v.z], j * 3); }
            if (U) U.set([g0.attributes.uv.getX(k), g0.attributes.uv.getY(k)], j * 2);
            if (C) { const a = paint ? paint.getX(k) : 1; C.set([1 + (col.r - 1) * a, 1 + (col.g - 1) * a, 1 + (col.b - 1) * a], j * 3); } } }
        const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(P, 3));
        if (N) g.setAttribute('normal', new THREE.BufferAttribute(N, 3)); if (U) g.setAttribute('uv', new THREE.BufferAttribute(U, 2));
        let mat = im.material; if (C) { g.setAttribute('color', new THREE.BufferAttribute(C, 3)); mat = [].concat(mat).map(m => { const c = m.clone(); c.vertexColors = true; c.name = m.name; if (anim.has(m)) anim.set(c, anim.get(m)); return c; }); if (mat.length === 1) mat = mat[0]; }
        const me = new THREE.Mesh(g, mat); me.name = im.name; me.position.copy(im.position); me.quaternion.copy(im.quaternion); me.scale.copy(im.scale);
        im.parent.add(me); im.parent.remove(im); n.cuits++; }
      z.traverse(o => [].concat(o.material || []).forEach(m => { if (m.toneMapped === false && !/^nt\|/.test(m.name)) { m.name = 'nt|' + m.name; n.nt = (n.nt || 0) + 1; } }));
      z.traverse(o => [].concat(o.material || []).forEach(m => { if (m.blending === THREE.AdditiveBlending && !/add\|/.test(m.name)) { m.name = m.name.replace(/^(nt\|)?/, '$1add|'); n.add = (n.add || 0) + 1; } }));
      z.traverse(o => [].concat(o.material || []).forEach(m => { if (anim.has(m) && !/anim\|/.test(m.name)) { m.name = m.name.replace(/^((?:nt\|)?(?:add\|)?)/, '$1anim|' + anim.get(m) + '|'); n.anim++; } }));
    }
    return n; });
  console.log('préparé', JSON.stringify(bilan));
  for (const z of ZONES) { if (!z) continue;
    const b64 = await page.evaluate(async (z) => { const o = Casino.world.scene.getObjectByName(z); if (!o) return null;
      o.traverse(c => { c.visible = true; });
      const glb = await new Promise((res) => new THREE.GLTFExporter().parse(o, res, { binary: true, onlyVisible: false, maxTextureSize: 4096 }));
      let s = ''; const u = new Uint8Array(glb); for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return btoa(s); }, z);
    if (b64) { fs.writeFileSync(path.join(OUT, z + '.glb'), Buffer.from(b64, 'base64')); console.log(z, Buffer.from(b64, 'base64').length); } else console.log(z, 'absent'); }
  await browser.close(); process.exit(0);
})();
