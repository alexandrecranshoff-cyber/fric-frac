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
