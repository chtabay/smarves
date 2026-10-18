-- Smarves, le marché des transferts (le championnat de football, docs/SUITE.md section 6, « le mercato ») :
-- un marché à la Hattrick, ouvert toute l'année, commun à tous les villages.
--
-- Chaque dimanche à 17 h, le jeu met en vente seize nouveaux joueurs, les mêmes partout (lot « s<semaine>-<rang> »,
-- la semaine 1 commençant le 25 octobre 2026) ; chacun part aux enchères jusqu'à sa date limite, du lundi au
-- samedi entre 19 h et 22 h. Un club peut aussi remettre en vente un joueur acheté au marché (lot « v<id> »).
-- Le plus offrant l'emporte ; les clubs invités, que le jeu fait enchérir avec un plafond tiré de la graine du
-- lot, sont départagés dans le jeu, de la même façon partout. Les crédits se paient dans le jeu : ces tables
-- ne servent qu'à départager et à partager les offres, les ventes et les dates limites.
--
-- Qui dirige un club : smarves.dirige, aujourd'hui le premier porteur de parts (smarves.parts) ; la direction
-- des clubs n'a qu'à redéfinir cette fonction pour que le marché la suive.

create table if not exists smarves.mercato_ventes (
  id bigint generated always as identity primary key,
  club text not null,
  joueur text not null,
  saison integer not null,
  prix_depart bigint not null check (prix_depart >= 10),
  echeance timestamptz not null,
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  cree timestamptz not null default now()
);

create table if not exists smarves.mercato_encheres (
  id bigint generated always as identity primary key,
  lot text not null,
  club text not null,
  montant bigint not null check (montant > 0),
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  quand timestamptz not null default now()
);

create index if not exists mercato_encheres_lot on smarves.mercato_encheres (lot, montant desc);
create index if not exists mercato_ventes_joueur on smarves.mercato_ventes (joueur, echeance desc);

-- Les dates limites repoussées par une offre de dernière minute (lots de la semaine ; une vente garde la sienne).
create table if not exists smarves.mercato_prolongations (
  lot text primary key,
  echeance timestamptz not null
);

alter table smarves.mercato_ventes enable row level security;
alter table smarves.mercato_encheres enable row level security;
alter table smarves.mercato_prolongations enable row level security;

-- Le joueur p_joueur parle-t-il pour le club : sans actionnaire, tout le monde ; sinon le plus gros (à égalité, chacun).
create or replace function smarves.dirige(p_club text, p_joueur text) returns boolean
  language sql stable set search_path = ''
as $$
  select coalesce((select nombre from smarves.parts where club = p_club and pyramide_id = p_joueur), 0)
      >= coalesce((select max(nombre) from smarves.parts where club = p_club), 0)
$$;

-- L'ouverture des lots de la semaine k (le dimanche à 17 h, heure de Paris) et la date limite du lot i :
-- les mêmes calculs que scripts/socle/mercato/mercato.gd (debut_semaine, echeance_lot).
create or replace function smarves.mercato_ouverture(k integer) returns timestamptz
  language sql immutable set search_path = ''
as $$
  select (timestamp '2026-10-25 17:00:00' + make_interval(weeks => k - 1)) at time zone 'Europe/Paris'
$$;

create or replace function smarves.mercato_echeance(k integer, i integer) returns timestamptz
  language sql immutable set search_path = ''
as $$
  select (timestamp '2026-10-25 15:00:00' + make_interval(weeks => k - 1, days => 1 + (i * 6) / 16, hours => 4 + i % 4)) at time zone 'Europe/Paris'
$$;

create or replace function smarves.heure_paris(t timestamptz) returns text
  language sql stable set search_path = ''
as $$
  select to_char(t at time zone 'Europe/Paris', 'YYYY-MM-DD HH24:MI:SS')
$$;

revoke all on all functions in schema smarves from public;

