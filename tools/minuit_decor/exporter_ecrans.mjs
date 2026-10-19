// Exporte ce qu'il faut pour animer les écrans de l'original que le moteur web redessine en direct, rendu par
// le code de dessin de l'original lui-même (relu dans ses fichiers, pas recopié) :
// - le mur des tournois du poker (b-poker.js) : le tableau de départ et, pour les deux lignes qui changent,
//   chaque nombre de joueurs possible et les deux états du statut qui clignote ; recomposés, ils redonnent
//   l'image exacte de l'original ;
// - le jackpot du totem (b-machines.js) : l'afficheur sans son nombre, chaque chiffre avec sa lueur, à quatre
//   positions sous le pixel, et les chasses et crénages de la police ;
// - les écrans des paris (c-sports.js) : où tombe la ligne de base de chaque police (paris.json), et des
//   images de référence à quelques instants, pour comparer le redessin du portage (ecrans_paris.gd).
// Usage : node exporter_ecrans.mjs SORTIE REFERENCES   (MINUIT_VENDOR : le dossier vendor/, par défaut ./vendor)
import { createRequire } from 'module';
import { spawn } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
const require = createRequire(import.meta.url);
let pw; try { pw = require('playwright'); } catch (e) { pw = require('/opt/node-tools/node_modules/playwright'); }
const { chromium } = pw;
const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = '/mnt/project-files/casino-minuit/source', OUT = process.argv[2], REF = process.argv[3], PORT = 8767;
const VENDOR = process.env.MINUIT_VENDOR || path.join(HERE, 'vendor');
const MIME = { '.js': 'application/javascript', '.css': 'text/css', '.woff2': 'font/woff2' };
// Les polices sont demandées depuis la feuille de fonts.googleapis.com, donc d'une autre origine : sans cet
// en-tête, le navigateur les refuse et dessine les textes avec des polices de remplacement.
const vendorFile = f => ({ status: 200, contentType: MIME[path.extname(f)] || 'application/octet-stream', headers: { 'Access-Control-Allow-Origin': '*' }, body: fs.readFileSync(path.join(VENDOR, f)) });
function findChromium() { const base = '/opt/pw-browsers'; for (const d of fs.readdirSync(base).filter(d => /^chromium-\d+$/.test(d)).sort().reverse()) { const p = path.join(base, d, 'chrome-linux', 'chrome'); if (fs.existsSync(p)) return p; } }
const png = (f, d) => fs.writeFileSync(f, Buffer.from(d.split(',')[1], 'base64'));
(async () => {
  fs.mkdirSync(OUT, { recursive: true }); fs.mkdirSync(REF, { recursive: true });
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
  const res = await page.evaluate(async () => {
    const K = Casino.kit, P = K.pal, THREE = window.THREE, PI = Math.PI, TAU = PI * 2;
    const lire = async f => (await fetch('/js/zones/' + f)).text();
    // Le corps d'une fonction fléchée « (c, w, h) => { … } » qui suit `debut` dans le texte d'un fichier.
    const corps = (txt, debut) => { let i = txt.indexOf(debut); if (i < 0) throw new Error('introuvable : ' + debut); i = txt.indexOf('(c, w, h) =>', i);
      let j = txt.indexOf('{', i), n = 0; for (let k = j; k < txt.length; k++) { if (txt[k] === '{') n++; else if (txt[k] === '}' && --n === 0) return txt.slice(i, k + 1); } };
    const toile = (w, h) => { const cv = document.createElement('canvas'); cv.width = w; cv.height = h; return cv; };
    const peindre = (f, w, h) => { const cv = toile(w, h); f(cv.getContext('2d'), w, h); return cv; };
    const decoupe = (cv, x, y, w, h) => { const d = toile(w, h); d.getContext('2d').drawImage(cv, x, y, w, h, 0, 0, w, h); return d; };
    const out = {};

    // --- le poker ---
    const poker = await lire('b-poker.js');
    const lignes = eval(/const rows = (\[\[.*?\]\]);/.exec(poker)[1]);
    const dessinPoker = new Function('K', 'P', 'etat', 'with (etat) return ' + corps(poker, 'const board = K.canvasTex(1024, 384,'));
    const tableau = (r, blink) => peindre(dessinPoker(K, P, { rows: r, blink }), 1024, 384);
    const PW = 1024, PH = 384, rang = i => 142 + i * 40 - 20;
    out.poker_depart = tableau(lignes, false).toDataURL();
    // Les lignes 3 et 4 (inscriptions ouvertes) : le nombre de joueurs (x ∈ [600, 776[) monte d'un à chaque
    // clignotement jusqu'à 160 ; le statut (x ∈ [776, 1024[ : son texte déborde du cadre) clignote.
    const NX = 600, NW = 176, SX = 776, SW = 248, CH = 40, cellules = [], meta = { lignes: {}, statut: {}, cellule: [NW, CH], statut_taille: [SW, CH] };
    for (const i of [3, 4]) {
      meta.lignes[i] = { y: rang(i), de: lignes[i][2], a: 160, premiere: cellules.length };
      for (let v = lignes[i][2]; v <= 160; v++) { const r = lignes.map(l => l.slice()); r[i][2] = v; cellules.push(decoupe(tableau(r, false), NX, rang(i), NW, CH)); }
    }
    const statuts = [];
    for (const i of [3, 4]) { meta.statut[i] = { y: rang(i), eteint: statuts.length, allume: statuts.length + 1 };
      statuts.push(decoupe(tableau(lignes, false), SX, rang(i), SW, CH), decoupe(tableau(lignes, true), SX, rang(i), SW, CH)); }
    meta.x_nombre = NX; meta.x_statut = SX; meta.taille = [PW, PH];
    const atl = toile(NW, CH * cellules.length); cellules.forEach((d, k) => atl.getContext('2d').drawImage(d, 0, k * CH)); out.poker_nombres = atl.toDataURL();
    const ats = toile(SW, CH * statuts.length); statuts.forEach((d, k) => ats.getContext('2d').drawImage(d, 0, k * CH)); out.poker_statuts = ats.toDataURL();
    // Un état quelconque, dessiné entier par l'original, pour vérifier la recomposition.
    { const r = lignes.map(l => l.slice()); r[3][2] = 41; r[4][2] = 160; out.poker_essai = tableau(r, true).toDataURL(); meta.essai = { 3: 41, 4: 160, allume: true }; }
    out.poker_json = meta;

    // --- le jackpot ---
    const machines = await lire('b-machines.js');
    const dessinJack = new Function('K', 'P', 'etat', 'with (etat) return ' + corps(machines, 'const jt = K.canvasTex(512, 256,'));
    const JW = 512, JH = 256, MARQUE = '§';
    // L'état du pinceau quand l'original écrit le nombre (police, couleur, lueur, position).
    let pinceau = null; const ft = CanvasRenderingContext2D.prototype.fillText;
    CanvasRenderingContext2D.prototype.fillText = function (s, x, y) { if (s === MARQUE) { pinceau = { font: this.font, fill: this.fillStyle, sc: this.shadowColor, sb: this.shadowBlur, al: this.textAlign, bl: this.textBaseline, x, y }; return; } return ft.apply(this, arguments); };
    out.jackpot_fond = peindre(dessinJack(K, P, { pot: MARQUE }), JW, JH).toDataURL();
    CanvasRenderingContext2D.prototype.fillText = ft;
    const CAR = '0123456789 ', PAD = 48, PHASES = 4, YH = Math.round(pinceau.y - 72), HH = 144;
    const mesure = toile(8, 8).getContext('2d'); mesure.font = pinceau.font;
    const chasse = {}, crenage = {};
    for (const a of CAR) { chasse[a] = mesure.measureText(a).width; for (const b of CAR) crenage[a + b] = mesure.measureText(a + b).width - mesure.measureText(a).width - mesure.measureText(b).width; }
    const SL = Math.ceil(Math.max(...Object.values(chasse))) + 2 * PAD;
    const gly = toile(SL * CAR.length, HH * PHASES), g = gly.getContext('2d');
    for (let p = 0; p < PHASES; p++) for (let k = 0; k < CAR.length; k++) {
      g.save(); g.beginPath(); g.rect(k * SL, p * HH, SL, HH); g.clip();
      g.font = pinceau.font; g.fillStyle = pinceau.fill; g.shadowColor = pinceau.sc; g.shadowBlur = pinceau.sb; g.textAlign = 'left'; g.textBaseline = pinceau.bl;
      g.fillText(CAR[k], k * SL + PAD + p / PHASES, p * HH + (pinceau.y - YH)); g.restore();
    }
    out.jackpot_glyphes = gly.toDataURL();
    out.jackpot_essai = peindre(dessinJack(K, P, { pot: 1284560 }), JW, JH).toDataURL();
    out.jackpot_json = { taille: [JW, JH], caracteres: CAR, case: [SL, HH], marge: PAD, phases: PHASES, y_bande: YH, x_centre: pinceau.x, chasse, crenage, depart: 1284560, essai: 1284560 };

    // --- les écrans des paris : références ---
    const sports = await lire('c-sports.js');
    const debut = sports.indexOf('const BODY = K.BODY'), fin = sports.indexOf('C.zones.register(');
    const { drawA, drawB } = new Function('K', 'THREE', 'PI', 'TAU', sports.slice(debut, fin) + '\nreturn { drawA, drawB };')(K, THREE, PI, TAU);
    out.sports = {};
    // Où tombe la ligne de base quand l'original écrit avec textBaseline « middle », pour chaque police et
    // taille des écrans : le redessin du portage s'y cale.
    const mi = toile(8, 8).getContext('2d'); mi.textBaseline = 'middle'; out.paris_json = { milieu: {} };
    for (const [nom, f] of [['barlow-600', '600 %spx ' + K.BODY], ['barlow-700', '700 %spx ' + K.BODY], ['limelight', '%spx ' + K.DISP]])
      for (const t of [12, 13, 14, 15, 17, 18, 22, 26, 34]) { mi.font = f.replace('%s', t); out.paris_json.milieu[nom + '|' + t] = mi.measureText('Hx').alphabeticBaseline; }
    for (const t of [0, 7.3, 45.25, 61.2, 300.5, 1234.75]) { out.sports['A_' + t] = peindre((c) => drawA(c, t), 1024, 256).toDataURL(); out.sports['B_' + t] = peindre((c) => drawB(c, t), 1024, 256).toDataURL(); }
    return out;
  });
  for (const k of ['poker_depart', 'poker_nombres', 'poker_statuts', 'jackpot_fond', 'jackpot_glyphes']) png(path.join(OUT, k + '.png'), res[k]);
  fs.writeFileSync(path.join(OUT, 'poker.json'), JSON.stringify(res.poker_json, null, 1));
  fs.writeFileSync(path.join(OUT, 'jackpot.json'), JSON.stringify(res.jackpot_json, null, 1));
  fs.writeFileSync(path.join(OUT, 'paris.json'), JSON.stringify(res.paris_json, null, 1));
  png(path.join(REF, 'poker_essai.png'), res.poker_essai); png(path.join(REF, 'jackpot_essai.png'), res.jackpot_essai);
  for (const [k, d] of Object.entries(res.sports)) png(path.join(REF, 'sports_' + k + '.png'), d);
  console.log('écrans exportés');
  await browser.close(); process.exit(0);
})();
