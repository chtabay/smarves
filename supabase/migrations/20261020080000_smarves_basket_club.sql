-- Smarves, le club de basket (spec : basket/spec-basket-reel.md du projet, sections 7 et 9) : les obligations
-- du club, le marché des vrais joueurs, les joueurs libérés et la consigne du match. Le schéma basket existe
-- déjà (le cliché des notes, addict 20261020000000_basket.sql) ; il reste fermé à l'API publique, et ces
-- fonctions security definer sont la seule porte.
--
-- Comme au football, les crédits se paient dans le jeu : ces tables ne servent qu'à départager (une seule
-- de chaque obligation, la meilleure offre) et à partager (qui tient quoi, qui a offert combien, qui part).
-- Le jeu règle les enchères de la même façon partout (scripts/socle/basket.gd, marche_du_groupe) : à la
-- clôture du jeudi 22 h, la meilleure offre d'un club du groupe qui a encore une place et la masse
-- salariale pour le salaire.

create table if not exists basket.obligations (
  club text not null,
  rang integer not null check (rang between 1 and 9),
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  maj timestamptz not null default now(),
  primary key (club, rang)
);

-- Une offre sur un vrai joueur libre d'un groupe (« 0-0 » : niveau et groupe), pour la journée j de la saison.
create table if not exists basket.encheres (
  id bigint generated always as identity primary key,
  saison integer not null,
  journee integer not null,
  groupe text not null,
  joueur text not null,
  club text not null,
  montant bigint not null check (montant > 0),
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  quand timestamptz not null default now()
);
create index if not exists encheres_lot on basket.encheres (saison, journee, groupe, joueur, montant desc);

-- Un joueur qu'un club libère à la clôture qui précède la journée j.
create table if not exists basket.liberations (
  saison integer not null,
  journee integer not null,
  club text not null,
  joueur text not null,
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  quand timestamptz not null default now(),
  primary key (saison, club, joueur)
);

-- La consigne d'un club pour un match : « titulaires » ou « rotation ».
create table if not exists basket.consignes (
  saison integer not null,
  journee integer not null,
  club text not null,
  consigne text not null check (consigne in ('titulaires', 'rotation')),
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  maj timestamptz not null default now(),
  primary key (saison, journee, club)
);

alter table basket.obligations enable row level security;
alter table basket.encheres enable row level security;
alter table basket.liberations enable row level security;
alter table basket.consignes enable row level security;
revoke all on all tables in schema basket from public, anon, authenticated;

-- Le coup d'envoi de la journée j (le samedi à 20 h, heure de Paris ; seize semaines par saison, la première
-- journée le 24 octobre 2026) et la clôture du marché qui la précède (le jeudi à 22 h) : les mêmes calculs
-- que scripts/socle/basket.gd (coup_envoi, cloture).
create or replace function basket.coup_envoi(s integer, j integer) returns timestamptz
  language sql immutable set search_path = ''
as $$
  select (timestamp '2026-10-24 20:00:00' + make_interval(weeks => (s - 1) * 16 + j - 1)) at time zone 'Europe/Paris'
$$;

create or replace function basket.cloture(s integer, j integer) returns timestamptz
  language sql immutable set search_path = ''
as $$
  select (timestamp '2026-10-22 22:00:00' + make_interval(weeks => (s - 1) * 16 + j - 1)) at time zone 'Europe/Paris'
$$;

-- Qui dirige un club : sans porteur, tout le monde ; sinon la plus grosse somme investie, et chacun à égalité.
create or replace function basket.dirige(p_club text, p_joueur text) returns boolean
  language plpgsql stable security definer set search_path = ''
as $$
declare
  plus integer;
  mien integer;
begin
  select max(total) into plus from (
    select sum(smarves.obligation_valeur(rang)) as total from basket.obligations where club = p_club group by pyramide_id) t;
  if plus is null then return true; end if;
  select coalesce(sum(smarves.obligation_valeur(rang)), 0) into mien from basket.obligations where club = p_club and pyramide_id = p_joueur;
  return mien >= plus;
