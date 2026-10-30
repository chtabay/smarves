-- Essais des migrations 20261030000000_smarves_pensionnaires_inscription.sql et
-- 20261031000000_smarves_pensionnaires_par_lasso.sql, sur une base LOCALE qui a rejoué toutes les migrations
-- (voir supabase/tests/inscription-pg.mjs). Chaque contrôle lève une exception au premier écart ; tout se passe
-- dans une transaction annulée à la fin : la base reste telle quelle.
--   psql -v ON_ERROR_STOP=1 -d <base locale> -f supabase/tests/inscription.sql
begin;

create function pg_temp.attendre(c boolean, quoi text) returns void language plpgsql as $$
begin
  if c is not true then raise exception 'ÉCHEC : %', quoi; end if;
  raise notice 'ok : %', quoi;
end $$;

-- Une création signée : p_agent est l'empreinte de l'agent Lasso (`agt`).
create function pg_temp.inscrire(jti text, humain text, ins uuid, id text, nom text, agent text default repeat('1', 64), op text default 'creer')
  returns json language sql as $$
  select smarves.doublure_inscrire(jti, now() + interval '2 minutes', humain, 'Nom Pyramides', op, ins, id, nom,
    'Une histoire de village assez longue pour passer.', null, null, 'costume__', 7, 500, repeat('a', 64), agent)
$$;

-- Le refus d'une création au moment où la transaction voudrait la valider.
create function pg_temp.refuse_au_commit(requete text) returns boolean language plpgsql as $$
begin
  begin
    execute requete;
    set constraints all immediate;
    return false;
  exception when check_violation then
    return true;
  end;
end $$;

-- La clé de nom.
select pg_temp.attendre(smarves.nom_cle('Billy Bob (pensionnaire)') = smarves.nom_cle('  BILLY   bob '), 'clé : casse, espaces, suffixe');
select pg_temp.attendre(smarves.nom_cle('Élodie d’Arc') = smarves.nom_cle('elodie d''arc'), 'clé : accents et apostrophes');
select pg_temp.attendre(smarves.nom_cle('Jean-Pierre') = smarves.nom_cle('Jean Pierre'), 'clé : tiret');
select pg_temp.attendre(smarves.nom_cle('Billy Bob') <> smarves.nom_cle('Billy Bab'), 'clé : deux noms distincts');

-- La création indépendante est refusée par la base, quel que soit le chemin qui l'essaie.
insert into smarves.joueurs (pyramide_id, nom) values ('humainA', 'Alice Joueuse');
select pg_temp.attendre(pg_temp.refuse_au_commit($q$select smarves.doublure_ouvrir('doublure:aaaaaaaaaaaa', 'humainA', 'Clé (pensionnaire)', 'autre', 'mistral', 'm', null, 'chiffre', '1234', 7, 500)$q$),
  'mode clé : création indépendante refusée');
select pg_temp.attendre(pg_temp.refuse_au_commit($q$select smarves.doublure_ouvrir('doublure:aaaaaaaaaaab', 'humainA', 'Connecteur (pensionnaire)', 'autre', null, null, null, null, null, 7, 500)$q$),
  'connecteur (smarves_creer) : création indépendante refusée');
select pg_temp.attendre(pg_temp.refuse_au_commit($q$
  insert into smarves.joueurs (pyramide_id, nom) values ('doublure:aaaaaaaaaaac', 'Direct (pensionnaire)');
  insert into smarves.doublures (id, humain, personnalite) values ('doublure:aaaaaaaaaaac', 'humainA', 'autre')$q$),
  'insertion directe refusée');
set constraints all deferred;
select pg_temp.attendre(not exists (select 1 from smarves.doublures where humain = 'humainA'), 'aucun pensionnaire hors Lasso');

-- Seule la création signée passe, et seulement « creer ».
do $$ begin
  perform pg_temp.inscrire('jetonadopt0000001', 'humainA', '00000000-0000-4000-8000-000000000001', null, null, repeat('1', 64), 'adopter');
  raise exception 'ÉCHEC : adoption acceptée';
