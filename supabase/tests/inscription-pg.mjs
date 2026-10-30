// PostgreSQL réel, base jetable locale. Aucune connexion distante n'est permise.
// Rejoue toutes les migrations, pose les trois pilotes tels qu'ils sont en production avant
// 20261031000000_smarves_pensionnaires_par_lasso.sql, applique celle-ci, puis exerce l'inscription,
// le script de nettoyage (à blanc, sous concurrence, pour de bon), le rejeu après nettoyage et les retours arrière.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { randomUUID, createHash } from 'node:crypto';
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
const third = new pg.Client({ connectionString: url.href });
await db.connect(); await second.connect(); await third.connect();
const sql = async p => readFile(new URL(p, import.meta.url), 'utf8');
const PAR_LASSO = '20261031000000_smarves_pensionnaires_par_lasso.sql';
const migration = '../migrations/' + PAR_LASSO;
const rollback = '../rollback/' + PAR_LASSO;
const nettoyage = await sql('../nettoyage/20261031_pensionnaires_pilotes.sql');
const sha = s => createHash('sha256').update(s, 'utf8').digest('hex');
const AGT = sha('lasso-agent:' + '0d6a3f62-4f4e-4c1e-9b7a-6a2d9e0c1b11');
const call = async (client, { ins, human = 'concurrent', dem = 'a'.repeat(64), id = 'doublure:concurrent12', jti = randomUUID(), agent = AGT, nom = 'Rosalie' }) =>
  (await client.query(`SELECT smarves.doublure_inscrire($1, now()+interval '2 minutes', $2, 'Humain', 'creer', $3,
    $4, $5, 'Une histoire de village assez longue pour passer.', null, null, null, 7, 500, $6, $7) AS r`,
  [jti, human, ins, id, nom, dem, agent])).rows[0].r;
const count = async (q, p = []) => (await db.query(`SELECT count(*)::int AS n FROM ${q}`, p)).rows[0].n;

// Les trois pilotes, avec les identifiants relevés en production le 30 octobre 2026.
const BILLY = { id: 'doublure:fqqzbuolq6rimha7', humain: 'cmtdcie9v0000jm04khiynjae', nom: 'Billy Bob (pensionnaire)',
  agent: '3711e506-8436-4d8d-8e90-0881e559d8a6', ins: '431666cd-ccd5-42fb-b26e-962de7bd1b6f', jti: 'jetonpilotebilly0001' };
const FRICK = { id: 'doublure:ttvgc4r80zrc2hbr', humain: 'cmve6nh8n0000ku08qwmc6d1r', nom: 'Frick Francis (pensionnaire)' };
const ESSAI = { id: 'doublure:27vpb1vf9e3i03z9', humain: 'cmvuyz4ve0000l8082b57l86h', nom: 'Essai (pensionnaire)',
  agent: '66b08313-9d26-4e53-bb2b-1c40b16e2124', ins: '7d1b99c1-107c-4557-af88-d51f0a9a662f', jti: 'jetonpiloteessai0001' };
