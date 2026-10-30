-- Smarves, la passerelle Lasso : l'assistant n'a qu'un connecteur, celui de Lasso (chtabay/lasso,
-- docs/18-un-seul-connecteur.md). Lasso relaie les outils du pensionnaire vers la fonction `doublures`
-- (chtabay/addict) avec, à chaque appel, une assertion qu'il signe : « cet humain, cet agent », soixante
-- secondes, usage unique. Lasso ne détient aucun jeton Smarves ; il n'y a plus de lien personnel
-- (smarves.doublure_acces ne sert plus ; la table reste jusqu'à un nettoyage revu à part).
--
-- - smarves.passerelle_entrer : pour une assertion déjà vérifiée par la fonction, rend le pensionnaire du couple
--   (humain, agent) : celui né d'une inscription Lasso « creer / cree » portant cette empreinte d'agent, et aucun
--   autre. Refuse un `jti` déjà vu (rejeu), un couple sans pensionnaire, et une coupure en cours.
-- - smarves.passerelle_jetons : les `jti` déjà vus, purgés une heure après expiration.
-- - smarves.passerelle_appels : une trace par appel d'outil (heure, humain, agent, nom de l'outil, réussi ou
--   non), sans contenu : ni arguments, ni réponse. Quatre-vingt-dix jours.
-- - smarves.doublures.assistant_coupe : la coupure est tenue ici, par le jeu, et vérifiée à chaque appel ;
--   elle ne dépend pas de Lasso. smarves.doublure_deconnecter la pose (et arrête la session de jeu),
--   smarves.doublure_reprendre la lève. Depuis Lasso comme depuis la fiche du jeu.
-- - smarves.doublure_effacer efface aussi la coupure et les traces de l'humain.
-- Fiche : docs/PENSIONNAIRES.md, section 9. Essais : supabase/tests/passerelle-pg.mjs.
begin;
set local lock_timeout = '5s';

do $garde$
begin
  if to_regprocedure('smarves.doublure_deconnecter(text)') is null
     or not exists (select 1 from pg_attribute where attrelid = 'smarves.inscriptions'::regclass
                    and attname = 'agent' and not attisdropped) then
    raise exception 'smarves passerelle lasso : appliquer 20261031000000_smarves_pensionnaires_par_lasso d''abord';
  end if;
  if to_regclass('smarves.passerelle_jetons') is not null then
    raise exception 'smarves passerelle lasso : déjà appliquée ; migration abandonnée sans aucun changement';
  end if;
end
$garde$;

-- --- La coupure, tenue par le jeu ------------------------------------------------------------------

alter table smarves.doublures add column if not exists assistant_coupe timestamptz;

-- --- Les assertions vues, et la trace des appels --------------------------------------------------

create table smarves.passerelle_jetons (
  jti text primary key check (jti ~ '^[A-Za-z0-9_-]{16,64}$'),
  humain text not null,
  exp timestamptz not null,
  vu timestamptz not null default now()
);
create index passerelle_jetons_exp on smarves.passerelle_jetons (exp);

create table smarves.passerelle_appels (
  id bigint generated always as identity primary key,
  quand timestamptz not null default now(),
  humain text not null,
  agent text not null check (agent ~ '^[0-9a-f]{64}$'),
  outil text not null check (length(outil) between 1 and 64),
  ok boolean not null
);
create index passerelle_appels_humain on smarves.passerelle_appels (humain, quand);
create index passerelle_appels_quand on smarves.passerelle_appels (quand);

alter table smarves.passerelle_jetons enable row level security;
alter table smarves.passerelle_appels enable row level security;
revoke all on smarves.passerelle_jetons, smarves.passerelle_appels from public, anon, authenticated;

-- --- Entrer par la passerelle ---------------------------------------------------------------------

