// PostgreSQL réel, base jetable locale. Aucune connexion distante n'est permise.
// Rejoue toutes les migrations (la passerelle Lasso comprise), crée un pensionnaire par le chemin Lasso, puis
// exerce smarves.passerelle_entrer (le pensionnaire du couple humain + agent, rejeu, coupure), la trace des
// appels, couper / reprendre / effacer, les droits, le retour arrière et la réapplication.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID, createHash } from 'node:crypto';
const { default: pg } = await import(process.env.SMARVES_TEST_PG_MODULE || 'pg');
const url = new URL(process.env.SMARVES_TEST_PG_ADMIN_URL || '');
assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname), 'PostgreSQL local obligatoire');
const admin = new pg.Client({ connectionString: url.href });
await admin.connect();
const name = 'smarves_test_' + randomUUID().replaceAll('-', '');
await admin.query(`CREATE DATABASE ${name} TEMPLATE template0 LOCALE_PROVIDER icu ICU_LOCALE 'und'`);
url.pathname = '/' + name;
const db = new pg.Client({ connectionString: url.href });
await db.connect();
const sql = async p => readFile(new URL(p, import.meta.url), 'utf8');
const PASSERELLE = '20261101000000_smarves_passerelle_lasso.sql';
const sha = s => createHash('sha256').update(s, 'utf8').digest('hex');
const jti = () => 'jti' + randomUUID().replaceAll('-', '');
const AGT = sha('lasso-agent:' + randomUUID());
const AUTRE_AGT = sha('lasso-agent:' + randomUUID());
const HUMAIN = 'humainpasserelle01';
const entrer = async (j = jti(), humain = HUMAIN, agent = AGT, exp = "now() + interval '60 seconds'") =>
  (await db.query(`SELECT smarves.passerelle_entrer($1, $2, $3, ${exp}) AS r`, [j, humain, agent])).rows[0].r;
const count = async (q, p = []) => (await db.query(`SELECT count(*)::int AS n FROM ${q}`, p)).rows[0].n;
const refuse = async (q, p, motif) => {
  try { await db.query(q, p); } catch (e) { assert.match(e.message, motif); return; }
  assert.fail('aurait dû refuser : ' + q);
};

