-- Smarves, la bourse (docs/BOURSE.md) : la charge d'agent de change de Mme Vasseur, rue du Clain. On y
-- prend position sur quatre valeurs réelles (CAC 40, S&P 500, Nikkei 225, l'or) avec de très gros leviers.
--
-- Les cours sont ceux des vraies places, en clôture quotidienne. La base les relève elle-même (pg_net
-- vers Yahoo Finance, toutes les quinze minutes par pg_cron) et les garde ici : tout le monde voit les
-- mêmes. Un ordre est exécuté à la clôture suivante de sa place, celle qui suit l'heure du serveur où il
-- a été passé : personne ne connaît son prix en passant l'ordre.
--
-- Une position : une marge, un levier, un sens. L'exposition (marge × levier) est fixée à l'ouverture.
-- À chaque clôture, valeur = garantie + exposition × sens × (cours / cours d'entrée − 1)
--                            − exposition × 0,02 % × nuits depuis l'entrée,
-- la garantie étant la marge plus les renforts versés avant cette clôture. Sous la moitié de la garantie,
-- c'est l'appel de marge ; à 20 % ou moins, la position est soldée à cette clôture (liquidée), et ce
-- qui reste revient au joueur, jamais moins que zéro : pas de dette.
--
-- Comme pour les parts du football, les crédits sont ceux de la sauvegarde : le jeu débite la marge et
-- le courtage avant d'ouvrir, et crédite ce que rend une position soldée, une seule fois (encaisser).

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

-- --- Les valeurs et leurs cours --------------------------------------------------------------------

create table if not exists smarves.indices (
  id text primary key,
  nom text not null,
  place text not null,
  symbole text not null,
  fuseau text not null,
  cloture time not null,
  rang integer not null
);

insert into smarves.indices (id, nom, place, symbole, fuseau, cloture, rang) values
  ('cac40', 'CAC 40', 'Paris', '^FCHI', 'Europe/Paris', '17:35', 1),
  ('sp500', 'S&P 500', 'New York', '^GSPC', 'America/New_York', '16:00', 2),
  ('nikkei', 'Nikkei 225', 'Tokyo', '^N225', 'Asia/Tokyo', '15:30', 3),
  ('or', 'L''or', 'New York', 'GC=F', 'America/New_York', '17:00', 4)
on conflict (id) do update set nom = excluded.nom, place = excluded.place, symbole = excluded.symbole,
  fuseau = excluded.fuseau, cloture = excluded.cloture, rang = excluded.rang;

create table if not exists smarves.cours (
  indice text not null references smarves.indices (id),
  jour date not null,
  cloture numeric(14, 4) not null check (cloture > 0),
  clos_a timestamptz not null,
  releve timestamptz not null default now(),
  primary key (indice, jour)
);

create index if not exists cours_clos_a on smarves.cours (indice, clos_a);

-- Les demandes de relevé en vol (l'identifiant de pg_net), lues au passage suivant.
create table if not exists smarves.releves (
  id bigint primary key,
  indice text not null references smarves.indices (id),
  demande timestamptz not null default now()
);

alter table smarves.indices enable row level security;
alter table smarves.cours enable row level security;
alter table smarves.releves enable row level security;

-- L'heure de clôture d'une place pour un jour donné.
create or replace function smarves.bourse_clos_a(p_indice text, p_jour date) returns timestamptz
  language sql stable set search_path = ''
as $$ select (p_jour + i.cloture) at time zone i.fuseau from smarves.indices i where i.id = p_indice $$;

-- La première clôture ouvrée d'une place après un instant (les fériés ne sont pas connus : un jour sans
-- cours renvoie simplement l'ordre à la séance suivante).
create or replace function smarves.bourse_prochaine(p_indice text, p_apres timestamptz) returns timestamptz
  language plpgsql stable set search_path = ''
as $$
declare
  i record;
  d date;
  t timestamptz;
begin
  select * into i from smarves.indices where id = p_indice;
  if not found then return null; end if;
  d := (p_apres at time zone i.fuseau)::date;
  for k in 0..10 loop
    if extract(isodow from d + k) < 6 then
      t := ((d + k) + i.cloture) at time zone i.fuseau;
      if t > p_apres then return t; end if;
    end if;
  end loop;
  return null;
end $$;

-- La dernière clôture ouvrée passée (vingt minutes de battement) : celle qu'on attend dans les cours.
create or replace function smarves.bourse_attendue(p_indice text) returns date
  language plpgsql stable set search_path = ''
as $$
declare
  i record;
  d date;
begin
  select * into i from smarves.indices where id = p_indice;
  d := ((now() - interval '20 minutes') at time zone i.fuseau)::date;
  for k in 0..10 loop
    if extract(isodow from d - k) < 6 and ((d - k) + i.cloture) at time zone i.fuseau <= now() - interval '20 minutes' then
      return d - k;
    end if;
  end loop;
  return null;
end $$;

-- Range une réponse de Yahoo Finance (/v8/finance/chart, intervalle d'un jour) : chaque barre dont la
-- clôture est passée, datée dans le fuseau de la place. La barre du jour en cours est laissée.
create or replace function smarves.bourse_ranger(p_indice text, p_corps text) returns integer
  language plpgsql set search_path = ''
as $$
declare
  i record;
  r jsonb;
  ts jsonb;
  cl jsonb;
  n integer := 0;
  j date;
  a timestamptz;
begin
  select * into i from smarves.indices where id = p_indice;
  begin
    r := p_corps::jsonb -> 'chart' -> 'result' -> 0;
  exception when others then return 0;
  end;
  ts := r -> 'timestamp';
  cl := r -> 'indicators' -> 'quote' -> 0 -> 'close';
  if jsonb_typeof(ts) is distinct from 'array' or jsonb_typeof(cl) is distinct from 'array' then return 0; end if;
  for k in 0 .. jsonb_array_length(ts) - 1 loop
    continue when jsonb_typeof(cl -> k) is distinct from 'number' or (cl ->> k)::numeric <= 0;
    j := (to_timestamp((ts ->> k)::double precision) at time zone i.fuseau)::date;
    a := (j + i.cloture) at time zone i.fuseau;
    continue when a > now() - interval '10 minutes';
    insert into smarves.cours as c (indice, jour, cloture, clos_a) values (p_indice, j, round((cl ->> k)::numeric, 4), a)
      on conflict (indice, jour) do update set cloture = excluded.cloture, releve = now()
      where c.cloture is distinct from excluded.cloture;
    n := n + 1;
  end loop;
  return n;
end $$;

-- Le relevé, toutes les quinze minutes : ranger les réponses arrivées, puis redemander les places dont
-- la dernière clôture manque (au plus douze heures après elle ; trois mois d'historique la première fois).
create or replace function smarves.bourse_relever() returns void
  language plpgsql security definer set search_path = ''
as $$
declare
  d record;
  i record;
  attendue date;
  url text;
  rid bigint;
begin
  for d in select r.id, r.indice, h.status_code, h.content from smarves.releves r
      join net._http_response h on h.id = r.id loop
    if d.status_code = 200 then
      perform smarves.bourse_ranger(d.indice, d.content);
    end if;
    delete from smarves.releves where id = d.id;
  end loop;
  delete from smarves.releves where demande < now() - interval '1 hour';
  for i in select * from smarves.indices order by rang loop
    continue when exists (select 1 from smarves.releves where indice = i.id);
    attendue := smarves.bourse_attendue(i.id);
    continue when exists (select 1 from smarves.cours where indice = i.id and jour >= attendue);
    continue when exists (select 1 from smarves.cours where indice = i.id)
      and smarves.bourse_clos_a(i.id, attendue) < now() - interval '12 hours';
    url := 'https://query1.finance.yahoo.com/v8/finance/chart/' || replace(replace(i.symbole, '^', '%5E'), '=', '%3D')
      || '?interval=1d&range=' || case when exists (select 1 from smarves.cours where indice = i.id) then '1mo' else '3mo' end;
    rid := net.http_get(url := url, headers := '{"User-Agent": "Mozilla/5.0 (Smarves)"}'::jsonb, timeout_milliseconds := 10000);
    insert into smarves.releves (id, indice) values (rid, i.id);
  end loop;
end $$;

-- --- Les positions ---------------------------------------------------------------------------------

create table if not exists smarves.positions (
  id bigserial primary key,
  pyramide_id text not null references smarves.joueurs (pyramide_id) on delete cascade,
  indice text not null references smarves.indices (id),
  sens smallint not null check (sens in (-1, 1)),
  levier integer not null check (levier in (10, 25, 50, 100)),
  marge integer not null check (marge between 100 and 1000000),
  ordre_a timestamptz not null default now(),
  entree_jour date,
  entree numeric(14, 4),
  solde_a timestamptz,
  sortie_jour date,
  sortie numeric(14, 4),
  -- « soldee » (à la demande du joueur), « liquidee » (sous 20 % de la garantie), « annulee » (avant
  -- l'exécution de l'ordre : tout est rendu).
  issue text check (issue in ('soldee', 'liquidee', 'annulee')),
  rendu integer,
  encaisse boolean not null default false
);

create index if not exists positions_joueur on smarves.positions (pyramide_id, issue);

create table if not exists smarves.renforts (
  position_id bigint not null references smarves.positions (id) on delete cascade,
  montant integer not null check (montant between 10 and 1000000),
  verse timestamptz not null default now()
);

create index if not exists renforts_position on smarves.renforts (position_id);

alter table smarves.positions enable row level security;
alter table smarves.renforts enable row level security;

-- La garantie d'une position à un instant : la marge et les renforts versés avant.
create or replace function smarves.bourse_garantie(p_id bigint, p_a timestamptz) returns integer
  language sql stable set search_path = ''
as $$
  select p.marge + coalesce((select sum(montant)::integer from smarves.renforts where position_id = p_id and verse < p_a), 0)
  from smarves.positions p where p.id = p_id
$$;

-- La valeur d'une position à une clôture (cours et jour de cette clôture).
create or replace function smarves.bourse_valeur(p smarves.positions, p_cours numeric, p_jour date, p_garantie integer) returns numeric
  language sql immutable set search_path = ''
as $$
  select p_garantie + (p.marge::numeric * p.levier) * p.sens * (p_cours / p.entree - 1)
    - (p.marge::numeric * p.levier) * 0.0002 * (p_jour - p.entree_jour)
$$;

-- Fait avancer une position jusqu'aux derniers cours connus : l'exécution de l'ordre, puis, clôture
-- après clôture, la liquidation ou le solde demandé. Tout ne dépend que des cours et des heures du
-- serveur : rejouée cent fois, elle aboutit au même endroit.
create or replace function smarves.bourse_suivre(p_id bigint) returns void
  language plpgsql set search_path = ''
as $$
declare
  p smarves.positions;
  c record;
  g integer;
  v numeric;
begin
  select * into p from smarves.positions where id = p_id for update;
  if not found or p.issue is not null then return; end if;
  if p.entree is null then
    select jour, cloture into c from smarves.cours where indice = p.indice and clos_a > p.ordre_a order by clos_a limit 1;
    if not found then return; end if;
    update smarves.positions set entree_jour = c.jour, entree = c.cloture where id = p_id returning * into p;
  end if;
  for c in select jour, cloture, clos_a from smarves.cours where indice = p.indice and jour > p.entree_jour order by jour loop
    g := smarves.bourse_garantie(p_id, c.clos_a);
    v := smarves.bourse_valeur(p, c.cloture, c.jour, g);
    if (p.solde_a is not null and c.clos_a > p.solde_a) or v <= 0.2 * g then
      -- Un renfort versé après cette clôture (le cours n'était pas encore relevé) est rendu tel quel.
      update smarves.positions set sortie_jour = c.jour, sortie = c.cloture,
        issue = case when p.solde_a is not null and c.clos_a > p.solde_a then 'soldee' else 'liquidee' end,
        rendu = greatest(0, round(v))::integer + smarves.bourse_garantie(p_id, 'infinity') - g where id = p_id;
      return;
    end if;
  end loop;
end $$;

-- Une position telle que le jeu l'affiche.
create or replace function smarves.bourse_json(p_id bigint) returns json
  language plpgsql stable set search_path = ''
as $$
declare
  p smarves.positions;
  c record;
  g integer;
  v numeric;
begin
  select * into p from smarves.positions where id = p_id;
  g := smarves.bourse_garantie(p_id, 'infinity');
  if p.entree is not null and p.issue is null then
    select jour, cloture into c from smarves.cours where indice = p.indice order by jour desc limit 1;
    -- Ce que vaudrait la position si l'on soldait au dernier cours, renforts compris.
    v := smarves.bourse_valeur(p, c.cloture, c.jour, g);
  end if;
  return json_build_object('id', p.id, 'indice', p.indice, 'sens', p.sens, 'levier', p.levier, 'marge', p.marge,
    'garantie', g, 'ordre_a', extract(epoch from p.ordre_a)::bigint, 'entree_jour', p.entree_jour, 'entree', p.entree,
    'solde_a', extract(epoch from p.solde_a)::bigint, 'sortie_jour', p.sortie_jour, 'sortie', p.sortie,
    'issue', p.issue, 'rendu', p.rendu, 'encaisse', p.encaisse, 'valeur', round(v)::integer,
    -- L'heure où l'ordre en cours (ouvrir ou solder) sera exécuté, s'il y en a un.
    'execution', extract(epoch from case when p.issue is not null then null when p.entree is null then smarves.bourse_prochaine(p.indice, p.ordre_a)
      when p.solde_a is not null then smarves.bourse_prochaine(p.indice, p.solde_a) end)::bigint);
end $$;

revoke all on all functions in schema smarves from public;

-- --- Ce que le jeu appelle -------------------------------------------------------------------------

-- La cote et, avec un jeton, les positions du joueur : {maintenant, indices: [{id, nom, place, cours:
-- [[jour, cloture], …] (soixante dernières séances), prochaine}], positions: […] ou null sans compte}.
create or replace function public.smarves_bourse(p_jeton text default null) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  x record;
begin
  if moi is not null then
    for x in select id from smarves.positions where pyramide_id = moi and issue is null loop
      perform smarves.bourse_suivre(x.id);
    end loop;
  end if;
  return json_build_object(
    'maintenant', extract(epoch from now())::bigint,
    'indices', (select json_agg(json_build_object('id', i.id, 'nom', i.nom, 'place', i.place,
        'prochaine', extract(epoch from smarves.bourse_prochaine(i.id, now()))::bigint,
        'cours', coalesce((select json_agg(json_build_array(k.jour, k.cloture) order by k.jour) from
            (select jour, cloture from smarves.cours where indice = i.id order by jour desc limit 60) k), '[]'::json))
      order by i.rang) from smarves.indices i),
    'positions', case when moi is null then null else coalesce((select json_agg(smarves.bourse_json(y.id) order by y.id desc) from
        (select id from smarves.positions where pyramide_id = moi and (not encaisse or sortie_jour > current_date - 30)
          order by id desc limit 30) y), '[]'::json) end);
end $$;

-- Passer un ordre : {ok: true, position} ; {ok: false, raison: 'plein'} à huit positions ouvertes ;
-- {erreur: 'jeton'} sans compte. Le jeu a déjà débité la marge et le courtage, et les rend sur un refus.
create or replace function public.smarves_bourse_ouvrir(p_jeton text, p_indice text, p_sens integer, p_levier integer, p_marge integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  nid bigint;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if not exists (select 1 from smarves.indices where id = p_indice) then raise exception 'valeur inconnue'; end if;
  if p_sens is null or p_sens not in (-1, 1) then raise exception 'sens invalide'; end if;
  if p_levier is null or p_levier not in (10, 25, 50, 100) then raise exception 'levier invalide'; end if;
  if p_marge is null or p_marge not between 100 and 1000000 then raise exception 'marge invalide'; end if;
  if (select count(*) from smarves.positions where pyramide_id = moi and issue is null) >= 8 then
    return json_build_object('ok', false, 'raison', 'plein');
  end if;
  insert into smarves.positions (pyramide_id, indice, sens, levier, marge) values (moi, p_indice, p_sens, p_levier, p_marge)
    returning id into nid;
  return json_build_object('ok', true, 'position', smarves.bourse_json(nid));
end $$;

-- Renflouer une position ouverte : {ok: true, position} ; {ok: false, raison: 'close'} si elle est soldée.
create or replace function public.smarves_bourse_renflouer(p_jeton text, p_id bigint, p_montant integer) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_montant is null or p_montant not between 10 and 1000000 then raise exception 'montant invalide'; end if;
  if not exists (select 1 from smarves.positions where id = p_id and pyramide_id = moi) then raise exception 'position inconnue'; end if;
  perform smarves.bourse_suivre(p_id);
  if exists (select 1 from smarves.positions where id = p_id and (issue is not null or solde_a is not null)) then
    return json_build_object('ok', false, 'raison', 'close');
  end if;
  insert into smarves.renforts (position_id, montant) values (p_id, p_montant);
  return json_build_object('ok', true, 'position', smarves.bourse_json(p_id));
end $$;

-- Solder une position à la clôture suivante (ou l'annuler, tout rendu, si l'ordre n'est pas encore
-- exécuté) : {ok: true, position} ; {ok: false, raison: 'close'} si c'est déjà fait.
create or replace function public.smarves_bourse_solder(p_jeton text, p_id bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  p smarves.positions;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if not exists (select 1 from smarves.positions where id = p_id and pyramide_id = moi) then raise exception 'position inconnue'; end if;
  perform smarves.bourse_suivre(p_id);
  select * into p from smarves.positions where id = p_id for update;
  if p.issue is not null or p.solde_a is not null then return json_build_object('ok', false, 'raison', 'close'); end if;
  if p.entree is null then
    update smarves.positions set issue = 'annulee', solde_a = now(), rendu = smarves.bourse_garantie(p_id, 'infinity') where id = p_id;
  else
    update smarves.positions set solde_a = now() where id = p_id;
  end if;
  return json_build_object('ok', true, 'position', smarves.bourse_json(p_id));
end $$;

-- Encaisser ce que rend une position soldée, une seule fois pour tous les appareils : {ok: true, rendu,
-- garantie} (le jeu crédite rendu, et compte rendu − garantie dans le total gagné s'il est positif) ;
-- {ok: false, raison: 'ouverte' | 'deja'}.
create or replace function public.smarves_bourse_encaisser(p_jeton text, p_id bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  p smarves.positions;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  perform smarves.bourse_suivre(p_id);
  select * into p from smarves.positions where id = p_id and pyramide_id = moi for update;
  if not found then raise exception 'position inconnue'; end if;
  if p.issue is null then return json_build_object('ok', false, 'raison', 'ouverte'); end if;
  if p.encaisse then return json_build_object('ok', false, 'raison', 'deja'); end if;
  update smarves.positions set encaisse = true where id = p_id;
  return json_build_object('ok', true, 'rendu', p.rendu, 'garantie', smarves.bourse_garantie(p_id, 'infinity'));
end $$;

revoke all on function public.smarves_bourse(text), public.smarves_bourse_ouvrir(text, text, integer, integer, integer),
  public.smarves_bourse_renflouer(text, bigint, integer), public.smarves_bourse_solder(text, bigint),
  public.smarves_bourse_encaisser(text, bigint) from public;
grant execute on function public.smarves_bourse(text), public.smarves_bourse_ouvrir(text, text, integer, integer, integer),
  public.smarves_bourse_renflouer(text, bigint, integer), public.smarves_bourse_solder(text, bigint),
  public.smarves_bourse_encaisser(text, bigint) to anon, authenticated;

-- Le relevé tourne tout seul ; un premier passage part tout de suite (trois mois d'historique).
select cron.schedule('smarves-bourse', '*/15 * * * *', 'select smarves.bourse_relever()');
select smarves.bourse_relever();
