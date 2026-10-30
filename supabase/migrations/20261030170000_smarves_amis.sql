-- Les amis et le mot laissé à la mairie (docs/AMIS.md, 30 octobre 2026).
--
-- Deux habitants qui se sont croisés de près au village (deux jours différents sur trois mois), ou qui se
-- sont écrit chacun un mot, sont amis. Un ami peut recevoir un mot à la mairie, même sans maison : un par
-- ami et par jour, relevé au panneau de n'importe quelle mairie (il suit la personne, pas le lieu). Un
-- rendez-vous écrit dans le mot (« vendredi vers 11 h 15 ») est relevé et rappelé aux deux.

create table if not exists smarves.rencontres (
  a text not null references smarves.joueurs (pyramide_id) on delete cascade,
  b text not null references smarves.joueurs (pyramide_id) on delete cascade,
  jour date not null,
  n integer not null default 1,
  maj timestamptz not null default now(),
  primary key (a, b, jour),
  check (a < b)
);
create index if not exists rencontres_b on smarves.rencontres (b, jour desc);
alter table smarves.rencontres enable row level security;

alter table smarves.mots add column if not exists rdv timestamptz;
create index if not exists mots_rdv on smarves.mots (rdv) where rdv is not null;

-- Deux habitants se sont croisés de près : une ligne par paire et par jour (un de plus toutes les dix minutes).
create or replace function smarves.rencontrer(p_a text, p_b text) returns void
  language plpgsql security definer set search_path = ''
as $$
begin
  if p_a is null or p_b is null or p_a = p_b then return; end if;
  if not exists (select 1 from smarves.joueurs where pyramide_id = p_a)
     or not exists (select 1 from smarves.joueurs where pyramide_id = p_b) then return; end if;
  insert into smarves.rencontres as r (a, b, jour) values (least(p_a, p_b), greatest(p_a, p_b), (now() at time zone 'Europe/Paris')::date)
    on conflict (a, b, jour) do update set n = r.n + 1, maj = now() where r.maj < now() - interval '10 minutes';
end $$;

-- Un habitant par ce que le jeu voit de lui : son compte, sinon son membre de présence (un joueur) ou
-- celui de son corps (un pensionnaire tenu par le serveur).
create or replace function smarves.habitant_de(p_qui text) returns text
  language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select pyramide_id from smarves.joueurs where pyramide_id = p_qui),
    (select pyramide_id from smarves.presences where membre = p_qui order by vu desc limit 1),
    (select doublure from smarves.doublure_corps where membre = p_qui limit 1));
$$;

