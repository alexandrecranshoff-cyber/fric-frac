"""Rehausse la texture de couleur d'un personnage GLB dans Blender, sans écran.

Les modèles sortis de Higgsfield (Meshy) ont des couleurs grisées : noirs levés,
cuirs et cordes ternes, détails du tricot noyés. Ce script reprend la texture de
couleur de base, sans toucher à la forme, aux UV, au squelette ni aux poids :
  1. point noir : les noirs levés redeviennent noirs ;
  2. contraste autour d'un pivot sombre (le personnage est vêtu de noir) ;
  3. saturation : les teintes franches (cuir, corde, peau) reprennent de la couleur,
     les gris presque neutres (tissus noirs) restent neutres, la peau gagne moins ;
  4. clarté : contraste local à petit rayon, qui fait ressortir mailles et coutures.
Il retire aussi l'émission, inutile (texture noire), puis réexporte le GLB.

Lancement, avec le module Python « bpy » (Blender 5.3) ou dans Blender :
    python tools/blender/rehausser_texture.py source.glb sortie.glb [réglage=valeur ...]
Réglages (valeurs par défaut ci-dessous) : noir, pivot, contraste, saturation,
tons_clairs, neutre, clarte, rayon. Exemple : saturation=1.8 clarte=0.5
"""

import os
import sys

import bpy
import numpy as np

DEFAULTS = {
	"noir": 0.035,       # point noir, en valeur sRGB 0..1
	"pivot": 0.22,       # valeur qui ne bouge pas sous le contraste
	"contraste": 1.45,
	"saturation": 2.1,
	"tons_clairs": 0.45,  # part du gain de saturation retirée aux tons clairs (peau)
	"neutre": 0.04,      # écart entre composantes sous lequel une couleur est un gris
	"clarte": 0.8,       # force du contraste local
	"rayon": 5,          # rayon du contraste local, en pixels de texture
}

LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def arguments():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
	files = [a for a in args if "=" not in a]
	if len(files) != 2:
		sys.exit(__doc__)
	settings = dict(DEFAULTS)
	for a in args:
		if "=" in a:
			key, value = a.split("=", 1)
			if key not in settings:
				sys.exit(f"Réglage inconnu : {key}")
			settings[key] = type(DEFAULTS[key])(float(value))
	return files[0], files[1], settings


def box_blur(img, radius):
	"""Flou en boîte séparable (sommes cumulées), bords répétés."""
	out = img
	for axis in (0, 1):
		pad = [(0, 0)] * img.ndim
		pad[axis] = (radius + 1, radius)
		padded = np.pad(out, pad, mode="edge")
		cumsum = np.cumsum(padded, axis=axis, dtype=np.float64)
		size = out.shape[axis]
		upper = np.take(cumsum, np.arange(2 * radius + 1, 2 * radius + 1 + size), axis=axis)
		lower = np.take(cumsum, np.arange(0, size), axis=axis)
		out = ((upper - lower) / (2 * radius + 1)).astype(np.float32)
	return out


def contrast_curve(rgb, pivot, contrast):
	"""Courbe en S sur la luminance, appliquée en gardant la teinte.

	Sous le pivot, une puissance creuse les ombres (0 reste 0) ; au-dessus, une
	courbe à épaule ramène 1 sur 1 sans écrêter : la peau ne vire pas au blanc jaune.
	"""
	luma = np.maximum(rgb @ LUMA, 1e-5)
	low = pivot * np.power(luma / pivot, contrast)
	t = (luma - pivot) / (1.0 - pivot)
	high = pivot + (1.0 - pivot) * t * contrast / (1.0 + (contrast - 1.0) * t)
	target = np.where(luma < pivot, low, high)
	scaled = rgb * (target / luma)[..., None]
	# Une composante qui dépasserait 1 est ramenée vers la luminance, sans saut de teinte.
	excess = np.maximum(scaled.max(axis=2), 1.0)
	return np.clip(target[..., None] + (scaled - target[..., None]) / excess[..., None], 0.0, 1.0)


