"""Coupe une animation Higgsfield pour en faire une boucle propre, dans Blender sans écran.

Certaines animations de la bibliothèque commencent et finissent à l'arrêt (« Walk_Slowly_and_Look_Around » :
le personnage attend deux secondes avant de partir). Le script cherche, dans les deux fenêtres données, l'image
de départ et l'image de fin dont les poses se ressemblent le plus (position de chaque os par rapport aux
hanches), efface les images hors de cet intervalle et ramène le départ à l'image 0. Il réécrit le GLB, que
fusionner_animations.py peut ensuite prendre comme n'importe quelle animation.

Lancement, avec le module Python « bpy » (Blender 5.3) ou dans Blender :
    python tools/blender/couper_boucle.py animation.glb sortie.glb debut_min debut_max fin_min fin_max
Exemple (ronde du garde) :
    python tools/blender/couper_boucle.py ronde.glb ronde_coupee.glb 55 110 460 530
"""

import os
import sys

import bpy


def fcurves(action):
	"""Courbes d'une action, qu'elle soit à l'ancienne ou en couches (Blender 4.4 et plus)."""
	if hasattr(action, "layers") and action.layers:
		for layer in action.layers:
			for strip in layer.strips:
				for bag in strip.channelbags:
					yield from bag.fcurves
	else:
		yield from action.fcurves


def main() -> None:
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
	if len(args) != 6:
		sys.exit(__doc__)
	source, target = args[0], args[1]
	a0, a1, b0, b1 = (int(v) for v in args[2:])
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=os.path.abspath(source))
	armature = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
	# L'animation est la plus longue action du fichier (l'autre est l'instant de pose du modèle brut).
	action = max(bpy.data.actions, key=lambda a: a.frame_range[1] - a.frame_range[0])
	armature.animation_data.action = action

	def pose(frame):
		bpy.context.scene.frame_set(frame)
		hips = armature.matrix_world @ armature.pose.bones["Hips"].head
		return [(armature.matrix_world @ b.head) - hips for b in armature.pose.bones]

	starts = {f: pose(f) for f in range(a0, a1)}
	best = None
	for end in range(b0, b1):
		end_pose = pose(end)
		for start, start_pose in starts.items():
			gap = sum((x - y).length for x, y in zip(start_pose, end_pose))
			if best is None or gap < best[0]:
				best = (gap, start, end)
	gap, start, end = best
	for curve in fcurves(action):
		keys = curve.keyframe_points
		for i in range(len(keys) - 1, -1, -1):
			if keys[i].co.x < start or keys[i].co.x > end:
				keys.remove(keys[i])
		for key in keys:
			key.co.x -= start
			key.handle_left.x -= start
			key.handle_right.x -= start
		curve.update()
	action.frame_range = (0, end - start)
	print("Coupe aux images %d et %d (%d images), écart des poses %.3f m pour %d os" % (
		start, end, end - start + 1, gap, len(armature.pose.bones)))
	bpy.ops.export_scene.gltf(filepath=os.path.abspath(target), export_format="GLB", export_yup=True,
		export_animation_mode="ACTIONS")


main()