-- Le joueur a passé un moment tout près d'un autre habitant : le jeu le dit.
create or replace function public.smarves_rencontrer(p_jeton text, p_autre text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  autre text;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_autre is null or length(p_autre) > 80 then return json_build_object('ok', false, 'raison', 'inconnu'); end if;
  autre := smarves.habitant_de(p_autre);
  if autre is null then return json_build_object('ok', false, 'raison', 'inconnu'); end if;
  perform smarves.rencontrer(moi, autre);
  return json_build_object('ok', true);
end $$;

-- Les amis d'un habitant : croisés de près deux jours différents sur trois mois, ou un mot dans chaque sens.
create or replace function smarves.amis(p_id text) returns table (autre text, nom text, jours integer, dernier timestamptz)
  language sql stable security definer set search_path = ''
as $$
  with croises as (
    select case when r.a = p_id then r.b else r.a end as autre, count(distinct r.jour)::int as jours, max(r.maj) as dernier
    from smarves.rencontres r where (r.a = p_id or r.b = p_id) and r.jour > (now() at time zone 'Europe/Paris')::date - 90 group by 1),
  ecrits as (
    select m.pour as autre from smarves.mots m where m.de = p_id and m.cree > now() - interval '90 days'
    intersect
    select m.de from smarves.mots m where m.pour = p_id and m.cree > now() - interval '90 days'),
  tous as (
    select c.autre, c.jours, c.dernier from croises c where c.jours >= 2
    union
    select e.autre, coalesce(c.jours, 0), c.dernier from ecrits e left join croises c using (autre))
  select t.autre, j.nom, max(t.jours)::int as jours, max(t.dernier) as dernier
  from tous t join smarves.joueurs j on j.pyramide_id = t.autre
  group by t.autre, j.nom order by max(t.dernier) desc nulls last, j.nom;
$$;

-- Le rendez-vous écrit dans un mot, à l'heure de Paris : un jour (lundi… dimanche, demain, aujourd'hui, ce
-- soir ; sans jour, la prochaine fois que l'heure vient) et une heure (« 11 h 15 », « 18h », « 9:30 »). Nul sans heure.
create or replace function smarves.rendez_vous(p_texte text, p_depuis timestamptz default now()) returns timestamptz
  language plpgsql stable set search_path = ''
as $$
declare
  t text := lower(coalesce(p_texte, ''));
  jours text[] := array['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
  ici timestamp := p_depuis at time zone 'Europe/Paris';
  m text[];
  h integer;
  mn integer;
  jour date := ici::date;
  voulu integer := null;
  cible timestamp;
begin
  m := regexp_match(t, '(^|[^0-9])(\d{1,2})\s*(?:h|:)\s*(\d{2})?([^0-9]|$)');
  if m is null then return null; end if;
  h := m[2]::integer;
  mn := coalesce(nullif(m[3], ''), '0')::integer;
  if h > 23 or mn > 59 then return null; end if;
  for i in 1..7 loop
    if position(jours[i] in t) > 0 then voulu := i - 1; exit; end if;
  end loop;
  if voulu is not null then
    jour := jour + ((voulu - extract(dow from jour)::integer + 7) % 7);
    cible := jour + make_interval(hours => h, mins => mn);
    if cible <= ici then cible := cible + interval '7 days'; end if;
  elsif position('demain' in t) > 0 then
    cible := (jour + 1) + make_interval(hours => h, mins => mn);
  else
    cible := jour + make_interval(hours => h, mins => mn);
    if cible <= ici then cible := cible + interval '1 day'; end if;
  end if;
  return cible at time zone 'Europe/Paris';
end $$;

-- Un mot : à la porte d'une maison que l'autre possède, ou à la mairie pour un ami (un par ami et par jour).
create or replace function smarves.mot_poser(p_de text, p_pour text, p_lot text, p_texte text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  t text := smarves.texte(p_texte, 200);
  rv timestamptz;
begin
  if t is null then return json_build_object('ok', false, 'raison', 'texte'); end if;
  if p_pour = p_de then return json_build_object('ok', false, 'raison', 'soi'); end if;
  if p_lot = 'mairie' then
    if not exists (select 1 from smarves.amis(p_de) where autre = p_pour) then
      return json_build_object('ok', false, 'raison', 'ami');
    end if;
    if exists (select 1 from smarves.mots where de = p_de and pour = p_pour and lot = 'mairie' and cree > now() - interval '20 hours') then
      return json_build_object('ok', false, 'raison', 'jour');
    end if;
  elsif not exists (select 1 from smarves.vitrines v, jsonb_array_elements(v.logements) l
                    where v.pyramide_id = p_pour and l->>'lot' = p_lot) then
    return json_build_object('ok', false, 'raison', 'porte');
  end if;
  if (select count(*) from smarves.mots where de = p_de and cree > now() - interval '1 hour') >= 3 then
    return json_build_object('ok', false, 'raison', 'heure');
  end if;
  rv := smarves.rendez_vous(t);
  insert into smarves.mots (lot, pour, de, texte, rdv) values (p_lot, p_pour, p_de, t, rv);
  return json_build_object('ok', true, 'rdv', extract(epoch from rv)::bigint);
end $$;

create or replace function public.smarves_mot_laisser(p_jeton text, p_pour text, p_lot text, p_texte text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  return smarves.mot_poser(moi, p_pour, p_lot, p_texte);
end $$;

create or replace function smarves.doublure_mot(p_id text, p_pour text, p_lot text, p_texte text) returns json
  language plpgsql security definer set search_path = ''
as $$
begin
  if not exists (select 1 from smarves.doublures where id = p_id and actif) then return json_build_object('ok', false, 'raison', 'doublure'); end if;
  return smarves.mot_poser(p_id, p_pour, p_lot, p_texte);
end $$;

-- Les rendez-vous à venir d'un habitant (ceux qu'il a proposés et ceux qu'on lui a proposés), deux semaines.
create or replace function smarves.rendez_vous_de(p_id text) returns table (avec text, nom text, de_moi boolean, quand timestamptz, texte text)
  language sql stable security definer set search_path = ''
as $$
  select case when m.de = p_id then m.pour else m.de end as avec, j.nom, m.de = p_id as de_moi, m.rdv as quand, m.texte
  from smarves.mots m join smarves.joueurs j on j.pyramide_id = case when m.de = p_id then m.pour else m.de end
  where (m.de = p_id or m.pour = p_id) and m.rdv is not null and m.rdv > now() - interval '1 hour' and m.rdv < now() + interval '14 days'
  order by m.rdv limit 12;
$$;

-- Tout le voisinage en un appel. Sans jeton (ou avec un jeton périmé), la part commune ; avec, aussi
-- l'identifiant du joueur, les mots de son livre d'or et de la mairie, ses amis et ses rendez-vous.
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
        select j.nom, m.lot, m.texte, extract(epoch from m.cree)::bigint as quand, extract(epoch from m.rdv)::bigint as rdv
        from smarves.mots m join smarves.joueurs j on j.pyramide_id = m.de
        where m.pour = moi order by m.cree desc limit 30) x), '[]') end,
    'amis', case when moi is null then '[]'::json else coalesce((select json_agg(x) from (
        select a.autre as id, a.nom, a.jours, extract(epoch from a.dernier)::bigint as dernier,
          extract(epoch from (select max(p.vu) from smarves.passages p where p.pyramide_id = a.autre))::bigint as vu
        from smarves.amis(moi) a limit 30) x), '[]') end,
    'rendez_vous', case when moi is null then '[]'::json else coalesce((select json_agg(x) from (
        select r.avec as id, r.nom, r.de_moi, extract(epoch from r.quand)::bigint as quand, r.texte from smarves.rendez_vous_de(moi) r) x), '[]') end
  );
end $$;

revoke all on function public.smarves_rencontrer(text, text) from public;
grant execute on function public.smarves_rencontrer(text, text) to anon, authenticated;
