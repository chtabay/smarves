-- Smarves, l'argent tenu par le serveur (docs/ARGENT.md) : un solde en crédits par joueur et le journal
-- de tous ses mouvements, d'où qu'ils viennent (le jeu, une commune, la caisse de Casino Minuit).
--
-- Le jeu garde ses crédits sur l'appareil et continue de jouer hors ligne. Avec un compte, il ouvre une
-- fois le solde du serveur avec ce qu'il a en poche (smarves_argent_ouvrir), puis il y envoie ce qui a
-- bougé, mouvement par mouvement, chacun avec une clé tirée par l'appareil : un mouvement rejoué (réponse
-- perdue, file d'attente reprise sur un autre appareil) n'est compté qu'une fois. Le serveur refuse tout
-- ce qui rendrait le solde négatif, et tient un plafond par jour pour les sources qui en ont un (le change
-- de Casino Minuit). En ligne, c'est son solde qui fait foi : le jeu s'y range.
--
-- Le journal ne se modifie jamais : on n'y fait qu'ajouter. Le solde est toujours la somme du journal.

-- --- Les tables ----------------------------------------------------------------------------------

create table if not exists smarves.argent_comptes (
  pyramide_id text primary key references smarves.joueurs (pyramide_id) on delete cascade,
  solde bigint not null check (solde >= 0),
  ouvert timestamptz not null default now(),
  maj timestamptz not null default now()
);