end $$;

revoke all on function basket.coup_envoi(integer, integer), basket.cloture(integer, integer), basket.dirige(text, text) from public;

-- Prendre une obligation libre : {ok: true}, {ok: false, raison: 'prise'}, {erreur: 'jeton'} sans compte.
create or replace function public.smarves_basket_obligation_prendre(p_jeton text, p_club text, p_rang integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  tenue text;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_rang is null or p_rang not between 1 and 9 then raise exception 'rang invalide'; end if;
  select pyramide_id into tenue from basket.obligations where club = p_club and rang = p_rang;
  if tenue = moi then return json_build_object('ok', true); end if;
  if tenue is not null then return json_build_object('ok', false, 'raison', 'prise'); end if;
  insert into basket.obligations (club, rang, pyramide_id) values (p_club, p_rang, moi) on conflict (club, rang) do nothing;
  if not found then return json_build_object('ok', false, 'raison', 'prise'); end if;
  return json_build_object('ok', true);
end $$;

-- Rendre une de ses obligations : {ok: true}, {ok: false, raison: 'absente'}.
create or replace function public.smarves_basket_obligation_rendre(p_jeton text, p_club text, p_rang integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_rang is null or p_rang not between 1 and 9 then raise exception 'rang invalide'; end if;
  delete from basket.obligations where club = p_club and rang = p_rang and pyramide_id = moi;
  if not found then return json_build_object('ok', false, 'raison', 'absente'); end if;
  return json_build_object('ok', true);
end $$;

-- Enchérir sur un vrai joueur libre du groupe p_groupe pour la journée p_journee : {ok: true, quand},
-- {ok: false, raison} avec « ferme » (après la clôture du jeudi 22 h), « parts » (un autre dirige le club),
-- « bas » (sous la meilleure offre plus 2 %, au moins 10 crédits) ; {erreur: 'jeton'} sans compte. Le prix
-- de départ, la place dans l'effectif et le plafond se jugent dans le jeu, qui connaît les notes.
create or replace function public.smarves_basket_encherir(p_jeton text, p_saison integer, p_journee integer, p_groupe text,
    p_joueur text, p_club text, p_montant bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  meilleure bigint;
  q timestamptz;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_saison is null or p_saison not between 1 and 1000 or p_journee is null or p_journee not between 2 and 14 then raise exception 'journée invalide'; end if;
  if p_groupe is null or p_groupe !~ '^[0-9]{1,2}-[0-9]{1,6}$' then raise exception 'groupe invalide'; end if;
  if p_joueur is null or p_joueur !~ '^[0-9A-Za-z]{1,16}$' then raise exception 'joueur invalide'; end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_montant is null or p_montant not between 1 and 1000000000000 then raise exception 'montant invalide'; end if;
  if now() >= basket.cloture(p_saison, p_journee) then return json_build_object('ok', false, 'raison', 'ferme'); end if;
  if not basket.dirige(p_club, moi) then return json_build_object('ok', false, 'raison', 'parts'); end if;
  -- Une offre à la fois par joueur : la meilleure se lit et s'écrit sans qu'une autre s'intercale.
  perform pg_advisory_xact_lock(hashtext(format('basket/%s/%s/%s/%s', p_saison, p_journee, p_groupe, p_joueur)));
  select max(montant) into meilleure from basket.encheres
    where saison = p_saison and journee = p_journee and groupe = p_groupe and joueur = p_joueur;
  if meilleure is not null and p_montant < meilleure + greatest(10, ((meilleure + 499) / 500) * 10) then
    return json_build_object('ok', false, 'raison', 'bas');
  end if;
  insert into basket.encheres (saison, journee, groupe, joueur, club, montant, pyramide_id)
    values (p_saison, p_journee, p_groupe, p_joueur, p_club, p_montant, moi) returning quand into q;
  return json_build_object('ok', true, 'quand', to_char(q at time zone 'Europe/Paris', 'YYYY-MM-DD HH24:MI:SS.US'));
end $$;

-- Libérer un joueur de l'effectif à la clôture qui précède la journée p_journee : {ok: true}, {ok: false,
-- raison} « ferme » ou « parts ». Le jeu ne tient compte que d'un joueur que le club avait.
create or replace function public.smarves_basket_liberer(p_jeton text, p_saison integer, p_journee integer, p_club text, p_joueur text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_saison is null or p_saison not between 1 and 1000 or p_journee is null or p_journee not between 2 and 14 then raise exception 'journée invalide'; end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_joueur is null or p_joueur !~ '^[0-9A-Za-z]{1,16}$' then raise exception 'joueur invalide'; end if;
  if now() >= basket.cloture(p_saison, p_journee) then return json_build_object('ok', false, 'raison', 'ferme'); end if;
  if not basket.dirige(p_club, moi) then return json_build_object('ok', false, 'raison', 'parts'); end if;
  insert into basket.liberations (saison, journee, club, joueur, pyramide_id) values (p_saison, p_journee, p_club, p_joueur, moi)
    on conflict (saison, club, joueur) do nothing;
  return json_build_object('ok', true);
end $$;

-- Poser la consigne d'un match avant son coup d'envoi : {ok: true}, {ok: false, raison} « joue » ou « parts ».
create or replace function public.smarves_basket_consigne(p_jeton text, p_saison integer, p_journee integer, p_club text, p_consigne text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_saison is null or p_saison not between 1 and 1000 or p_journee is null or p_journee not between 1 and 14 then raise exception 'journée invalide'; end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_consigne is null or p_consigne not in ('titulaires', 'rotation') then raise exception 'consigne invalide'; end if;
  if now() >= basket.coup_envoi(p_saison, p_journee) then return json_build_object('ok', false, 'raison', 'joue'); end if;
  if not basket.dirige(p_club, moi) then return json_build_object('ok', false, 'raison', 'parts'); end if;
  insert into basket.consignes as c (saison, journee, club, consigne, pyramide_id) values (p_saison, p_journee, p_club, p_consigne, moi)
    on conflict (saison, journee, club) do update set consigne = excluded.consigne, pyramide_id = excluded.pyramide_id, maj = now();
  return json_build_object('ok', true);
end $$;

-- Le bureau de tous les clubs, public comme le championnat : {obligations: [{club, rang, par, moi}], encheres:
-- [{saison, journee, groupe, joueur, club, montant, par, moi, quand}], liberations: [{saison, journee, club,
-- joueur}], consignes: [{saison, journee, club, consigne}]}, pour la saison p_saison ; « moi » dit ce qui
-- vient du joueur du jeton.
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
        select c.saison, c.journee, c.club, c.consigne from basket.consignes c where c.saison = p_saison order by c.journee, c.club) x), '[]'::json));
end $$;

revoke all on function public.smarves_basket_obligation_prendre(text, text, integer), public.smarves_basket_obligation_rendre(text, text, integer),
  public.smarves_basket_encherir(text, integer, integer, text, text, text, bigint), public.smarves_basket_liberer(text, integer, integer, text, text),
  public.smarves_basket_consigne(text, integer, integer, text, text), public.smarves_basket_bureau(text, integer) from public;
grant execute on function public.smarves_basket_obligation_prendre(text, text, integer), public.smarves_basket_obligation_rendre(text, text, integer),
  public.smarves_basket_encherir(text, integer, integer, text, text, text, bigint), public.smarves_basket_liberer(text, integer, integer, text, text),
  public.smarves_basket_consigne(text, integer, integer, text, text), public.smarves_basket_bureau(text, integer) to anon, authenticated;
