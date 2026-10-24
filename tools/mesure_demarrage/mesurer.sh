#!/bin/sh
# Mesure le démarrage du jeu sans rien changer au dépôt : copie le projet dans un dossier temporaire,
# y ajoute le chronomètre (chrono.gd) en tête des autoloads, exporte le paquet comme pour les joueurs
# (scripts en jetons binaires, ressources importées), et lance trois fois chacun des deux parcours :
# l'écran titre puis « Jouer », et le carnet sur une scène vide, sans village ; puis une fois les trajets
# (distances de la place aux portes des gestes courants, chargement du notaire, du stade et du casino).
#   GODOT=/chemin/godot sh tools/mesure_demarrage/mesurer.sh [dossier] [options de godot...]
# Sans écran (processeur seul) : options --headless. Rendu logiciel : sous xvfb-run, sans --headless.
set -e
GODOT="${GODOT:-godot}"
ICI="$(cd "$(dirname "$0")/../.." && pwd)"
COPIE="${1:-/tmp/smarves-mesure}"
shift || true
rm -rf "$COPIE"
mkdir -p "$COPIE"
(cd "$ICI" && tar -cf - --exclude=.git .) | (cd "$COPIE" && tar -xf -)
# Hors de tools/, que l'export écarte.
mkdir -p "$COPIE/mesure_demarrage"
cp "$ICI/tools/mesure_demarrage/chrono.gd" "$ICI/tools/mesure_demarrage/vide.tscn" "$COPIE/mesure_demarrage/"
# Le chronomètre en premier autoload : il voit arriver les 26 autres.
sed -i 's|^\[autoload\]$|[autoload]\n\nChrono="*res://mesure_demarrage/chrono.gd"|' "$COPIE/project.godot"
"$GODOT" --headless --path "$COPIE" --import > "$COPIE/import.txt" 2>&1 || true
"$GODOT" --headless --path "$COPIE" --export-pack "Windows Desktop" "$COPIE/jeu.pck" > "$COPIE/export.txt" 2>&1
echo "Paquet exporté : $(du -h "$COPIE/jeu.pck" | cut -f1)"
# Une partie neuve au premier essai, dans un dossier de données à part ; les suivants retrouvent la
# partie et les caches (shaders, catalogue) du premier, comme un joueur qui revient.
export XDG_DATA_HOME="$COPIE/.donnees"
cd "$COPIE/mesure_demarrage"
for essai in 1 2 3; do
	echo "== titre, essai $essai"
	"$GODOT" --main-pack "$COPIE/jeu.pck" "$@" -- --mesure=titre > "$COPIE/journal.txt" 2>&1 || true
	grep CHRONO "$COPIE/journal.txt"
	echo "== carnet sans village, essai $essai"
	"$GODOT" --main-pack "$COPIE/jeu.pck" "$@" res://mesure_demarrage/vide.tscn -- --mesure=carnet > "$COPIE/journal.txt" 2>&1 || true
	grep CHRONO "$COPIE/journal.txt"
done
echo "== trajets"
"$GODOT" --main-pack "$COPIE/jeu.pck" "$@" -- --mesure=trajets > "$COPIE/journal.txt" 2>&1 || true
grep CHRONO "$COPIE/journal.txt"
