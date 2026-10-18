-- Smarves, le mercato (le championnat de football, docs/SUITE.md section 6) : la recrue de chaque club
-- pour une saison, tenue ici pour que l'effectif soit le même chez tout le monde.
--
-- Chaque saison, le jeu tire douze joueurs libres, les mêmes partout. La semaine qui précède la première
-- journée, celui qui parle pour un club (son premier actionnaire, smarves.parts) peut en recruter un : une
-- recrue par club et par saison, un libre ne part qu'une fois. Le prix se paie dans le jeu, avec les
-- crédits du joueur : la table ne sert qu'à départager et à partager.

create table if not exists smarves.transferts (
  saison integer not null,
  club text not null,
  joueur integer not null check (joueur between 0 and 11),
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  maj timestamptz not null default now(),
  primary key (saison, club),
  unique (saison, joueur)
);

alter table smarves.transferts enable row level security;

-- Recruter le joueur libre p_joueur pour p_club à la saison p_saison : {ok: true}, {ok: false, raison}
-- avec raison « ferme » (hors de la semaine du mercato), « parts » (un autre actionnaire parle pour le
-- club), « deja » (le club a sa recrue), « pris » (le joueur est parti ailleurs) ; {erreur: 'jeton'} sans compte.
create or replace function public.smarves_transfert_recruter(p_jeton text, p_saison integer, p_club text, p_joueur integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  plus integer;
  envoi timestamptz;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_saison is null or p_saison not between 1 and 1000 then raise exception 'saison invalide'; end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_joueur is null or p_joueur not between 0 and 11 then raise exception 'joueur invalide'; end if;
  envoi := smarves.coup_envoi(p_saison, 1);
  if now() < envoi - interval '7 days' or now() >= envoi then return json_build_object('ok', false, 'raison', 'ferme'); end if;
  select max(nombre) into plus from smarves.parts where club = p_club;
  if plus is not null and coalesce((select nombre from smarves.parts where club = p_club and pyramide_id = moi), 0) < plus then
    return json_build_object('ok', false, 'raison', 'parts');
  end if;
  if exists (select 1 from smarves.transferts where saison = p_saison and club = p_club) then
    return json_build_object('ok', false, 'raison', 'deja');
  end if;
  if exists (select 1 from smarves.transferts where saison = p_saison and joueur = p_joueur) then
    return json_build_object('ok', false, 'raison', 'pris');
  end if;
  insert into smarves.transferts (saison, club, joueur, pyramide_id) values (p_saison, p_club, p_joueur, moi);
  return json_build_object('ok', true);
end $$;

-- Toutes les recrues, publiques comme le championnat : [{saison, club, joueur, par}].
create or replace function public.smarves_transferts(p_jeton text default null) returns json
  language sql security definer set search_path = ''
as $$
  select coalesce((select json_agg(x) from (
      select t.saison, t.club, t.joueur, j.nom as par
      from smarves.transferts t join smarves.joueurs j using (pyramide_id)
      order by t.saison, t.club) x), '[]'::json)
$$;

revoke all on function public.smarves_transfert_recruter(text, integer, text, integer), public.smarves_transferts(text) from public;
grant execute on function public.smarves_transfert_recruter(text, integer, text, integer), public.smarves_transferts(text) to anon, authenticated;
