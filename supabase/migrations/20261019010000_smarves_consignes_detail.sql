-- Smarves, le détail des consignes du dimanche (le championnat de football, docs/SUITE.md section 6) : depuis le
-- 18 octobre 2026, une consigne porte aussi, s'ils sont donnés, la composition (onze ids, « » pour une case laissée
-- à l'adjoint), le banc et un rôle par joueur (Football.consigne()). Comme la formation, ils entrent dans la
-- graine du match : tout le monde doit les lire, donc ils vivent ici, dans une colonne json à part, telle que le
-- jeu l'envoie. Un jeu d'avant (sept paramètres) continue d'appeler smarves_consigne_poser : le détail est nul.

alter table smarves.consignes add column if not exists detail jsonb;

drop function if exists public.smarves_consigne_poser(text, integer, integer, text, text, text, text);

create or replace function public.smarves_consigne_poser(p_jeton text, p_saison integer, p_journee integer, p_club text,
    p_formation text, p_mentalite text, p_pressing text, p_detail json default null) returns json
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
  if p_detail is not null and (json_typeof(p_detail) <> 'object' or length(p_detail::text) > 4000) then raise exception 'détail invalide'; end if;
  if now() >= smarves.coup_envoi(p_saison, p_journee) then return json_build_object('ok', false, 'raison', 'joue'); end if;
  if not smarves.dirige(p_club, moi) then return json_build_object('ok', false, 'raison', 'parts'); end if;
  insert into smarves.consignes as c (saison, journee, club, pyramide_id, formation, mentalite, pressing, detail)
    values (p_saison, p_journee, p_club, moi, p_formation, p_mentalite, p_pressing, p_detail::jsonb)
    on conflict (saison, journee, club) do update set pyramide_id = excluded.pyramide_id,
      formation = excluded.formation, mentalite = excluded.mentalite, pressing = excluded.pressing, detail = excluded.detail, maj = now();
  return json_build_object('ok', true);
end $$;

-- Toutes les consignes posées, avec leur détail (null sans).
create or replace function public.smarves_consignes(p_jeton text default null) returns json
  language sql security definer set search_path = ''
as $$
  select coalesce((select json_agg(x) from (
      select c.saison, c.journee, c.club, c.formation, c.mentalite, c.pressing, c.detail, j.nom as par
      from smarves.consignes c join smarves.joueurs j using (pyramide_id)
      order by c.saison, c.journee, c.club) x), '[]'::json)
$$;

revoke all on function public.smarves_consigne_poser(text, integer, integer, text, text, text, text, json), public.smarves_consignes(text) from public;
grant execute on function public.smarves_consigne_poser(text, integer, integer, text, text, text, text, json), public.smarves_consignes(text) to anon, authenticated;
