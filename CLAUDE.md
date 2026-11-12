# Fric-Frac

Jeu vidéo de cambriolage tactique au tour par tour, adapté du jeu de plateau « Fric-Frac » (encart de Jeux & Stratégie, 1982). Moteur : **Godot 4.6**, GDScript. Projet frère de « Délire à la cantine », dont il reprend l'organisation.

## Méthode de travail

- Le projet avance par étapes. **Chaque étape est validée par Alexandre avant de passer à la suivante.**
- Étapes prévues : structure du dépôt, transcription des règles et du plan de la villa, document de game design, moteur de règles et tests, visuels de référence, maquette grise jouable, habillage, versions web et PC, essais de jeu.

## Cible et décisions de design

- Plateforme : navigateur (export web Godot, rendu Compatibilité / WebGL 2) et PC. Garder les assets légers.
- Plateau hexagonal : la villa de Neuilly, son jardin et ses gardes.
- Infiltration au tour par tour. Les trois tableaux du livret sont gardés tels quels : 6 points d'action par voleur, 1 point = 1 case de déplacement ou 1 colonne du tableau d'effraction. Valeurs à régler à la maquette grise.
- Gardes : règle du livret (ronde en ligne droite, dé de direction à chaque obstacle). Ils parcourent 6 cases par tour de table, 12 dès la première alerte et jusqu'à la fin.
- Brouillard : le joueur ne voit que les pièces où se tiennent ses voleurs, et les gardes hors de vue s'entendent à 6 cases (12 en alerte). Option « plateau ouvert » qui montre tout.
- Bruit : portée comptée en cases à travers les murs, affichée en onde avant et après chaque geste. Dés visibles à l'écran.
- Lumière : ambiance de nuit seulement, sans effet sur les règles dans la première version.
- Balustrade de la terrasse : obstacle bas, 2 points pour l'enjamber ; elle arrête un garde en ronde.
- Modes de la première version : casse en solo (trois voleurs, horloge de 24 tours), casse du jour (graine tirée de la date), tour de rôle de 2 à 6 joueurs sur le même écran. Campagne et rivaux joués par l'ordinateur plus tard.
- Meubles toujours tirés au hasard : le placement secret par les joueurs (parties à 4 et plus) est abandonné.
- Style : manoir à énigme du début du XXe siècle, dans l'esprit de Cluedo, de nuit (boiseries, lampes à pétrole, gardes en livrée et lanterne). Seule l'ambiance est reprise, aucun personnage, nom ni élément de Cluedo.
- Film du casse : une partie est une graine et une liste de gestes, rejouable à l'identique.
- Game design complet : https://claude.ai/artifact/GAYdVm9U4Wx3JAG6dwUhWP

## Langue

Communication, documentation et messages de commit en français. Code (noms de variables, fonctions, classes) en anglais, commentaires en français.

## Structure

- `docs/regles-originales.md` : règles du jeu de plateau, référence du moteur de règles.
- `docs/interpretations-regles.md` : ce que le livret laisse flou et la lecture retenue.
- `docs/plan_villa.svg` : plan redessiné depuis `data/villa.json` par `tools/dessiner_plan.py`. À régénérer après toute retouche du plan.
- `data/` : valeurs chiffrées (tables d'effraction, de combat, de butin, équipement, plan de la villa) en JSON. Ne jamais dupliquer ces chiffres en dur dans le code.
- `scripts/rules/` : moteur de règles pur (aucune dépendance aux nœuds de scène), entièrement testable. `GameState` (pions, meubles, tour), `GameSetup` (mise en place), `Movement`, `BreakIn` (effraction et butin), `NoiseRules` (bruit et alarme), `Combat`, `Fence` (receleur), `TurnFlow`, `Visibility` (brouillard), `GameActions` (gestes du joueur en commandes) et `SaveGame` (graine et gestes, rejouables).
- `scripts/ai/` : comportement des pions automatiques. `guards.gd` : ronde, alerte et poursuite des gardes. Plus tard : voleurs adverses joués par l'ordinateur.
- `data/regles_video.json` : réglages de l'adaptation vidéo (points d'action, allure des gardes, horloge du solo, tenues).
- `scripts/ui/` et `scenes/` : affichage, caméra, interface. Pour l'instant, la maquette 3D de la villa : `villa_outline.gd` redresse le tracé des murs pour l'affichage (les règles gardent les cases), `villa_view.gd` construit la villa depuis `VillaPlan`, `orbit_camera.gd` la fait visiter.
- `assets/` : modèles (glTF/GLB), sprites, textures, audio. Fichiers lourds suivis par Git LFS.
- `tools/` : petits outils hors jeu (dessin du plan, fabrication des matières de `assets/textures/`).
- `tests/` : tests automatiques des règles (`godot --headless --path . -s tests/run_tests.gd`).

## Principes

- Séparer strictement règles et affichage : l'état de partie est une donnée, les scènes l'affichent.
- Tout tirage aléatoire passe par le générateur de dés à graine (`DiceRoller`), pour rejouer et tester une partie.
- Chaque règle du livret implémentée doit avoir un test, en reprenant si possible l'exemple du livret.
- Ne pas recréer un jeu existant : s'inspirer du genre et des mécaniques seulement. Les noms et textes d'origine du livret sont provisoires, les droits restant à vérifier avant diffusion.

## Assets

Pipeline prévu : Higgsfield (images, fiches perso, 3D, audio) → retouche Blender → export glTF → import Godot. Nommer les fichiers en `snake_case` sans accents.
