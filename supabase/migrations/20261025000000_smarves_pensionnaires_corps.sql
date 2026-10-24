-- Smarves, le corps des pensionnaires (docs/PENSIONNAIRES.md, « Le corps ») : un pensionnaire se tient sur
-- la place pendant les événements, marche, parle en bulles, et ne voit qu'à la portée d'un joueur.
--
-- 1. Les présents de la place donnent leur position à chaque battement (toutes les 20 s) : c'est ainsi
--    que le serveur sait qui un pensionnaire voit. Les positions fines, elles, passent toujours de joueur
--    à joueur sur le canal du lieu, sans la base.
-- 2. Le corps d'un pensionnaire : un trajet minuté [[t (ms), x, y, z], …] et des bulles [[t, texte], …],
--    écrits par la fonction doublures à chaque tour, et sa présence jusqu'à la fin de l'événement. La vue
--    d'un présent de la place les lui donne : son jeu le fait marcher et parler à l'heure dite.

alter table smarves.presences add column if not exists x real;
alter table smarves.presences add column if not exists z real;
alter table smarves.presences add column if not exists pos_vu timestamptz;

create table if not exists smarves.doublure_corps (
  doublure text primary key references smarves.doublures (id) on delete cascade,
  -- L'identifiant public dans la vue des présents, comme celui d'un joueur (smarves.membre).
  membre text not null,
  tenue text not null default 'costume' check (tenue ~ '^[a-z0-9_]{1,40}$'),
  trajet jsonb not null default '[]'::jsonb check (jsonb_typeof(trajet) = 'array' and jsonb_array_length(trajet) <= 200),
  bulles jsonb not null default '[]'::jsonb check (jsonb_typeof(bulles) = 'array' and jsonb_array_length(bulles) <= 12),
  present_jusqu timestamptz,
  maj timestamptz not null default now()
);
create index if not exists doublure_corps_present on smarves.doublure_corps (present_jusqu);
alter table smarves.doublure_corps enable row level security;
revoke all on smarves.doublure_corps from anon, authenticated;

-- La vue d'un présent : celle d'avant, plus l'heure du serveur (pour caler les trajets) et, sur la place
-- de Smarves, les pensionnaires présents.
create or replace function smarves.presences_vue(p_moi text) returns json
  language plpgsql stable security definer set search_path = ''
as $$
declare
  r jsonb := smarves.presences_reglages();
  p smarves.presences;
  n integer;
begin
  select * into p from smarves.presences where pyramide_id = p_moi;
  if p.pyramide_id is null then return json_build_object('sorti', true); end if;
  select count(*) into n from smarves.presences where (commune, lieu, copie) = (p.commune, p.lieu, p.copie);
  return json_build_object(
    'canal', (select 'smarves:' || c.commune || ':' || c.lieu || ':' || c.copie || ':' || c.secret from smarves.canaux c
      where (c.commune, c.lieu, c.copie) = (p.commune, p.lieu, p.copie)),
    'moi', p.membre,
    'cadence', case when n > (r->>'foule')::int then (r->>'cadence_foule')::int else (r->>'cadence')::int end,
    'presents', coalesce((select json_agg(json_build_object('membre', o.membre, 'nom', j.nom, 'tenue', o.tenue) order by o.entre)
      from smarves.presences o join smarves.joueurs j using (pyramide_id)
      where (o.commune, o.lieu, o.copie) = (p.commune, p.lieu, p.copie) and o.pyramide_id <> p_moi), '[]'),
    'maintenant', floor(extract(epoch from now()) * 1000)::bigint,
    'pensionnaires', case when (p.commune, p.lieu) = ('smarves', 'place') then coalesce((select json_agg(json_build_object(
        'membre', c.membre, 'nom', j.nom, 'tenue', c.tenue, 'trajet', c.trajet, 'bulles', c.bulles))
      from smarves.doublure_corps c join smarves.joueurs j on j.pyramide_id = c.doublure
      where c.present_jusqu > now()), '[]') else '[]' end);
end $$;

revoke all on function smarves.presences_vue(text) from public;

-- Le battement porte la position du joueur sur la place (en unités de la scène) ; sans elle, rien ne
-- change. Un ancien jeu, qui n'envoie que son jeton, est toujours servi.
drop function if exists public.smarves_lieu_battement(text);
create or replace function public.smarves_lieu_battement(p_jeton text, p_x real default null, p_z real default null)
  returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  pos boolean := p_x is not null and p_z is not null and abs(p_x) < 1000 and abs(p_z) < 1000;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  perform smarves.presences_ranger();
  update smarves.presences set vu = now(),
    x = case when pos then p_x else x end,
    z = case when pos then p_z else z end,
    pos_vu = case when pos then now() else pos_vu end
    where pyramide_id = moi;
  return smarves.presences_vue(moi);
end $$;

revoke all on function public.smarves_lieu_battement(text, real, real) from public;
grant execute on function public.smarves_lieu_battement(text, real, real) to anon, authenticated;
