-- Smarves, la relève des présidents (demande de Guillaume du 31 octobre 2026), pour le football
-- (smarves.obligations) et le basket (basket.obligations). Elle remplace les règles du 23 octobre au soir
-- (20261024000000_smarves_directions.sql) :
-- - les parts se prennent toute l'année, et plus seulement à l'intersaison ;
-- - un président ne dirige qu'un club à la fois dans un sport (et non plus un par division) ;
-- - prendre la direction d'un club que quelqu'un dirige déjà, ou quitter son club pour un autre, se déclare
--   quand on veut et prend effet à la relève suivante, le lundi à midi (heure de Paris) : au plus un
--   changement par semaine, et pas d'allers-retours d'un jour à l'autre ;
-- - un président ne change de club qu'une fois pendant la saison, et une fois pendant l'intersaison (le
--   mercato) : la période est celle de la relève où le changement prend effet. La première prise d'un club,
--   quand on n'en dirige aucun, ne compte pas ; elle est immédiate si la direction du club est vacante.
-- Le lundi à midi : les matchs du week-end sont joués (le basket le samedi à 20 h, le football le dimanche
-- à 15 h), et le nouveau président a toute la semaine pour la consigne, le mercato et le marché du basket
-- (clôture le jeudi à 22 h) avant son premier match.
-- Le jeu suit les mêmes règles (scripts/socle/diriger.gd).

-- Les déclarations en attente : une par joueur et par sport ; une nouvelle remplace l'ancienne.
create table if not exists smarves.directions_releves (
  sport text not null check (sport in ('football', 'basket')),
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  club text not null,
  division text not null default '',
  declaree timestamptz not null default now(),
  effet timestamptz not null,
  primary key (sport, pyramide_id)
);

