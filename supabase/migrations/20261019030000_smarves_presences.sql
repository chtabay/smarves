-- Smarves, se croiser (lot 1 du temps réel, fiche « se croiser » du projet) : qui est dans quel lieu en
-- ce moment. Un lieu est une scène du jeu (la place de Smarves, l'intérieur du casino). Chaque lieu a un
-- canal Supabase Realtime public dont le nom porte un secret, donné ici aux seuls présents ; les positions
-- passent de joueur à joueur sur ce canal sans toucher la base. La base ne tient que la liste des présents,
-- avec leur nom et leur tenue, qu'un joueur relit à chaque battement (toutes les 20 s).
--
-- Rien ne tourne en boucle : chaque appel range d'abord ce qui a expiré (présents sans battement depuis
-- une minute, canaux vides depuis dix minutes). Au-delà de 16 présents, un lieu ouvre une deuxième copie.

create table if not exists smarves.canaux (
  commune text not null,
  lieu text not null,
  copie integer not null,
  secret text not null,
  cree timestamptz not null default now(),
  primary key (commune, lieu, copie)
);

create table if not exists smarves.presences (
  pyramide_id text primary key references smarves.joueurs (pyramide_id) on delete cascade,
  commune text not null,
  lieu text not null,
  copie integer not null,
  -- L'identifiant public dans les canaux : un condensé stable qui ne révèle pas l'identifiant Pyramides.
  membre text not null,
  tenue text not null default '',
  entre timestamptz not null default now(),
  vu timestamptz not null default now()
);
create index if not exists presences_lieu on smarves.presences (commune, lieu, copie);

alter table smarves.canaux enable row level security;
alter table smarves.presences enable row level security;

-- Les réglages, en un seul endroit : la place d'une copie, la cadence des positions.
create or replace function smarves.presences_reglages() returns jsonb
  language sql immutable set search_path = ''
as $$ select '{"places": 16, "expire": 60, "vide": 600, "cadence": 3, "cadence_foule": 1, "foule": 8}'::jsonb $$;

create or replace function smarves.membre(p_id text) returns text
  language sql immutable set search_path = ''
as $$ select left(encode(extensions.digest('smarves-lieu:' || p_id, 'sha256'), 'hex'), 12) $$;

-- Range ce qui a expiré.
create or replace function smarves.presences_ranger() returns void
  language plpgsql security definer set search_path = ''
as $$
declare
  r jsonb := smarves.presences_reglages();
begin
  delete from smarves.presences where vu < now() - make_interval(secs => (r->>'expire')::int);
  delete from smarves.canaux c where c.cree < now() - make_interval(secs => (r->>'vide')::int)
    and not exists (select 1 from smarves.presences p where (p.commune, p.lieu, p.copie) = (c.commune, c.lieu, c.copie));
end $$;

-- Ce que voit un présent de son lieu : le canal, sa cadence et les autres présents.
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
      where (o.commune, o.lieu, o.copie) = (p.commune, p.lieu, p.copie) and o.pyramide_id <> p_moi), '[]'));
end $$;

revoke all on all functions in schema smarves from public;

-- --- Ce que le jeu appelle -----------------------------------------------------------------------

-- Entrer dans un lieu (on quitte celui d'avant) : {canal, moi, cadence, presents: [{membre, nom, tenue}]}.
create or replace function public.smarves_lieu_entrer(p_jeton text, p_commune text, p_lieu text, p_tenue text default '')
  returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  r jsonb := smarves.presences_reglages();
  c integer;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_commune !~ '^[a-z0-9_]{1,40}$' or p_lieu !~ '^[a-z0-9_]{1,40}$' then raise exception 'lieu invalide'; end if;
  if coalesce(p_tenue, '') !~ '^[a-z0-9_]{0,40}$' then raise exception 'tenue invalide'; end if;
  perform smarves.presences_ranger();
  -- Deux entrées en même temps dans le même lieu ne doivent pas dépasser la place d'une copie.
  perform pg_advisory_xact_lock(hashtext('smarves-lieu:' || p_commune || ':' || p_lieu));
  delete from smarves.presences where pyramide_id = moi;
  -- La première copie qui a de la place, sinon une nouvelle.
  select k into c from generate_series(1, 1000) k
    where (select count(*) from smarves.presences p where (p.commune, p.lieu, p.copie) = (p_commune, p_lieu, k)) < (r->>'places')::int
    order by k limit 1;
  insert into smarves.canaux (commune, lieu, copie, secret)
    values (p_commune, p_lieu, c, encode(extensions.gen_random_bytes(12), 'hex'))
    on conflict do nothing;
  insert into smarves.presences (pyramide_id, commune, lieu, copie, membre, tenue)
    values (moi, p_commune, p_lieu, c, smarves.membre(moi), coalesce(p_tenue, ''));
  return smarves.presences_vue(moi);
end $$;

-- Toujours là : {canal, moi, cadence, presents}, ou {sorti: true} si la place a expiré (il faut rentrer).
create or replace function public.smarves_lieu_battement(p_jeton text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  perform smarves.presences_ranger();
  update smarves.presences set vu = now() where pyramide_id = moi;
  return smarves.presences_vue(moi);
end $$;

-- Quitter son lieu.
create or replace function public.smarves_lieu_sortir(p_jeton text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  delete from smarves.presences where pyramide_id = moi;
  return json_build_object('ok', true);
end $$;

revoke all on function public.smarves_lieu_entrer(text, text, text, text), public.smarves_lieu_battement(text),
  public.smarves_lieu_sortir(text) from public;
grant execute on function public.smarves_lieu_entrer(text, text, text, text), public.smarves_lieu_battement(text),
  public.smarves_lieu_sortir(text) to anon, authenticated;
