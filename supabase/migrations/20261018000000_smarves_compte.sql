-- Smarves, le compte (étape 1 du multi, docs/SUITE.md section 4) : la partie gardée au nom du joueur.
--
-- Le jeu Godot se connecte par le serveur d'autorisation de Pyramides (portée « smarves ») et reçoit
-- un jeton HS256 de trente jours. Il appelle ensuite ces fonctions par l'API REST du projet, avec la
-- clé publique : c'est le jeton qui dit qui joue, vérifié ici même, comme pour Belley. Le schéma
-- `smarves` est fermé à l'API ; seules les fonctions `public.smarves_*` en sortent.
--
-- La partie est celle des fichiers du jeu (socle, tiroirs des communes, biens), gardée telle quelle :
-- le serveur ne la lit pas, il la range et la numérote. Une écriture dit sur quelle version elle se
-- fonde ; si une autre est passée entre-temps (un autre appareil), elle est refusée et le jeu demande
-- au joueur laquelle garder.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists smarves;
revoke all on schema smarves from public;

-- --- Le jeton ------------------------------------------------------------------------------------

create or replace function smarves.b64url(p text) returns bytea
  language sql immutable set search_path = ''
as $$ select decode(rpad(translate(p, '-_', '+/'), (char_length(p) + 3) / 4 * 4, '='), 'base64') $$;

-- La même dérivation que Pyramides (src/lib/portees-jeu.ts, smarvesKey).
create or replace function smarves.deriver_cle(p_secret text) returns bytea
  language sql immutable set search_path = ''
as $$ select extensions.hmac(convert_to('pyramides:smarves:v1', 'UTF8'), convert_to(p_secret, 'UTF8'), 'sha256') $$;

create or replace function smarves.cle_jeton() returns bytea
  language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select convert_to(decrypted_secret, 'UTF8') from vault.decrypted_secrets where name = 'smarves_token_secret'),
    (select smarves.deriver_cle(decrypted_secret) from vault.decrypted_secrets where name = 'casino_token_secret'))
$$;

-- Le joueur d'un jeton valide, ou deux nuls.
create or replace function smarves.joueur_du_jeton(p_jeton text, out id text, out nom text)
  language plpgsql stable security definer set search_path = ''
as $$
declare
  parts text[];
  entete jsonb;
  corps jsonb;
  cle bytea;
  attendu text;
begin
  if p_jeton is null or char_length(p_jeton) > 2048 then return; end if;
  parts := string_to_array(p_jeton, '.');
  if cardinality(parts) <> 3 then return; end if;
  cle := smarves.cle_jeton();
  if cle is null then return; end if;
  begin
    entete := convert_from(smarves.b64url(parts[1]), 'UTF8')::jsonb;
    corps := convert_from(smarves.b64url(parts[2]), 'UTF8')::jsonb;
  exception when others then return;
  end;
  if entete->>'alg' is distinct from 'HS256' then return; end if;
  attendu := rtrim(translate(encode(extensions.hmac(convert_to(parts[1] || '.' || parts[2], 'UTF8'), cle, 'sha256'), 'base64'), E'+/\n', '-_'), '=');
  if extensions.digest(attendu, 'sha256') <> extensions.digest(parts[3], 'sha256') then return; end if;
  if corps->>'aud' is distinct from 'smarves' then return; end if;
  if jsonb_typeof(corps->'exp') is distinct from 'number' or (corps->>'exp')::numeric < extract(epoch from now()) then return; end if;
  if jsonb_typeof(corps->'sub') is distinct from 'string' or char_length(corps->>'sub') not between 1 and 64 then return; end if;
  id := corps->>'sub';
  nom := left(coalesce(corps->>'name', ''), 80);
end $$;

-- --- Les tables ----------------------------------------------------------------------------------

create table if not exists smarves.joueurs (
  pyramide_id text primary key,
  nom text not null,
  cree timestamptz not null default now(),
  vu timestamptz not null default now()
);