-- Les changements de club faits, un par joueur, par sport et par période (« s3 » : la saison 3 en cours ;
-- « i3 » : l'intersaison qui précède la saison 3).
create table if not exists smarves.directions_changements (
  sport text not null check (sport in ('football', 'basket')),
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  periode text not null check (periode ~ '^[si][0-9]{1,4}$'),
  club text not null,
  effet timestamptz not null,
  primary key (sport, pyramide_id, periode)
);

alter table smarves.directions_releves enable row level security;
alter table smarves.directions_changements enable row level security;
revoke all on smarves.directions_releves, smarves.directions_changements from public, anon, authenticated;

-- La relève qui suit un instant : le lundi à midi, heure de Paris, strictement après.
create or replace function smarves.releve_suivante(p_t timestamptz) returns timestamptz
  language plpgsql stable set search_path = ''
as $$
declare
  lundi timestamp := date_trunc('week', p_t at time zone 'Europe/Paris');
  r timestamptz := (lundi + interval '12 hours') at time zone 'Europe/Paris';
begin
  if r <= p_t then
    r := (lundi + interval '7 days 12 hours') at time zone 'Europe/Paris';
  end if;
  return r;
end $$;

-- La période d'un sport à un instant, comme le jeu la compte (diriger.gd, periode) : « s<k> » de la
-- première journée de la saison k à la fin de sa quatorzième (trois heures après son coup d'envoi),
-- « i<k> » pendant l'intersaison qui précède la saison k (et avant la toute première). En heure de Paris lue
-- comme une horloge, sans les heures d'été, comme le jeu.
create or replace function smarves.periode_de(p_sport text, p_t timestamptz) returns text
  language plpgsql stable set search_path = ''
as $$
declare
  t timestamp := p_t at time zone 'Europe/Paris';
  premier timestamp := (case when p_sport = 'basket' then basket.coup_envoi(1, 1) else smarves.coup_envoi(1, 1) end)
    at time zone 'Europe/Paris';
  k integer;
  fin timestamp;
begin
  if t < premier then return 'i1'; end if;
  k := floor(extract(epoch from (t - premier)) / (16 * 7 * 86400))::integer + 1;
  fin := ((case when p_sport = 'basket' then basket.coup_envoi(k, 14) else smarves.coup_envoi(k, 14) end)
    at time zone 'Europe/Paris') + interval '3 hours';
  return case when t >= fin then 'i' || (k + 1) else 's' || k end;
end $$;

-- Un instant en secondes « locales » (l'heure de Paris lue comme UTC), l'horloge du jeu.
create or replace function smarves.secondes_locales(p_t timestamptz) returns bigint
  language sql stable set search_path = ''
as $$ select extract(epoch from (p_t at time zone 'Europe/Paris'))::bigint $$;

-- Parmi les déclarations échues pour un club, celle qui l'emporte : son auteur tient encore une part, et le
-- plus gros porteur, puis le premier déclaré, passe devant.
create or replace function smarves.releve_gagnant(p_sport text, p_club text) returns text
  language sql stable security definer set search_path = ''
as $$
  select r.pyramide_id from smarves.directions_releves r
  where r.sport = p_sport and r.club = p_club and r.effet <= now()
    and smarves.investi(p_sport, p_club, r.pyramide_id) > 0
  order by smarves.investi(p_sport, p_club, r.pyramide_id) desc, r.declaree, r.pyramide_id
  limit 1
$$;

-- Le titulaire de la direction d'un club : la déclaration échue qui l'emporte, sinon la direction tenue si
-- son titulaire tient encore une part et ne part pas, à cette relève, pour un autre club ; null sinon.
create or replace function smarves.directeur(p_sport text, p_club text) returns text
  language plpgsql stable security definer set search_path = ''
as $$
declare
  g text := smarves.releve_gagnant(p_sport, p_club);
  d text;
begin
  if g is not null then return g; end if;
  select x.pyramide_id into d from smarves.directions x
  where x.sport = p_sport and x.club = p_club and smarves.investi(p_sport, p_club, x.pyramide_id) > 0
    and not exists (select 1 from smarves.directions_releves r where r.sport = p_sport
      and r.pyramide_id = x.pyramide_id and r.club <> p_club and r.effet <= now()
      and smarves.releve_gagnant(p_sport, r.club) = r.pyramide_id);
  return d;
end $$;

-- Le club qu'un joueur dirige dans un sport, autre que p_sauf ; null s'il n'en dirige pas.
create or replace function smarves.club_dirige(p_sport text, p_joueur text, p_sauf text default '') returns text
  language sql stable security definer set search_path = ''
as $$
  select c.club from (
    select club from smarves.directions where sport = p_sport and pyramide_id = p_joueur
    union
    select club from smarves.directions_releves where sport = p_sport and pyramide_id = p_joueur and effet <= now()) c
  where c.club <> coalesce(p_sauf, '') and smarves.directeur(p_sport, c.club) = p_joueur
  order by c.club
  limit 1
$$;

-- Les déclarations échues passent dans la table des directions, et les changements de club sont comptés.
create or replace function smarves.regler_releves(p_sport text) returns void
  language plpgsql security definer set search_path = ''
as $$
declare
  c record;
  g text;
  quitte text;
begin
  for c in select r.club, min(r.effet) as effet from smarves.directions_releves r
      where r.sport = p_sport and r.effet <= now() group by r.club order by min(r.effet), r.club loop
    g := smarves.releve_gagnant(p_sport, c.club);
    if g is not null then
      select d.club into quitte from smarves.directions d
        where d.sport = p_sport and d.pyramide_id = g and d.club <> c.club
          and smarves.investi(p_sport, d.club, g) > 0
        limit 1;
      if quitte is not null then
        insert into smarves.directions_changements (sport, pyramide_id, periode, club, effet)
          values (p_sport, g, smarves.periode_de(p_sport, c.effet), c.club, c.effet)
          on conflict do nothing;
      end if;
      delete from smarves.directions where sport = p_sport and pyramide_id = g and club <> c.club;
      insert into smarves.directions as d (sport, club, pyramide_id, division)
        select p_sport, c.club, g, r.division from smarves.directions_releves r
        where r.sport = p_sport and r.pyramide_id = g
        on conflict (sport, club) do update set pyramide_id = excluded.pyramide_id, division = excluded.division, maj = now();
    end if;
    delete from smarves.directions_releves where sport = p_sport and club = c.club and effet <= now();
  end loop;
end $$;

-- Qui dirige : le titulaire de la direction ; sinon la plus grosse somme investie parmi les porteurs qui ne
-- dirigent pas un autre club du sport (et chacun à égalité), et tout le monde sans porteur.
create or replace function smarves.dirige_sport(p_sport text, p_club text, p_joueur text) returns boolean
  language plpgsql stable security definer set search_path = ''
as $$
declare
  d text := smarves.directeur(p_sport, p_club);
  porteurs integer;
  plus integer;
begin
  if d is not null then return d = p_joueur; end if;
  select count(distinct o.pyramide_id) into porteurs from (
    select pyramide_id from smarves.obligations where p_sport = 'football' and club = p_club
    union all
    select pyramide_id from basket.obligations where p_sport = 'basket' and club = p_club) o;
  if porteurs = 0 then return true; end if;
  if smarves.club_dirige(p_sport, p_joueur, p_club) is not null then return false; end if;
  select max(t.total) into plus from (
    select o.pyramide_id, sum(smarves.obligation_valeur(o.rang)) as total from (
      select pyramide_id, rang from smarves.obligations where p_sport = 'football' and club = p_club
      union all
      select pyramide_id, rang from basket.obligations where p_sport = 'basket' and club = p_club) o
    group by o.pyramide_id) t
  where smarves.club_dirige(p_sport, t.pyramide_id, p_club) is null;
  if plus is null then return false; end if;
  return smarves.investi(p_sport, p_club, p_joueur) >= plus;
end $$;

revoke all on function smarves.releve_suivante(timestamptz), smarves.periode_de(text, timestamptz),
  smarves.secondes_locales(timestamptz), smarves.releve_gagnant(text, text), smarves.directeur(text, text),
  smarves.club_dirige(text, text, text), smarves.regler_releves(text), smarves.dirige_sport(text, text, text) from public;

-- Les directions, publiques comme le championnat : [{club, par, moi, division}].
create or replace function public.smarves_directions(p_jeton text default null, p_sport text default 'football') returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if p_sport is null or p_sport not in ('football', 'basket') then raise exception 'sport invalide'; end if;
  perform smarves.regler_releves(p_sport);
  return coalesce((select json_agg(x) from (
      select d.club, j.nom as par, (d.pyramide_id = moi) is true as moi, d.division
      from smarves.directions d join smarves.joueurs j using (pyramide_id)
      where d.sport = p_sport and smarves.investi(p_sport, d.club, d.pyramide_id) > 0
      order by d.club) x), '[]'::json);
end $$;

-- Les relèves annoncées, publiques aussi, et les changements de club du joueur :
-- {releves: [{club, par, moi, effet}], changements: [{periode, club}]} ; effet en secondes locales.
create or replace function public.smarves_direction_releves(p_jeton text default null, p_sport text default 'football') returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if p_sport is null or p_sport not in ('football', 'basket') then raise exception 'sport invalide'; end if;
  perform smarves.regler_releves(p_sport);
  return json_build_object(
    'releves', coalesce((select json_agg(x) from (
      select r.club, j.nom as par, (r.pyramide_id = moi) is true as moi, smarves.secondes_locales(r.effet) as effet
      from smarves.directions_releves r join smarves.joueurs j using (pyramide_id)
      where r.sport = p_sport order by r.effet, r.club, r.declaree) x), '[]'::json),
    'changements', coalesce((select json_agg(x) from (
      select c.periode, c.club from smarves.directions_changements c
      where c.sport = p_sport and c.pyramide_id = moi order by c.effet) x), '[]'::json));
end $$;

-- Prendre la direction d'un club : {ok: true} si c'est fait tout de suite (la direction est vacante et l'on
-- n'en tient pas d'autre, ou c'est déjà la sienne : la déclaration en attente est alors retirée) ;
-- {ok: true, releve: true, effet} si c'est déclaré pour la relève (effet en secondes locales) ;
-- {ok: false, raison} avec « parts » (aucune part, ou un autre porteur a mis plus), « ailleurs » (on dirige
-- un autre club du sport : p_changer le quitte à la relève), « saison » (on a déjà changé de club dans la
-- période de cette relève, la saison ou l'intersaison ; avec periode) ; {erreur: 'jeton'} sans compte.
-- p_division reste la division du club, gardée pour l'affichage.
create or replace function public.smarves_direction_prendre(p_jeton text, p_sport text, p_club text, p_division text,
    p_changer boolean default false) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  mien integer;
  actuel text;
  ailleurs text;
  plus integer;
  effet timestamptz;
  sa_periode text;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_sport is null or p_sport not in ('football', 'basket') then raise exception 'sport invalide'; end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_division is null or p_division !~ '^[0-9]{0,3}$' then raise exception 'division invalide'; end if;
  perform pg_advisory_xact_lock(hashtext(format('direction/%s/%s', p_sport, moi)));
  perform pg_advisory_xact_lock(hashtext(format('direction/%s/%s', p_sport, p_club)));
  perform smarves.regler_releves(p_sport);
  mien := smarves.investi(p_sport, p_club, moi);
  if mien <= 0 then return json_build_object('ok', false, 'raison', 'parts'); end if;
  actuel := smarves.directeur(p_sport, p_club);
  if actuel = moi then
    update smarves.directions set division = p_division, maj = now() where sport = p_sport and club = p_club;
    delete from smarves.directions_releves where sport = p_sport and pyramide_id = moi;
    return json_build_object('ok', true);
  end if;
  ailleurs := smarves.club_dirige(p_sport, moi, p_club);
  if ailleurs is not null and not p_changer then
    return json_build_object('ok', false, 'raison', 'ailleurs');
  end if;
  -- Le plus gros des autres porteurs qui ne dirigent pas un autre club du sport (le titulaire compte).
  select max(t.total) into plus from (
    select o.pyramide_id, sum(smarves.obligation_valeur(o.rang)) as total from (
      select pyramide_id, rang from smarves.obligations where p_sport = 'football' and club = p_club
      union all
      select pyramide_id, rang from basket.obligations where p_sport = 'basket' and club = p_club) o
    where o.pyramide_id <> moi
    group by o.pyramide_id) t
  where smarves.club_dirige(p_sport, t.pyramide_id, p_club) is null;
  if plus is not null and mien < plus then return json_build_object('ok', false, 'raison', 'parts'); end if;
  if actuel is null and ailleurs is null then
    insert into smarves.directions as d (sport, club, pyramide_id, division) values (p_sport, p_club, moi, p_division)
      on conflict (sport, club) do update set pyramide_id = excluded.pyramide_id, division = excluded.division, maj = now();
    delete from smarves.directions_releves where sport = p_sport and pyramide_id = moi;
    return json_build_object('ok', true);
  end if;
  effet := smarves.releve_suivante(now());
  sa_periode := smarves.periode_de(p_sport, effet);
  if ailleurs is not null and exists (select 1 from smarves.directions_changements c
      where c.sport = p_sport and c.pyramide_id = moi and c.periode = sa_periode) then
    return json_build_object('ok', false, 'raison', 'saison', 'periode', sa_periode);
  end if;
  insert into smarves.directions_releves as r (sport, pyramide_id, club, division, declaree, effet)
    values (p_sport, moi, p_club, p_division, now(), effet)
    on conflict (sport, pyramide_id) do update set club = excluded.club, division = excluded.division,
      declaree = excluded.declaree, effet = excluded.effet;
  return json_build_object('ok', true, 'releve', true, 'effet', smarves.secondes_locales(effet));
end $$;

-- Retirer sa déclaration en attente : {ok: true}.
create or replace function public.smarves_direction_renoncer(p_jeton text, p_sport text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_sport is null or p_sport not in ('football', 'basket') then raise exception 'sport invalide'; end if;
  perform pg_advisory_xact_lock(hashtext(format('direction/%s/%s', p_sport, moi)));
  delete from smarves.directions_releves where sport = p_sport and pyramide_id = moi and effet > now();
  return json_build_object('ok', true);
end $$;

-- Prendre une obligation : toute l'année.
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
  insert into basket.obligations (club, rang, pyramide_id) values (p_club, p_rang, moi) on conflict (club, rang) do nothing;
  if not found then return json_build_object('ok', false, 'raison', 'prise'); end if;
  return json_build_object('ok', true);
end $$;

revoke all on function public.smarves_directions(text, text), public.smarves_direction_prendre(text, text, text, text, boolean),
  public.smarves_direction_releves(text, text), public.smarves_direction_renoncer(text, text) from public;
grant execute on function public.smarves_directions(text, text), public.smarves_direction_prendre(text, text, text, text, boolean),
  public.smarves_direction_releves(text, text), public.smarves_direction_renoncer(text, text) to anon, authenticated;