const PILOTES = [BILLY, FRICK, ESSAI];

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
    // Les migrations postérieures (la passerelle Lasso) ont leur propre essai : passerelle-pg.mjs.
    if (/bourse/.test(file) || file >= PAR_LASSO) continue;
    if (file === '20261020080000_smarves_basket_club.sql') await db.query(await sql('./basket-fixture.sql'));
    await db.query(await sql('../migrations/' + file));
  }

  // --- La production avant la migration : trois pilotes, nés par l'ancien chemin. -------------------
  // Lasso réduit à ce que touche le nettoyage (les vraies migrations Lasso sont exercées par l'essai inter-dépôts).
  await db.query(`CREATE SCHEMA lasso;
    CREATE TABLE lasso.agents (id uuid PRIMARY KEY, owner_id text NOT NULL, display_name text NOT NULL, pensionnaire_empreinte text);
    CREATE TABLE lasso.connexions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), agent_id uuid REFERENCES lasso.agents ON DELETE CASCADE, owner_id text, etat text);
    CREATE TABLE lasso.activities (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), agent_id uuid REFERENCES lasso.agents ON DELETE CASCADE, texte text);
    CREATE TABLE lasso.smarves_liens (owner_id text PRIMARY KEY, agent_id uuid NOT NULL REFERENCES lasso.agents ON DELETE CASCADE, empreinte text NOT NULL, consenti timestamptz DEFAULT now(), vues timestamptz);
    CREATE TABLE lasso.inscriptions (id uuid PRIMARY KEY, owner_id text NOT NULL, agent_id uuid REFERENCES lasso.agents ON DELETE SET NULL, op text, etat text);`);
  for (const p of PILOTES) await db.query('INSERT INTO smarves.joueurs (pyramide_id, nom) VALUES ($1, $2)', [p.humain, 'Humain ' + p.nom]);
  await db.query(`SELECT smarves.doublure_ouvrir($1, $2, $3, 'autre', null, null, null, null, null, 7, 500)`, [BILLY.id, BILLY.humain, BILLY.nom]);
  await db.query(`SELECT smarves.doublure_ouvrir($1, $2, $3, 'autre', null, null, null, null, null, 7, 500)`, [FRICK.id, FRICK.humain, FRICK.nom]);
  await db.query(`SELECT smarves.doublure_inscrire($1, now()+interval '2 minutes', $2, 'Humain', 'adopter', $3, null, null, null, null, null, null, 7, 500, null)`,
    [BILLY.jti, BILLY.humain, BILLY.ins]);
  assert.equal((await db.query(`SELECT smarves.doublure_inscrire($1, now()+interval '2 minutes', $2, 'Humain', 'creer', $3, $4, $5,
    'Une histoire de recette assez longue pour passer.', null, null, 'costume__', 7, 500, $6) AS r`,
    [ESSAI.jti, ESSAI.humain, ESSAI.ins, ESSAI.id, ESSAI.nom, 'e'.repeat(64)])).rows[0].r.resultat, 'cree');
  for (const p of PILOTES) {
    await db.query(`INSERT INTO smarves.doublure_gestes (doublure, genre, texte) VALUES ($1, 'dire', 'Bonjour')`, [p.id]);
    await db.query(`INSERT INTO smarves.doublure_reveils (doublure, motif, statut) VALUES ($1, 'session', 'fait')`, [p.id]);
    await db.query(`INSERT INTO smarves.doublure_humeurs (humain, consentement, humeur) VALUES ($1, true, 'sereine')`, [p.humain]);
    await db.query(`INSERT INTO smarves.doublure_pilote (doublure, demande) VALUES ($1, now())`, [p.id]);
  }
  for (const p of [BILLY, FRICK]) await db.query(`INSERT INTO smarves.doublure_acces (humain, jeton_hash) VALUES ($1, $2)`, [p.humain, sha('jeton ' + p.id)]);
  await db.query(`INSERT INTO smarves.doublure_liens (doublure, autre, avis) VALUES ($1, $2, 'un ami'), ($2, $1, 'un rival')`, [BILLY.id, FRICK.id]);
  await db.query(`INSERT INTO smarves.argent_mouvements (pyramide_id, cle, source, motif, montant, solde_apres) VALUES ($1, 'test:1', 'casino', 'mise', -10, 490)`, [FRICK.id]);
  for (const p of [BILLY, ESSAI]) {
    await db.query(`INSERT INTO lasso.agents VALUES ($1, $2, 'Agent ' || $3, $4)`, [p.agent, p.humain, p.nom, sha(p.id)]);
    await db.query(`INSERT INTO lasso.connexions (agent_id, owner_id, etat) VALUES ($1, $2, 'active')`, [p.agent, p.humain]);
    await db.query(`INSERT INTO lasso.activities (agent_id, texte) VALUES ($1, 'publication')`, [p.agent]);
    await db.query(`INSERT INTO lasso.inscriptions VALUES ($1, $2, $3, $4, 'terminee')`, [p.ins, p.humain, p.agent, p === BILLY ? 'adopter' : 'creer']);
  }
  await db.query(`INSERT INTO lasso.smarves_liens (owner_id, agent_id, empreinte) VALUES ($1, $2, $3)`, [BILLY.humain, BILLY.agent, sha(BILLY.id)]);

  // --- La migration ne touche pas aux pilotes ; elle ferme tout chemin indépendant. ----------------
  await db.query(await sql(migration));
  assert.equal(await count('smarves.doublures'), 3, 'migration : les pilotes restent jusqu\'au nettoyage');
  await db.query("UPDATE smarves.doublures SET memoire = 'encore actif' WHERE id = $1", [BILLY.id]);
  console.log('ok : migration appliquée, pilotes encore actifs');
  db.on('notice', n => { if (n.message.startsWith('ok :')) console.log(n.message); });
  await db.query(await sql('./inscription.sql'));

  // --- Même ins, deux créations concurrentes. ------------------------------------------------------
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
  assert.equal(await count('smarves.doublures WHERE humain=$1', ['concurrent']), 1);
  console.log('ok : même ins, deux créations concurrentes, même résultat durable');
  // Coupure après COMMIT Smarves, aucun rattachement Lasso : un nouveau clic restitue le résultat.
  assert.equal((await call(second, { ins })).resultat, 'deja_fait');
  assert.equal((await call(second, { ins, dem: 'b'.repeat(64) })).raison, 'inscription');
  assert.equal((await call(second, { ins, agent: sha('lasso-agent:autre') })).raison, 'inscription');
  assert.equal((await call(second, { ins: randomUUID(), id: 'doublure:concurrent13', nom: 'Autre' })).raison, 'deja_pensionnaire');
  assert.equal((await call(second, { ins })).resultat, 'deja_fait');
  assert.equal(await count('smarves.doublures WHERE humain=$1', ['concurrent']), 1);
  console.log('ok : reprise après interruption, sans doublon ; autre demande ou autre agent refusés sans perdre le succès');

  // --- Nettoyage à blanc : tout reste. --------------------------------------------------------------
  const blanc = [];
  const ecoute = n => { if (n.message.startsWith('nettoyage')) blanc.push(n.message); };
  db.on('notice', ecoute);
  await db.query(nettoyage.replace(/commit;\s*$/, 'rollback;'));
  db.off('notice', ecoute);
  assert.ok(blanc.some(m => m.includes('pensionnaires supprimés (avec leurs données) : 3')), blanc.join('\n'));
  assert.equal(await count('smarves.doublures'), 4);
  assert.equal(await count('lasso.agents WHERE pensionnaire_empreinte IS NOT NULL'), 2);
  console.log('ok : nettoyage à blanc, rien de changé ;', blanc.join(' | '));

  // --- Périmètre différent du relevé : arrêt sans rien changer. -----------------------------------
  await db.query("UPDATE smarves.joueurs SET nom = 'Frick (renommé)' WHERE pyramide_id = $1", [FRICK.id]);
  await assert.rejects(db.query(nettoyage), /Frick Francis.*absent ou différent/);
  await db.query('ROLLBACK').catch(() => {});
  await db.query('UPDATE smarves.joueurs SET nom = $2 WHERE pyramide_id = $1', [FRICK.id, FRICK.nom]);
  assert.equal(await count('smarves.doublures'), 4);
  console.log('ok : périmètre modifié, nettoyage refusé sans effet');

  // --- Nettoyage sous concurrence. ------------------------------------------------------------------
  // Une action de pilote en cours (verrou sur sa ligne) : le nettoyage l'attend.
  await second.query('BEGIN');
  await second.query("UPDATE smarves.doublures SET memoire = 'tour en cours' WHERE id = $1", [FRICK.id]);
  await third.query('BEGIN');
  let cleaned = false;
  const enCours = third.query(nettoyage.replace(/commit;\s*$/, '')).then(() => { cleaned = true; });
  await new Promise(r => setTimeout(r, 300));
  assert.equal(cleaned, false, 'le nettoyage attend l\'action du pilote');
  await second.query('COMMIT');
  await enCours;
  // Le nettoyage tient ses verrous jusqu'au COMMIT : une action de pilote attend, une création Lasso d'un autre humain passe.
  await db.query("SET lock_timeout = '300ms'");
  await assert.rejects(db.query("UPDATE smarves.doublures SET memoire = 'après' WHERE id = $1", [BILLY.id]), e => e.code === '55P03');
  await assert.rejects(call(db, { ins: randomUUID(), human: BILLY.humain, id: 'doublure:billyneuf1234', nom: 'Billy Neuf' }), e => e.code === '55P03');
  const t = performance.now();
  const autre = await call(db, { ins: randomUUID(), human: 'autrehumain', id: 'doublure:autrehumain12', nom: 'Léontine' });
  assert.equal(autre.resultat, 'cree');
  console.log(`ok : pendant le nettoyage, action de pilote en attente, création d'un autre humain en ${(performance.now() - t).toFixed(1)} ms`);
  await db.query("SET lock_timeout = '0'");
  await third.query('COMMIT');

  // --- Après le nettoyage. --------------------------------------------------------------------------
  for (const p of PILOTES) {
    assert.equal(await count('smarves.joueurs WHERE pyramide_id=$1', [p.id]), 0, p.nom);
    assert.equal(await count('smarves.joueurs WHERE pyramide_id=$1', [p.humain]), 1, 'compte humain conservé');
    assert.equal(await count('smarves.argent_mouvements WHERE pyramide_id=$1', [p.id]), 0);
    assert.equal(await count('smarves.doublure_acces WHERE humain=$1', [p.humain]), 0);
    assert.equal(await count('smarves.doublure_humeurs WHERE humain=$1', [p.humain]), 0);
  }
  assert.equal(await count('smarves.doublure_liens'), 0);
  assert.equal(await count('smarves.inscriptions WHERE ins = ANY($1::uuid[])', [[BILLY.ins, ESSAI.ins]]), 0);
  assert.equal(await count('smarves.inscriptions_closes WHERE ins = ANY($1::uuid[])', [[BILLY.ins, ESSAI.ins]]), 2);
  assert.equal(await count('smarves.inscription_jetons WHERE jti = ANY($1)', [[BILLY.jti, ESSAI.jti]]), 2, 'les jti vus restent');
  assert.equal(await count('lasso.agents'), 2, 'agents Lasso conservés');
  assert.equal(await count('lasso.agents WHERE pensionnaire_empreinte IS NOT NULL'), 0);
  assert.equal(await count('lasso.connexions'), 2, 'connexions Lasso conservées');
  assert.equal(await count('lasso.activities'), 2, 'activités Lasso conservées');
  assert.equal(await count('lasso.smarves_liens'), 0);
  assert.equal(await count('lasso.inscriptions'), 0);
  assert.equal(await count('smarves.doublures'), 2, 'les pensionnaires nés de Lasso restent');
  assert.equal(await count("pg_constraint WHERE conname = 'inscriptions_par_lasso' AND convalidated"), 1);
  console.log('ok : nettoyage fait, périmètre exact, comptes, agents, connexions et autres pensionnaires intacts, contrainte validée');

  // --- Rejeu après nettoyage. -----------------------------------------------------------------------
  // Le jeton déjà employé par Essai : son jti est toujours vu.
  assert.equal((await call(db, { ins: ESSAI.ins, human: ESSAI.humain, jti: ESSAI.jti, id: ESSAI.id, nom: 'Essai', dem: 'e'.repeat(64) })).raison, 'rejeu');
  // Un autre jeton encore valable pour la même demande : l'inscription est close.
  assert.equal((await call(db, { ins: ESSAI.ins, human: ESSAI.humain, id: ESSAI.id, nom: 'Essai', dem: 'e'.repeat(64) })).raison, 'inscription');
  assert.equal((await call(db, { ins: BILLY.ins, human: BILLY.humain, id: BILLY.id, nom: 'Billy Bob' })).raison, 'inscription');
  assert.equal(await count('smarves.doublures WHERE humain = ANY($1)', [PILOTES.map(p => p.humain)]), 0);
  // Une nouvelle demande Lasso pour l'humain de Billy : un nouveau pensionnaire, sans rien de l'ancien.
  const neuf = await call(db, { ins: randomUUID(), human: BILLY.humain, id: 'doublure:billyneuf1234', nom: 'Billy Bob' });
  assert.equal(neuf.resultat, 'cree');
  assert.equal(await count('smarves.doublure_liens WHERE doublure=$1', ['doublure:billyneuf1234']), 0);
  console.log('ok : rejeu après nettoyage refusé (même jti, autre jti), nouvelle création Lasso possible');
  await assert.rejects(db.query(nettoyage), /absent ou différent/);
  await db.query('ROLLBACK').catch(() => {});
  console.log('ok : le nettoyage ne se rejoue pas');

  if (process.env.LASSO_TEST_SOURCE) {
    const { integration } = await import(pathToFileURL(resolve(process.env.LASSO_TEST_SOURCE, 'scripts/essai-inscription-integre.mjs')));
    // L'essai inter-dépôts applique les vraies migrations Lasso : le schéma minimal de ce test s'efface d'abord.
    await db.query('DROP SCHEMA lasso CASCADE');
    await integration({ db, connectionString: url.href });
  }

  // --- Retour arrière : l'interdiction tient toujours. ---------------------------------------------
  await db.query(await sql(rollback));
  await db.query("INSERT INTO smarves.joueurs (pyramide_id, nom) VALUES ('autrehumain2', 'H')");
  await db.query('BEGIN');
  await db.query(`SELECT smarves.doublure_ouvrir('doublure:apresretour1', 'autrehumain2', 'Après Retour', 'autre', null, null, null, null, null, 7, 500)`);
  await assert.rejects(db.query('COMMIT'), e => e.code === '23514');
  await assert.rejects(db.query(`SELECT smarves.doublure_inscrire('jetonretour000001', now()+interval '2 minutes', 'autrehumain3', 'H', 'adopter',
    gen_random_uuid(), null, null, null, null, null, null, 7, 500, null)`), /operation invalide/);
  const ancien = (await db.query(`SELECT smarves.doublure_inscrire('jetonretour000002', now()+interval '2 minutes', 'autrehumain4', 'H', 'creer',
    gen_random_uuid(), 'doublure:apresretour2', 'Après Retour Deux', 'Une histoire de village assez longue pour passer.', null, null, null, 7, 500, $1) AS r`, ['c'.repeat(64)])).rows[0].r;
  assert.equal(ancien.resultat, 'cree');
  assert.equal((await db.query(`SELECT smarves.doublure_inscrire('jetonretour000003', now()+interval '2 minutes', $1, 'H', 'creer',
    $2, $3, 'Essai', 'Une histoire de village assez longue pour passer.', null, null, null, 7, 500, $4) AS r`,
    [ESSAI.humain, ESSAI.ins, ESSAI.id, 'e'.repeat(64)])).rows[0].r.raison, 'inscription');
  console.log('ok : retour arrière, création indépendante et adoption toujours refusées, inscriptions closes toujours closes');
  // L'inscription faite pendant le retour arrière n'a pas d'agent : la réapplication la garde, sans la valider.
  await db.query(await sql(migration));
  assert.equal(await count("pg_constraint WHERE conname = 'inscriptions_par_lasso' AND NOT convalidated"), 1);
  await assert.rejects(db.query(await sql(migration)), /déjà appliquée/);
  console.log('ok : réapplication après retour arrière ; seconde application refusée');
} finally {
  await Promise.allSettled([db.end(), second.end(), third.end()]);
  await admin.query(`DROP DATABASE ${name} WITH (FORCE)`);
  await admin.end();
}
