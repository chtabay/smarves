-- Retour arrière de 20261101100000_smarves_pensionnaire_position.sql (appliquer d'abord celui de Lasso 009, sql/009_rollback.sql).
begin;
drop function if exists smarves.pensionnaire_position(text);
commit;
