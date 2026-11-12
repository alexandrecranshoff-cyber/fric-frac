"""Rassemble des animations Higgsfield sur le modèle retouché d'un personnage.

Higgsfield rend une animation par fichier GLB, chacun avec sa copie du maillage.
Ce script garde le modèle retouché (texture rehaussée) et lui ajoute l'action de
chaque fichier, renommée, puis réexporte un seul GLB qui porte toutes les animations.

Les os doivent porter les mêmes noms. Le script compare aussi la position de
repos de chaque articulation : au-delà de la tolérance, l'animation est refusée,
car elle tordrait le maillage du modèle retouché.

Une marche qui avance d'elle-même (déplacement porté par les hanches) peut être
remise sur place en ajoutant « sur_place=nom1,nom2 » : le jeu déplace lui-même le
pion de case en case. Le script donne alors la distance parcourue par cycle, pour
accorder la vitesse du pion à celle des pas.

Lancement, avec le module Python « bpy » (Blender 5.3) ou dans Blender :
    python tools/blender/fusionner_animations.py modele.glb sortie.glb nom=animation.glb ... [sur_place=nom,...]
Exemple :
    python tools/blender/fusionner_animations.py chatte.glb chatte.glb attente=idle.glb marche_furtive=walk.glb
"""

import os
import sys

import bpy

TOLERANCE_M = 0.02  # écart toléré entre articulations au repos, en mètres


def arguments():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
	files = [a for a in args if "=" not in a]
	clips = [a.split("=", 1) for a in args if "=" in a and not a.startswith("sur_place=")]
	in_place = set()
	for a in args:
		if a.startswith("sur_place="):
			in_place.update(a.split("=", 1)[1].split(","))
	if len(files) != 2 or not clips:
		sys.exit(__doc__)
	return files[0], files[1], clips, in_place


def remove_drift(action, armature, bone="Hips"):
	"""Retire l'avancée nette des hanches : chaque composante perd sa pente du début à la fin.

	Une boucle de marche revient à la même hauteur : seule la part horizontale change.
	Rend la distance parcourue en un cycle, en mètres.
	"""
	path = f'pose.bones["{bone}"].location'
	start = {}
	end = {}
	curves = [c for c in fcurves(action) if c.data_path == path]
	for curve in curves:
		keys = curve.keyframe_points
		t0, v0 = keys[0].co
		t1, v1 = keys[-1].co
		start[curve.array_index] = v0
		end[curve.array_index] = v1
		for key in keys:
			shift = (v1 - v0) * (key.co[0] - t0) / (t1 - t0)
			key.co[1] -= shift
			key.handle_left[1] -= shift
			key.handle_right[1] -= shift
		curve.update()
	delta = [end.get(i, 0) - start.get(i, 0) for i in range(3)]
	pose_bone = armature.pose.bones[bone]
	world = armature.matrix_world.to_3x3() @ pose_bone.bone.matrix_local.to_3x3()
	from mathutils import Vector
	return (world @ Vector(delta)).length


def fcurves(action):
	"""Courbes d'une action, qu'elle soit à l'ancienne ou en couches (Blender 4.4 et plus)."""
	if hasattr(action, "layers") and action.layers:
		for layer in action.layers:
			for strip in layer.strips:
				for bag in strip.channelbags:
					yield from bag.fcurves
	else:
		yield from action.fcurves


def imported_objects(path):
	before = set(bpy.data.objects)
	actions_before = set(bpy.data.actions)
	bpy.ops.import_scene.gltf(filepath=path)
	objects = [o for o in bpy.data.objects if o not in before]
	actions = [a for a in bpy.data.actions if a not in actions_before]
	return objects, actions


def joints(armature):
	return {b.name: armature.matrix_world @ b.head_local for b in armature.data.bones}


def main():
	base_path, target, clips, in_place = arguments()
	bpy.ops.wm.read_factory_settings(use_empty=True)
	objects, _ = imported_objects(base_path)
	armature = next(o for o in objects if o.type == "ARMATURE")
	mesh = next(o for o in objects if o.type == "MESH" and o.parent == armature)
	# L'instant de pose vide du modèle brut ne doit pas repartir dans l'export.
	armature.animation_data_clear()
	for action in list(bpy.data.actions):
		bpy.data.actions.remove(action)
	base_joints = joints(armature)
	armature.animation_data_create()
	report = []

	for name, path in clips:
		objects, actions = imported_objects(path)
		other = next(o for o in objects if o.type == "ARMATURE")
		other_joints = joints(other)
		missing = sorted(set(base_joints) - set(other_joints))
		if missing:
			sys.exit(f"{path} : os absents {missing}")
		gap = max((base_joints[b] - other_joints[b]).length for b in base_joints)
		if gap > TOLERANCE_M:
			sys.exit(f"{path} : squelette différent au repos (écart {gap:.3f} m)")
		action = max(actions, key=lambda a: a.frame_range[1] - a.frame_range[0])
		action.name = name
		action.use_fake_user = True
		drift = ""
		if name in in_place:
			drift = f", remise sur place ({remove_drift(action, armature):.2f} m par cycle)"
		# Une piste NLA par animation : l'exporteur en fait autant d'animations glTF.
		track = armature.animation_data.nla_tracks.new()
		track.name = name
		start = int(action.frame_range[0])
		track.strips.new(name, start, action)
		start_f, end_f = action.frame_range
		report.append(f"{name} : {end_f - start_f + 1:.0f} images, écart de repos {gap * 1000:.1f} mm{drift}")
		for obj in objects:
			bpy.data.objects.remove(obj, do_unlink=True)
		for extra in actions:
			if extra != action:
				bpy.data.actions.remove(extra)

	bpy.ops.object.select_all(action="DESELECT")
	mesh.select_set(True)
	armature.select_set(True)
	bpy.ops.export_scene.gltf(
		filepath=target,
		export_format="GLB",
		use_selection=True,
		export_image_format="AUTO",
		export_animations=True,
		export_animation_mode="NLA_TRACKS",
		export_skins=True,
		export_yup=True,
	)
	print("\n".join(report))
	print(f"Écrit : {target} ({os.path.getsize(target) / 1e6:.1f} Mo)")


main()