def grade(rgb, s):
	"""Étalonnage d'une image sRGB (hauteur, largeur, 3) en flottants 0..1."""
	rgb = np.clip((rgb - s["noir"]) / (1.0 - s["noir"]), 0.0, 1.0)
	rgb = contrast_curve(rgb, s["pivot"], s["contraste"])
	luma = rgb @ LUMA
	# Les tons clairs (peau, reflets) gagnent moins : sinon la peau tourne au jaune.
	light = np.clip((luma - 0.2) / 0.3, 0.0, 1.0)
	# Les gris presque neutres (tissus noirs) restent neutres : sinon leur légère
	# dominante tourne au violet. Seules les teintes déjà franches sont poussées.
	chroma = rgb.max(axis=2) - rgb.min(axis=2)
	franc = np.clip((chroma - s["neutre"]) / s["neutre"], 0.0, 1.0)
	gain = 1.0 + (s["saturation"] - 1.0) * (1.0 - s["tons_clairs"] * light) * franc
	rgb = np.clip(luma[..., None] + (rgb - luma[..., None]) * gain[..., None], 0.0, 1.0)
	if s["clarte"] > 0:
		luma = rgb @ LUMA
		detail = luma - box_blur(luma, int(s["rayon"]))
		rgb = np.clip(rgb + detail[..., None] * s["clarte"], 0.0, 1.0)
	return rgb


def base_color_node(material):
	bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	link = bsdf.inputs["Base Color"].links[0]
	return bsdf, link.from_node


def drop_emission(material, bsdf):
	nodes = material.node_tree.nodes
	for link in list(bsdf.inputs["Emission Color"].links):
		nodes.remove(link.from_node)
	bsdf.inputs["Emission Color"].default_value = (0, 0, 0, 1)
	bsdf.inputs["Emission Strength"].default_value = 0.0


def name_textures(material, color_node):
	"""Nomme les textures : Godot les extrait sous « <modèle>_<nom>.png »."""
	for node in material.node_tree.nodes:
		if node.type != "TEX_IMAGE" or node.image is None or node == color_node:
			continue
		targets = {l.to_node.type for out in node.outputs for l in out.links}
		if "NORMAL_MAP" in targets:
			node.image.name = "normales"
		else:
			node.image.name = "metal_rugosite"


def stats(rgb):
	maxc, minc = rgb.max(axis=2), rgb.min(axis=2)
	sat = np.where(maxc > 1e-4, (maxc - minc) / np.maximum(maxc, 1e-4), 0)
	return f"moyenne {rgb.mean():.3f}, écart {rgb.std():.3f}, saturation {sat.mean():.3f}"


def main():
	source, target, settings = arguments()
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=source)
	mesh = next(o for o in bpy.context.scene.objects
		if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers))
	material = mesh.material_slots[0].material
	bsdf, tex_node = base_color_node(material)
	image = tex_node.image
	width, height = image.size

	pixels = np.empty(width * height * 4, dtype=np.float32)
	image.pixels.foreach_get(pixels)
	pixels = pixels.reshape(height, width, 4)
	before = stats(pixels[..., :3])
	pixels[..., :3] = grade(pixels[..., :3], settings)
	after = stats(pixels[..., :3])

	graded = bpy.data.images.new("couleur", width, height, alpha=False)
	graded.colorspace_settings.name = "sRGB"
	graded.pixels.foreach_set(pixels.ravel())
	graded.file_format = "PNG"  # sans perte : Godot la recompresse à l'import
	tex_node.image = graded
	drop_emission(material, bsdf)
	name_textures(material, tex_node)

	bpy.ops.object.select_all(action="DESELECT")
	mesh.select_set(True)
	mesh.parent.select_set(True)
	os.makedirs(os.path.dirname(os.path.abspath(target)), exist_ok=True)
	bpy.ops.export_scene.gltf(
		filepath=target,
		export_format="GLB",
		use_selection=True,
		export_image_format="AUTO",
		export_animations=True,
		export_skins=True,
		export_yup=True,
	)
	print(f"Couleur avant : {before}")
	print(f"Couleur après : {after}")
	print(f"Réglages : {settings}")
	print(f"Écrit : {target} ({os.path.getsize(target) / 1e6:.1f} Mo)")


main()
