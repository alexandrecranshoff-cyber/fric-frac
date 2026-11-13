#!/usr/bin/env python3
"""Fait une matière de la villa (couleur, normales, rugosité) à partir d'une image Higgsfield.

  1. recadre l'image au carré et la met à la taille voulue (2048 par défaut) ;
  2. si demandé (raccord=oui), efface les raccords : l'image est fondue avec elle-même décalée d'une
     demi-largeur, près des bords seulement. À réserver aux matières sans motif régulier (herbe,
     gravier, moquette) : sur un parquet ou un carrelage, le fondu dédoublerait les joints ;
  3. tire un relief de la clarté (les joints sombres sont en creux), puis les normales de ce relief,
     en se raccordant aux bords comme la couleur ;
  4. la rugosité suit le relief : les creux (joints) sont plus mats, réglée par rugosite=min,max.

Écrit dans assets/textures/villa/ (suivi par Git LFS, contrairement aux petites matières calculées) : <nom>.jpg (couleur), <nom>_normales.jpg, <nom>_rugosite.jpg.

Usage : python3 tools/preparer_matiere.py image.png nom [taille=2048] [raccord=oui] [relief=2.0]
        [rugosite=0.55,0.9] [flou=1.0] [clarte=1.0]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "textures" / "villa"
DEFAULTS = {"taille": "2048", "raccord": "non", "relief": "2.0", "rugosite": "0.55,0.9", "flou": "1.0",
	"clarte": "1.0"}


def seamless(image: np.ndarray) -> np.ndarray:
	"""Fond l'image avec sa copie décalée d'une demi-largeur, là où elle touche les bords."""
	size = image.shape[0]
	shifted = np.roll(image, (size // 2, size // 2), axis=(0, 1))
	ramp = np.abs(np.linspace(-1.0, 1.0, size))
	edge = np.clip((ramp - 0.55) / 0.45, 0.0, 1.0)
	mask = np.maximum(edge[:, None], edge[None, :])
	mask = mask * mask * (3.0 - 2.0 * mask)
	return image * (1.0 - mask[..., None]) + shifted * mask[..., None]


def main() -> None:
	args = sys.argv[1:]
	if len(args) < 2:
		sys.exit(__doc__)
	source, name = args[0], args[1]
	settings = dict(DEFAULTS)
	for item in args[2:]:
		key, value = item.split("=", 1)
		if key not in settings:
			sys.exit("Réglage inconnu : " + key)
		settings[key] = value
	size = int(settings["taille"])

	image = Image.open(source).convert("RGB")
	side = min(image.size)
	left = (image.width - side) // 2
	top = (image.height - side) // 2
	image = image.crop((left, top, left + side, top + side)).resize((size, size), Image.LANCZOS)
	color = np.asarray(image, dtype=np.float64) / 255.0
	if settings["raccord"] == "oui":
		color = seamless(color)
	color = np.clip(color * float(settings["clarte"]), 0.0, 1.0)

	# Relief : la clarté, adoucie, centrée. Les gradients se calculent en boucle (np.roll) : la matière se répète.
	luma = color @ np.array([0.2126, 0.7152, 0.0722])
	blurred = Image.fromarray((luma * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(float(settings["flou"])))
	height = np.asarray(blurred, dtype=np.float64) / 255.0
	height -= height.mean()
	strength = float(settings["relief"]) * size / 512.0
	dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5 * strength
	dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5 * strength
	normal = np.stack([-dx, dy, np.ones_like(dx)], axis=-1)
	normal /= np.linalg.norm(normal, axis=-1, keepdims=True)

	low, high = (float(v) for v in settings["rugosite"].split(","))
	spread = (height - height.min()) / max(height.max() - height.min(), 1e-6)
	rough = high - (high - low) * spread

	OUT.mkdir(parents=True, exist_ok=True)
	# En JPEG de qualité 92 : quatre fois plus léger que le PNG, et Godot recompresse de toute façon en BPTC.
	Image.fromarray((color * 255 + 0.5).astype(np.uint8)).save(OUT / f"{name}.jpg", quality=92)
	Image.fromarray(((normal * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8)).save(OUT / f"{name}_normales.jpg", quality=92)
	Image.fromarray((rough * 255 + 0.5).astype(np.uint8)).save(OUT / f"{name}_rugosite.jpg", quality=92)
	print(f"{name} : {size} px, raccord {settings['raccord']}, couleur moyenne {color.mean():.3f}")


main()
