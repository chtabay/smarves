-- Smarves, les doublures (docs/DOUBLURES.md) : des habitants tenus par le modèle de langage d'un joueur,
-- qui se réveillent quelques fois par semaine, jouent, écrivent au panneau et laissent des mots.
--
-- Tout passe par la fonction `doublures` (dépôt chtabay/addict, supabase/functions/doublures), qui
-- vérifie le jeton de l'humain, chiffre sa clé, appelle le modèle et joue ce qu'il répond. Ce fichier
-- tient les tables et les règles qui comptent : une doublure est un joueur comme un autre
-- (smarves.joueurs, smarves.argent_comptes), soumise aux mêmes limites que les humains. Rien de ce
-- schéma ne sort par l'API publique : aucune fonction public.* ici.
--
-- Vie privée : l'humeur de l'humain n'est qu'un mot d'une liste fermée, posé avec son consentement,
-- effacé au bout de dix-huit heures ou dès qu'il coupe ; aucun historique n'en est gardé, et le journal
-- des réveils ne dit pas quelle humeur a servi. Le lien entre une doublure et son humain ne sort jamais
-- de ce schéma.

-- --- Les tables ----------------------------------------------------------------------------------

create table if not exists smarves.doublures (
  -- « doublure:<hasard> », aussi sa ligne dans smarves.joueurs.
  id text primary key references smarves.joueurs (pyramide_id) on delete cascade,
  humain text not null unique references smarves.joueurs (pyramide_id) on delete cascade,
  personnalite text not null check (personnalite in ('prudent', 'flambeuse', 'commere', 'superstitieux', 'calculatrice', 'bon_vivant')),
  fournisseur text not null check (fournisseur in ('anthropic', 'openai', 'compatible')),
  modele text not null check (char_length(modele) between 1 and 100),
  -- L'adresse https d'un point d'accès compatible ; nulle pour Anthropic et OpenAI.
  adresse text check (adresse is null or (adresse ~ '^https://' and char_length(adresse) <= 300)),
  -- La clé de l'humain, chiffrée par la fonction (AES-GCM, base64 de l'IV suivi du chiffré) ; la clé de
  -- chiffrement n'est pas dans la base. Seuls ses quatre derniers caractères se montrent.
  cle_chiffree text not null,
  cle_fin text not null check (char_length(cle_fin) <= 4),
  reveils_semaine integer not null default 3 check (reveils_semaine between 1 and 7),
  actif boolean not null default true,
  -- Pourquoi elle dort : « erreurs » (trois réveils de suite en erreur), « humain » (mise en pause).
  pause_raison text,
  -- Son carnet, qu'elle réécrit à chaque réveil.
  memoire text not null default '' check (char_length(memoire) <= 1200),
  -- Ce qu'elle a gagné au jeu depuis le début (net), pour la vitrine.
  net_total bigint not null default 0,
  cree timestamptz not null default now(),
  maj timestamptz not null default now()
);

create table if not exists smarves.doublure_reveils (
  id bigint generated always as identity primary key,
  doublure text not null references smarves.doublures (id) on delete cascade,
  quand timestamptz not null default now(),
  -- « session », « evenement:match:2026-10-25 », « evenement:loto:2026-10-24 ».
  motif text not null check (char_length(motif) <= 60),
  -- « en_cours » le temps de l'appel au modèle : le réveil est réservé avant, si bien que deux demandes
  -- simultanées n'en font qu'un.
  statut text not null check (statut in ('en_cours', 'fait', 'erreur')),
  jetons_entree integer not null default 0,
  jetons_sortie integer not null default 0,
  -- Ce qui a été fait (coups et leurs résultats, annonce, mots) et ce qui a été refusé, avec la raison.
  actions jsonb not null default '[]',
  refusees jsonb not null default '[]',
  -- Le code et un mot, jamais la réponse du fournisseur.
  erreur text check (char_length(erreur) <= 80)
);
create index if not exists doublure_reveils_quand on smarves.doublure_reveils (doublure, quand desc);

create table if not exists smarves.doublure_humeurs (
  humain text primary key references smarves.joueurs (pyramide_id) on delete cascade,
  consentement boolean not null default false,
  humeur text check (humeur in ('fatiguee', 'euphorique', 'morose', 'agacee', 'sereine', 'pressee')),
  expire timestamptz,
  check (consentement or humeur is null)
);

