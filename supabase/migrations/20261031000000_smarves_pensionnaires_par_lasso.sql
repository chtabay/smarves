-- Smarves, un pensionnaire ne naît plus que du parcours Lasso (chtabay/lasso, activation de Smarves depuis Lasso).
-- La création indépendante (le jeu en mode clé, l'outil smarves_creer, l'adoption d'un pensionnaire existant)
-- est fermée ici, dans la base, et pas seulement dans la fonction `doublures` :
--
-- - Contrainte (déclencheur différé) sur smarves.doublures : une ligne n'est valide au COMMIT que si une
--   inscription « creer » réussie, portant l'agent Lasso signé par Pyramides2, la désigne pour le même humain.
--   smarves.doublure_ouvrir appelée seule (l'ancienne création du jeu ou du connecteur) échoue donc au COMMIT.
--   Les pensionnaires déjà présents ne sont pas réécrits : le déclencheur ne regarde que les insertions et les
--   changements d'identifiant ou d'humain. Les pilotes partent par le script de nettoyage, revu à part.
-- - smarves.inscriptions.agent : l'empreinte de l'agent Lasso (`agt` du jeton signé). Une nouvelle inscription
--   n'est plus que « creer » ; l'ancienne règle (« adopter ») reste lisible jusqu'au nettoyage, qui valide la
--   contrainte inscriptions_par_lasso.
-- - smarves.inscriptions_closes : les inscriptions retirées par le nettoyage. Un jeton encore valable pour l'une
--   d'elles (autre jti, même ins) ne recrée rien. Les jti déjà vus restent dans smarves.inscription_jetons
--   jusqu'à leur purge normale (expiration + un jour).
-- - smarves.doublure_acces.outil_ok : le dernier appel réussi d'un outil qui a touché le pensionnaire (« prêt à
--   jouer » côté Lasso). La simple découverte du connecteur ne le pose pas.
-- - smarves.doublure_deconnecter : « Déconnecter mon assistant de Smarves » ; le lien et les sessions de jeu
--   qu'il a ouvertes tombent, le pensionnaire et l'agent Lasso restent.
begin;
set local lock_timeout = '5s';

do $garde$
begin
  if to_regprocedure('smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text)') is null
     and to_regprocedure('smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text, text)') is null then
    raise exception 'smarves par lasso : appliquer 20261030000000_smarves_pensionnaires_inscription d''abord';
  end if;
  -- Après son retour arrière (qui garde la table des inscriptions closes), la migration se rejoue.
  if exists (select 1 from pg_constraint where conname = 'inscriptions_par_lasso'
             and conrelid = 'smarves.inscriptions'::regclass) then
    raise exception 'smarves par lasso : déjà appliquée ; migration abandonnée sans aucun changement';
  end if;
end
$garde$;

-- --- L'inscription porte l'agent Lasso ------------------------------------------------------------

alter table smarves.inscriptions add column if not exists agent text check (agent ~ '^[0-9a-f]{64}$');
-- NOT VALID : les deux lignes pilotes (« adopte », et une création sans agent) restent jusqu'au nettoyage,
-- qui la valide. Toute ligne nouvelle ou modifiée la respecte déjà.
alter table smarves.inscriptions drop constraint if exists inscriptions_creer;
alter table smarves.inscriptions add constraint inscriptions_par_lasso
  check (op = 'creer' and resultat = 'cree' and agent is not null and dem is not null) not valid;
create index if not exists inscriptions_doublure on smarves.inscriptions (doublure);

create table if not exists smarves.inscriptions_closes (
  ins uuid primary key,
  close timestamptz not null default now()
);
alter table smarves.inscriptions_closes enable row level security;
revoke all on smarves.inscriptions_closes from public, anon, authenticated;

-- --- Un pensionnaire n'existe que par une inscription Lasso ---------------------------------------

create or replace function smarves.doublure_par_lasso() returns trigger
  language plpgsql security definer set search_path = ''
as $$
begin
  -- Créé puis effacé dans la même transaction : rien à vérifier.
  if not exists (select 1 from smarves.doublures where id = new.id) then return null; end if;
  if not exists (select 1 from smarves.inscriptions i
      where i.doublure = new.id and i.humain = new.humain
        and i.op = 'creer' and i.resultat = 'cree' and i.agent is not null) then
    raise exception using errcode = 'check_violation', constraint = 'doublure_par_lasso',
      message = 'smarves : un pensionnaire ne naît que d''une inscription Lasso';
  end if;
  return null;
end $$;
revoke all on function smarves.doublure_par_lasso() from public, anon, authenticated;

drop trigger if exists doublure_par_lasso on smarves.doublures;
create constraint trigger doublure_par_lasso
  after insert or update of id, humain on smarves.doublures
  deferrable initially deferred
  for each row execute function smarves.doublure_par_lasso();

-- --- Créer, et seulement créer, pour un agent Lasso -----------------------------------------------

drop function if exists smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text);