exception when raise_exception then
  if sqlerrm <> 'operation invalide' then raise; end if;
  raise notice 'ok : adoption refusée';
end $$;
do $$ begin
  perform pg_temp.inscrire('jetonsansagent001', 'humainA', '00000000-0000-4000-8000-000000000002', 'doublure:bbbbbbbbbbbb', 'Sans Agent', null);
  raise exception 'ÉCHEC : création sans agent acceptée';
exception when raise_exception then
  if sqlerrm <> 'agent invalide' then raise; end if;
  raise notice 'ok : création sans agent Lasso refusée';
end $$;

select pg_temp.attendre(not exists (select 1 from smarves.joueurs where pyramide_id = 'humainC'), 'humainC n''a jamais joué');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000001', 'humainC', '00000000-0000-4000-8000-000000000010',
  'doublure:cccccccccccc', 'Rosalie (pensionnaire)')->>'resultat') = 'cree', 'création pour un nouveau joueur');
set constraints all immediate;
set constraints all deferred;
select pg_temp.attendre(true, 'création signée acceptée au commit');
select pg_temp.attendre(exists (select 1 from smarves.joueurs where pyramide_id = 'humainC' and nom = 'Nom Pyramides'), 'ligne joueur créée');
select pg_temp.attendre(exists (select 1 from smarves.doublures where id = 'doublure:cccccccccccc' and humain = 'humainC' and mode = 'agent'
  and personnalite = 'autre' and caractere like 'Une histoire%'), 'pensionnaire en mode agent, avec son histoire');
select pg_temp.attendre(exists (select 1 from smarves.inscriptions where doublure = 'doublure:cccccccccccc' and agent = repeat('1', 64)), 'agent Lasso enregistré');
select pg_temp.attendre(exists (select 1 from smarves.doublure_corps where doublure = 'doublure:cccccccccccc' and tenue = 'costume__'), 'allure posée');
select pg_temp.attendre((select solde from smarves.argent_comptes where pyramide_id = 'doublure:cccccccccccc') = 500, 'pécule');

-- Reprise, rejeu, demandes divergentes.
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000001', 'humainC', '00000000-0000-4000-8000-000000000099',
  'doublure:dddddddddddd', 'Prosper')->>'raison') = 'rejeu', 'rejeu du même jti');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000002', 'humainC', '00000000-0000-4000-8000-000000000010',
  'doublure:dddddddddddd', 'Rosalie (pensionnaire)')::jsonb) = '{"ok": true, "resultat": "deja_fait", "id": "doublure:cccccccccccc", "nom": "Rosalie (pensionnaire)"}'::jsonb,
  'reprise de la même inscription, même résultat');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000003', 'humainC', '00000000-0000-4000-8000-000000000010',
  'doublure:dddddddddddd', 'Rosalie (pensionnaire)', repeat('2', 64))->>'raison') = 'inscription', 'même ins, autre agent : refusé');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000004', 'humainB', '00000000-0000-4000-8000-000000000010',
  'doublure:dddddddddddd', 'Rosalie (pensionnaire)')->>'raison') = 'inscription', 'même ins, autre humain : refusé');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000005', 'humainC', '00000000-0000-4000-8000-000000000011',
  'doublure:dddddddddddd', 'Autre Nom (pensionnaire)')->>'raison') = 'deja_pensionnaire', 'un seul pensionnaire par compte, sans transfert');
select pg_temp.attendre((select count(*) from smarves.doublures where humain = 'humainC') = 1, 'aucun doublon');
select pg_temp.attendre((pg_temp.inscrire('jetoncreer0000006', 'humainD', '00000000-0000-4000-8000-000000000012',
  'doublure:eeeeeeeeeeee', 'ROSALIE (pensionnaire)')->>'raison') = 'nom_pris', 'nom déjà pris (casse différente)');