-- Le verrou de la tâche horaire : un passage à la fois, pas plus d'un toutes les cinq minutes.
create table if not exists smarves.doublures_etat (
  id smallint primary key check (id = 1),
  tick_at timestamptz
);
insert into smarves.doublures_etat (id) values (1) on conflict do nothing;

alter table smarves.doublures enable row level security;
alter table smarves.doublure_reveils enable row level security;
alter table smarves.doublure_humeurs enable row level security;
alter table smarves.doublures_etat enable row level security;
revoke all on smarves.doublures, smarves.doublure_reveils, smarves.doublure_humeurs, smarves.doublures_etat
  from public, anon, authenticated;

-- Ce qui a expiré : les humeurs de plus de dix-huit heures (le mot s'efface, le consentement reste), les
-- réveils restés en cours (la fonction s'est arrêtée en route), le journal de plus de trois mois.
create or replace function smarves.doublures_ranger() returns void
  language sql security definer set search_path = ''
as $$
  update smarves.doublure_humeurs set humeur = null, expire = null where humeur is not null and expire < now();
  update smarves.doublure_reveils set statut = 'erreur', erreur = '0 interrompu'
    where statut = 'en_cours' and quand < now() - interval '10 minutes';
  delete from smarves.doublure_reveils where quand < now() - interval '90 days';
$$;

-- --- Les gestes d'une doublure, aux mêmes règles que les humains ----------------------------------

-- Une petite annonce : 120 caractères, une par jour (smarves_annoncer).
create or replace function smarves.doublure_annoncer(p_id text, p_texte text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  t text := smarves.texte(p_texte, 120);
begin
  if not exists (select 1 from smarves.doublures where id = p_id and actif) then return json_build_object('ok', false, 'raison', 'doublure'); end if;
  if t is null then return json_build_object('ok', false, 'raison', 'texte'); end if;
  if exists (select 1 from smarves.annonces where pyramide_id = p_id and cree > now() - interval '20 hours') then
    return json_build_object('ok', false, 'raison', 'jour');
  end if;
  insert into smarves.annonces (pyramide_id, texte) values (p_id, t);
  return json_build_object('ok', true);
end $$;

-- Un mot à la porte d'un logement d'un autre joueur : 200 caractères, trois par heure (smarves_mot_laisser).
create or replace function smarves.doublure_mot(p_id text, p_pour text, p_lot text, p_texte text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  t text := smarves.texte(p_texte, 200);
begin
  if not exists (select 1 from smarves.doublures where id = p_id and actif) then return json_build_object('ok', false, 'raison', 'doublure'); end if;
  if t is null then return json_build_object('ok', false, 'raison', 'texte'); end if;
  if p_pour = p_id then return json_build_object('ok', false, 'raison', 'soi'); end if;
  if not exists (select 1 from smarves.vitrines v, jsonb_array_elements(v.logements) l
                 where v.pyramide_id = p_pour and l->>'lot' = p_lot) then
    return json_build_object('ok', false, 'raison', 'porte');
  end if;
  if (select count(*) from smarves.mots where de = p_id and cree > now() - interval '1 hour') >= 3 then
    return json_build_object('ok', false, 'raison', 'heure');
  end if;
  insert into smarves.mots (lot, pour, de, texte) values (p_lot, p_pour, p_id, t);
  return json_build_object('ok', true);
end $$;

-- Un coup de roulette joué par la fonction : le mouvement sur son solde, sous la source « doublure ».
-- Le solde ne devient jamais négatif ; une clé rejouée ne compte qu'une fois.
create or replace function smarves.doublure_mouvement(p_id text, p_cle text, p_motif text, p_montant bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  c smarves.argent_comptes;
begin
  if p_cle is null or p_cle !~ '^[A-Za-z0-9_.:-]{8,80}$' then raise exception 'cle invalide'; end if;
  if p_montant is null or p_montant = 0 or abs(p_montant) > 100000 then raise exception 'montant invalide'; end if;
  select * into c from smarves.argent_comptes where pyramide_id = p_id for update;
  if c.pyramide_id is null then return json_build_object('ok', false, 'raison', 'compte'); end if;
  if exists (select 1 from smarves.argent_mouvements where pyramide_id = p_id and cle = p_cle) then
    return json_build_object('ok', true, 'deja', true, 'solde', c.solde);
  end if;
  if c.solde + p_montant < 0 then return json_build_object('ok', false, 'raison', 'solde', 'solde', c.solde); end if;
  update smarves.argent_comptes set solde = solde + p_montant, maj = now() where pyramide_id = p_id returning * into c;
  insert into smarves.argent_mouvements (pyramide_id, cle, source, motif, montant, solde_apres)
    values (p_id, p_cle, 'doublure', left(p_motif, 60), p_montant, c.solde);
  update smarves.doublures set net_total = net_total + p_montant, maj = now() where id = p_id;
  -- La vitrine : le classement du village la montre comme les autres.
  insert into smarves.vitrines as v (pyramide_id, gagne, dette, logements)
    select p_id, greatest(d.net_total, 0), 0, '[]'::jsonb from smarves.doublures d where d.id = p_id
    on conflict (pyramide_id) do update set gagne = excluded.gagne, maj = now();
  return json_build_object('ok', true, 'solde', c.solde);
end $$;

-- Ouvre une doublure : sa ligne de joueur, son solde de nouveau venu et sa fiche, en une fois.
create or replace function smarves.doublure_ouvrir(p_id text, p_humain text, p_nom text, p_personnalite text,
    p_fournisseur text, p_modele text, p_adresse text, p_cle_chiffree text, p_cle_fin text, p_reveils integer,
    p_pecule bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
begin
  if p_id !~ '^doublure:[a-z0-9]{12,40}$' then raise exception 'identifiant invalide'; end if;
  if p_humain like 'doublure:%' then raise exception 'une doublure n''a pas de doublure'; end if;
  if exists (select 1 from smarves.doublures where humain = p_humain) then return json_build_object('ok', false, 'raison', 'deja'); end if;
  insert into smarves.joueurs (pyramide_id, nom) values (p_id, p_nom);
  insert into smarves.argent_comptes (pyramide_id, solde) values (p_id, p_pecule);
  insert into smarves.argent_mouvements (pyramide_id, cle, source, motif, montant, solde_apres)
    values (p_id, 'ouverture:' || substr(p_id, 10), 'doublure', 'ouverture', p_pecule, p_pecule);
  insert into smarves.doublures (id, humain, personnalite, fournisseur, modele, adresse, cle_chiffree, cle_fin, reveils_semaine)
    values (p_id, p_humain, p_personnalite, p_fournisseur, p_modele, p_adresse, p_cle_chiffree, p_cle_fin, p_reveils);
  return json_build_object('ok', true);
end $$;

-- Efface une doublure et tout ce qui est à elle : sa fiche, sa clé, sa mémoire, son journal, son solde,
-- ses annonces et ses mots (en cascade depuis smarves.joueurs), et l'humeur de son humain.
create or replace function smarves.doublure_effacer(p_humain text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  d text;
begin
  select id into d from smarves.doublures where humain = p_humain;
  delete from smarves.doublure_humeurs where humain = p_humain;
  if d is null then return json_build_object('ok', true, 'efface', false); end if;
  delete from smarves.joueurs where pyramide_id = d;
  return json_build_object('ok', true, 'efface', true);
end $$;

revoke all on function smarves.doublures_ranger(), smarves.doublure_annoncer(text, text),
  smarves.doublure_mot(text, text, text, text), smarves.doublure_mouvement(text, text, text, bigint),
  smarves.doublure_ouvrir(text, text, text, text, text, text, text, text, text, integer, bigint),
  smarves.doublure_effacer(text) from public;

-- --- La tâche horaire ----------------------------------------------------------------------------

-- Toutes les heures, la fonction réveille les doublures dont un événement tombe (le matin du match du
-- dimanche, le soir du loto du samedi) ; la base range d'abord ce qui a expiré.
select cron.schedule('smarves-doublures-ranger', '17 * * * *', 'select smarves.doublures_ranger()');
select cron.schedule('smarves-doublures', '23 * * * *', $$
  select net.http_post(
    url := 'https://alvxrjftenialifyktyz.supabase.co/functions/v1/doublures',
    body := '{"action": "tick"}'::jsonb,
    headers := '{"content-type": "application/json"}'::jsonb,
    timeout_milliseconds := 140000
  )
$$);
