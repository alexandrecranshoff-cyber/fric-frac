# Fric-Frac

Jeu de cambriolage tactique au tour par tour, en 3D et jouable dans le navigateur : des gentlemen cambrioleurs pénètrent dans une villa de Neuilly pour rafler le plus de butin possible sans se faire voir des gardes, ni réveiller les dormeurs.

Adapté du jeu de plateau paru en encart de Jeux & Stratégie (1982). Projet en cours : voir `CLAUDE.md` pour les étapes.

## Prérequis

- [Godot 4.6](https://godotengine.org/download)
- [Git LFS](https://git-lfs.com/) (`git lfs install` une fois sur la machine)
- [Blender](https://www.blender.org/) pour les assets 3D

## Démarrer

```bash
git clone https://github.com/alexandrecranshoff-cyber/fric-frac
cd fric-frac
git lfs pull
```

Puis ouvrir le dossier dans Godot (Importer > `project.godot`).

## Tests

```bash
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```

## Plan de la villa

Le plan relevé sur le plateau est dans `data/villa.json`. Pour le voir, ouvrir `docs/plan_villa.svg`. Après une retouche du plan :

```bash
python3 tools/dessiner_plan.py
```

## Maquette 3D de la villa

Lancer le projet dans Godot (F5) affiche la villa en 3D, construite depuis `data/villa.json` : sols en matières (parquet, carrelage, moquette, dallage, herbe, gravier), murs coupés à hauteur d'appui, portes, fenêtres, tapis des salons, mur d'enceinte et grille, arbres et gardes. Les murs sont redressés comme sur le poster ; le quadrillage du jeu reste tracé sur les sols.

- Clic droit glissé : tourner et incliner. Clic gauche glissé ou flèches : déplacer. Molette : zoom.
- Q / E : tourner d'un côté de case. L : lettres des pièces. Début : vue de départ.
- Écran tactile : un doigt déplace, deux doigts zooment et tournent.

Pour enregistrer les vues de contrôle ou un tour filmé image par image :

```bash
godot --path . -- vues=/tmp/vues
godot --path . -- film=/tmp/film
```

Les matières sont calculées, pas photographiées : `python3 tools/generer_textures.py` les refabrique à l'identique dans `assets/textures/` (numpy et Pillow).