select pg_temp.attendre(not exists (select 1 from smarves.joueurs where pyramide_id = 'doublure:eeeeeeeeeeee'), 'rien de créé après nom pris');

-- Une inscription close ne renaît pas, même avec un jeton neuf.
insert into smarves.inscriptions_closes (ins) values ('00000000-0000-4000-8000-000000000020');
select pg_temp.attendre((pg_temp.inscrire('jetonclose0000001', 'humainG', '00000000-0000-4000-8000-000000000020',
  'doublure:gggggggggggg', 'Gaspard (pensionnaire)')->>'raison') = 'inscription', 'inscription close refusée');
select pg_temp.attendre(not exists (select 1 from smarves.doublures where humain = 'humainG'), 'rien de créé pour une inscription close');

-- Déconnecter l'assistant : le lien et la session tombent, le pensionnaire reste.
insert into smarves.doublure_acces (humain, jeton_hash, outil_ok) values ('humainC', repeat('f', 64), now());
insert into smarves.doublure_pilote (doublure, demande, geste) values ('doublure:cccccccccccc', now(), '{"touche": "e"}');
update smarves.doublure_corps set present_jusqu = now() + interval '10 minutes' where doublure = 'doublure:cccccccccccc';
select pg_temp.attendre((smarves.doublure_deconnecter('humainC')->>'lien')::boolean, 'déconnexion : lien retiré');
select pg_temp.attendre(not exists (select 1 from smarves.doublure_acces where humain = 'humainC'), 'déconnexion : plus de jeton');
select pg_temp.attendre(exists (select 1 from smarves.doublure_pilote where doublure = 'doublure:cccccccccccc' and demande is null and geste is null), 'déconnexion : session de jeu arrêtée');
select pg_temp.attendre(exists (select 1 from smarves.doublure_corps where doublure = 'doublure:cccccccccccc' and present_jusqu <= now()), 'déconnexion : le corps quitte la place');
select pg_temp.attendre(exists (select 1 from smarves.doublures where id = 'doublure:cccccccccccc'), 'déconnexion : le pensionnaire reste');
select pg_temp.attendre(not (smarves.doublure_deconnecter('humainC')->>'lien')::boolean, 'déconnexion : deux fois sans erreur');

-- Débit.
select pg_temp.attendre((select bool_and(smarves.inscription_debit(repeat('a', 64), 3)) from generate_series(1, 3)), 'débit : trois passent');
select pg_temp.attendre(not smarves.inscription_debit(repeat('a', 64), 3), 'débit : le quatrième est refusé');

-- Trop d'inscriptions en une heure (des essais qui échouent comptent aussi).
select pg_temp.inscrire('jetontrop0000' || lpad(g::text, 4, '0'), 'humainC', gen_random_uuid(), 'doublure:hhhhhhhhhhh' || g, 'Trop ' || g) from generate_series(1, 9) g;
select pg_temp.attendre((pg_temp.inscrire('jetontrop00000011', 'humainC', gen_random_uuid(), 'doublure:hhhhhhhhhhhz', 'Trop Z')->>'raison') = 'trop', 'au plus dix jetons par heure');

-- Personne d'autre que le propriétaire des fonctions ne peut les appeler.
select pg_temp.attendre(not has_function_privilege('anon', 'smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text, text)', 'execute'), 'anon sans droit');
select pg_temp.attendre(not has_function_privilege('authenticated', 'smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text, text)', 'execute'), 'authenticated sans droit');
select pg_temp.attendre(not has_function_privilege('authenticated', 'smarves.doublure_deconnecter(text)', 'execute'), 'déconnexion fermée');
select pg_temp.attendre(to_regprocedure('smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text)') is null, 'ancienne signature retirée');
select pg_temp.attendre(not has_table_privilege('anon', 'smarves.inscriptions', 'select'), 'tables fermées');
select pg_temp.attendre(not has_table_privilege('anon', 'smarves.inscriptions_closes', 'select'), 'inscriptions closes fermées');

rollback;
