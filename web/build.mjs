// La version web de Smarves sur Vercel (projet « smarves ») : rien ne s'y construit, la page sert
// l'export web que le workflow GitHub joint à la Release « derniere-version » (Smarves-web.tar.gz).
// Le workflow publie une dizaine de minutes après le push ; on attend donc que la Release porte ce
// commit-ci (commit.txt dans l'archive). Si main a déjà avancé, on s'arrête : le déploiement
// suivant publiera la version plus récente, et celle en ligne reste en place.
import { execSync } from 'node:child_process';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';

const REPO = 'https://github.com/chtabay/smarves';
const ARCHIVE = `${REPO}/releases/download/derniere-version/Smarves-web.tar.gz`;
const want = process.env.VERCEL_GIT_COMMIT_SHA || '';
const deadline = Date.now() + 35 * 60 * 1000;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const tagSha = () => execSync(`git ls-remote ${REPO} refs/tags/derniere-version`).toString().split(/\s/)[0];

rmSync('public', { recursive: true, force: true });
for (;;) {
  const res = await fetch(ARCHIVE, { redirect: 'follow' });
  if (res.ok) {
    writeFileSync('web.tar.gz', Buffer.from(await res.arrayBuffer()));
    mkdirSync('public', { recursive: true });
    execSync('tar -xzf web.tar.gz -C public');
    const got = readFileSync('public/commit.txt', 'utf8').trim();
    if (!want || got === want) { console.log(`Version web ${got} prête.`); break; }
    console.log(`La Release porte encore ${got.slice(0, 7)}, on attend ${want.slice(0, 7)}.`);
    rmSync('public', { recursive: true, force: true });
  } else console.log(`Archive pas encore là (${res.status}).`);
  const tag = tagSha();
  if (want && tag && tag !== want) {
    // L'étiquette est sur un autre commit : plus récent si l'export de celui-ci a déjà été dépassé.
    const ahead = execSync(`git ls-remote ${REPO} refs/heads/main`).toString().split(/\s/)[0];
    if (ahead !== want) { console.error('main a avancé : le déploiement suivant publiera.'); process.exit(1); }
  }
  if (Date.now() > deadline) { console.error('La Release n’a pas porté ce commit à temps.'); process.exit(1); }
  await sleep(30000);
}
