"""Ajoute des os de doigts à un personnage Higgsfield et lui ferme les mains à demi.

Le squelette Higgsfield s'arrête au poignet : les mains restent grandes ouvertes,
ce qui paraît figé. Pour chaque main, le script :
  1. repère dans le gant la paume, les quatre doigts (au-delà des jointures) et le
     pouce (qui part vers l'avant), d'après la position des sommets ;
  2. ajoute trois os : doigts (jointures), bouts des doigts (seconde phalange), pouce ;
  3. reprend aux poids de la main la part de ces os, avec un fondu aux jointures ;
  4. pose ces os, doigts repliés vers la paume, dans chaque animation.

Les doigts plient ensemble, comme une main gantée au repos : assez pour un jeu vu
d'en haut, sans os par doigt.

Lancement, avec le module Python « bpy » (Blender 5.3) ou dans Blender :
    python tools/blender/ajouter_doigts.py modele.glb sortie.glb [réglage=valeur ...]
Réglages (valeurs par défaut ci-dessous) : jointure, phalange, pouce_avant,
pli_doigts, pli_bouts, pli_pouce, pouce_vers_doigts. Exemple : pli_doigts=60
"""

import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

DEFAULTS = {
	"jointure": 0.095,     # distance du poignet aux jointures, en mètres, le long de la main
	"phalange": 0.135,     # distance du poignet à la seconde phalange
	"fondu": 0.012,        # largeur du fondu des poids aux articulations
	"pouce_avant": 0.032,  # écart vers l'avant au-delà duquel un sommet est au pouce
	"pli_doigts": 80.0,    # pli aux jointures, en degrés
	"pli_bouts": 75.0,     # pli de la seconde phalange
	"pli_pouce": 70.0,     # pouce rabattu vers la paume
	"pouce_vers_doigts": 35.0,  # pouce ramené le long des doigts
}


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
			settings[key] = float(value)
	return files[0], files[1], settings


def smoothstep(edge0, edge1, x):
	t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
	return t * t * (3 - 2 * t)


def fcurves(action):
	"""Courbes d'une action en couches (Blender 4.4 et plus) ou à l'ancienne."""
	if hasattr(action, "layers") and action.layers:
		for layer in action.layers:
			for strip in layer.strips:
				for bag in strip.channelbags:
					yield from bag.fcurves
	else:
		yield from action.fcurves


class Hand:
	"""Repère d'une main : poignet, axe de la main, avant (vers le pouce), paume."""

	def __init__(self, armature, side):
		self.side = side
		hand = armature.data.bones[side + "Hand"]
		forearm = armature.data.bones[side + "ForeArm"]
		self.wrist = armature.matrix_world @ hand.head_local
		elbow = armature.matrix_world @ forearm.head_local
		self.along = (self.wrist - elbow).normalized()
		forward = Vector((0, -1, 0))  # le personnage regarde vers -Y dans Blender
		self.forward = (forward - forward.dot(self.along) * self.along).normalized()
		# La paume regarde la cuisse : vers l'axe du corps.
		inward = Vector((-math.copysign(1.0, self.wrist.x), 0, 0))
		inward -= inward.dot(self.along) * self.along + inward.dot(self.forward) * self.forward
		self.palm = inward.normalized()

	def local(self, point):
		p = point - self.wrist
		return p.dot(self.along), p.dot(self.forward), p.dot(self.palm)


def classify(mesh, hand, s):
	"""Poids de chaque nouvel os pour les sommets de la main : {index: (doigts, bouts, pouce)}."""
	group = mesh.vertex_groups[hand.side + "Hand"].index
	result = {}
	thumb_points = []
	for v in mesh.data.vertices:
		weight = next((g.weight for g in v.groups if g.group == group), 0.0)
		if weight < 0.05:
			continue
		a, f, _ = hand.local(mesh.matrix_world @ v.co)
		thumb = smoothstep(s["pouce_avant"] - s["fondu"], s["pouce_avant"], f) * (1.0 - smoothstep(s["jointure"], s["jointure"] + s["fondu"], a))
		fingers = smoothstep(s["jointure"] - s["fondu"], s["jointure"] + s["fondu"], a) * (1.0 - thumb)
		tips = smoothstep(s["phalange"] - s["fondu"], s["phalange"] + s["fondu"], a) * (1.0 - thumb)
		if fingers > 0 or thumb > 0:
			result[v.index] = (weight, fingers - tips, tips, thumb)
		if thumb > 0.9:
			thumb_points.append((a, f, mesh.matrix_world @ v.co))
	return result, thumb_points


