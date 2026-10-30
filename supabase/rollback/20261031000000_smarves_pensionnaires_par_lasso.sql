-- Retour arrière de 20261031000000_smarves_pensionnaires_par_lasso.sql.
-- Il rend au code précédent de la fonction `doublures` (chtabay/addict) la signature à quinze arguments de
-- smarves.doublure_inscrire, SANS rouvrir la création indépendante :
-- - le déclencheur doublure_par_lasso reste : un pensionnaire n'existe toujours que par une inscription
--   « creer » réussie (l'agent signé n'est simplement plus exigé, puisque l'ancien code ne le transmet pas) ;
-- - l'adoption reste refusée (la version rendue ne connaît que « creer ») ;
-- - les inscriptions closes par le nettoyage restent closes, les jti déjà vus restent vus ;
-- - aucun pensionnaire, aucun lien, aucune donnée de jeu n'est touché.
-- La version à seize arguments et smarves.doublure_deconnecter restent en place : le code nouveau, s'il est
-- redéployé, retrouve tout sans nouvelle migration.
begin;
set local lock_timeout = '5s';

do $garde$
begin
  if to_regclass('smarves.inscriptions_closes') is null then
    raise exception 'retour arrière smarves par lasso : migration absente';
  end if;
end
$garde$;

alter table smarves.inscriptions drop constraint if exists inscriptions_creer;
alter table smarves.inscriptions drop constraint inscriptions_par_lasso;
alter table smarves.inscriptions add constraint inscriptions_creer
  check (op = 'creer' and resultat = 'cree' and dem is not null) not valid;

create or replace function smarves.doublure_par_lasso() returns trigger
  language plpgsql security definer set search_path = ''
as $$
begin
  if not exists (select 1 from smarves.doublures where id = new.id) then return null; end if;
  if not exists (select 1 from smarves.inscriptions i
      where i.doublure = new.id and i.humain = new.humain and i.op = 'creer' and i.resultat = 'cree') then
    raise exception using errcode = 'check_violation', constraint = 'doublure_par_lasso',
      message = 'smarves : un pensionnaire ne naît que d''une inscription Lasso';
  end if;
  return null;
end $$;

-- L'ancienne signature, restreinte à la création. Un jeton « adopter » de l'ancien code est refusé.
create or replace function smarves.doublure_inscrire(p_jti text, p_exp timestamptz, p_humain text, p_nom_pyramides text,
    p_op text, p_ins uuid, p_id text, p_nom text, p_caractere text, p_envies text, p_besoins text, p_tenue text,
    p_reveils integer, p_pecule bigint, p_dem text) returns json
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

  delete from smarves.inscription_jetons where exp < now() - interval '1 day';
  insert into smarves.inscription_jetons (jti, humain, exp) values (p_jti, p_humain, p_exp) on conflict (jti) do nothing;
  if not found then return json_build_object('ok', false, 'raison', 'rejeu'); end if;

  perform pg_advisory_xact_lock(hashtextextended('smarves:ins:' || p_ins::text, 0));
  if exists (select 1 from smarves.inscriptions_closes where ins = p_ins) then
    return json_build_object('ok', false, 'raison', 'inscription');
  end if;

  select * into i from smarves.inscriptions where ins = p_ins;
  if i.ins is not null then
    if i.humain <> p_humain or i.op <> p_op or i.dem is distinct from p_dem then
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
    return json_build_object('ok', false, 'raison', case o->>'raison' when 'nom' then 'nom_pris' else 'deja_pensionnaire' end);
  end if;
  update smarves.doublures set caractere = p_caractere, envies = p_envies, besoins = p_besoins where id = p_id;
  if p_tenue is not null then
    insert into smarves.doublure_corps (doublure, membre, tenue) values (p_id, smarves.membre(p_id), p_tenue);
  end if;
  insert into smarves.inscriptions (ins, humain, op, dem, doublure, resultat) values (p_ins, p_humain, p_op, p_dem, p_id, 'cree');
  return json_build_object('ok', true, 'resultat', 'cree', 'id', p_id, 'nom', p_nom);
end $$;

revoke all on function smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text)
  from public, anon, authenticated;

commit;
