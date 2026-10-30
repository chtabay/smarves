# Essais SQL

`inscription-pg.mjs` automatise les essais sur PostgreSQL 17 local : installer `pg`, puis définir
`SMARVES_TEST_PG_ADMIN_URL=postgres://postgres@127.0.0.1:5432/postgres` et lancer
`node supabase/tests/inscription-pg.mjs`. Le script refuse une adresse distante, crée puis supprime une
base jetable avec collation Unicode ICU. Il rejoue les migrations sauf la bourse, avec le schéma basket
copié de addict a318dc9 dans `basket-fixture.sql`, un coffre vide et un ordonnanceur inerte.
Il vérifie aussi deux créations et deux adoptions de même `ins` avec des `jti` distincts, la reprise
après un COMMIT non reçu, le refus d'une autre empreinte `dem`, puis le rollback/réapplication.
Ce n'est pas un E2E du navigateur, de l'OAuth ni des fonctions Edge Supabase.

`passerelle-pg.mjs` (mêmes variables) rejoue toutes les migrations, la passerelle Lasso comprise
(`20261101000000_smarves_passerelle_lasso.sql`), crée un pensionnaire par le chemin Lasso et exerce
`smarves.passerelle_entrer` (le pensionnaire du couple humain + agent, rejeu, autre agent, coupure), la trace des
appels sans contenu et sa purge, couper / reprendre / effacer, les droits, puis le retour arrière (refusé tant que
Lasso 012 est en place) et la réapplication. PostgreSQL 16 ou 17.

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