create table if not exists smarves.argent_mouvements (
  id bigint generated always as identity primary key,
  pyramide_id text not null references smarves.argent_comptes (pyramide_id) on delete cascade,
  -- La clé tirée par l'appareil : un même mouvement envoyé deux fois n'est écrit qu'une fois.
  cle text not null,
  -- D'où vient le mouvement : « smarves » (le jeu lui-même), l'identifiant d'une commune, « casino_minuit ».
  source text not null,
  -- Pourquoi : « ouverture », « jeu » (ce que les jeux de l'appareil ont fait bouger), « jetons », …
  motif text not null,
  montant bigint not null check (montant <> 0 or motif = 'ouverture'),
  solde_apres bigint not null check (solde_apres >= 0),
  quand timestamptz not null default now(),
  unique (pyramide_id, cle)
);

create index if not exists argent_mouvements_source on smarves.argent_mouvements (pyramide_id, source, quand);

-- Les plafonds par jour (heure de Paris) d'une source, dans chaque sens : entree, ce qui peut arriver sur
-- le solde ; sortie, ce qui peut en partir. Nul : pas de plafond. Se règle ici, sans nouvelle migration.
create table if not exists smarves.argent_plafonds (
  source text primary key,
  entree_jour bigint check (entree_jour >= 0),
  sortie_jour bigint check (sortie_jour >= 0)
);

-- Le change de Casino Minuit, un jeton pour un crédit en attendant sa doctrine : au plus 50 000 crédits
-- achetés en jetons et 50 000 revendus par jour.
insert into smarves.argent_plafonds (source, entree_jour, sortie_jour) values ('casino_minuit', 50000, 50000)
  on conflict (source) do nothing;

alter table smarves.argent_comptes enable row level security;
alter table smarves.argent_mouvements enable row level security;
alter table smarves.argent_plafonds enable row level security;

-- Le journal ne s'efface ni ne se récrit. Seul l'effacement d'un joueur (en cascade) l'emporte.
create or replace function smarves.argent_journal_fige() returns trigger
  language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 then return old; end if;
  raise exception 'le journal de l''argent ne se modifie pas';
end $$;

drop trigger if exists argent_journal_fige on smarves.argent_mouvements;
create trigger argent_journal_fige before update or delete on smarves.argent_mouvements
  for each row execute function smarves.argent_journal_fige();

-- --- Les pièces ----------------------------------------------------------------------------------

-- Le jour de Paris où tombe un instant, et son début.
create or replace function smarves.argent_debut_jour(p_a timestamptz) returns timestamptz
  language sql stable set search_path = ''
as $$ select date_trunc('day', p_a at time zone 'Europe/Paris') at time zone 'Europe/Paris' $$;

-- Ce qui reste d'aujourd'hui sous les plafonds d'une source : {entree, sortie}, nul s'il n'y en a pas.
create or replace function smarves.argent_reste(p_moi text, p_source text) returns json
  language plpgsql stable set search_path = ''
as $$
declare
  pl smarves.argent_plafonds;
  entre bigint;
  sort bigint;
begin
  select * into pl from smarves.argent_plafonds where source = p_source;
  if pl.source is null then return json_build_object('entree', null, 'sortie', null); end if;
  select coalesce(sum(montant) filter (where montant > 0), 0), coalesce(-sum(montant) filter (where montant < 0), 0)
    into entre, sort
    from smarves.argent_mouvements
    where pyramide_id = p_moi and source = p_source and quand >= smarves.argent_debut_jour(now());
  return json_build_object('entree', case when pl.entree_jour is null then null else greatest(0, pl.entree_jour - entre) end,
    'sortie', case when pl.sortie_jour is null then null else greatest(0, pl.sortie_jour - sort) end);
end $$;

revoke all on all functions in schema smarves from public;

-- --- Ce que le jeu appelle -----------------------------------------------------------------------

-- Le solde du joueur : {ouvert: true, solde, mouvements: [{source, motif, montant, solde_apres, quand}]
-- (les vingt derniers), change: {casino_minuit: {entree, sortie}}} ; {ouvert: false} sans solde ouvert ;
-- {erreur: 'jeton'} sans compte.
create or replace function public.smarves_argent(p_jeton text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  c smarves.argent_comptes;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  select * into c from smarves.argent_comptes where pyramide_id = moi;
  if c.pyramide_id is null then return json_build_object('ouvert', false); end if;
  return json_build_object('ouvert', true, 'solde', c.solde, 'maj', extract(epoch from c.maj)::bigint,
    'mouvements', coalesce((select json_agg(json_build_object('source', m.source, 'motif', m.motif, 'montant', m.montant,
        'solde_apres', m.solde_apres, 'quand', extract(epoch from m.quand)::bigint) order by m.id desc) from
        (select * from smarves.argent_mouvements where pyramide_id = moi order by id desc limit 20) m), '[]'::json),
    'change', (select json_object_agg(p.source, smarves.argent_reste(moi, p.source)) from smarves.argent_plafonds p));
end $$;

-- Ouvre le solde du joueur avec ce que l'appareil a en poche, une seule fois : {ok: true, cree: true,
-- solde} ; s'il est déjà ouvert (par un autre appareil), rien ne change et la réponse dit le solde du
-- serveur : {ok: true, cree: false, solde}. L'appareil s'y range.
create or replace function public.smarves_argent_ouvrir(p_jeton text, p_solde bigint, p_cle text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  s bigint;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_solde is null or p_solde not between 0 and 1000000000 then raise exception 'solde invalide'; end if;
  if p_cle is null or p_cle !~ '^[A-Za-z0-9_.:-]{8,80}$' then raise exception 'cle invalide'; end if;
  insert into smarves.argent_comptes (pyramide_id, solde) values (moi, p_solde)
    on conflict (pyramide_id) do nothing;
  if found then
    insert into smarves.argent_mouvements (pyramide_id, cle, source, motif, montant, solde_apres)
      values (moi, p_cle, 'smarves', 'ouverture', p_solde, p_solde);
    return json_build_object('ok', true, 'cree', true, 'solde', p_solde);
  end if;
  select solde into s from smarves.argent_comptes where pyramide_id = moi;
  return json_build_object('ok', true, 'cree', false, 'solde', s);
end $$;

-- Un mouvement sur le solde : montant positif, il arrive ; négatif, il part.
-- {ok: true, solde, id} ; déjà reçu sous cette clé : {ok: true, deja: true, solde, id} (rien ne bouge) ;
-- refusé : {ok: false, raison, solde}, raison étant 'compte' (solde pas encore ouvert), 'solde' (il
-- deviendrait négatif), 'plafond' (celui du jour de la source est atteint ; reste dit ce qui passe encore)
-- ou 'cle' (la clé a déjà servi pour un autre mouvement).
create or replace function public.smarves_argent_mouvement(p_jeton text, p_cle text, p_source text, p_motif text,
    p_montant bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  moi text := smarves.joueur(p_jeton);
  c smarves.argent_comptes;
  m smarves.argent_mouvements;
  reste json;
  nid bigint;
begin
  if moi is null then return json_build_object('erreur', 'jeton'); end if;
  if p_cle is null or p_cle !~ '^[A-Za-z0-9_.:-]{8,80}$' then raise exception 'cle invalide'; end if;
  if p_source is null or p_source !~ '^[a-z0-9_]{1,40}$' then raise exception 'source invalide'; end if;
  if p_motif is null or char_length(p_motif) not between 1 and 60 or p_motif = 'ouverture' then raise exception 'motif invalide'; end if;
  if p_montant is null or p_montant = 0 or abs(p_montant) > 1000000000 then raise exception 'montant invalide'; end if;
  -- Un mouvement à la fois par joueur : tout ce qui suit voit le même solde.
  select * into c from smarves.argent_comptes where pyramide_id = moi for update;
  if c.pyramide_id is null then return json_build_object('ok', false, 'raison', 'compte'); end if;
  select * into m from smarves.argent_mouvements where pyramide_id = moi and cle = p_cle;
  if m.id is not null then
    if m.source = p_source and m.motif = p_motif and m.montant = p_montant then
      return json_build_object('ok', true, 'deja', true, 'solde', c.solde, 'id', m.id);
    end if;
    return json_build_object('ok', false, 'raison', 'cle', 'solde', c.solde);
  end if;
  if c.solde + p_montant < 0 then
    return json_build_object('ok', false, 'raison', 'solde', 'solde', c.solde);
  end if;
  reste := smarves.argent_reste(moi, p_source);
  if (p_montant > 0 and (reste->>'entree') is not null and p_montant > (reste->>'entree')::bigint)
      or (p_montant < 0 and (reste->>'sortie') is not null and -p_montant > (reste->>'sortie')::bigint) then
    return json_build_object('ok', false, 'raison', 'plafond', 'solde', c.solde, 'reste', reste);
  end if;
  update smarves.argent_comptes set solde = solde + p_montant, maj = now() where pyramide_id = moi
    returning * into c;
  insert into smarves.argent_mouvements (pyramide_id, cle, source, motif, montant, solde_apres)
    values (moi, p_cle, p_source, left(p_motif, 60), p_montant, c.solde)
    returning id into nid;
  return json_build_object('ok', true, 'solde', c.solde, 'id', nid);
end $$;

revoke all on function public.smarves_argent(text), public.smarves_argent_ouvrir(text, bigint, text),
  public.smarves_argent_mouvement(text, text, text, text, bigint) from public;
grant execute on function public.smarves_argent(text), public.smarves_argent_ouvrir(text, bigint, text),
  public.smarves_argent_mouvement(text, text, text, text, bigint) to anon, authenticated;