-- p_humain est le `sub` et p_agent l'`agt` d'une assertion dont la fonction a déjà vérifié la signature, la
-- portée et la durée ; p_jti son identifiant, p_exp son expiration. Rend { ok, id } ou { ok: false, raison }
-- avec raison parmi « rejeu », « pensionnaire », « coupe ». Le jti est consommé même si la suite refuse.
create function smarves.passerelle_entrer(p_jti text, p_humain text, p_agent text, p_exp timestamptz) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  x smarves.doublures;
begin
  if p_humain is null or p_humain !~ '^[A-Za-z0-9_-]{1,64}$' or p_humain like 'doublure:%' then raise exception 'humain invalide'; end if;
  if p_agent is null or p_agent !~ '^[0-9a-f]{64}$' then raise exception 'agent invalide'; end if;
  if p_jti is null or p_exp is null then raise exception 'assertion invalide'; end if;

  delete from smarves.passerelle_jetons where exp < now() - interval '1 hour';
  insert into smarves.passerelle_jetons (jti, humain, exp) values (p_jti, p_humain, p_exp) on conflict (jti) do nothing;
  if not found then return json_build_object('ok', false, 'raison', 'rejeu'); end if;

  -- Le pensionnaire de CET agent : né d'une inscription Lasso pour ce même humain, portant cette empreinte.
  select d.* into x from smarves.doublures d
    where d.humain = p_humain
      and exists (select 1 from smarves.inscriptions i
                   where i.doublure = d.id and i.humain = d.humain
                     and i.op = 'creer' and i.resultat = 'cree' and i.agent = p_agent);
  if x.id is null then return json_build_object('ok', false, 'raison', 'pensionnaire'); end if;
  if x.assistant_coupe is not null then return json_build_object('ok', false, 'raison', 'coupe'); end if;
  return json_build_object('ok', true, 'id', x.id);
end $$;

-- Une trace par appel d'outil, sans contenu. Purge au-delà de quatre-vingt-dix jours.
create function smarves.passerelle_tracer(p_humain text, p_agent text, p_outil text, p_ok boolean) returns void
  language plpgsql security definer set search_path = ''
as $$
begin
  delete from smarves.passerelle_appels where quand < now() - interval '90 days';
  insert into smarves.passerelle_appels (humain, agent, outil, ok)
    values (p_humain, p_agent, left(coalesce(p_outil, '?'), 64), coalesce(p_ok, false));
end $$;

-- --- Couper, reprendre, effacer -------------------------------------------------------------------

-- « Couper Smarves pour mon assistant » : la passerelle refuse ses appels jusqu'à « reprendre », la session de
-- jeu qu'il pilotait s'arrête et le corps quitte la place. Le pensionnaire, sa mémoire, ses crédits et l'agent
-- Lasso restent. (L'ancien lien personnel, s'il en reste un, tombe aussi.)
create or replace function smarves.doublure_deconnecter(p_humain text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  d text;
begin
  if p_humain is null or p_humain like 'doublure:%' then raise exception 'humain invalide'; end if;
  delete from smarves.doublure_acces where humain = p_humain;
  update smarves.doublures set assistant_coupe = coalesce(assistant_coupe, now()) where humain = p_humain returning id into d;
  if d is not null then
    update smarves.doublure_pilote set demande = null, geste = null, maj = now() where doublure = d;
    update smarves.doublure_corps set present_jusqu = now(), maj = now() where doublure = d and present_jusqu > now();
  end if;
  return json_build_object('ok', true, 'coupe', d is not null);
end $$;

-- « Reprendre » : la passerelle accepte de nouveau les appels de l'assistant.
create function smarves.doublure_reprendre(p_humain text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  d text;
begin
  if p_humain is null or p_humain like 'doublure:%' then raise exception 'humain invalide'; end if;
  update smarves.doublures set assistant_coupe = null where humain = p_humain returning id into d;
  return json_build_object('ok', true, 'repris', d is not null);
end $$;

create or replace function smarves.doublure_effacer(p_humain text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  d text;
begin
  select id into d from smarves.doublures where humain = p_humain;
  delete from smarves.doublure_humeurs where humain = p_humain;
  delete from smarves.doublure_acces where humain = p_humain;
  delete from smarves.passerelle_appels where humain = p_humain;
  if d is null then return json_build_object('ok', true, 'efface', false); end if;
  delete from smarves.joueurs where pyramide_id = d;
  return json_build_object('ok', true, 'efface', true);
end $$;

revoke all on function
  smarves.passerelle_entrer(text, text, text, timestamptz),
  smarves.passerelle_tracer(text, text, text, boolean),
  smarves.doublure_deconnecter(text),
  smarves.doublure_reprendre(text),
  smarves.doublure_effacer(text) from public, anon, authenticated;

commit;
