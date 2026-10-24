-- Pensionnaires (docs/PENSIONNAIRES.md), deuxième lot : une histoire, une mémoire, un connecteur.
--
-- - L'histoire écrite par le créateur (« autre ») passe à 900 caractères, avec ses envies et ses besoins.
-- - Le mode : « cle », le serveur appelle le modèle avec la clé de l'humain (chiffrée) ; « agent »,
--   l'assistant de l'humain tient le pensionnaire par le connecteur MCP de la fonction `doublures`, sans
--   clé. smarves.doublure_ouvrir déduit le mode de la clé : sans clé, c'est l'assistant.
-- - Ses relations (smarves.doublure_liens) : ce qu'il pense de chaque habitant, le dernier échange, leur
--   nombre ; trente au plus, la fonction range le reste.
-- - Le lien du connecteur (smarves.doublure_acces) : un jeton par humain, gardé haché.
-- Rien de ce schéma ne sort par l'API publique.

alter table smarves.doublures drop constraint doublures_caractere_check;
alter table smarves.doublures add constraint doublures_caractere_check check (caractere is null or char_length(caractere) <= 900);
alter table smarves.doublures add column envies text check (envies is null or char_length(envies) <= 300);
alter table smarves.doublures add column besoins text check (besoins is null or char_length(besoins) <= 300);

alter table smarves.doublures add column mode text not null default 'cle' check (mode in ('cle', 'agent'));
alter table smarves.doublures alter column fournisseur drop not null;
alter table smarves.doublures alter column modele drop not null;
alter table smarves.doublures alter column cle_chiffree drop not null;
alter table smarves.doublures alter column cle_fin drop not null;
alter table smarves.doublures add constraint doublures_mode_cle
  check (mode = 'agent' or (fournisseur is not null and modele is not null and cle_chiffree is not null and cle_fin is not null));

create table if not exists smarves.doublure_liens (
  doublure text not null references smarves.doublures (id) on delete cascade,
  autre text not null references smarves.joueurs (pyramide_id) on delete cascade,
  avis text not null default '' check (char_length(avis) <= 160),
  dernier text not null default '' check (char_length(dernier) <= 300),
  echanges integer not null default 0,
  -- Le dernier mot reçu de lui déjà compté.
  recu timestamptz,
  maj timestamptz not null default now(),
  primary key (doublure, autre)
);
create index if not exists doublure_liens_maj on smarves.doublure_liens (doublure, maj desc);

create table if not exists smarves.doublure_acces (
  humain text primary key references smarves.joueurs (pyramide_id) on delete cascade,
  jeton_hash text not null unique check (jeton_hash ~ '^[0-9a-f]{64}$'),
  cree timestamptz not null default now(),
  vu timestamptz
);

alter table smarves.doublure_liens enable row level security;
alter table smarves.doublure_acces enable row level security;
revoke all on smarves.doublure_liens, smarves.doublure_acces from public, anon, authenticated;

-- L'ouverture, la même, qui range le mode : sans clé, c'est l'assistant.
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
  insert into smarves.doublures (id, humain, personnalite, mode, fournisseur, modele, adresse, cle_chiffree, cle_fin, reveils_semaine)
    values (p_id, p_humain, p_personnalite, case when p_cle_chiffree is null then 'agent' else 'cle' end,
      p_fournisseur, p_modele, p_adresse, p_cle_chiffree, p_cle_fin, p_reveils);
  return json_build_object('ok', true);
end $$;

-- L'effacer coupe aussi le lien du connecteur.
create or replace function smarves.doublure_effacer(p_humain text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  d text;
begin
  select id into d from smarves.doublures where humain = p_humain;
  delete from smarves.doublure_humeurs where humain = p_humain;
  delete from smarves.doublure_acces where humain = p_humain;
  if d is null then return json_build_object('ok', true, 'efface', false); end if;
  delete from smarves.joueurs where pyramide_id = d;
  return json_build_object('ok', true, 'efface', true);
end $$;
