-- Smarves, la direction des clubs (demande de Guillaume du 23 octobre 2026 au soir), pour le football
-- (smarves.obligations) et le basket (basket.obligations) :
-- - un joueur ne dirige pas deux clubs de la même division : s'il dirige un club et devient le plus gros
--   porteur d'un autre de la même division, il reste à la tête du premier, et le second revient au plus
--   gros porteur suivant ; il ne change de club qu'à l'intersaison ;
-- - les parts ne se prennent qu'à l'intersaison, entre la fin de la dernière journée d'une saison (trois
--   heures après son coup d'envoi) et la première de la suivante, et avant la toute première saison.
-- La direction est tenue ici (smarves.directions), une par club. Elle ne compte que tant que son titulaire
-- tient une part du club ; sinon la place est vacante et la règle d'avant (la plus grosse somme investie)
-- vaut jusqu'à ce que le jeu la demande pour le bon porteur. La division (le niveau du club dans la
-- pyramide) est celle que le jeu calcule, comme le groupe des enchères du basket : le serveur ne tient pas
-- la pyramide. Le jeu suit les mêmes règles (scripts/socle/diriger.gd).

create table if not exists smarves.directions (
  sport text not null check (sport in ('football', 'basket')),
  club text not null,
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  division text not null default '',
  maj timestamptz not null default now(),
  primary key (sport, club)
);

alter table smarves.directions enable row level security;
revoke all on smarves.directions from public, anon, authenticated;

-- Ce qu'un joueur a mis dans un club.
create or replace function smarves.investi(p_sport text, p_club text, p_joueur text) returns integer
  language sql stable security definer set search_path = ''
as $$
  select coalesce(sum(smarves.obligation_valeur(rang)), 0)::integer from (
    select rang from smarves.obligations where p_sport = 'football' and club = p_club and pyramide_id = p_joueur
    union all
    select rang from basket.obligations where p_sport = 'basket' and club = p_club and pyramide_id = p_joueur) o
$$;

-- Le titulaire de la direction d'un club, s'il tient encore une part ; null sinon.
create or replace function smarves.directeur(p_sport text, p_club text) returns text
  language sql stable security definer set search_path = ''
as $$
  select d.pyramide_id from smarves.directions d
  where d.sport = p_sport and d.club = p_club and smarves.investi(p_sport, p_club, d.pyramide_id) > 0
$$;

-- L'intersaison : avant le premier coup d'envoi, ou après la fin de la dernière journée d'une saison.
create or replace function smarves.intersaison(p_sport text) returns boolean
  language plpgsql stable set search_path = ''
as $$
declare
  premier timestamptz;
  k integer;
  fin timestamptz;
begin
  premier := case when p_sport = 'basket' then basket.coup_envoi(1, 1) else smarves.coup_envoi(1, 1) end;
  if now() < premier then return true; end if;
  k := floor(extract(epoch from (now() - premier)) / (16 * 7 * 86400))::integer + 1;
  fin := case when p_sport = 'basket' then basket.coup_envoi(k, 14) else smarves.coup_envoi(k, 14) end;
  return now() >= fin + interval '3 hours';
end $$;

-- Qui dirige : le titulaire de la direction s'il tient encore une part ; sinon, comme avant, la plus grosse
-- somme investie (et chacun à égalité), et tout le monde sans porteur.
create or replace function smarves.dirige_sport(p_sport text, p_club text, p_joueur text) returns boolean
  language plpgsql stable security definer set search_path = ''
as $$
declare
  d text := smarves.directeur(p_sport, p_club);
  plus integer;
begin
  if d is not null then return d = p_joueur; end if;
  if p_sport = 'basket' then
    select max(total) into plus from (
      select sum(smarves.obligation_valeur(rang)) as total from basket.obligations where club = p_club group by pyramide_id) t;
  else
    select max(total) into plus from (
      select sum(smarves.obligation_valeur(rang)) as total from smarves.obligations where club = p_club group by pyramide_id) t;
  end if;
  if plus is null then return true; end if;
  return smarves.investi(p_sport, p_club, p_joueur) >= plus;
end $$;

create or replace function smarves.dirige(p_club text, p_joueur text) returns boolean
  language sql stable security definer set search_path = ''
as $$ select smarves.dirige_sport('football', p_club, p_joueur) $$;

create or replace function basket.dirige(p_club text, p_joueur text) returns boolean
  language sql stable security definer set search_path = ''
as $$ select smarves.dirige_sport('basket', p_club, p_joueur) $$;

revoke all on function smarves.investi(text, text, text), smarves.directeur(text, text), smarves.intersaison(text),
  smarves.dirige_sport(text, text, text), smarves.dirige(text, text), basket.dirige(text, text) from public;

-- Les directions, publiques comme le championnat : [{club, par, moi, division}].
create or replace function public.smarves_directions(p_jeton text default null, p_sport text default 'football') returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  return coalesce((select json_agg(x) from (
      select d.club, j.nom as par, (d.pyramide_id = moi) is true as moi, d.division
      from smarves.directions d join smarves.joueurs j using (pyramide_id)
      where d.sport = p_sport and smarves.investi(p_sport, d.club, d.pyramide_id) > 0
      order by d.club) x), '[]'::json);
