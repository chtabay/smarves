#!/usr/bin/env bash
# Essais de concurrence de l'inscription (migration 20261030000000) sur une base LOCALE : deux sessions
# en même temps. La première garde sa transaction ouverte deux secondes ; la seconde attend sur l'index unique,
# puis doit recevoir un refus propre, jamais une erreur ni un doublon. Nettoie ce qu'il crée.
#   PSQL="psql -d <base locale>" bash supabase/tests/concurrence.sh
set -euo pipefail
PSQL=${PSQL:-psql}
q() { $PSQL -q -At -v ON_ERROR_STOP=1 -c "$1"; }
appel() { # jti humain ins id nom
  echo "select smarves.doublure_inscrire('$1', now() + interval '2 minutes', '$2', 'P', 'creer', '$3', '$4', '$5',
    'Une histoire de village assez longue pour passer.', null, null, null, 7, 500)"
}
nettoyer() { q "delete from smarves.joueurs where pyramide_id in ('concA','concB','doublure:concaaaaaaaa','doublure:concbbbbbbbb','doublure:conccccccccc');
  delete from smarves.inscriptions where humain in ('concA','concB'); delete from smarves.inscription_jetons where humain in ('concA','concB');" >/dev/null; }
echec() { echo "ÉCHEC : $1"; nettoyer; exit 1; }
nettoyer

# Deux humains, le même nom (casse différente), en même temps.
( $PSQL -q -At -c "begin; $(appel concjeton0000001 concA 10000000-0000-4000-8000-000000000001 doublure:concaaaaaaaa 'Marcel (pensionnaire)'); select pg_sleep(2); commit;" >/tmp/conc1 ) &
sleep 0.5
r2=$(q "$(appel concjeton0000002 concB 10000000-0000-4000-8000-000000000002 doublure:concbbbbbbbb 'MARCEL (pensionnaire)')")
wait
grep -q '"resultat" : "cree"' /tmp/conc1 || echec "la première création devait réussir"
[[ "$r2" == *'"nom_pris"'* ]] || echec "la seconde devait recevoir nom_pris, reçu : $r2"
[[ $(q "select count(*) from smarves.joueurs where smarves.nom_cle(nom) = 'marcel' and pyramide_id like 'doublure:%'") == 1 ]] || echec "un seul Marcel"
echo "ok : même nom en parallèle, un seul pensionnaire"

# Le même humain, deux créations en même temps.
( $PSQL -q -At -c "begin; $(appel concjeton0000003 concB 10000000-0000-4000-8000-000000000003 doublure:concbbbbbbbb 'Ernest (pensionnaire)'); select pg_sleep(2); commit;" >/tmp/conc1 ) &
sleep 0.5
r2=$(q "$(appel concjeton0000004 concB 10000000-0000-4000-8000-000000000004 doublure:conccccccccc 'Firmin (pensionnaire)')")
wait
grep -q '"resultat" : "cree"' /tmp/conc1 || echec "la première création devait réussir"
[[ "$r2" == *'"deja_pensionnaire"'* ]] || echec "la seconde devait recevoir deja_pensionnaire, reçu : $r2"
echo "ok : même humain en parallèle, un seul pensionnaire"

# Le même jeton deux fois en même temps.
( $PSQL -q -At -c "begin; select smarves.doublure_inscrire('concjeton0000005', now() + interval '2 minutes', 'concA', 'P', 'adopter', '10000000-0000-4000-8000-000000000005', null, null, null, null, null, null, 7, 500); select pg_sleep(2); commit;" >/tmp/conc1 ) &
sleep 0.5
r2=$(q "select smarves.doublure_inscrire('concjeton0000005', now() + interval '2 minutes', 'concA', 'P', 'adopter', '10000000-0000-4000-8000-000000000006', null, null, null, null, null, null, 7, 500)")
wait
grep -q '"resultat" : "adopte"' /tmp/conc1 || echec "la première adoption devait réussir"
[[ "$r2" == *'"rejeu"'* ]] || echec "le second usage devait recevoir rejeu, reçu : $r2"
echo "ok : même jeton en parallèle, un seul effet"

nettoyer
