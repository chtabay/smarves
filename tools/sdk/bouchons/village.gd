extends Node3D
## Bouchon du SDK des communes : le village de Smarves n'est pas dans le SDK. Le carnet du socle
## nomme ce script pour dessiner le plan de Smarves ; ici, le plan n'a ni quartiers ni lieux cachés.
## Le vrai fichier est scripts/village/village.gd dans le dépôt de Smarves (tools/sdk/construire_sdk.py).

const ZONES := {}
const CACHES := {}
var lots := {}
