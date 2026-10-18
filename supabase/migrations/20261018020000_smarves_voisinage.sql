-- Smarves, le voisinage (étape 2 du multi, docs/SUITE.md section 4) : ce que les joueurs laissent dans
-- le village sans y être en même temps. Tout se lit en un appel (public.smarves_village), à l'arrivée
-- au village et à l'ouverture du panneau de la mairie ; on écrit par petites fonctions, chacune avec
-- son jeton et ses limites.
--
-- - la vitrine : ce que le joueur montre de sa partie (total gagné, dette, logements), envoyée avec la
--   partie ; le classement et les noms sur les maisons en sortent ;
-- - les petites annonces du panneau de la mairie : une par joueur et par jour, gardées sept jours ;
-- - le livre d'or : un mot laissé à la porte d'un autre joueur ;
-- - les passages : qui est passé où ces dernières vingt-quatre heures.

create table if not exists smarves.vitrines (
  pyramide_id text primary key references smarves.joueurs (pyramide_id) on delete cascade,
  gagne bigint not null default 0,
  dette bigint not null default 0,
  -- [{lot, habite, meubles}]
  logements jsonb not null default '[]',
  maj timestamptz not null default now()
);

create table if not exists smarves.annonces (
  id bigint generated always as identity primary key,
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  texte text not null,
  cree timestamptz not null default now()
);
create index if not exists annonces_cree on smarves.annonces (cree desc);

create table if not exists smarves.mots (
  id bigint generated always as identity primary key,
  lot text not null,
  pour text not null references smarves.joueurs (pyramide_id) on delete cascade,
  de text not null references smarves.joueurs (pyramide_id) on delete cascade,
  texte text not null,
  cree timestamptz not null default now()
);
create index if not exists mots_pour on smarves.mots (pour, cree desc);

create table if not exists smarves.passages (
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  lieu text not null,
  vu timestamptz not null default now(),
  primary key (pyramide_id, lieu)
);
create index if not exists passages_vu on smarves.passages (vu desc);

alter table smarves.vitrines enable row level security;
alter table smarves.annonces enable row level security;
alter table smarves.mots enable row level security;
alter table smarves.passages enable row level security;

-- Un texte écrit par un joueur : une ligne, sans balises, de 1 à n caractères. Nul s'il ne va pas.
create or replace function smarves.texte(p text, n integer) returns text
  language sql immutable set search_path = ''
as $$
  select case when t is null or char_length(t) not between 1 and n or t ~ '[[:cntrl:]<>]' then null else t end
  from (select btrim(regexp_replace(coalesce(p, ''), '\s+', ' ', 'g')) as t) x
$$;

revoke all on all functions in schema smarves from public;

-- Ce que le joueur montre de sa partie. Les logements : lot connu, habité ou non, nombre de meubles.
create or replace function public.smarves_vitrine_ecrire(p_jeton text, p_gagne bigint, p_dette bigint, p_logements jsonb)
  returns json language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  l jsonb;
  propres jsonb := '[]';
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if jsonb_typeof(p_logements) is distinct from 'array' or jsonb_array_length(p_logements) > 10 then raise exception 'logements invalides'; end if;
  for l in select * from jsonb_array_elements(p_logements) loop
    if l->>'lot' is null or l->>'lot' !~ '^[a-z0-9_]{1,40}$' then raise exception 'lot invalide'; end if;
    propres := propres || jsonb_build_array(jsonb_build_object('lot', l->>'lot',
      'habite', coalesce((l->>'habite')::boolean, false), 'meubles', least(greatest(coalesce((l->>'meubles')::int, 0), 0), 999)));
  end loop;
  insert into smarves.vitrines as v (pyramide_id, gagne, dette, logements)
    values (moi, greatest(coalesce(p_gagne, 0), 0), greatest(coalesce(p_dette, 0), 0), propres)
    on conflict (pyramide_id) do update set gagne = excluded.gagne, dette = excluded.dette,
      logements = excluded.logements, maj = now();
  return json_build_object('ok', true);
end $$;