-- p_humain est le `sub` du jeton vérifié par la fonction `doublures`, p_agent son `agt` (l'empreinte de
-- l'agent Lasso choisi dans la demande), p_ins son `ins` (la demande Lasso). Rend {ok, resultat ('cree',
-- 'deja_fait'), id, nom} ou {ok: false, raison}.
create or replace function smarves.doublure_inscrire(p_jti text, p_exp timestamptz, p_humain text, p_nom_pyramides text,
    p_op text, p_ins uuid, p_id text, p_nom text, p_caractere text, p_envies text, p_besoins text, p_tenue text,
    p_reveils integer, p_pecule bigint, p_dem text, p_agent text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  i smarves.inscriptions;
  o json;
  n text;
begin
  if p_humain is null or p_humain !~ '^[A-Za-z0-9_-]{1,64}$' then raise exception 'humain invalide'; end if;
  if p_op is distinct from 'creer' then raise exception 'operation invalide'; end if;
  if p_ins is null or p_exp is null then raise exception 'inscription invalide'; end if;
  if p_dem is null or p_dem !~ '^[0-9a-f]{64}$' then raise exception 'demande invalide'; end if;
  if p_agent is null or p_agent !~ '^[0-9a-f]{64}$' then raise exception 'agent invalide'; end if;

  -- Le jeton ne sert qu'une fois : un second usage ne fait rien et ne dit rien.
  delete from smarves.inscription_jetons where exp < now() - interval '1 day';
  insert into smarves.inscription_jetons (jti, humain, exp) values (p_jti, p_humain, p_exp) on conflict (jti) do nothing;
  if not found then return json_build_object('ok', false, 'raison', 'rejeu'); end if;

  perform pg_advisory_xact_lock(hashtextextended('smarves:ins:' || p_ins::text, 0));

  -- Une inscription retirée par le nettoyage ne renaît pas, même avec un autre jeton.
  if exists (select 1 from smarves.inscriptions_closes where ins = p_ins) then
    return json_build_object('ok', false, 'raison', 'inscription');
  end if;

  -- La même inscription, reprise par un nouveau clic : le même résultat, sans nouvel effet.
  select * into i from smarves.inscriptions where ins = p_ins;
  if i.ins is not null then
    if i.humain <> p_humain or i.op <> p_op or i.dem is distinct from p_dem or i.agent is distinct from p_agent then
      return json_build_object('ok', false, 'raison', 'inscription');
    end if;
    select j.nom into n from smarves.doublures x join smarves.joueurs j on j.pyramide_id = x.id
      where x.id = i.doublure and x.humain = p_humain;
    if n is null then return json_build_object('ok', false, 'raison', 'aucun_pensionnaire'); end if;
    return json_build_object('ok', true, 'resultat', 'deja_fait', 'id', i.doublure, 'nom', n);
  end if;

  perform pg_advisory_xact_lock(hashtextextended('smarves:ins-humain:' || p_humain, 0));
  if (select count(*) from smarves.inscription_jetons where humain = p_humain and vu > now() - interval '1 hour') > 10 then
    return json_build_object('ok', false, 'raison', 'trop');
  end if;

  insert into smarves.joueurs (pyramide_id, nom) values (p_humain, left(coalesce(nullif(btrim(p_nom_pyramides), ''), 'Joueur'), 80))
    on conflict (pyramide_id) do nothing;

  if p_nom is null or p_caractere is null then raise exception 'creation incomplete'; end if;
  o := smarves.doublure_ouvrir(p_id, p_humain, p_nom, 'autre', null, null, null, null, null, p_reveils, p_pecule);
  if not (o->>'ok')::boolean then
    -- « deja_pensionnaire » dit seulement que ce compte a déjà un pensionnaire : Lasso cherche alors s'il
    -- est né d'une de ses demandes (reprise après un rattachement manqué) avant de conclure.
    return json_build_object('ok', false, 'raison', case o->>'raison' when 'nom' then 'nom_pris' else 'deja_pensionnaire' end);
  end if;
  update smarves.doublures set caractere = p_caractere, envies = p_envies, besoins = p_besoins where id = p_id;
  if p_tenue is not null then
    insert into smarves.doublure_corps (doublure, membre, tenue) values (p_id, smarves.membre(p_id), p_tenue);
  end if;
  insert into smarves.inscriptions (ins, humain, op, dem, doublure, resultat, agent)
    values (p_ins, p_humain, p_op, p_dem, p_id, 'cree', p_agent);
  return json_build_object('ok', true, 'resultat', 'cree', 'id', p_id, 'nom', p_nom);
end $$;

-- --- Prêt à jouer, et déconnexion de l'assistant --------------------------------------------------

alter table smarves.doublure_acces add column if not exists outil_ok timestamptz;

-- Le lien du connecteur tombe (l'assistant n'entre plus), la session de jeu qu'il pilotait s'arrête et le
-- corps quitte la place. Le pensionnaire, sa mémoire, ses crédits et l'agent Lasso restent.
create or replace function smarves.doublure_deconnecter(p_humain text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  d text;
  lien boolean;
begin
  if p_humain is null or p_humain like 'doublure:%' then raise exception 'humain invalide'; end if;
  delete from smarves.doublure_acces where humain = p_humain;
  lien := found;
  select id into d from smarves.doublures where humain = p_humain;
  if d is not null then
    update smarves.doublure_pilote set demande = null, geste = null, maj = now() where doublure = d;
    update smarves.doublure_corps set present_jusqu = now(), maj = now() where doublure = d and present_jusqu > now();
  end if;
  return json_build_object('ok', true, 'lien', lien);
end $$;

revoke all on function
  smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text, text),
  smarves.doublure_deconnecter(text) from public, anon, authenticated;

commit;
