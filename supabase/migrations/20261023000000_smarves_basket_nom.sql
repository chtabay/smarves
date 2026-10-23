-- Smarves, le nom du club de basket (demande de Guillaume du 23 octobre 2026) : le dirigeant d'un club, s'il
-- en tient des parts, peut le renommer, et le nouveau nom vaut pour tous les joueurs. Le nom par défaut reste
-- celui de la structure « gymnase » de la commune. Le jeu applique la même règle (scripts/socle/basket.gd,
-- nom_valide et renommer).

create table if not exists basket.noms (
  club text primary key,
  nom text not null check (char_length(nom) between 3 and 40),
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  maj timestamptz not null default now()
);

alter table basket.noms enable row level security;
revoke all on basket.noms from public, anon, authenticated;

-- Renommer un club : {ok: true}, {ok: false, raison} avec « nom » (nom refusé), « detenir » (aucune part du
-- club), « parts » (un autre dirige) ; {erreur: 'jeton'} sans compte.
create or replace function public.smarves_basket_nommer(p_jeton text, p_club text, p_nom text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  nom text := regexp_replace(btrim(coalesce(p_nom, '')), '\s+', ' ', 'g');
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if nom !~ '^[A-Za-zÀ-ÖØ-öø-ÿŒœ0-9 ''’.&-]{3,40}$' then return json_build_object('ok', false, 'raison', 'nom'); end if;
  if not exists (select 1 from basket.obligations where club = p_club and pyramide_id = moi) then
    return json_build_object('ok', false, 'raison', 'detenir');
  end if;
  if not basket.dirige(p_club, moi) then return json_build_object('ok', false, 'raison', 'parts'); end if;
  insert into basket.noms (club, nom, pyramide_id) values (p_club, nom, moi)
    on conflict (club) do update set nom = excluded.nom, pyramide_id = excluded.pyramide_id, maj = now();
  return json_build_object('ok', true);
end $$;

-- Le bureau lu par le jeu : celui d'avant (20261020080000_smarves_basket_club.sql), et les noms choisis.
create or replace function public.smarves_basket_bureau(p_jeton text default null, p_saison integer default 1) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  return json_build_object(
    'obligations', coalesce((select json_agg(x) from (
        select o.club, o.rang, j.nom as par, (o.pyramide_id = moi) is true as moi
        from basket.obligations o join smarves.joueurs j using (pyramide_id) order by o.club, o.rang) x), '[]'::json),
    'encheres', coalesce((select json_agg(x) from (
        select e.saison, e.journee, e.groupe, e.joueur, e.club, e.montant, j.nom as par, (e.pyramide_id = moi) is true as moi,
          to_char(e.quand at time zone 'Europe/Paris', 'YYYY-MM-DD HH24:MI:SS.US') as quand
        from basket.encheres e join smarves.joueurs j using (pyramide_id) where e.saison = p_saison order by e.id) x), '[]'::json),
    'liberations', coalesce((select json_agg(x) from (
        select l.saison, l.journee, l.club, l.joueur from basket.liberations l where l.saison = p_saison order by l.quand) x), '[]'::json),
    'consignes', coalesce((select json_agg(x) from (
        select c.saison, c.journee, c.club, c.consigne from basket.consignes c where c.saison = p_saison order by c.journee, c.club) x), '[]'::json),
    'noms', coalesce((select json_agg(x) from (
        select n.club, n.nom, j.nom as par from basket.noms n join smarves.joueurs j using (pyramide_id) order by n.club) x), '[]'::json));
end $$;

revoke all on function public.smarves_basket_nommer(text, text, text), public.smarves_basket_bureau(text, integer) from public;
grant execute on function public.smarves_basket_nommer(text, text, text), public.smarves_basket_bureau(text, integer) to anon, authenticated;
