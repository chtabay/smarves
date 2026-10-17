# Smarves en web et sur mobile

Ce que donnerait le jeu dans un navigateur ou sur un téléphone, mesuré sur le projet tel qu'il est (Godot 4.7.2, rendu Forward+, physique Jolt) le 17 octobre 2026. Rien de ce qui est décrit ici n'est appliqué au jeu : le rendu reste en Forward+.

## En bref

Oui, le jeu tourne déjà dans un navigateur : l'export web passe sans toucher au code et Chromium affiche l'écran titre puis la place. Mais le web n'a qu'un seul rendu, Compatibility (WebGL 2), qui n'a ni l'éclairage indirect (SDFGI, SSIL), ni le brouillard volumétrique, ni les reflets (SSR), ni le flou de profondeur. Le village et les tables y perdent peu ; le casino, qui vit de ses lustres et de leur rebond sur la moquette, perd beaucoup, et deux réglages en rattrapent l'essentiel. Sur mobile en natif, le rendu Mobile garde presque tout l'éclairage direct ; le vrai chantier est ailleurs : le jeu n'a aucune commande tactile.

## Décision (17 octobre 2026)

Guillaume : le mobile est une cible, le web ne l'est que si nécessaire.

- Sur téléphone (Android, iOS), le jeu tournera avec le rendu Mobile ; l'ordinateur garde Forward+. Godot le permet par plateforme avec `rendering/renderer/rendering_method.mobile="mobile"`, sans toucher au rendu Windows.
- Chaque nouveau lieu prévoit ses commandes tactiles en même temps que le clavier et la souris.
- Le réseau reste Supabase (HTTP et Realtime en WebSocket), qui marche aussi dans un navigateur : la porte du web reste ouverte sans rien coûter.
- Le web ne se prépare pas d'avance ; les étapes de « Ce qu'il faudrait pour un export web aujourd'hui » servent le jour où il devient nécessaire.

## Ce que le rendu utilise aujourd'hui

