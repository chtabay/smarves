#!/bin/sh
# Vérifie le SDK des communes comme le recevrait un développeur : construit le zip, le déballe dans un
# dossier neuf, hors du dépôt, et y passe les tests du kit, de l'atelier, de la salle de jeu et du
# serveur MCP. Usage : sh tools/sdk/test_sdk.sh [dossier de travail]
set -e
ici=$(cd "$(dirname "$0")/../.." && pwd)
travail=${1:-$(mktemp -d)}
python3 "$ici/tools/sdk/construire_sdk.py" --sortie="$travail"
cd "$travail"
rm -rf smarves-sdk
unzip -q smarves-sdk-*.zip
cd smarves-sdk
godot=${GODOT:-godot}
"$godot" --headless --path . --import > import.log 2>&1 || true
echo "--- erreurs de script à l'import"
grep -E "SCRIPT ERROR|Parse Error|Failed to load" import.log | head -20 || true
for t in test_commune test_atelier test_salle_jeu test_availles; do
	"$godot" --headless --path . -s tools/$t.gd > $t.log 2>&1 && echo "ok      $t" || { echo "ÉCHEC   $t"; tail -20 $t.log; exit 1; }
done
"$godot" --headless --path . --quit-after 120 > lanceur.log 2>&1 || true
grep -E "SCRIPT ERROR" lanceur.log && { echo "ÉCHEC   le lanceur"; exit 1; } || echo "ok      le lanceur s'ouvre"
python3 tools/mcp/test_kit_communes.py --godot | tail -1
echo "SDK vérifié dans $travail/smarves-sdk"
