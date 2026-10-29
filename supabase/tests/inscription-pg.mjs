// PostgreSQL réel, base jetable locale. Aucune connexion distante n'est permise.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
const { default: pg } = await import(process.env.SMARVES_TEST_PG_MODULE || 'pg');
const url = new URL(process.env.SMARVES_TEST_PG_ADMIN_URL || '');
assert.ok(['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname), 'PostgreSQL local obligatoire');
const admin = new pg.Client({ connectionString: url.href });
await admin.connect();
const name = 'smarves_test_' + randomUUID().replaceAll('-', '');
await admin.query(`CREATE DATABASE ${name} TEMPLATE template0 LOCALE_PROVIDER icu ICU_LOCALE 'und'`);
url.pathname = '/' + name;
const db = new pg.Client({ connectionString: url.href });
const second = new pg.Client({ connectionString: url.href });
await db.connect(); await second.connect();
const sql = async p => readFile(new URL(p, import.meta.url), 'utf8');
const migration = '../migrations/20261030000000_smarves_pensionnaires_inscription.sql';
const call = async (client, { ins, op = 'creer', human = 'concurrent', dem = 'a'.repeat(64), id = 'doublure:concurrent12', jti = randomUUID() }) =>
  (await client.query(`SELECT smarves.doublure_inscrire($1, now()+interval '2 minutes', $2, 'Humain', $3, $4,
    $5, 'Rosalie', 'Une histoire de village assez longue pour passer.', null, null, null, 7, 500, $6) AS r`,
  [jti, human, op, ins, id, op === 'creer' ? dem : null])).rows[0].r;
try {
  // Services Supabase hors sujet : aucune tâche planifiée ni requête réseau exécutée.
  await db.query(`DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
    END $$;
    CREATE SCHEMA extensions; CREATE SCHEMA vault;
    CREATE TABLE vault.decrypted_secrets(name text, decrypted_secret text);
    CREATE SCHEMA cron;
    CREATE FUNCTION cron.schedule(text,text,text) RETURNS bigint LANGUAGE sql AS 'SELECT 1::bigint';`);
  // Schéma partagé basket, copie de addict a318dc9 (migration 20261020000000).
  // La bourse reste hors périmètre : ses fonctions réseau ne sont pas exercées.
  const files = (await readdir(new URL('../migrations/', import.meta.url))).sort();
  for (const file of files) {
    if (/bourse/.test(file)) continue;
    if (file === '20261020080000_smarves_basket_club.sql') await db.query(await sql('./basket-fixture.sql'));
    await db.query(await sql('../migrations/' + file));
  }
  db.on('notice', n => { if (n.message.startsWith('ok :')) console.log(n.message); });
  await db.query(await sql('./inscription.sql'));
  const ins = randomUUID();
  await db.query('BEGIN');
  const first = await call(db, { ins });
  assert.equal(first.resultat, 'cree');
  let finished = false;
  const waiting = call(second, { ins, id: 'doublure:otherresult12' }).then(r => { finished = true; return r; });
  await new Promise(r => setTimeout(r, 150));
  assert.equal(finished, false, 'la deuxième transaction attend la première');
  await db.query('COMMIT');
  assert.deepEqual(await waiting, { ...first, resultat: 'deja_fait' });
  assert.equal((await db.query('SELECT count(*)::int n FROM smarves.doublures WHERE humain=$1', ['concurrent'])).rows[0].n, 1);
  console.log('ok : même ins, deux créations concurrentes, même résultat durable');
  // Coupure après COMMIT Smarves, aucun rattachement Lasso : un nouveau clic restitue le résultat.
  assert.equal((await call(second, { ins })).resultat, 'deja_fait');
  assert.equal((await call(second, { ins, dem: 'b'.repeat(64) })).raison, 'inscription');
  assert.equal((await call(second, { ins })).resultat, 'deja_fait');
  console.log('ok : reprise après interruption, demande différente refusée sans perdre le succès');
  const adoptIns = randomUUID();
  await db.query('BEGIN');
  const adopted = await call(db, { ins: adoptIns, op: 'adopter' });
  const adoptionWaiting = call(second, { ins: adoptIns, op: 'adopter' });
  await db.query('COMMIT');
  assert.equal(adopted.resultat, 'adopte');
  assert.deepEqual(await adoptionWaiting, { ...adopted, resultat: 'deja_fait' });
  console.log('ok : même ins, deux adoptions concurrentes');
  if (process.env.LASSO_TEST_SOURCE) {
    const { integration } = await import(pathToFileURL(resolve(process.env.LASSO_TEST_SOURCE, 'scripts/essai-inscription-integre.mjs')));
    await integration({ db, connectionString: url.href });
  }
  await db.query(await sql('../rollback/20261030000000_smarves_pensionnaires_inscription.sql'));
  await db.query(await sql(migration));
  console.log('ok : retour arrière et réapplication');
} finally {
  await Promise.allSettled([db.end(), second.end()]);
  await admin.query(`DROP DATABASE ${name} WITH (FORCE)`);
  await admin.end();
}
