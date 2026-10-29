-- Essais de la migration 20261030000000_smarves_pensionnaires_inscription.sql, sur une base LOCALE qui a
-- rejoué toutes les migrations (voir supabase/tests/README.md). Chaque contrôle lève une exception au premier
-- écart ; tout se passe dans une transaction annulée à la fin : la base reste telle quelle.
--   psql -v ON_ERROR_STOP=1 -d <base locale> -f supabase/tests/inscription.sql
begin;

create function pg_temp.attendre(c boolean, quoi text) returns void language plpgsql as $$
begin
  if c is not true then raise exception 'ÉCHEC : %', quoi; end if;
  raise notice 'ok : %', quoi;
end $$;

create function pg_temp.inscrire(jti text, humain text, op text, ins uuid, id text default null, nom text default null)
  returns json language sql as $$
  select smarves.doublure_inscrire(jti, now() + interval '2 minutes', humain, 'Nom Pyramides', op, ins, id, nom,
    case when op = 'creer' then 'Une histoire de village assez longue pour passer.' end, null, null, 'costume__', 7, 500, case when op = 'creer' then repeat('a', 64) end)
$$;

-- Un joueur qui tient déjà un pensionnaire, et ses données de jeu.
insert into smarves.joueurs (pyramide_id, nom) values ('humainA', 'Alice Joueuse');
select smarves.doublure_ouvrir('doublure:aaaaaaaaaaaa', 'humainA', 'Billy Bob (pensionnaire)', 'autre', null, null, null, null, null, 7, 500);
update smarves.doublures set memoire = 'MEMOIRE-PRIVEE', caractere = 'HISTOIRE-DE-BILLY' where id = 'doublure:aaaaaaaaaaaa';
create temp table avant as select d.*, j.nom from smarves.doublures d join smarves.joueurs j on j.pyramide_id = d.id;

-- La clé de nom.
select pg_temp.attendre(smarves.nom_cle('Billy Bob (pensionnaire)') = smarves.nom_cle('  BILLY   bob '), 'clé : casse, espaces, suffixe');
select pg_temp.attendre(smarves.nom_cle('Élodie d’Arc') = smarves.nom_cle('elodie d''arc'), 'clé : accents et apostrophes');
select pg_temp.attendre(smarves.nom_cle('Jean-Pierre') = smarves.nom_cle('Jean Pierre'), 'clé : tiret');
select pg_temp.attendre(smarves.nom_cle('Billy Bob') <> smarves.nom_cle('Billy Bab'), 'clé : deux noms distincts');

-- Adoption : le pensionnaire du seul humain authentifié, rien n'est écrit dans ses données.
select pg_temp.attendre((pg_temp.inscrire('jetonadopt0000001', 'humainA', 'adopter', '00000000-0000-4000-8000-000000000001')::jsonb)
  = '{"ok": true, "resultat": "adopte", "id": "doublure:aaaaaaaaaaaa", "nom": "Billy Bob (pensionnaire)"}'::jsonb, 'adoption');
select pg_temp.attendre(not exists (select d.*, j.nom from smarves.doublures d join smarves.joueurs j on j.pyramide_id = d.id
  except select * from avant), 'adoption : aucune donnée de jeu modifiée');
select pg_temp.attendre((pg_temp.inscrire('jetonadopt0000001', 'humainA', 'adopter', '00000000-0000-4000-8000-000000000002')->>'raison') = 'rejeu', 'rejeu du même jti');
select pg_temp.attendre((pg_temp.inscrire('jetonadopt0000002', 'humainA', 'adopter', '00000000-0000-4000-8000-000000000001')->>'resultat') = 'deja_fait', 'reprise de la même inscription');
select pg_temp.attendre((pg_temp.inscrire('jetonadopt0000003', 'humainB', 'adopter', '00000000-0000-4000-8000-000000000001')->>'raison') = 'inscription', 'inscription d''un autre humain');
select pg_temp.attendre((pg_temp.inscrire('jetonadopt0000004', 'humainB', 'adopter', '00000000-0000-4000-8000-000000000003')->>'raison') = 'aucun_pensionnaire', 'adoption sans pensionnaire');

