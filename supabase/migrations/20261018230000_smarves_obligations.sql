-- Smarves, les obligations des clubs (le championnat de football, docs/SUITE.md section 6), sur le modèle
-- d'Impérial 2030 : neuf obligations par club, de tailles différentes (rang 1 à 9 : 500, 1 000, 1 500, 2 250,
-- 3 000, 4 000, 5 000, 6 250, 7 500 crédits), chacune en un seul exemplaire. La plus grosse somme investie
-- dirige le club (smarves.dirige) : la consigne du dimanche, la recrue du mercato. Elles remplacent les parts
-- à taille unique (20261018180000_smarves_parts.sql), dont la table était vide.
--
-- Le prix et les dividendes se paient dans le jeu, avec les crédits du joueur : la table ne sert qu'à
-- départager (une seule de chaque) et à partager (qui tient quoi, public comme le championnat).

create table if not exists smarves.obligations (
  club text not null,
  rang integer not null check (rang between 1 and 9),
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  maj timestamptz not null default now(),
  primary key (club, rang)
);

alter table smarves.obligations enable row level security;

-- La valeur d'une obligation, par son rang.
create or replace function smarves.obligation_valeur(p_rang integer) returns integer
  language sql immutable set search_path = ''
as $$
  select (array[500, 1000, 1500, 2250, 3000, 4000, 5000, 6250, 7500])[p_rang]
$$;

-- Qui dirige un club : sans porteur, tout le monde ; sinon la plus grosse somme investie, et chacun à égalité.
-- Le module mercato s'en sert aussi.
create or replace function smarves.dirige(p_club text, p_joueur text) returns boolean
  language plpgsql stable security definer set search_path = ''
as $$
declare
  plus integer;
  mien integer;
begin
  select max(total) into plus from (
    select sum(smarves.obligation_valeur(rang)) as total from smarves.obligations where club = p_club group by pyramide_id) t;
  if plus is null then return true; end if;
  select coalesce(sum(smarves.obligation_valeur(rang)), 0) into mien from smarves.obligations where club = p_club and pyramide_id = p_joueur;
  return mien >= plus;
end $$;

-- Prendre une obligation libre : {ok: true}, {ok: false, raison: 'prise'} si un autre l'a, {erreur: 'jeton'} sans compte.
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

-- Rendre une de ses obligations : {ok: true}, {ok: false, raison: 'absente'} si elle n'est pas à soi.
create or replace function public.smarves_obligation_rendre(p_jeton text, p_club text, p_rang integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_rang is null or p_rang not between 1 and 9 then raise exception 'rang invalide'; end if;
  delete from smarves.obligations where club = p_club and rang = p_rang and pyramide_id = moi;
  if not found then return json_build_object('ok', false, 'raison', 'absente'); end if;
  return json_build_object('ok', true);
end $$;

-- Toutes les obligations tenues, publiques comme le championnat : [{club, rang, par, moi}].
create or replace function public.smarves_obligations(p_jeton text default null) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  return coalesce((select json_agg(x) from (
      select o.club, o.rang, j.nom as par, (o.pyramide_id = moi) is true as moi
      from smarves.obligations o join smarves.joueurs j using (pyramide_id)
      order by o.club, o.rang) x), '[]'::json);
end $$;

revoke all on function public.smarves_obligation_prendre(text, text, integer), public.smarves_obligation_rendre(text, text, integer), public.smarves_obligations(text) from public;
grant execute on function public.smarves_obligation_prendre(text, text, integer), public.smarves_obligation_rendre(text, text, integer), public.smarves_obligations(text) to anon, authenticated;

-- La consigne du dimanche et la recrue du mercato suivent smarves.dirige (la plus grosse somme investie).
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
  if not smarves.dirige(p_club, moi) then return json_build_object('ok', false, 'raison', 'parts'); end if;
  insert into smarves.consignes as c (saison, journee, club, pyramide_id, formation, mentalite, pressing)
    values (p_saison, p_journee, p_club, moi, p_formation, p_mentalite, p_pressing)
    on conflict (saison, journee, club) do update set pyramide_id = excluded.pyramide_id,
      formation = excluded.formation, mentalite = excluded.mentalite, pressing = excluded.pressing, maj = now();
  return json_build_object('ok', true);
end $$;

create or replace function public.smarves_transfert_recruter(p_jeton text, p_saison integer, p_club text, p_joueur integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  envoi timestamptz;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_saison is null or p_saison not between 1 and 1000 then raise exception 'saison invalide'; end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_joueur is null or p_joueur not between 0 and 11 then raise exception 'joueur invalide'; end if;
  envoi := smarves.coup_envoi(p_saison, 1);
  if now() < envoi - interval '7 days' or now() >= envoi then return json_build_object('ok', false, 'raison', 'ferme'); end if;
  if not smarves.dirige(p_club, moi) then return json_build_object('ok', false, 'raison', 'parts'); end if;
  if exists (select 1 from smarves.transferts where saison = p_saison and club = p_club) then
    return json_build_object('ok', false, 'raison', 'deja');
  end if;
  if exists (select 1 from smarves.transferts where saison = p_saison and joueur = p_joueur) then
    return json_build_object('ok', false, 'raison', 'pris');
  end if;
  insert into smarves.transferts (saison, club, joueur, pyramide_id) values (p_saison, p_club, p_joueur, moi);
  return json_build_object('ok', true);
end $$;

-- Les parts à taille unique s'en vont (la table n'a jamais rien contenu).
drop function if exists public.smarves_part_declarer(text, text, integer);
drop function if exists public.smarves_parts(text);
drop table if exists smarves.parts;