end $$;

-- Prendre la direction d'un club : {ok: true}, ou {ok: false, raison} avec « parts » (aucune part, ou un autre
-- porteur a mis plus), « intersaison » (un autre dirige, et l'on n'est pas à l'intersaison), « division »
-- (on dirige déjà un club de la même division ; à l'intersaison, p_changer le quitte pour celui-ci) ;
-- {erreur: 'jeton'} sans compte.
create or replace function public.smarves_direction_prendre(p_jeton text, p_sport text, p_club text, p_division text,
    p_changer boolean default false) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  mien integer;
  actuel text;
  inter boolean;
  plus integer;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_sport is null or p_sport not in ('football', 'basket') then raise exception 'sport invalide'; end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_division is null or p_division !~ '^[0-9]{0,3}$' then raise exception 'division invalide'; end if;
  perform pg_advisory_xact_lock(hashtext(format('direction/%s/%s', p_sport, moi)));
  perform pg_advisory_xact_lock(hashtext(format('direction/%s/%s', p_sport, p_club)));
  mien := smarves.investi(p_sport, p_club, moi);
  if mien <= 0 then return json_build_object('ok', false, 'raison', 'parts'); end if;
  inter := smarves.intersaison(p_sport);
  actuel := smarves.directeur(p_sport, p_club);
  if actuel = moi then
    update smarves.directions set division = p_division, maj = now() where sport = p_sport and club = p_club;
    return json_build_object('ok', true);
  end if;
  if actuel is not null and not inter then return json_build_object('ok', false, 'raison', 'intersaison'); end if;
  if exists (select 1 from smarves.directions d where d.sport = p_sport and d.pyramide_id = moi and d.club <> p_club
      and d.division = p_division and smarves.investi(p_sport, d.club, moi) > 0) and not (p_changer and inter) then
    return json_build_object('ok', false, 'raison', 'division');
  end if;
  -- Le plus gros des autres porteurs qui ne dirigent pas déjà un club de la même division.
  select max(total) into plus from (
    select o.pyramide_id, sum(smarves.obligation_valeur(o.rang)) as total from (
      select pyramide_id, rang from smarves.obligations where p_sport = 'football' and club = p_club
      union all
      select pyramide_id, rang from basket.obligations where p_sport = 'basket' and club = p_club) o
    where o.pyramide_id <> moi and not exists (select 1 from smarves.directions d where d.sport = p_sport
      and d.pyramide_id = o.pyramide_id and d.club <> p_club and d.division = p_division
      and smarves.investi(p_sport, d.club, d.pyramide_id) > 0)
    group by o.pyramide_id) t;
  if plus is not null and mien < plus then return json_build_object('ok', false, 'raison', 'parts'); end if;
  if p_changer and inter then
    delete from smarves.directions where sport = p_sport and pyramide_id = moi and club <> p_club and division = p_division;
  end if;
  insert into smarves.directions as d (sport, club, pyramide_id, division) values (p_sport, p_club, moi, p_division)
    on conflict (sport, club) do update set pyramide_id = excluded.pyramide_id, division = excluded.division, maj = now();
  return json_build_object('ok', true);
end $$;

-- Prendre une obligation : seulement à l'intersaison (raison « intersaison »).
create or replace function public.smarves_obligation_prendre(p_jeton text, p_club text, p_rang integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  tenue text;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_rang is null or p_rang not between 1 and 9 then raise exception 'rang invalide'; end if;
  select pyramide_id into tenue from smarves.obligations where club = p_club and rang = p_rang;
  if tenue = moi then return json_build_object('ok', true); end if;
  if tenue is not null then return json_build_object('ok', false, 'raison', 'prise'); end if;
  if not smarves.intersaison('football') then return json_build_object('ok', false, 'raison', 'intersaison'); end if;
  insert into smarves.obligations (club, rang, pyramide_id) values (p_club, p_rang, moi)
    on conflict (club, rang) do nothing;
  if not found then return json_build_object('ok', false, 'raison', 'prise'); end if;
  return json_build_object('ok', true);
end $$;

create or replace function public.smarves_basket_obligation_prendre(p_jeton text, p_club text, p_rang integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  tenue text;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_rang is null or p_rang not between 1 and 9 then raise exception 'rang invalide'; end if;
  select pyramide_id into tenue from basket.obligations where club = p_club and rang = p_rang;
  if tenue = moi then return json_build_object('ok', true); end if;
  if tenue is not null then return json_build_object('ok', false, 'raison', 'prise'); end if;
  if not smarves.intersaison('basket') then return json_build_object('ok', false, 'raison', 'intersaison'); end if;
  insert into basket.obligations (club, rang, pyramide_id) values (p_club, p_rang, moi) on conflict (club, rang) do nothing;
  if not found then return json_build_object('ok', false, 'raison', 'prise'); end if;
  return json_build_object('ok', true);
end $$;

revoke all on function public.smarves_directions(text, text), public.smarves_direction_prendre(text, text, text, text, boolean) from public;
grant execute on function public.smarves_directions(text, text), public.smarves_direction_prendre(text, text, text, text, boolean) to anon, authenticated;