create table if not exists smarves.parties (
  pyramide_id text primary key references smarves.joueurs (pyramide_id) on delete cascade,
  version integer not null,
  -- {chemin relatif dans user:// : contenu du fichier}
  fichiers jsonb not null,
  -- Ce que le jeu montre pour choisir entre deux parties : crédits, total gagné, fortune.
  resume jsonb not null default '{}',
  appareil text not null default '',
  maj timestamptz not null default now()
);

alter table smarves.joueurs enable row level security;
alter table smarves.parties enable row level security;

-- Le joueur du jeton, tenu à jour (son nom Pyramides peut changer). Nul si le jeton ne vaut rien.
create or replace function smarves.joueur(p_jeton text) returns text
  language plpgsql security definer set search_path = ''
as $$
declare
  j record;
begin
  select * into j from smarves.joueur_du_jeton(p_jeton);
  if j.id is null then return null; end if;
  insert into smarves.joueurs as o (pyramide_id, nom) values (j.id, j.nom)
    on conflict (pyramide_id) do update set nom = excluded.nom, vu = now()
    where o.vu < now() - interval '1 minute' or o.nom is distinct from excluded.nom;
  return j.id;
end $$;

revoke all on all functions in schema smarves from public;

-- --- Ce que le jeu appelle -----------------------------------------------------------------------

-- Qui joue : {id, nom}, ou {erreur: 'jeton'}.
create or replace function public.smarves_moi(p_jeton text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  return (select json_build_object('id', pyramide_id, 'nom', nom) from smarves.joueurs where pyramide_id = moi);
end $$;

-- La partie du compte : {version, fichiers, resume, appareil, maj} ; {version: 0} s'il n'y en a pas.
create or replace function public.smarves_partie_lire(p_jeton text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  p smarves.parties;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  select * into p from smarves.parties where pyramide_id = moi;
  if p.pyramide_id is null then return json_build_object('version', 0); end if;
  return json_build_object('version', p.version, 'fichiers', p.fichiers, 'resume', p.resume,
    'appareil', p.appareil, 'maj', extract(epoch from p.maj)::bigint);
end $$;

-- Écrit la partie si elle se fonde sur la dernière version : {ok: true, version}. Sinon rien n'est
-- écrit et la réponse dit ce qu'il y a : {ok: false, version, resume, appareil, maj}.
create or replace function public.smarves_partie_ecrire(p_jeton text, p_version integer, p_fichiers jsonb,
    p_resume jsonb default '{}', p_appareil text default '') returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  p smarves.parties;
  k text;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_version is null or p_version < 0 then raise exception 'version invalide'; end if;
  if jsonb_typeof(p_fichiers) is distinct from 'object' or octet_length(p_fichiers::text) > 1000000 then
    raise exception 'partie invalide';
  end if;
  for k in select jsonb_object_keys(p_fichiers) loop
    if char_length(k) > 120 or k !~ '^[A-Za-z0-9_./-]+$' or k like '%..%' or jsonb_typeof(p_fichiers->k) <> 'string' then
      raise exception 'fichier invalide';
    end if;
  end loop;
  if jsonb_typeof(coalesce(p_resume, '{}')) <> 'object' or octet_length(coalesce(p_resume, '{}')::text) > 2000 then
    raise exception 'resume invalide';
  end if;
  select * into p from smarves.parties where pyramide_id = moi for update;
  if coalesce(p.version, 0) <> p_version then
    return json_build_object('ok', false, 'version', p.version, 'resume', p.resume, 'appareil', p.appareil,
      'maj', extract(epoch from p.maj)::bigint);
  end if;
  insert into smarves.parties as o (pyramide_id, version, fichiers, resume, appareil, maj)
    values (moi, 1, p_fichiers, coalesce(p_resume, '{}'), left(coalesce(p_appareil, ''), 80), now())
    on conflict (pyramide_id) do update set version = o.version + 1, fichiers = excluded.fichiers,
      resume = excluded.resume, appareil = excluded.appareil, maj = now();
  return json_build_object('ok', true, 'version', p_version + 1);
end $$;

-- Oublier la partie du compte (le jeu garde la sienne).
create or replace function public.smarves_partie_effacer(p_jeton text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  delete from smarves.parties where pyramide_id = moi;
  return json_build_object('ok', true);
end $$;

revoke all on function public.smarves_moi(text), public.smarves_partie_lire(text),
  public.smarves_partie_ecrire(text, integer, jsonb, jsonb, text), public.smarves_partie_effacer(text) from public;
grant execute on function public.smarves_moi(text), public.smarves_partie_lire(text),
  public.smarves_partie_ecrire(text, integer, jsonb, jsonb, text), public.smarves_partie_effacer(text) to anon, authenticated;