try {
  await db.query(`DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
    END $$;
    CREATE SCHEMA extensions; CREATE SCHEMA vault;
    CREATE TABLE vault.decrypted_secrets(name text, decrypted_secret text);
    CREATE SCHEMA cron;
    CREATE FUNCTION cron.schedule(text,text,text) RETURNS bigint LANGUAGE sql AS 'SELECT 1::bigint';`);
  const files = (await readdir(new URL('../migrations/', import.meta.url))).sort();
  for (const file of files) {
    if (/bourse/.test(file)) continue;
    if (file === '20261020080000_smarves_basket_club.sql') await db.query(await sql('./basket-fixture.sql'));
    await db.query(await sql('../migrations/' + file));
  }
  await refuse(await sql('../migrations/' + PASSERELLE), [], /déjà appliquée/);
  await db.query('ROLLBACK');
  console.log('ok : migrations appliquées, seconde application refusée');

  // Un pensionnaire né du chemin Lasso, pour HUMAIN et AGT.
  const ins = randomUUID();
  const ID = 'doublure:passerelle01';
  const r = (await db.query(`SELECT smarves.doublure_inscrire($1, now()+interval '2 minutes', $2, 'Humain', 'creer', $3,
    $4, 'Rosalie', 'Une histoire de village assez longue pour passer.', null, null, null, 7, 500, $5, $6) AS r`,
  [jti(), HUMAIN, ins, ID, 'b'.repeat(64), AGT])).rows[0].r;
  assert.equal(r.ok, true); assert.equal(r.id, ID);

  // --- Entrer : le pensionnaire du couple, et de lui seul ----------------------------------------
  const j1 = jti();
  assert.deepEqual(await entrer(j1), { ok: true, id: ID });
  assert.deepEqual(await entrer(j1), { ok: false, raison: 'rejeu' });
  assert.deepEqual(await entrer(jti(), HUMAIN, AUTRE_AGT), { ok: false, raison: 'pensionnaire' });
  assert.deepEqual(await entrer(jti(), 'autrehumain000001', AGT), { ok: false, raison: 'pensionnaire' });
  assert.equal(await count('smarves.passerelle_jetons'), 3, 'chaque jti est consommé, même refusé ensuite');
  await refuse(`SELECT smarves.passerelle_entrer($1, $2, $3, now())`, [jti(), 'doublure:passerelle01', AGT], /humain invalide/);
  await refuse(`SELECT smarves.passerelle_entrer($1, $2, $3, now())`, [jti(), HUMAIN, 'pas-une-empreinte'], /agent invalide/);
  await refuse(`SELECT smarves.passerelle_entrer($1, $2, $3, now())`, ['court', HUMAIN, AGT], /passerelle_jetons_jti_check/);
  console.log('ok : entrer : le pensionnaire de cet agent, rejeu refusé, autre agent ou autre humain refusés');

  // Purge des jti une heure après expiration.
  await db.query(`INSERT INTO smarves.passerelle_jetons (jti, humain, exp) VALUES ($1, $2, now() - interval '2 hours')`, ['vieuxjetonpasserelle01', HUMAIN]);
  assert.equal((await entrer()).ok, true);
  assert.equal(await count('smarves.passerelle_jetons WHERE jti = $1', ['vieuxjetonpasserelle01']), 0, 'jti expiré purgé');
  console.log('ok : jti expirés purgés');

  // --- La trace, sans contenu ------------------------------------------------------------------
  await db.query(`SELECT smarves.passerelle_tracer($1, $2, 'smarves_fiche', true)`, [HUMAIN, AGT]);
  await db.query(`SELECT smarves.passerelle_tracer($1, $2, $3, false)`, [HUMAIN, AGT, 'x'.repeat(100)]);
  const traces = (await db.query(`SELECT humain, agent, outil, ok FROM smarves.passerelle_appels ORDER BY id`)).rows;
  assert.deepEqual(traces, [{ humain: HUMAIN, agent: AGT, outil: 'smarves_fiche', ok: true }, { humain: HUMAIN, agent: AGT, outil: 'x'.repeat(64), ok: false }]);
  const colonnes = (await db.query(`SELECT column_name FROM information_schema.columns WHERE table_schema = 'smarves' AND table_name = 'passerelle_appels' ORDER BY ordinal_position`)).rows.map(c => c.column_name);
  assert.deepEqual(colonnes, ['id', 'quand', 'humain', 'agent', 'outil', 'ok'], 'ni arguments ni réponse dans la trace');
  await db.query(`UPDATE smarves.passerelle_appels SET quand = now() - interval '91 days' WHERE outil = 'smarves_fiche'`);
  await db.query(`SELECT smarves.passerelle_tracer($1, $2, 'smarves_journal', true)`, [HUMAIN, AGT]);
  assert.equal(await count('smarves.passerelle_appels'), 2, 'trace de plus de 90 jours purgée');
  console.log('ok : trace par appel sans contenu, outil tronqué, purge à 90 jours');

  // --- Couper, reprendre -----------------------------------------------------------------------
  await db.query(`INSERT INTO smarves.doublure_corps (doublure, membre, tenue, present_jusqu) VALUES ($1, smarves.membre($1), 'tenue', now() + interval '1 hour')`, [ID]);
  const c1 = (await db.query(`SELECT smarves.doublure_deconnecter($1) AS r`, [HUMAIN])).rows[0].r;
  assert.deepEqual(c1, { ok: true, coupe: true });
  const [{ assistant_coupe: t1 }] = (await db.query(`SELECT assistant_coupe FROM smarves.doublures WHERE id = $1`, [ID])).rows;
  assert.ok(t1 instanceof Date);
  assert.equal(await count('smarves.doublure_corps WHERE doublure = $1 AND present_jusqu > now()', [ID]), 0, 'le corps a quitté la place');
  assert.deepEqual(await entrer(), { ok: false, raison: 'coupe' });
  await db.query(`SELECT smarves.doublure_deconnecter($1)`, [HUMAIN]);
  const [{ assistant_coupe: t2 }] = (await db.query(`SELECT assistant_coupe FROM smarves.doublures WHERE id = $1`, [ID])).rows;
  assert.equal(+t2, +t1, 'couper deux fois garde la première heure');
  assert.deepEqual((await db.query(`SELECT smarves.doublure_deconnecter('personne0000000001') AS r`)).rows[0].r, { ok: true, coupe: false });
  assert.deepEqual((await db.query(`SELECT smarves.doublure_reprendre($1) AS r`, [HUMAIN])).rows[0].r, { ok: true, repris: true });
  assert.deepEqual(await entrer(), { ok: true, id: ID });
  assert.deepEqual((await db.query(`SELECT smarves.doublure_reprendre('personne0000000001') AS r`)).rows[0].r, { ok: true, repris: false });
  await refuse(`SELECT smarves.doublure_reprendre('doublure:passerelle01')`, [], /humain invalide/);
  console.log('ok : couper (durable, idempotent, session arrêtée) puis reprendre');

  // --- Les droits ------------------------------------------------------------------------------
  for (const role of ['anon', 'authenticated']) {
    for (const [q, p] of [[`SELECT smarves.passerelle_entrer($1, $2, $3, now())`, [jti(), HUMAIN, AGT]],
      [`SELECT smarves.passerelle_tracer($1, $2, 'x', true)`, [HUMAIN, AGT]], [`SELECT smarves.doublure_reprendre($1)`, [HUMAIN]],
      [`SELECT * FROM smarves.passerelle_jetons`, []], [`SELECT * FROM smarves.passerelle_appels`, []]]) {
      await db.query('BEGIN'); await db.query(`SET LOCAL ROLE ${role}`);
      await refuse(q, p, /permission denied/);
      await db.query('ROLLBACK');
    }
  }
  console.log('ok : anon et authenticated sans droit');

  // --- Effacer ---------------------------------------------------------------------------------
  assert.deepEqual((await db.query(`SELECT smarves.doublure_effacer($1) AS r`, [HUMAIN])).rows[0].r, { ok: true, efface: true });
  assert.equal(await count('smarves.passerelle_appels WHERE humain = $1', [HUMAIN]), 0, 'traces effacées avec le pensionnaire');
  assert.equal(await count('smarves.doublures WHERE id = $1', [ID]), 0);
  assert.deepEqual(await entrer(), { ok: false, raison: 'pensionnaire' });
  console.log('ok : effacer emporte la coupure et les traces');

  // --- Retour arrière et réapplication ---------------------------------------------------------
  await db.query(`CREATE SCHEMA lasso; CREATE FUNCTION lasso.smarves_reprendre(uuid) RETURNS boolean LANGUAGE sql AS 'SELECT true'`);
  await refuse(await sql('../rollback/' + PASSERELLE), [], /retirer d'abord Lasso 012/);
  await db.query('ROLLBACK').catch(() => {});
  await db.query(`DROP SCHEMA lasso CASCADE`);
  await db.query(await sql('../rollback/' + PASSERELLE));
  assert.equal((await db.query(`SELECT to_regclass('smarves.passerelle_jetons') AS t`)).rows[0].t, null);
  assert.equal((await db.query(`SELECT to_regprocedure('smarves.doublure_reprendre(text)') AS t`)).rows[0].t, null);
  assert.equal(await count(`information_schema.columns WHERE table_schema = 'smarves' AND table_name = 'doublures' AND column_name = 'assistant_coupe'`), 0);
  assert.deepEqual((await db.query(`SELECT smarves.doublure_deconnecter('personne0000000001') AS r`)).rows[0].r, { ok: true, lien: false });
  await refuse(await sql('../rollback/' + PASSERELLE), [], /migration absente/);
  await db.query('ROLLBACK').catch(() => {});
  await db.query(await sql('../migrations/' + PASSERELLE));
  assert.deepEqual(await entrer(), { ok: false, raison: 'pensionnaire' });
  console.log('ok : retour arrière (refusé tant que Lasso 012 est là), puis réapplication');
} finally {
  await db.end().catch(() => {});
  await admin.query(`DROP DATABASE IF EXISTS ${name} WITH (FORCE)`);
  await admin.end();
}
