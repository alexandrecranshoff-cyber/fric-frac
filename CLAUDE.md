# Fric-Frac

Jeu vidéo de cambriolage tactique au tour par tour, adapté du jeu de plateau « Fric-Frac » (encart de Jeux & Stratégie, 1982). Moteur : **Godot 4.6**, GDScript. Projet frère de « Délire à la cantine », dont il reprend l'organisation.

## Méthode de travail

- Le projet avance par étapes. **Chaque étape est validée par Alexandre avant de passer à la suivante.**
- Étapes prévues : structure du dépôt, transcription des règles et du plan de la villa, document de game design, moteur de règles et tests, visuels de référence, maquette grise jouable, habillage, versions web et PC, essais de jeu.

## Cible et décisions de design

- Plateforme : navigateur (export web Godot, rendu Compatibilité / WebGL 2) et PC. Garder les assets légers.
- Plateau hexagonal : la villa de Neuilly, son jardin et ses gardes.
- Les autres décisions (points d'action, modes de jeu, style graphique) seront prises dans le document de game design (étape 3) et reportées ici.

## Langue

Communication, documentation et messages de commit en français. Code (noms de variables, fonctions, classes) en anglais, commentaires en français.

## Structure

- `docs/regles-originales.md` : règles du jeu de plateau, référence du moteur de règles.
- `docs/interpretations-regles.md` : ce que le livret laisse flou et la lecture retenue.
- `docs/plan_villa.svg` : plan redessiné depuis `data/villa.json` par `tools/dessiner_plan.py`. À régénérer après toute retouche du plan.
- `data/` : valeurs chiffrées (tables d'effraction, de combat, de butin, équipement, plan de la villa) en JSON. Ne jamais dupliquer ces chiffres en dur dans le code.
- `scripts/rules/` : moteur de règles pur (aucune dépendance aux nœuds de scène), entièrement testable.
- `scripts/ai/` : comportement des pions automatiques (gardes, dormeurs, voleurs adverses joués par l'ordinateur).
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
