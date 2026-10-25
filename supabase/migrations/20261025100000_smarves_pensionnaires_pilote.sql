-- Smarves, le pilote des pensionnaires (docs/PENSIONNAIRES.md, « Le pilote ») : pendant les événements, un
-- pensionnaire joue dans le vrai jeu, lancé sans écran sur GitHub Actions, et son assistant le tient par
-- des gestes de joueur (aller devant une zone, appuyer sur E, cliquer un bouton). La fonction doublures
-- passe les gestes de l'assistant au jeu, et ce que le jeu montre à l'assistant ; cette table les garde
-- le temps du passage.
--
-- - demande : l'assistant veut jouer ; le superviseur de la tâche GitHub lance alors son jeu ;
-- - vivant : le dernier signe du jeu (il attend un geste au plus vingt secondes d'affilée) ;
-- - geste, geste_n : le dernier geste demandé, numéroté ; vue, vue_n : ce que le jeu montre après lui ;
-- - lieu, x, y, z : où est son corps (la scène et la position), pour la portée de sa vue.
--
-- Seule la fonction y touche (aucun droit pour le jeu ni pour les joueurs).

create table if not exists smarves.doublure_pilote (
  doublure text primary key references smarves.doublures (id) on delete cascade,
  demande timestamptz,
  vivant timestamptz,
  geste jsonb,
  geste_n integer not null default 0,
  vue jsonb,
  vue_n integer not null default 0,
  lieu text check (lieu is null or char_length(lieu) <= 60),
  x real,
  y real,
  z real,
  maj timestamptz not null default now()
);
alter table smarves.doublure_pilote enable row level security;
revoke all on smarves.doublure_pilote from anon, authenticated;

-- Le dernier signe du superviseur de la tâche GitHub : tant qu'il tourne, les pensionnaires de
-- l'événement jouent dans le jeu ; sinon, comme avant, par les tours du serveur.
alter table smarves.doublures_etat add column if not exists pilote_vu timestamptz;
