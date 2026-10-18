-- Smarves, les parts des clubs (le championnat de football, docs/SUITE.md section 6) : qui tient des
-- parts d'un club, pour savoir qui parle pour lui à la causerie.
--
-- Les parts s'achètent et se revendent dans le jeu, chez le notaire, avec les crédits du joueur : la
-- sauvegarde fait foi, et le jeu déclare ici le nombre qu'il tient (zéro après une revente). La table ne
-- sert qu'à départager : quand un club a des actionnaires, seul le plus gros (chacun d'eux à égalité)
-- peut poser sa consigne du dimanche ; sans actionnaire, tout joueur connecté le peut, comme avant.

create table if not exists smarves.parts (
  club text not null,
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  nombre integer not null check (nombre > 0),
  maj timestamptz not null default now(),
  primary key (club, pyramide_id)
);

alter table smarves.parts enable row level security;

-- Déclarer les parts qu'on tient d'un club (zéro les retire) : {ok: true}, {erreur: 'jeton'} sans compte.
create or replace function public.smarves_part_declarer(p_jeton text, p_club text, p_nombre integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_nombre is null or p_nombre not between 0 and 1000 then raise exception 'nombre invalide'; end if;
  if p_nombre = 0 then
    delete from smarves.parts where club = p_club and pyramide_id = moi;
  else
    insert into smarves.parts as p (club, pyramide_id, nombre) values (p_club, moi, p_nombre)
      on conflict (club, pyramide_id) do update set nombre = excluded.nombre, maj = now();
  end if;
  return json_build_object('ok', true);
end $$;

-- Les parts de tous les clubs, publiques comme le championnat : [{club, nombre, par, moi}], les plus gros
-- d'abord ; « moi » dit celles du joueur du jeton, que son jeu remplace par les siennes.
create or replace function public.smarves_parts(p_jeton text default null) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  return coalesce((select json_agg(x) from (
      select p.club, p.nombre, j.nom as par, (p.pyramide_id = moi) is true as moi
      from smarves.parts p join smarves.joueurs j using (pyramide_id)
      order by p.club, p.nombre desc, j.nom) x), '[]'::json);
end $$;

revoke all on function public.smarves_part_declarer(text, text, integer), public.smarves_parts(text) from public;
grant execute on function public.smarves_part_declarer(text, text, integer), public.smarves_parts(text) to anon, authenticated;

-- La consigne du dimanche n'est plus à tout le monde : quand le club a des actionnaires, seul le plus gros
-- la pose ({ok: false, raison: 'parts'} sinon). Le reste comme avant (20261018140000_smarves_consignes.sql).
create or replace function public.smarves_consigne_poser(p_jeton text, p_saison integer, p_journee integer, p_club text,
    p_formation text, p_mentalite text, p_pressing text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  plus integer;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_saison is null or p_saison not between 1 and 1000 or p_journee is null or p_journee not between 1 and 14 then
    raise exception 'journée invalide';
  end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_formation is null or p_formation not in ('4-4-2', '4-3-3', '4-2-3-1', '3-5-2', '5-3-2', '4-5-1') then raise exception 'formation invalide'; end if;
  if p_mentalite is null or p_mentalite not in ('defensive', 'prudente', 'equilibree', 'offensive', 'tout') then raise exception 'mentalité invalide'; end if;
  if p_pressing is null or p_pressing not in ('bas', 'normal', 'haut') then raise exception 'pressing invalide'; end if;
  if now() >= smarves.coup_envoi(p_saison, p_journee) then return json_build_object('ok', false, 'raison', 'joue'); end if;
  select max(nombre) into plus from smarves.parts where club = p_club;
  if plus is not null and coalesce((select nombre from smarves.parts where club = p_club and pyramide_id = moi), 0) < plus then
    return json_build_object('ok', false, 'raison', 'parts');
  end if;
  insert into smarves.consignes as c (saison, journee, club, pyramide_id, formation, mentalite, pressing)
    values (p_saison, p_journee, p_club, moi, p_formation, p_mentalite, p_pressing)
    on conflict (saison, journee, club) do update set pyramide_id = excluded.pyramide_id,
      formation = excluded.formation, mentalite = excluded.mentalite, pressing = excluded.pressing, maj = now();
  return json_build_object('ok', true);
end $$;
