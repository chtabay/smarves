-- Nettoyage des trois pensionnaires pilotes (décision de Guillaume, 30 octobre 2026) : Billy Bob, Frick Francis
-- et Essai. Aucun n'est conservé, aucun n'est adopté, aucune exception ne reste.
--
-- À exécuter UNE fois, en production, après 20261031000000_smarves_pensionnaires_par_lasso.sql, sur le feu vert
-- explicite de Guillaume. Irréversible : faire une sauvegarde (ou noter l'heure pour une restauration PITR) avant.
-- Essai à blanc : remplacer le « commit; » final par « rollback; » ; les NOTICE donnent ce qui serait supprimé.
--
-- Périmètre FERMÉ : trois identifiants de pensionnaire, leurs trois humains, deux inscriptions, deux agents Lasso.
-- Le script s'arrête sans rien changer si la base ne correspond pas exactement à ce qui a été relevé le
-- 30 octobre 2026 (noms, humains, porteurs), ou s'il existe un autre pensionnaire né hors du parcours Lasso.
--
-- Ce qui part :
--   - les lignes smarves.joueurs des trois pensionnaires, et par cascade tout ce qui les référence
--     (doublures, corps, pilote, gestes, réveils, liens dans les deux sens, comptes, positions, présences,
--     vitrines, annonces, passages, mots, parties, basket, mercato…), y compris leur compte et leur journal
--     d'argent (smarves.argent_comptes puis argent_mouvements, en cascade : le journal figé ne cède qu'à elle) ;
--   - leurs lignes smarves.inscriptions (les deux ins sont recopiés dans smarves.inscriptions_closes) ;
--   - le lien du connecteur et le mot d'humeur des trois humains (ce que fait aussi l'effacement du jeu) ;
--   - côté Lasso : l'empreinte portée par les deux agents, l'accord smarves_liens de ces empreintes (colonne
--     « vues » des migrations 009/010 comprise, si elles sont appliquées), et les deux lignes lasso.inscriptions.
-- Ce qui reste : les trois comptes humains (smarves.joueurs de l'humain, Pyramides2), les agents Lasso, leurs
-- connexions Lasso et leurs activités ; les jti déjà vus (smarves.inscription_jetons), purgés normalement un
-- jour après leur expiration, pour qu'aucun jeton encore valable ne soit rejoué.
--
-- Concurrence : verrous consultatifs par humain pilote (ceux de l'inscription Smarves et du rattachement Lasso)
-- et verrous de ligne sur les seuls pensionnaires pilotes et leurs liens de connecteur. Une action d'un pilote
-- en cours attend la fin de ce script puis ne trouve plus rien ; la création Lasso d'un autre humain n'attend pas.
begin;
set local lock_timeout = '10s';
set local statement_timeout = '120s';

create temp table nettoyage_pilotes (
  doublure text primary key,
  humain text not null,
  nom text not null,
  agent uuid,          -- l'agent Lasso qui porte l'empreinte, s'il y en a un
  ins uuid             -- l'inscription Smarves/Lasso qui le désigne, s'il y en a une
) on commit drop;
insert into nettoyage_pilotes values
  ('doublure:fqqzbuolq6rimha7', 'cmtdcie9v0000jm04khiynjae', 'Billy Bob (pensionnaire)',     '3711e506-8436-4d8d-8e90-0881e559d8a6', '431666cd-ccd5-42fb-b26e-962de7bd1b6f'),
  ('doublure:ttvgc4r80zrc2hbr', 'cmve6nh8n0000ku08qwmc6d1r', 'Frick Francis (pensionnaire)', null,                                   null),
  ('doublure:27vpb1vf9e3i03z9', 'cmvuyz4ve0000l8082b57l86h', 'Essai (pensionnaire)',         '66b08313-9d26-4e53-bb2b-1c40b16e2124', '7d1b99c1-107c-4557-af88-d51f0a9a662f');

do $nettoyage$
declare
  p record;
  n bigint;
  e text;
  reste text;
  humains bigint;
begin
  if to_regclass('smarves.inscriptions_closes') is null
     or not exists (select 1 from pg_constraint where conname = 'inscriptions_par_lasso' and conrelid = 'smarves.inscriptions'::regclass) then
    raise exception 'nettoyage : appliquer 20261031000000_smarves_pensionnaires_par_lasso d''abord';
  end if;
  if to_regclass('lasso.agents') is null or to_regclass('lasso.smarves_liens') is null or to_regclass('lasso.inscriptions') is null then
    raise exception 'nettoyage : schéma Lasso introuvable';
  end if;

  -- 1. Verrous, dans un ordre fixe. Ceux de l'inscription (Smarves) et du rattachement (Lasso) des seuls humains pilotes.
  for p in select * from nettoyage_pilotes order by humain loop
    perform pg_advisory_xact_lock(hashtextextended('smarves:ins-humain:' || p.humain, 0));
    perform pg_advisory_xact_lock(hashtextextended('lasso.avatar:' || p.humain, 0));
  end loop;
  perform 1 from smarves.joueurs where pyramide_id in (select doublure from nettoyage_pilotes) order by pyramide_id for update;
  perform 1 from smarves.doublures where id in (select doublure from nettoyage_pilotes) order by id for update;
  perform 1 from smarves.doublure_acces where humain in (select humain from nettoyage_pilotes) order by humain for update;

  select count(*) into humains from smarves.joueurs where pyramide_id in (select humain from nettoyage_pilotes);

  -- 2. Le périmètre, vérifié sous verrou : exactement ce qui a été relevé.
  for p in select * from nettoyage_pilotes loop
    if not exists (select 1 from smarves.doublures d join smarves.joueurs j on j.pyramide_id = d.id
                   where d.id = p.doublure and d.humain = p.humain and j.nom = p.nom) then
      raise exception 'nettoyage : % (%) absent ou différent du relevé ; rien n''a été changé', p.nom, p.doublure;
    end if;
    e := encode(sha256(convert_to(p.doublure, 'UTF8')), 'hex');
    if exists (select 1 from lasso.agents a where a.pensionnaire_empreinte = e
               and (p.agent is null or a.id <> p.agent or a.owner_id <> p.humain)) then
      raise exception 'nettoyage : % porté par un agent Lasso inattendu ; rien n''a été changé', p.nom;
    end if;
    if exists (select 1 from smarves.inscriptions i where i.doublure = p.doublure and i.ins is distinct from p.ins) then
      raise exception 'nettoyage : % désigné par une inscription inattendue ; rien n''a été changé', p.nom;
    end if;
  end loop;
  -- Tout autre pensionnaire doit être né du parcours Lasso : sinon le périmètre a changé depuis le relevé.
  select string_agg(d.id, ', ') into reste from smarves.doublures d
   where d.id not in (select doublure from nettoyage_pilotes)
     and not exists (select 1 from smarves.inscriptions i where i.doublure = d.id and i.humain = d.humain
                     and i.op = 'creer' and i.resultat = 'cree' and i.agent is not null);
  if reste is not null then
    raise exception 'nettoyage : pensionnaires hors parcours Lasso non prévus (%) ; rien n''a été changé', reste;
  end if;
  -- Les autres inscriptions anciennes (sans agent) bloqueraient la validation finale : on les signale, on n'y touche pas.
  select string_agg(i.ins::text, ', ') into reste from smarves.inscriptions i
   where i.doublure not in (select doublure from nettoyage_pilotes)
     and not (i.op = 'creer' and i.resultat = 'cree' and i.agent is not null and i.dem is not null);
  if reste is not null then
    raise exception 'nettoyage : inscriptions anciennes hors périmètre (%) ; rien n''a été changé', reste;
  end if;

  -- 3. Révocation : le lien du connecteur des trois humains (la session de jeu part avec le pensionnaire, étape 5).
  delete from smarves.doublure_acces where humain in (select humain from nettoyage_pilotes);
  get diagnostics n = row_count; raise notice 'nettoyage : liens de connecteur révoqués : %', n;

  -- 4. Lasso : seulement ce qui désigne ces trois pensionnaires.
  delete from lasso.smarves_liens l
   where (l.owner_id, l.empreinte) in (select humain, encode(sha256(convert_to(doublure, 'UTF8')), 'hex') from nettoyage_pilotes);
  get diagnostics n = row_count; raise notice 'nettoyage : accords Lasso retirés : %', n;
  update lasso.agents a set pensionnaire_empreinte = null
   where (a.id, a.owner_id, a.pensionnaire_empreinte) in
     (select agent, humain, encode(sha256(convert_to(doublure, 'UTF8')), 'hex') from nettoyage_pilotes where agent is not null);
  get diagnostics n = row_count; raise notice 'nettoyage : agents Lasso libérés (conservés) : %', n;
  delete from lasso.inscriptions li
   where (li.id, li.owner_id) in (select ins, humain from nettoyage_pilotes where ins is not null);
  get diagnostics n = row_count; raise notice 'nettoyage : demandes Lasso retirées : %', n;

  -- 5. Smarves : l'inscription se ferme avant de disparaître ; ses jti restent vus.
  insert into smarves.inscriptions_closes (ins)
    select ins from nettoyage_pilotes where ins is not null on conflict do nothing;
  delete from smarves.inscriptions where doublure in (select doublure from nettoyage_pilotes);
  get diagnostics n = row_count; raise notice 'nettoyage : inscriptions Smarves closes : %', n;
  delete from smarves.doublure_humeurs where humain in (select humain from nettoyage_pilotes);
  delete from smarves.joueurs where pyramide_id in (select doublure from nettoyage_pilotes);
  get diagnostics n = row_count; raise notice 'nettoyage : pensionnaires supprimés (avec leurs données) : %', n;

  -- 6. Contrôles : plus aucune trace des trois identifiants, dans aucune colonne texte des schémas concernés.
  for p in select c.table_schema, c.table_name, c.column_name from information_schema.columns c
           join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name and t.table_type = 'BASE TABLE'
           where c.table_schema in ('smarves', 'basket', 'lasso') and c.data_type in ('text', 'character varying') loop
    execute format('select count(*) from %I.%I where %I in (select doublure from nettoyage_pilotes)
                    or %I in (select encode(sha256(convert_to(doublure, ''UTF8'')), ''hex'') from nettoyage_pilotes)',
                   p.table_schema, p.table_name, p.column_name, p.column_name) into n;
    if n > 0 then
      raise exception 'nettoyage : % ligne(s) de %.%.% désignent encore un pilote ; tout est annulé', n, p.table_schema, p.table_name, p.column_name;
    end if;
  end loop;
  if (select count(*) from smarves.joueurs where pyramide_id in (select humain from nettoyage_pilotes)) <> humains then
    raise exception 'nettoyage : un compte humain a disparu ; tout est annulé';
  end if;

  -- 7. Plus aucune inscription ancienne : la règle devient pleinement vérifiée.
  alter table smarves.inscriptions validate constraint inscriptions_par_lasso;
  raise notice 'nettoyage : terminé ; contrainte inscriptions_par_lasso validée';
end
$nettoyage$;

commit;