- `project.godot` : Forward+, Jolt Physics, MSAA 3D ×2, ombres douces qualité 3, Direct3D 12 sous Windows.
- Environnements (`main.gd`, `casino_interior.gd`, `shop_interior.gd`, `tools/table_lab.gd`) : SDFGI avec occlusion, SSIL, SSAO, brouillard volumétrique, glow, tonemap AgX, correction colorimétrique ; SSR dans le casino ; flou de profondeur en vue maquette.
- Deux `FogVolume` (fumée du Fumoir, brume de Passelourdin) avec un shader de type `fog`.
- Beaucoup de lampes dynamiques : plus de 32 dans la première salle du casino (voir plus bas).
- Shaders maison (13, `shaders/`) : tous de type `spatial` ou `sky`, sans lecture de l'écran ni de la profondeur. Celui des habitants (`critter.gdshader`, plafond de l'albédo, rim light) compile et rend pareil en Compatibility.
- Particules GPU (`jeux/kit.gd`), pas de décals.
- Son : bus Ambiance et Bruitages, et une musique fabriquée à la volée par `AudioStreamGenerator` (`sfx.gd`).
- Sauvegardes dans `user://`, souris capturée en vue à pied, aucune gestion du toucher (`InputEventScreenTouch` n'apparaît nulle part).

## Ce que dit la documentation de Godot 4.7

- **Web** : seul le rendu Compatibility (WebGL 2.0) est disponible ; Godot ne prend pas encore en charge WebGPU. Les exports à un seul fil d'exécution (par défaut depuis 4.3) n'ont pas besoin des en-têtes COOP/COEP ; les exports multifils, si. Pas de C#, GDExtension seulement compilée pour le web. Réseau : HTTP, WebSocket et WebRTC, pas de TCP ni d'UDP bruts. Le son par défaut (mode « sample ») ne passe pas les effets de bus. Plein écran et capture de la souris seulement après un geste du joueur. Safari a des soucis de WebGL 2 que Chrome et Firefox n'ont pas.
- **Rendus** : Compatibility n'a ni SDFGI, ni VoxelGI, ni SSIL, ni SSR, ni brouillard volumétrique, ni décals ; il garde SSAO, glow, tonemap et MSAA ; 8 lampes omni ou spot par objet. Le rendu Mobile n'a pas non plus SDFGI, SSIL, SSR ni brouillard volumétrique, et pas de SSAO, mais 256 lampes par vue. Forward+ marche sur téléphone mais « mal optimisé », Godot conseille Mobile ou Compatibility.
- **Jolt** : la page ne parle pas des plateformes. L'export web s'est chargé sans erreur de physique (voir plus bas), mais je n'ai pas fait marcher le personnage dans le navigateur.

## Mesures

Rendu logiciel du conteneur (lavapipe pour Vulkan, llvmpipe pour OpenGL), mêmes vues dans les trois rendus, sauf la place en rendu Mobile, qui n'a pas abouti en rendu logiciel en vingt minutes. Les planches sont dans le dossier du projet `smarves/web/` ; celle du casino est copiée ici.

![Casino : Forward+, Mobile, Compatibility, Compatibility réglé](captures/web-casino.jpg)

- **Place en vue de dessus** : très proche. Compatibility perd le voile de brume et le flou de profondeur en haut de l'image ; la place est un peu plus plate et plus claire.
- **Blackjack, assis** : presque identique. La croupière et le tapis rendent pareil, le plafond de la fourrure tient.
- **Première salle du casino** : en Compatibility la moquette devient presque noire. La cause est la limite de 32 lampes visibles du rendu OpenGL (`rendering/limits/opengl/max_renderable_lights`), pas l'absence de SDFGI : en passant cette limite à 256 et `max_lights_per_object` à 64, la salle retrouve ses lustres et ressemble au rendu Mobile. Il manque encore le rebond chaud et la brume dorée de Forward+.
- **Navigateur** : export web à un seul fil, 50 Mo (39,5 Mo de WebAssembly, 11,6 Mo de données), 21 Mo une fois compressé en gzip. Chromium (WebGL 2 par SwiftShader) charge le jeu en quelques secondes, affiche l'écran titre et, après « Jouer », la place avec Josiane et la tournée générale. Deux défauts vus à l'écran : les puces « ● » de la liste du village sortent en carrés (le navigateur n'a pas les polices du système, il faut une police embarquée qui a ces signes), et le son attend un clic pour démarrer. La seule erreur est celle du shader `fog`. La cadence en rendu logiciel (moins d'une image par seconde) ne dit rien de celle d'une vraie carte graphique ; je n'ai pas pu la mesurer ici.

## Ce qu'il faudrait pour un export web aujourd'hui

1. Un préréglage d'export « Web » (à un seul fil, sans PWA), et un workflow qui le publie, par exemple sur GitHub Pages.
2. Les deux limites de lampes, réservées au web avec le suffixe de fonctionnalité (`max_renderable_lights.web=256`, `max_lights_per_object.web=64`), pour ne rien changer au jeu Windows.
3. Ne pas créer les deux `FogVolume` en Compatibility (`RenderingServer.get_current_rendering_method()`), et remplacer la brume par du brouillard de profondeur ou des plans transparents.
4. Une police embarquée qui couvre tous les signes affichés.
5. Écouter le son dans un vrai navigateur (pas fait ici, le conteneur n'a pas de sortie audio) : la musique fabriquée par `AudioStreamGenerator` ne relève sans doute pas du mode « sample » et passerait par le mode « stream », plus sujet aux craquements sans fils d'exécution. Sinon, des boucles enregistrées.
6. Pour se rapprocher de Forward+ dans le casino : éclairage précuit (`LightmapGI`, affiché par Compatibility) ou quelques lampes d'appoint sans ombre.

Les points 1 à 4 tiennent en une journée ; le 5 et le 6 sont du réglage lieu par lieu.

## Mobile

- **En natif (Android, iOS)** : le rendu Mobile garde la moquette et les lustres du casino (planche ci-dessus) ; il perd SDFGI, SSIL, SSR, le brouillard volumétrique et le SSAO. C'est le meilleur rendu pour téléphone, mieux que Compatibility.
- **Dans le navigateur d'un téléphone** : Compatibility comme sur ordinateur, avec moins de mémoire et de puissance, et Safari sur iPhone moins fiable en WebGL 2.
- **Ce qui manque dans les deux cas** : des commandes tactiles (déplacement, regard, interaction, zoom de la maquette), une interface lisible sur petit écran, et un budget de lampes et d'ombres pour la chaleur et la batterie.

## Ce qu'il aurait fallu décider au départ

- Choisir le rendu cible dès le premier jour : Compatibility si le web compte, Mobile si ce sont les applications. La direction artistique se règle alors sur ce rendu au lieu d'être rattrapée.
- Garder l'éclairage sous un plafond de lampes visibles, et précuire la lumière des intérieurs plutôt que compter sur SDFGI.
- Prévoir les commandes tactiles avec les commandes clavier et souris.
- Embarquer les polices, et fixer un budget de téléchargement.

## Conséquences pour la suite

- **Multijoueur** : dans un navigateur, ni ENet ni UDP. Si le web est une cible, tout le monde passe par `WebSocketMultiplayerPeer` vers un serveur (Godot sans affichage, en natif), ou par WebRTC avec un serveur de mise en relation. Les versions natives peuvent parler WebSocket aussi, ce qui évite deux réseaux.
- **Logements** : l'état partagé vit sur le serveur ; les sauvegardes locales du navigateur (IndexedDB derrière `user://`) peuvent être effacées par le navigateur.
- **Mods et autres villes** : un mod en paquet de ressources (`.pck`) avec du GDScript se charge avec `ProjectSettings.load_resource_pack` après l'avoir téléchargé dans `user://`, ce qui devrait marcher aussi dans un navigateur (non essayé ici). Un mod en GDExtension demande un build web à part et le modèle d'export avec extensions : à éviter pour des mods.
- **Carte de la Vienne** : charger les villes à la demande, par paquets, plutôt que tout dans le premier téléchargement. 21 Mo compressés pour le village seul est raisonnable ; chaque ville en plus dans le paquet principal rallonge l'attente sur le web.
