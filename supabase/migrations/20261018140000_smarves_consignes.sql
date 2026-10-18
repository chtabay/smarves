-- Smarves, les consignes du dimanche (le championnat de football, docs/SUITE.md section 6) : ce qu'un
-- club décide avant son match, tenu au serveur pour que le match soit le même chez tout le monde.
--
-- Le championnat n'est pas calculé ici : chaque jeu le rejoue à l'identique à partir du registre des
-- terrains, du calendrier réel et d'un hasard à graine. La seule chose qu'un joueur y change, ce sont
-- les consignes d'avant-match de son club (formation, mentalité, pressing), et elles entrent dans la
-- graine : si elles restaient sur son appareil, son championnat divergerait des autres. Elles passent
-- donc par ici, avant le coup d'envoi, et tout le monde les lit avant de jouer la journée.
--
-- Une consigne par club et par journée ; la dernière posée avant le coup d'envoi l'emporte, et la ligne
-- dit qui l'a posée. La propriété du club (les parts, chez le notaire) viendra restreindre qui peut
-- parler pour lui ; pour l'instant tout joueur connecté le peut.

create table if not exists smarves.consignes (
  saison integer not null,
  journee integer not null,
  club text not null,
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  formation text not null,
  mentalite text not null,
  pressing text not null,
  maj timestamptz not null default now(),
  primary key (saison, journee, club)
);

alter table smarves.consignes enable row level security;

-- Le coup d'envoi d'une journée, le même calendrier que le jeu (scripts/socle/football.gd : première
-- journée le dimanche 25 octobre 2026 à 15 h, quatorze journées, seize semaines par saison) : 15 h à
-- l'horloge de Paris, été comme hiver, comme le jeu qui compte en heure locale.
create or replace function smarves.coup_envoi(s integer, j integer) returns timestamptz
  language sql immutable set search_path = ''
as $$
  select (timestamp '2026-10-25 15:00:00' + make_interval(weeks => (s - 1) * 16 + (j - 1))) at time zone 'Europe/Paris'
$$;

revoke all on all functions in schema smarves from public;

-- Poser la consigne d'un club pour une journée à venir : {ok: true}, {ok: false, raison: 'joue'} si le
-- coup d'envoi est passé, {erreur: 'jeton'} sans compte.
create or replace function public.smarves_consigne_poser(p_jeton text, p_saison integer, p_journee integer, p_club text,
    p_formation text, p_mentalite text, p_pressing text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
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
  insert into smarves.consignes as c (saison, journee, club, pyramide_id, formation, mentalite, pressing)
    values (p_saison, p_journee, p_club, moi, p_formation, p_mentalite, p_pressing)
    on conflict (saison, journee, club) do update set pyramide_id = excluded.pyramide_id,
      formation = excluded.formation, mentalite = excluded.mentalite, pressing = excluded.pressing, maj = now();
  return json_build_object('ok', true);
end $$;

-- Toutes les consignes posées, de la première saison à aujourd'hui : chaque jeu en a besoin pour rejouer
-- le championnat à l'identique. Sans jeton aussi : elles sont publiques, comme le championnat.
-- [{saison, journee, club, formation, mentalite, pressing, par}].
create or replace function public.smarves_consignes(p_jeton text default null) returns json
  language sql security definer set search_path = ''
as $$
  select coalesce((select json_agg(x) from (
      select c.saison, c.journee, c.club, c.formation, c.mentalite, c.pressing, j.nom as par
      from smarves.consignes c join smarves.joueurs j using (pyramide_id)
      order by c.saison, c.journee, c.club) x), '[]'::json)
$$;

revoke all on function public.smarves_consigne_poser(text, integer, integer, text, text, text, text), public.smarves_consignes(text) from public;
grant execute on function public.smarves_consigne_poser(text, integer, integer, text, text, text, text), public.smarves_consignes(text) to anon, authenticated;
