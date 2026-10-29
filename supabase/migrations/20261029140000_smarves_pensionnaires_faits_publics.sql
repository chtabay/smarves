-- Smarves, les faits publics des pensionnaires (docs/PENSIONNAIRES.md, « Ce que le village a vu de lui ») :
-- ce qu'un joueur présent aurait pu voir d'un pensionnaire qui joue par le pilote, gardé pour qui a le
-- droit de le lire (Lasso, par une fonction à lui, jamais par une table).
--
-- Jusqu'ici, le pilote n'écrivait rien dans le journal des réveils : seules les pages du carnet y entrent
-- (mémoire, journal intime, avis, sans geste public). Un pensionnaire qui a vécu toute la journée en
-- jeu semblait donc arrêté à son dernier tour de serveur.
--
-- 1. smarves.doublure_gestes : un fait par ligne, écrit par la fonction doublures (dépôt chtabay/addict) :
--    - « lieu » : il est entré dans un lieu (le code de la scène : main, casino, colaby…) ;
--    - « dire » : une parole faite par le jeu, qui passe le filtre des textes de pensionnaire ;
--    - « jeu » : ce qu'un jeu a fait à sa poche (le mouvement compté sur son solde).
--    Jamais ce qu'il a vu, cliqué ou pensé ; jamais sa mémoire, son journal intime, ses avis ni ses mots.
-- 2. Deux lectures, pour les fonctions d'une autre application qui ont déjà vérifié à qui est le
--    pensionnaire (aucun droit pour anon ni authenticated) :
--    - smarves.pensionnaire_present(id) : son dernier signe de vie en jeu et son lieu ;
--    - smarves.pensionnaire_faits(id, n, avant) : ses n derniers faits publics, du plus récent au plus ancien.
--
-- Ces faits ne sont publics qu'au sens du jeu (un joueur présent pouvait les voir) : hors du jeu, ils ne
-- sortent que vers le créateur du pensionnaire, après son consentement (Lasso, migration 005), jamais
-- vers un forum ni vers d'autres joueurs.
--
-- Rangement : le journal des gestes suit celui des réveils (trois mois), et ne garde que les 500 derniers
-- faits de chaque pensionnaire.
--
-- Une seule transaction : les fonctions naissent avec EXECUTE pour PUBLIC, retiré avant que quiconque ne
-- les voie. S'arrête sans rien changer si une table du même nom existe déjà.

begin;

do $garde$
begin
  if to_regclass('smarves.doublure_gestes') is not null then
    raise exception 'smarves.doublure_gestes existe déjà : migration abandonnée sans aucun changement';
  end if;
end
$garde$;

create table smarves.doublure_gestes (
  id bigint generated always as identity primary key,
  doublure text not null references smarves.doublures (id) on delete cascade,
  quand timestamptz not null default now(),
  genre text not null check (genre in ('lieu', 'dire', 'jeu')),
  lieu text check (lieu is null or lieu ~ '^[a-z0-9_]{1,40}$'),
  texte text check (texte is null or char_length(texte) between 1 and 200),
  montant bigint check (montant is null or (montant <> 0 and abs(montant) <= 100000)),
  check ((genre = 'lieu' and lieu is not null and texte is null and montant is null)
      or (genre = 'dire' and texte is not null and montant is null)
      or (genre = 'jeu' and montant is not null and texte is null))
);
create index doublure_gestes_quand on smarves.doublure_gestes (doublure, quand desc, id desc);
alter table smarves.doublure_gestes enable row level security;
revoke all on smarves.doublure_gestes from public, anon, authenticated;

-- Le nom d'un lieu pour un lecteur : celui des scènes du jeu, sinon nul (le code reste donné).
create or replace function smarves.lieu_nom(p_code text) returns text
  language sql immutable set search_path = ''
as $$
  select case p_code
    when 'main' then 'la place de Smarves'
    when 'casino' then 'le Casino'
    when 'colaby' then 'le Colaby'
    when 'cafe' then 'le café'
    when 'cercle' then 'le Cercle'
    when 'bourse' then 'la Bourse'
    when 'brocante' then 'la brocante'
    when 'commerce' then 'un commerce'
    when 'couture' then 'l''atelier de couture'
    when 'epicerie' then 'l''épicerie'
    when 'etude' then 'l''étude'
    when 'garage' then 'le garage'
    when 'logement' then 'un logement'
    when 'moulin' then 'le moulin'
    when 'notaire' then 'le notaire'
    when 'rabelais' then 'le Rabelais'
    when 'salle_basket' then 'la salle de basket'
    when 'salle_jeu' then 'la salle de jeu'
    when 'stade' then 'le stade'
  end
$$;

-- Les deux lectures s'exécutent avec les droits de l'appelant (SECURITY INVOKER) : seule une fonction
-- déjà propriétaire du schéma (lasso.smarves_vie, SECURITY DEFINER, à postgres) peut lire la table ; un
-- EXECUTE donné par erreur n'ouvrirait rien de plus.

-- Son dernier signe en jeu (le pilote) et son lieu : une ligne, vide s'il n'a jamais joué par le pilote.
create or replace function smarves.pensionnaire_present(p_id text)
  returns table (vivant timestamptz, lieu text, lieu_nom text)
  language sql stable security invoker set search_path = ''
as $$
  select p.vivant,
         case when p.lieu ~ '^[a-z0-9_]{1,40}$' then p.lieu end,
         case when p.lieu ~ '^[a-z0-9_]{1,40}$' then smarves.lieu_nom(p.lieu) end
    from smarves.doublure_pilote p
   where p.doublure = p_id and p.vivant is not null
$$;

-- Ses derniers faits publics (au plus 50), avant un instant donné si l'on veut la page d'après (deux faits
-- de la même microseconde peuvent alors tomber entre deux pages : Lasso ne lit que la première).
create or replace function smarves.pensionnaire_faits(p_id text, p_n integer default 20, p_avant timestamptz default null)
  returns table (id bigint, quand timestamptz, genre text, lieu text, lieu_nom text, texte text, montant bigint)
  language sql stable security invoker set search_path = ''
as $$
  select g.id, g.quand, g.genre, g.lieu, smarves.lieu_nom(g.lieu), g.texte, g.montant
    from smarves.doublure_gestes g
   where g.doublure = p_id and (p_avant is null or g.quand < p_avant)
   order by g.quand desc, g.id desc
   limit least(greatest(coalesce(p_n, 20), 1), 50)
$$;

revoke all on function smarves.lieu_nom(text), smarves.pensionnaire_present(text),
  smarves.pensionnaire_faits(text, integer, timestamptz) from public, anon, authenticated;

-- Le rangement de l'heure : celui d'avant, plus le journal des gestes.
create or replace function smarves.doublures_ranger() returns void
  language sql security definer set search_path = ''
as $$
  update smarves.doublure_humeurs set humeur = null, expire = null where humeur is not null and expire < now();
  update smarves.doublure_reveils set statut = 'erreur', erreur = '0 interrompu'
    where statut = 'en_cours' and quand < now() - interval '10 minutes';
  delete from smarves.doublure_reveils where quand < now() - interval '90 days';
  delete from smarves.doublure_gestes where quand < now() - interval '90 days';
  delete from smarves.doublure_gestes g using (
    select id from (select id, row_number() over (partition by doublure order by quand desc, id desc) as rang
      from smarves.doublure_gestes) x where x.rang > 500) v
   where g.id = v.id;
$$;
revoke all on function smarves.doublures_ranger() from public;

commit;
