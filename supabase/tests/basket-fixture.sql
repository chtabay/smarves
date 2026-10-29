-- Le basket de Smarves sur les résultats réels : les matchs de l'Euroleague et de l'EuroCup lus par
-- la fonction `basket`, la feuille de chaque joueur réel, et le cliché des notes publié chaque
-- vendredi à 23 h (heure de Paris). Spec : /mnt/project-files/basket/spec-basket-reel.md.
--
-- Comme le casino, schéma fermé à l'API publique : seule la fonction `basket`, connectée directement
-- à la base, lit et écrit. Le jeu lit le cliché en GET auprès de la fonction.

create schema if not exists basket;
revoke all on schema basket from public, anon, authenticated;

-- Un match réel déjà lu (« E2026-1 » : compétition, saison, numéro du match).
create table if not exists basket.matchs (
  id        text primary key,
  comp      text not null,
  saison    text not null,
  date      timestamptz not null,
  local     text not null,
  visiteur  text not null,
  score     jsonb,
  lu_at     timestamptz not null default now()
);

-- La feuille d'un joueur réel pour un match (notes.js, ligneEuroleague).
create table if not exists basket.lignes (
  match   text not null references basket.matchs (id) deferrable initially deferred,
  joueur  text not null,
  date    timestamptz not null,
  ligne   jsonb not null,
  primary key (match, joueur)
);
create index if not exists lignes_date on basket.lignes (date);

-- Le cliché de la semaine (notes.js, cliche) : une ligne par vendredi, jamais réécrite.
create table if not exists basket.cliches (
  id          text primary key,
  debut       timestamptz not null,
  fin         timestamptz not null,
  contenu     jsonb not null,
  publie_at   timestamptz not null default now()
);

-- Le verrou de la collecte : une à la fois, pas plus d'une toutes les 5 minutes.
create table if not exists basket.etat (
  id          smallint primary key check (id = 1),
  collecte_at timestamptz
);
insert into basket.etat (id) values (1) on conflict do nothing;

alter table basket.matchs enable row level security;
alter table basket.lignes enable row level security;
alter table basket.cliches enable row level security;
alter table basket.etat enable row level security;
revoke all on all tables in schema basket from public, anon, authenticated;

-- La collecte, toutes les heures (au plus 60 feuilles par appel, si bien qu'une semaine se lit en un
-- passage et la première reprise en quelques heures). Le cliché part au premier passage après le
-- vendredi 23 h : celui de 22 h ou 23 h UTC selon l'heure d'été.
select cron.schedule('smarves-basket', '7 * * * *', $$
  select net.http_post(
    url := 'https://alvxrjftenialifyktyz.supabase.co/functions/v1/basket',
    body := '{"action": "collecter"}'::jsonb,
    headers := '{"content-type": "application/json"}'::jsonb,
    timeout_milliseconds := 140000
  )
$$);