-- Enchérir p_montant crédits sur le lot p_lot pour p_club : {ok: true, echeance} (la date limite, repoussée de
-- trois minutes par une offre de dernière minute), {ok: false, raison} avec raison « inconnu », « ferme »,
-- « parts » (un autre parle pour le club), « vendeur » (sa propre vente), « bas » (sous la meilleure offre plus
-- 2 %, au moins 10 crédits, ou sous le prix de départ d'une vente) ; {erreur: 'jeton'} sans compte.
create or replace function public.smarves_mercato_encherir(p_jeton text, p_lot text, p_club text, p_montant bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  k integer;
  i integer;
  v smarves.mercato_ventes;
  ouverture timestamptz;
  fin timestamptz;
  depart bigint := 1;
  meilleure bigint;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_montant is null or p_montant not between 1 and 1000000000000 then raise exception 'montant invalide'; end if;
  if p_lot ~ '^s[0-9]{1,5}-[0-9]{1,2}$' then
    k := split_part(substr(p_lot, 2), '-', 1)::integer;
    i := split_part(p_lot, '-', 2)::integer;
    if i >= 16 then return json_build_object('ok', false, 'raison', 'inconnu'); end if;
    ouverture := smarves.mercato_ouverture(k);
    fin := coalesce((select echeance from smarves.mercato_prolongations where lot = p_lot), smarves.mercato_echeance(k, i));
  elsif p_lot ~ '^v[0-9]{1,18}$' then
    select * into v from smarves.mercato_ventes where id = substr(p_lot, 2)::bigint;
    if not found then return json_build_object('ok', false, 'raison', 'inconnu'); end if;
    if v.club = p_club then return json_build_object('ok', false, 'raison', 'vendeur'); end if;
    ouverture := v.cree;
    fin := v.echeance;
    depart := v.prix_depart;
  else
    return json_build_object('ok', false, 'raison', 'inconnu');
  end if;
  if now() < ouverture or now() >= fin then return json_build_object('ok', false, 'raison', 'ferme'); end if;
  if not smarves.dirige(p_club, moi) then return json_build_object('ok', false, 'raison', 'parts'); end if;
  -- Une offre à la fois par lot : la meilleure se lit et s'écrit sans qu'une autre s'intercale.
  perform pg_advisory_xact_lock(hashtext('smarves/mercato/' || p_lot));
  select max(montant) into meilleure from smarves.mercato_encheres where lot = p_lot and montant >= depart;
  if p_montant < depart or (meilleure is not null and p_montant < meilleure + greatest(10, ((meilleure + 499) / 500) * 10)) then
    return json_build_object('ok', false, 'raison', 'bas');
  end if;
  insert into smarves.mercato_encheres (lot, club, montant, pyramide_id) values (p_lot, p_club, p_montant, moi);
  if fin - now() < interval '3 minutes' then
    fin := now() + interval '3 minutes';
    if v.id is null then
      insert into smarves.mercato_prolongations (lot, echeance) values (p_lot, fin)
        on conflict (lot) do update set echeance = excluded.echeance;
    else
      update smarves.mercato_ventes set echeance = fin where id = v.id;
    end if;
  end if;
  return json_build_object('ok', true, 'echeance', smarves.heure_paris(fin));
end $$;

-- Mettre en vente un joueur acheté au marché (son lot d'arrivée, « s<semaine>-<rang> ») : prix de départ libre,
-- date limite dans p_jours jours (1, 3 ou 7) à 21 h. {ok: true, id, echeance, cree}, {ok: false, raison} avec
-- « parts » ou « deja » (une vente de ce joueur est ouverte). Le jeu ne tient compte que des ventes d'un club
-- qui possédait le joueur quand il l'a mis en vente.
create or replace function public.smarves_mercato_vendre(p_jeton text, p_club text, p_joueur text, p_prix bigint, p_jours integer, p_saison integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  v smarves.mercato_ventes;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_club is null or p_club !~ '^[a-z0-9_]{1,40}$' then raise exception 'club invalide'; end if;
  if p_joueur is null or p_joueur !~ '^s[0-9]{1,5}-[0-9]{1,2}$' then raise exception 'joueur invalide'; end if;
  if p_prix is null or p_prix not between 10 and 1000000000000 then raise exception 'prix invalide'; end if;
  if p_jours is null or p_jours not in (1, 3, 7) then raise exception 'durée invalide'; end if;
  if p_saison is null or p_saison not between 1 and 1000 then raise exception 'saison invalide'; end if;
  if not smarves.dirige(p_club, moi) then return json_build_object('ok', false, 'raison', 'parts'); end if;
  perform pg_advisory_xact_lock(hashtext('smarves/mercato/' || p_joueur));
  if exists (select 1 from smarves.mercato_ventes where joueur = p_joueur and echeance > now()) then
    return json_build_object('ok', false, 'raison', 'deja');
  end if;
  insert into smarves.mercato_ventes (club, joueur, saison, prix_depart, echeance, pyramide_id)
    values (p_club, p_joueur, p_saison, p_prix,
      (date_trunc('day', now() at time zone 'Europe/Paris') + make_interval(days => p_jours, hours => 21)) at time zone 'Europe/Paris', moi)
    returning * into v;
  return json_build_object('ok', true, 'id', v.id, 'echeance', smarves.heure_paris(v.echeance), 'cree', smarves.heure_paris(v.cree));
end $$;

-- Le marché, public comme le championnat : {encheres: [{lot, club, montant, par, moi, quand}], ventes: [{id, club,
-- joueur, saison, prix_depart, echeance, cree, par, moi}], prolongations: [{lot, echeance}], maintenant}, les
-- heures à l'horloge de Paris ; « moi » dit ce qui vient du joueur du jeton.
create or replace function public.smarves_mercato(p_jeton text default null) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  return json_build_object(
    'encheres', coalesce((select json_agg(x) from (
        select e.lot, e.club, e.montant, j.nom as par, (e.pyramide_id = moi) is true as moi,
          to_char(e.quand at time zone 'Europe/Paris', 'YYYY-MM-DD HH24:MI:SS.MS') as quand
        from smarves.mercato_encheres e join smarves.joueurs j using (pyramide_id)
        order by e.id) x), '[]'::json),
    'ventes', coalesce((select json_agg(x) from (
        select v.id, v.club, v.joueur, v.saison, v.prix_depart, smarves.heure_paris(v.echeance) as echeance,
          smarves.heure_paris(v.cree) as cree, j.nom as par, (v.pyramide_id = moi) is true as moi
        from smarves.mercato_ventes v join smarves.joueurs j using (pyramide_id)
        order by v.id) x), '[]'::json),
    'prolongations', coalesce((select json_agg(x) from (
        select p.lot, smarves.heure_paris(p.echeance) as echeance from smarves.mercato_prolongations p order by p.lot) x), '[]'::json),
    'maintenant', smarves.heure_paris(now()));
end $$;

revoke all on function public.smarves_mercato_encherir(text, text, text, bigint), public.smarves_mercato_vendre(text, text, text, bigint, integer, integer),
  public.smarves_mercato(text) from public;
grant execute on function public.smarves_mercato_encherir(text, text, text, bigint), public.smarves_mercato_vendre(text, text, text, bigint, integer, integer),
  public.smarves_mercato(text) to anon, authenticated;