-- Création pour un compte qui n'a jamais joué.
select pg_temp.attendre(not exists (select 1 from smarves.joueurs where pyramide_id = 'humainC'), 'humainC n''a jamais joué');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000001', 'humainC', 'creer', '00000000-0000-4000-8000-000000000010',
  'doublure:cccccccccccc', 'Rosalie (pensionnaire)')->>'resultat') = 'cree', 'création pour un nouveau joueur');
select pg_temp.attendre(exists (select 1 from smarves.joueurs where pyramide_id = 'humainC' and nom = 'Nom Pyramides'), 'ligne joueur créée');
select pg_temp.attendre(exists (select 1 from smarves.doublures where id = 'doublure:cccccccccccc' and humain = 'humainC' and mode = 'agent'
  and personnalite = 'autre' and caractere like 'Une histoire%'), 'pensionnaire en mode agent, avec son histoire');
select pg_temp.attendre(exists (select 1 from smarves.doublure_corps where doublure = 'doublure:cccccccccccc' and tenue = 'costume__'), 'allure posée');
select pg_temp.attendre((select solde from smarves.argent_comptes where pyramide_id = 'doublure:cccccccccccc') = 500, 'pécule');

-- Refus.
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000002', 'humainC', 'creer', '00000000-0000-4000-8000-000000000011',
  'doublure:dddddddddddd', 'Autre Nom (pensionnaire)')->>'raison') = 'deja_pensionnaire', 'un seul pensionnaire par compte');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000003', 'humainD', 'creer', '00000000-0000-4000-8000-000000000012',
  'doublure:eeeeeeeeeeee', 'ROSALIE (pensionnaire)')->>'raison') = 'nom_pris', 'nom déjà pris (casse différente)');
select pg_temp.attendre(not exists (select 1 from smarves.joueurs where pyramide_id = 'doublure:eeeeeeeeeeee'), 'rien de créé après nom pris');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000003', 'humainD', 'creer', '00000000-0000-4000-8000-000000000013',
  'doublure:ffffffffffff', 'Prosper (pensionnaire)')->>'raison') = 'rejeu', 'un refus consomme aussi le jti');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000004', 'humainC', 'adopter', '00000000-0000-4000-8000-000000000010')->>'raison') = 'inscription', 'même ins, autre opération');

-- Les autres chemins de création suivent la même règle.
select pg_temp.attendre((smarves.doublure_ouvrir('doublure:gggggggggggg', 'humainE', 'Billy-Bob (pensionnaire)', 'autre', null, null, null, null, null, 7, 500)->>'raison') = 'nom',
  'doublure_ouvrir : nom pris rendu comme raison');
insert into smarves.joueurs (pyramide_id, nom) values ('humainE', 'E');
select pg_temp.attendre((smarves.doublure_ouvrir('doublure:gggggggggggg', 'humainE', 'Gaspard (pensionnaire)', 'autre', null, null, null, null, null, 7, 500)->>'ok')::boolean, 'doublure_ouvrir : création normale');

-- Débit.
select pg_temp.attendre((select bool_and(smarves.inscription_debit(repeat('a', 64), 3)) from generate_series(1, 3)), 'débit : trois passent');
select pg_temp.attendre(not smarves.inscription_debit(repeat('a', 64), 3), 'débit : le quatrième est refusé');

-- Trop d'inscriptions en une heure.
select pg_temp.inscrire('jetontrop0000' || lpad(g::text, 4, '0'), 'humainF', 'adopter', gen_random_uuid()) from generate_series(1, 10) g;
select pg_temp.attendre((pg_temp.inscrire('jetontrop00000011', 'humainF', 'adopter', gen_random_uuid())->>'raison') = 'trop', 'au plus dix jetons par heure');

-- Personne d'autre que le propriétaire des fonctions ne peut les appeler.
select pg_temp.attendre(not has_function_privilege('anon', 'smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text)', 'execute'), 'anon sans droit');
select pg_temp.attendre(not has_function_privilege('authenticated', 'smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text)', 'execute'), 'authenticated sans droit');
select pg_temp.attendre(not has_table_privilege('anon', 'smarves.inscriptions', 'select'), 'tables fermées');

rollback;