def add_bones(armature, hand, s, thumb_points):
	"""Trois os par main, dans le repère du squelette, roulis aligné sur la paume."""
	to_local = armature.matrix_world.inverted()
	knuckle = hand.wrist + hand.along * s["jointure"] + hand.forward * 0.012
	middle = hand.wrist + hand.along * s["phalange"] + hand.forward * 0.012
	tip = hand.wrist + hand.along * (s["phalange"] + 0.04) + hand.forward * 0.012
	thumb_points.sort(key=lambda p: p[1])
	base = sum((p[2] for p in thumb_points[: max(len(thumb_points) // 5, 1)]), Vector()) / max(len(thumb_points) // 5, 1)
	end = sum((p[2] for p in thumb_points[-max(len(thumb_points) // 5, 1):]), Vector()) / max(len(thumb_points) // 5, 1)
	bpy.context.view_layer.objects.active = armature
	bpy.ops.object.mode_set(mode="EDIT")
	bones = armature.data.edit_bones
	parent = bones[hand.side + "Hand"]
	palm_local = (to_local.to_3x3() @ hand.palm).normalized()
	names = {}
	for key, head, tail, bone_parent in [
		("doigts", knuckle, middle, parent),
		("bouts", middle, tip, None),
		("pouce", base, end, parent),
	]:
		bone = bones.new(f"{hand.side}Hand{key.capitalize()}")
		bone.head = to_local @ head
		bone.tail = to_local @ tail
		bone.align_roll(palm_local)
		bone.parent = bone_parent or bones[names["doigts"]]
		bone.use_connect = False
		names[key] = bone.name
		if key == "pouce":
			# Sens de rotation autour de l'axe Z local qui ramène le bout du pouce vers les doigts.
			x_world = (armature.matrix_world.to_3x3() @ bone.x_axis).normalized()
			thumb_sign = -1.0 if x_world.dot(hand.along) > 0 else 1.0
	bpy.ops.object.mode_set(mode="OBJECT")
	return names, thumb_sign


def reweight(mesh, hand, weights, names):
	hand_group = mesh.vertex_groups[hand.side + "Hand"]
	groups = [mesh.vertex_groups.new(name=names[k]) for k in ("doigts", "bouts", "pouce")]
	for index, (weight, fingers, tips, thumb) in weights.items():
		taken = 0.0
		for group, part in zip(groups, (fingers, tips, thumb)):
			if part > 1e-3:
				group.add([index], weight * part, "REPLACE")
				taken += weight * part
		hand_group.add([index], max(weight - taken, 0.0), "REPLACE")


def pose_of(key, side_names, s):
	"""Rotation locale d'un os : repli autour de X (vers la paume), et pour le pouce,
	un pivot autour de Z qui le ramène le long des doigts."""
	angles = {"doigts": s["pli_doigts"], "bouts": s["pli_bouts"], "pouce": s["pli_pouce"]}
	q = Quaternion((1, 0, 0), math.radians(angles[key]))
	if key == "pouce":
		swing = Quaternion((0, 0, 1), math.radians(s["pouce_vers_doigts"]) * side_names["signe_pouce"])
		q = q @ swing
	return q


def bones_of(side_names):
	return {k: v for k, v in side_names.items() if k in ("doigts", "bouts", "pouce")}


def curl_keys(armature, names, s):
	"""Pose constante des nouveaux os dans chaque action."""
	data = armature.animation_data or armature.animation_data_create()
	previous = data.action
	for action in bpy.data.actions:
		start, end = action.frame_range
		data.action = action  # Blender 5 n'ajoute une courbe qu'à l'action en place
		for side_names in names:
			for key, bone in bones_of(side_names).items():
				q = pose_of(key, side_names, s)
				path = f'pose.bones["{bone}"].rotation_quaternion'
				for i in range(4):
					curve = action.fcurve_ensure_for_datablock(armature, path, index=i, group_name=bone)
					for frame in (start, end):
						curve.keyframe_points.insert(frame, q[i], options={"FAST"})
	data.action = previous
	print(f"Pistes d'animation : {[t.name for t in data.nla_tracks]}")
	for side_names in names:
		for key, bone in bones_of(side_names).items():
			pose = armature.pose.bones[bone]
			pose.rotation_mode = "QUATERNION"
			pose.rotation_quaternion = pose_of(key, side_names, s)


def main():
	source, target, s = arguments()
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=source)
	armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
	mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH" and o.parent == armature)
	if "LeftHandDoigts" in armature.data.bones:
		sys.exit("Ce modèle a déjà ses os de doigts.")
	all_names = []
	for side in ("Left", "Right"):
		hand = Hand(armature, side)
		weights, thumb_points = classify(mesh, hand, s)
		if len(thumb_points) < 10:
			sys.exit(f"Main {side} : pouce introuvable, régler pouce_avant.")
		names, thumb_sign = add_bones(armature, hand, s, thumb_points)
		names = dict(names, signe_pouce=thumb_sign)
		reweight(mesh, hand, weights, names)
		all_names.append(names)
		fingers = sum(1 for w in weights.values() if w[1] + w[2] > 0.5)
		thumbs = sum(1 for w in weights.values() if w[3] > 0.5)
		print(f"Main {side} : {fingers} sommets aux doigts, {thumbs} au pouce")
	curl_keys(armature, all_names, s)

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
	print(f"Écrit : {target} ({os.path.getsize(target) / 1e6:.1f} Mo)")


main()
