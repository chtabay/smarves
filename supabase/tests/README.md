# Essais SQL

Sur un Postgres **local** qui imite le projet Supabase partagé : rôles `anon` et `authenticated`, schémas
`extensions` (pgcrypto), `vault`, `cron`, `net` factices, puis toutes les migrations de ce dépôt et celles de
`chtabay/addict` (le basket), dans l'ordre de leurs noms.

- `inscription.sql` : la migration de l'inscription depuis Lasso (chtabay/lasso#13) — clé de nom, adoption sans
  écriture, création pour un joueur qui n'a jamais joué, refus (nom pris, déjà un pensionnaire, rejeu, autre
  humain), débit, droits. Transaction annulée à la fin.
  `psql -v ON_ERROR_STOP=1 -d <base> -f supabase/tests/inscription.sql`
- `concurrence.sh` : deux sessions en même temps (même nom, même humain, même jeton) : un seul effet, un refus
  propre pour l'autre. `PSQL="psql -d <base>" bash supabase/tests/concurrence.sh`
- Retour arrière : `supabase/rollback/20261030000000_smarves_pensionnaires_inscription.sql`, rejouable après la
  migration ; les essais vérifient qu'on peut réappliquer la migration ensuite.
