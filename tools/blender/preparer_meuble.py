"""Prépare un meuble GLB sorti de Higgsfield (SAM 3 3D ou Tripo) pour le jeu, dans Blender sans écran.

  1. rassemble ses maillages en un seul objet, transformations appliquées ;
  2. le tourne d'un quart de tour si demandé (la longueur d'un meuble de deux cases doit suivre x) ;
  3. allège le maillage jusqu'au nombre de triangles visé ;
  4. pose son origine au centre de sa base, et le met à la hauteur voulue (même échelle partout) ;
  5. renomme ses textures (couleur, normales, metal_rugosite) et réexporte le GLB.

Le jeu le cale ensuite sur ses cases (pieces_view.gd) : ici on ne fait que le nettoyer.

Lancement, avec le module Python « bpy » (Blender 5.3) ou dans Blender :
    python tools/blender/preparer_meuble.py source.glb sortie.glb [réglage=valeur ...]
Réglages : hauteur (m, 1.0), triangles (12000), quart (quarts de tour autour de la verticale, 0).
"""

import math
import os
import sys

import bpy
import mathutils

DEFAULTS = {"hauteur": 1.0, "triangles": 12000.0, "quart": 0.0}


def main() -> None:
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
	if len(args) < 2:
		print(__doc__)
		sys.exit(1)
	source, target = args[0], args[1]
	settings = dict(DEFAULTS)
	for item in args[2:]:
		key, value = item.split("=", 1)
		if key not in settings:
			sys.exit("Réglage inconnu : " + key)
		settings[key] = float(value)

	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=os.path.abspath(source))
	meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	if not meshes:
		sys.exit("Aucun maillage dans " + source)
	bpy.ops.object.select_all(action="DESELECT")
	for o in meshes:
		o.select_set(True)
	bpy.context.view_layer.objects.active = meshes[0]
	if len(meshes) > 1:
		bpy.ops.object.join()
	obj = bpy.context.view_layer.objects.active
	# Sortir des éventuels parents (nœuds vides de l'import), en gardant la place.
	bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
	for o in list(bpy.context.scene.objects):
		if o != obj:
			bpy.data.objects.remove(o, do_unlink=True)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	obj.data.transform(mathutils.Matrix.Rotation(settings["quart"] * math.pi / 2, 4, "Z"))

	before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
	if before > settings["triangles"]:
		decimate = obj.modifiers.new("allegement", "DECIMATE")
		decimate.ratio = settings["triangles"] / before
		bpy.ops.object.modifier_apply(modifier=decimate.name)
	after = sum(len(p.vertices) - 2 for p in obj.data.polygons)

	corners = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
	low = mathutils.Vector([min(c[i] for c in corners) for i in range(3)])
	high = mathutils.Vector([max(c[i] for c in corners) for i in range(3)])
	scale = settings["hauteur"] / max(high.z - low.z, 1e-6)
	base = mathutils.Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
	obj.data.transform(mathutils.Matrix.Scale(scale, 4) @ mathutils.Matrix.Translation(-base))
	obj.location = (0, 0, 0)
	obj.name = os.path.splitext(os.path.basename(target))[0]
	size = (high - low) * scale
	print("triangles %d -> %d ; taille %.2f x %.2f x %.2f m (largeur, profondeur, hauteur)" % (
		before, after, size.x, size.y, size.z))

	# Noms de textures lisibles : Godot les extrait en <meuble>_couleur.png, <meuble>_normales.png...
	for image in bpy.data.images:
		role = "normales" if "normal" in image.name.lower() else ("metal_rugosite" if "orm" in image.name.lower() else "couleur")
		image.name = role
	os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=os.path.abspath(target), export_format="GLB", use_selection=False,
		export_yup=True, export_apply=True)


main()