-- Une petite annonce au panneau de la mairie : 120 caractères, une par jour.
create or replace function public.smarves_annoncer(p_jeton text, p_texte text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  t text := smarves.texte(p_texte, 120);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if t is null then return json_build_object('ok', false, 'raison', 'texte'); end if;
  if exists (select 1 from smarves.annonces where pyramide_id = moi and cree > now() - interval '20 hours') then
    return json_build_object('ok', false, 'raison', 'jour');
  end if;
  insert into smarves.annonces (pyramide_id, texte) values (moi, t);
  return json_build_object('ok', true);
end $$;

-- Un mot dans le livre d'or d'un autre joueur, à la porte d'un logement qu'il possède : 200 caractères,
-- trois par heure et par auteur.
create or replace function public.smarves_mot_laisser(p_jeton text, p_pour text, p_lot text, p_texte text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  t text := smarves.texte(p_texte, 200);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if t is null then return json_build_object('ok', false, 'raison', 'texte'); end if;
  if p_pour = moi then return json_build_object('ok', false, 'raison', 'soi'); end if;
  if not exists (select 1 from smarves.vitrines v, jsonb_array_elements(v.logements) l
                 where v.pyramide_id = p_pour and l->>'lot' = p_lot) then
    return json_build_object('ok', false, 'raison', 'porte');
  end if;
  if (select count(*) from smarves.mots where de = moi and cree > now() - interval '1 hour') >= 3 then
    return json_build_object('ok', false, 'raison', 'heure');
  end if;
  insert into smarves.mots (lot, pour, de, texte) values (p_lot, p_pour, moi, t);
  return json_build_object('ok', true);
end $$;

-- Le joueur passe dans un lieu (au plus une écriture par lieu et par minute).
create or replace function public.smarves_passer(p_jeton text, p_lieu text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_lieu is null or p_lieu !~ '^[a-z0-9_]{1,40}$' then raise exception 'lieu invalide'; end if;
  insert into smarves.passages as p (pyramide_id, lieu) values (moi, p_lieu)
    on conflict (pyramide_id, lieu) do update set vu = now() where p.vu < now() - interval '1 minute';
  return json_build_object('ok', true);
end $$;

-- Tout le voisinage en un appel. Sans jeton (ou avec un jeton périmé), la part commune ; avec, aussi
-- l'identifiant du joueur et les mots de son livre d'or.
create or replace function public.smarves_village(p_jeton text default null) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := case when p_jeton is null then null else smarves.joueur(p_jeton) end;
begin
  return json_build_object(
    'moi', moi,
    'classement', coalesce((select json_agg(x) from (
        select j.nom, v.gagne from smarves.vitrines v join smarves.joueurs j using (pyramide_id)
        where v.gagne > 0 order by v.gagne desc, v.maj limit 10) x), '[]'),
    'annonces', coalesce((select json_agg(x) from (
        select j.nom, a.texte, extract(epoch from a.cree)::bigint as quand from smarves.annonces a join smarves.joueurs j using (pyramide_id)
        where a.cree > now() - interval '7 days' order by a.cree desc limit 20) x), '[]'),
    'maisons', coalesce((select json_object_agg(lot, gens) from (
        select l->>'lot' as lot, json_agg(json_build_object('id', v.pyramide_id, 'nom', j.nom,
          'habite', (l->>'habite')::boolean, 'meubles', (l->>'meubles')::int) order by v.maj desc) as gens
        from smarves.vitrines v join smarves.joueurs j using (pyramide_id), jsonb_array_elements(v.logements) l
        where v.maj > now() - interval '60 days' group by l->>'lot') x), '{}'),
    'passages', coalesce((select json_object_agg(lieu, noms) from (
        select p.lieu, json_agg(j.nom order by p.vu desc) as noms from smarves.passages p join smarves.joueurs j using (pyramide_id)
        where p.vu > now() - interval '24 hours' and p.pyramide_id is distinct from moi group by p.lieu) x), '{}'),
    'mots', case when moi is null then '[]'::json else coalesce((select json_agg(x) from (
        select j.nom, m.lot, m.texte, extract(epoch from m.cree)::bigint as quand from smarves.mots m join smarves.joueurs j on j.pyramide_id = m.de
        where m.pour = moi order by m.cree desc limit 30) x), '[]') end
  );
end $$;

revoke all on function public.smarves_vitrine_ecrire(text, bigint, bigint, jsonb), public.smarves_annoncer(text, text),
  public.smarves_mot_laisser(text, text, text, text), public.smarves_passer(text, text), public.smarves_village(text) from public;
grant execute on function public.smarves_vitrine_ecrire(text, bigint, bigint, jsonb), public.smarves_annoncer(text, text),
  public.smarves_mot_laisser(text, text, text, text), public.smarves_passer(text, text), public.smarves_village(text) to anon, authenticated;
