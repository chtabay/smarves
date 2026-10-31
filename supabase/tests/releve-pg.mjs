// PostgreSQL réel, base jetable locale. Aucune connexion distante n'est permise.
// Rejoue toutes les migrations, puis exerce la relève des présidents (20261101120000) : les parts toute
// l'année, un club par sport, la prise immédiate d'une direction vacante, la relève du lundi à midi pour
// le reste, un changement de club par saison, le renoncement, et les droits.
// Un changement de club pendant la saison, un pendant l'intersaison.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
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
const un = async (q, p = []) => (await db.query(q, p)).rows[0].r;
const refuse = async (q, p, motif) => {
  try { await db.query(q, p); } catch (e) { assert.match(e.message, motif); return; }
  assert.fail('aurait dû refuser : ' + q);
};
const prendre = (j, club, rang, sport = 'football') =>
  un(`SELECT public.${sport === 'basket' ? 'smarves_basket_obligation_prendre' : 'smarves_obligation_prendre'}($1, $2, $3) AS r`, [j, club, rang]);
const diriger = (j, club, changer = false, sport = 'football') =>
  un(`SELECT public.smarves_direction_prendre($1, $2, $3, '0', $4) AS r`, [j, sport, club, changer]);
const directions = (j = null, sport = 'football') => un(`SELECT public.smarves_directions($1, $2) AS r`, [j, sport]);
const releves = (j = null, sport = 'football') => un(`SELECT public.smarves_direction_releves($1, $2) AS r`, [j, sport]);
const directeur = (club, sport = 'football') => un(`SELECT smarves.directeur($1, $2) AS r`, [sport, club]);
const dirige = (club, j, sport = 'football') => un(`SELECT smarves.dirige_sport($1, $2, $3) AS r`, [sport, club, j]);
// La relève est échue : on la recule d'une minute, comme si le lundi midi était passé.
const echoir = () => db.query(`UPDATE smarves.directions_releves SET effet = now() - interval '1 minute'`);

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
  // Le jeton est ici le nom du joueur : pas de compte Pyramides dans la base jetable.
  await db.query(`CREATE OR REPLACE FUNCTION smarves.joueur(p_jeton text) RETURNS text LANGUAGE sql
    SECURITY DEFINER SET search_path = '' AS $$ SELECT pyramide_id FROM smarves.joueurs WHERE pyramide_id = p_jeton $$;
    INSERT INTO smarves.joueurs (pyramide_id, nom) VALUES ('ana', 'Ana'), ('bob', 'Bob'), ('cle', 'Clé');`);
  console.log('ok : migrations appliquées');

  // --- La relève : le lundi à midi, heure de Paris, strictement après ----------------------------
  const rel = t => un(`SELECT to_char(smarves.releve_suivante($1::timestamptz) AT TIME ZONE 'Europe/Paris', 'YYYY-MM-DD HH24:MI') AS r`, [t]);
  assert.equal(await rel('2026-10-31 18:00 Europe/Paris'), '2026-11-02 12:00');
  assert.equal(await rel('2026-11-02 11:59 Europe/Paris'), '2026-11-02 12:00');
  assert.equal(await rel('2026-11-02 12:00 Europe/Paris'), '2026-11-09 12:00');
  assert.equal(await rel('2027-03-28 18:00 Europe/Paris'), '2027-03-29 12:00', 'à l\'heure d\'été');
  assert.equal(await un(`SELECT smarves.secondes_locales('2026-11-02 12:00 Europe/Paris') AS r`), String(Date.UTC(2026, 10, 2, 12) / 1000));
  const periode = (s, t) => un(`SELECT smarves.periode_de($1, $2::timestamptz) AS r`, [s, t]);
  assert.equal(await periode('football', '2026-10-19 12:00 Europe/Paris'), 'i1', 'avant la première saison');
  assert.equal(await periode('football', '2026-10-25 15:00 Europe/Paris'), 's1');
  assert.equal(await periode('football', '2027-01-24 17:59 Europe/Paris'), 's1', 'la journée 14 se joue le 24 janvier à 15 h');
  assert.equal(await periode('football', '2027-01-24 18:00 Europe/Paris'), 'i2', 'trois heures après, l\'intersaison');
  assert.equal(await periode('football', '2027-02-14 15:00 Europe/Paris'), 's2');
  assert.equal(await periode('basket', '2027-01-23 22:59 Europe/Paris'), 's1');
  assert.equal(await periode('basket', '2027-01-25 12:00 Europe/Paris'), 'i2');
  console.log('ok : la relève du lundi midi, la saison et l\'intersaison');

  // --- Les parts toute l'année ------------------------------------------------------------------
  assert.deepEqual(await prendre('ana', 'c1', 1), { ok: true });
  assert.deepEqual(await prendre('bob', 'c1', 1), { ok: false, raison: 'prise' });
  assert.deepEqual(await prendre('ana', 'h1', 1, 'basket'), { ok: true });
  console.log('ok : les parts se prennent en saison, au football et au basket');

  // --- Une direction vacante se prend tout de suite ---------------------------------------------
  assert.deepEqual(await diriger('ana', 'c1'), { ok: true });
  assert.equal(await directeur('c1'), 'ana');
  assert.deepEqual(await diriger('ana', 'c1'), { ok: true }, 'on ne redemande pas la sienne');
  console.log('ok : la direction vacante se prend tout de suite');

  // --- Prendre la main sur un club dirigé : à la relève -------------------------------------------
  assert.deepEqual(await prendre('bob', 'c1', 2), { ok: true });
  assert.deepEqual(await diriger('bob', 'c1'), { ok: true, releve: true, effet: Number(await un(`SELECT smarves.secondes_locales(smarves.releve_suivante(now())) AS r`)) });
  assert.equal(await directeur('c1'), 'ana', 'Ana garde la main jusqu\'à la relève');
  let r = await releves('bob');
  assert.equal(r.releves.length, 1); assert.equal(r.releves[0].club, 'c1'); assert.equal(r.releves[0].par, 'Bob'); assert.equal(r.releves[0].moi, true);
  assert.equal((await releves('ana')).releves[0].moi, false, 'la relève est publique');
  await echoir();
  assert.equal(await directeur('c1'), 'bob', 'la relève passée, Bob dirige');
  assert.deepEqual(await directions('bob'), [{ club: 'c1', par: 'Bob', moi: true, division: '0' }]);
  assert.equal(await un(`SELECT count(*)::int AS r FROM smarves.directions_releves`), 0, 'la relève est réglée');
  assert.deepEqual((await releves('bob')).changements, [], 'une première prise ne compte pas comme un changement');
  console.log('ok : prendre la main sur un club dirigé se fait à la relève');

  // --- Un seul club à la fois, et un changement par saison --------------------------------------
  assert.deepEqual(await prendre('bob', 'c2', 1), { ok: true });
  assert.deepEqual(await diriger('bob', 'c2'), { ok: false, raison: 'ailleurs' }, 'Bob dirige déjà c1');
  assert.equal(await dirige('c2', 'bob'), false, 'ni de fait : il dirige déjà un club du sport');
  assert.deepEqual(await diriger('bob', 'c2', false, 'basket'), { ok: false, raison: 'parts' }, 'le basket est un autre sport');
  const d = await diriger('bob', 'c2', true);
  assert.equal(d.ok, true); assert.equal(d.releve, true);
  assert.equal(await directeur('c2'), null, 'c2 reste vacant jusqu\'à la relève');
  assert.equal(await dirige('c2', 'bob'), false);
  await echoir();
  assert.equal(await directeur('c2'), 'bob');
  assert.equal(await directeur('c1'), null, 'Bob a quitté c1');
  assert.equal(await dirige('c1', 'ana'), true, 'c1 revient de fait à Ana, qui ne dirige rien');
  assert.deepEqual(await directions('bob'), [{ club: 'c2', par: 'Bob', moi: true, division: '0' }]);
  assert.deepEqual((await releves('bob')).changements, [{ periode: 's1', club: 'c2' }]);
  const s = await diriger('bob', 'c1', true);
  assert.equal(s.ok, false); assert.equal(s.raison, 'saison'); assert.equal(s.periode, 's1');
  // Un changement fait à l'intersaison d'avant ne compte pas pour la saison.
  await db.query(`UPDATE smarves.directions_changements SET periode = 'i1'`);
  assert.equal((await diriger('bob', 'c1', true)).releve, true, 'celui de l\'intersaison n\'empêche pas celui de la saison');
  assert.deepEqual(await un(`SELECT public.smarves_direction_renoncer('bob', 'football') AS r`), { ok: true });
  await db.query(`UPDATE smarves.directions_changements SET periode = 's1'`);
  console.log('ok : un club à la fois, un changement pendant la saison et un pendant l\'intersaison');

  // --- Deux déclarations pour le même club : le plus gros porteur l'emporte ---------------------
  assert.deepEqual(await prendre('ana', 'c3', 1), { ok: true });
  assert.deepEqual(await diriger('ana', 'c3', true), { ok: true }, 'Ana ne dirige que de fait : c3 vacant, elle le prend');
  assert.deepEqual(await prendre('cle', 'c3', 3), { ok: true });
  assert.deepEqual(await prendre('bob', 'c3', 2), { ok: true });
  assert.equal((await diriger('cle', 'c3')).releve, true);
  assert.deepEqual(await diriger('bob', 'c3', true), { ok: false, raison: 'parts' }, 'Clé a mis plus que Bob');
  // Clé retire sa déclaration.
  assert.deepEqual(await un(`SELECT public.smarves_direction_renoncer('cle', 'football') AS r`), { ok: true });
  assert.equal((await releves()).releves.length, 0);
  assert.equal((await diriger('cle', 'c3')).releve, true);
  await echoir();
  assert.equal(await directeur('c3'), 'cle');
  console.log('ok : renoncer, et l\'emporter au plus gros porteur');

  // --- Une relève dont l'auteur a tout rendu ne compte pas ---------------------------------------
  assert.deepEqual(await prendre('ana', 'c3', 9), { ok: true });
  assert.equal((await diriger('ana', 'c3', true)).releve, true);
  await db.query(`DELETE FROM smarves.obligations WHERE club = 'c3' AND pyramide_id = 'ana'`);
  await echoir();
  assert.equal(await directeur('c3'), 'cle');
  await directions();
  assert.equal(await un(`SELECT count(*)::int AS r FROM smarves.directions_releves`), 0);
  console.log('ok : une relève sans part tombe');

  // --- Les droits ------------------------------------------------------------------------------
  for (const role of ['anon', 'authenticated']) {
    await db.query('BEGIN'); await db.query(`SET LOCAL ROLE ${role}`);
    await db.query(`SELECT public.smarves_direction_releves(null, 'football'), public.smarves_directions(null, 'basket')`);
    await refuse(`SELECT * FROM smarves.directions_releves`, [], /permission denied/);
    await db.query('ROLLBACK');
    await db.query('BEGIN'); await db.query(`SET LOCAL ROLE ${role}`);
    await refuse(`SELECT smarves.regler_releves('football')`, [], /permission denied/);
    await db.query('ROLLBACK');
  }
  await refuse(`SELECT public.smarves_direction_releves(null, 'rugby')`, [], /sport invalide/);
  console.log('ok : les droits');
  console.log('TOUT EST BON');
} finally {
  await db.end();
  await admin.query(`DROP DATABASE IF EXISTS ${name}`);
  await admin.end();
}
