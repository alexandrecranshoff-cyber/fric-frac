"""Vérifie un personnage riggé (GLB) dans Blender, sans écran.

Contrôles : maillage (sommets, triangles, UV), taille, squelette (os, hiérarchie),
peau (groupes de sommets, sommets sans poids, nombre d'influences), matière et
textures, animations. Écrit un rapport texte et, si demandé, des rendus Cycles de
face, de profil, de dos et dans une pose de contrôle qui fait travailler la peau.

Lancement, avec le module Python « bpy » (Blender 5.3) ou dans Blender :
    python tools/blender/verifier_personnage.py modele.glb dossier_sortie [--rendus]
    blender -b -P tools/blender/verifier_personnage.py -- modele.glb dossier_sortie --rendus
"""

import math
import os
import sys

import bpy
from mathutils import Euler, Vector

# Pose de contrôle : (os, rotation XYZ en degrés dans le repère de l'os)
CONTROL_POSE = [
	("LeftArm", (0, 0, 55)),
	("RightArm", (0, 0, -55)),
	("LeftForeArm", (0, 0, 60)),
	("RightForeArm", (0, 0, -60)),
	("LeftUpLeg", (-45, 0, 0)),
	("LeftLeg", (70, 0, 0)),
	("Spine01", (15, 0, 0)),
	("Head", (0, 25, 0)),
]


def arguments():
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
	renders = "--rendus" in args
	args = [a for a in args if a != "--rendus"]
	if len(args) != 2:
		sys.exit(__doc__)
	return args[0], args[1], renders


def reset_scene():
	bpy.ops.wm.read_factory_settings(use_empty=True)


def import_model(path):
	bpy.ops.import_scene.gltf(filepath=path)
	# L'importeur glTF crée une icosphère pour dessiner les os : on l'écarte.
	meshes = [o for o in bpy.context.scene.objects
		if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers)]
	armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
	return meshes, armatures


def mesh_report(lines, meshes):
	for obj in meshes:
		mesh = obj.data
		mesh.calc_loop_triangles()
		lines.append(f"Maillage « {obj.name} » : {len(mesh.vertices)} sommets, "
			f"{len(mesh.polygons)} faces, {len(mesh.loop_triangles)} triangles, "
			f"UV : {[uv.name for uv in mesh.uv_layers]}")
		corners = [Vector(c) for c in obj.bound_box]
		world = [obj.matrix_world @ c for c in corners]
		low = Vector((min(c.x for c in world), min(c.y for c in world), min(c.z for c in world)))
		high = Vector((max(c.x for c in world), max(c.y for c in world), max(c.z for c in world)))
		size = high - low
		lines.append(f"  Encombrement : largeur {size.x:.3f} m, profondeur {size.y:.3f} m, "
			f"hauteur {size.z:.3f} m (pieds à z = {low.z:.3f})")


def skeleton_report(lines, armatures):
	for arm in armatures:
		bones = arm.data.bones
		scale = arm.matrix_world.to_scale().x
		lines.append(f"Squelette « {arm.name} » : {len(bones)} os, échelle de l'objet {scale:g}")

		# Le glTF ne donne que la position des articulations : la longueur des os
		# dans Blender est devinée par l'importeur, on ne relève donc que leur hauteur.
		def walk(bone, depth):
			head = arm.matrix_world @ bone.head_local
			lines.append(f"  {'  ' * depth}{bone.name} (articulation à {head.z:.3f} m, "
				f"x = {head.x:+.3f})")
			for child in bone.children:
				walk(child, depth + 1)

		for root in [b for b in bones if b.parent is None]:
			walk(root, 0)


def skin_report(lines, meshes, armatures):
	bone_names = {b.name for a in armatures for b in a.data.bones}
	for obj in meshes:
		groups = {g.index: g.name for g in obj.vertex_groups}
		unknown = sorted(set(groups.values()) - bone_names)
		unused = sorted(bone_names - set(groups.values()))
		no_weight = 0
		max_influences = 0
		bad_sum = 0
		for v in obj.data.vertices:
			weights = [g.weight for g in v.groups if g.weight > 1e-4]
			if not weights:
				no_weight += 1
			max_influences = max(max_influences, len(weights))
			if weights and abs(sum(weights) - 1.0) > 0.02:
				bad_sum += 1
		modifiers = [m.type for m in obj.modifiers]
		lines.append(f"Peau de « {obj.name} » : {len(groups)} groupes, modificateurs {modifiers}")
		lines.append(f"  Sommets sans poids : {no_weight} ; influences au plus : {max_influences} ; "
			f"sommes de poids hors de 1 : {bad_sum}")
		lines.append(f"  Groupes sans os : {unknown or 'aucun'} ; os sans sommet : {unused or 'aucun'}")


def material_report(lines, meshes):
	for obj in meshes:
		for slot in obj.material_slots:
			mat = slot.material
			if mat is None:
				continue
			lines.append(f"Matière « {mat.name} »")
			for node in mat.node_tree.nodes:
				if node.type == "TEX_IMAGE" and node.image:
					img = node.image
					links = [l.to_socket.name for l in node.outputs["Color"].links]
					lines.append(f"  Texture {img.name} : {img.size[0]}×{img.size[1]}, "
						f"espace {img.colorspace_settings.name}, vers {links}")


def animation_report(lines):
	for action in bpy.data.actions:
		start, end = action.frame_range
		lines.append(f"Animation « {action.name} » : images {start:.0f} à {end:.0f}")


def apply_control_pose(arm):
	for name, degrees in CONTROL_POSE:
		bone = arm.pose.bones.get(name)
		if bone:
			bone.rotation_mode = "XYZ"
			bone.rotation_euler = Euler([math.radians(d) for d in degrees])


def setup_render(folder):
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = 48
	scene.cycles.use_denoising = True
	scene.render.resolution_x = 900
	scene.render.resolution_y = 1200
	scene.render.film_transparent = False
	scene.view_settings.view_transform = "Standard"
	world = bpy.data.worlds.new("fond")
	world.use_nodes = True
	world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.4, 0.38, 1)
	world.node_tree.nodes["Background"].inputs[1].default_value = 0.35
	scene.world = world
	# Éclairage trois points neutre, en rendu « Standard » sans courbe de tons :
	# on juge la texture telle quelle, pas l'ambiance
	for name, energy, location in [
		("cle", 220, (2.5, -3.0, 3.0)),
		("debouche", 70, (-3.0, -2.0, 1.8)),
		("contre", 160, (0.0, 3.5, 3.0)),
	]:
		light = bpy.data.lights.new(name, "AREA")
		light.energy = energy
		light.size = 2.0
		obj = bpy.data.objects.new(name, light)
		obj.location = location
		obj.rotation_euler = (Vector((0, 0, 0.9)) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
		scene.collection.objects.link(obj)
	cam_data = bpy.data.cameras.new("camera")
	cam_data.lens = 70
	cam = bpy.data.objects.new("camera", cam_data)
	scene.collection.objects.link(cam)
	scene.camera = cam
	os.makedirs(folder, exist_ok=True)
	return cam


def render_view(cam, angle_deg, path, height=0.85, distance=4.6):
	angle = math.radians(angle_deg)
	cam.location = (math.sin(angle) * distance, -math.cos(angle) * distance, height + 0.15)
	cam.rotation_euler = (Vector((0, 0, height)) - cam.location).to_track_quat("-Z", "Y").to_euler()
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)


def main():
	model, folder, renders = arguments()
	reset_scene()
	meshes, armatures = import_model(model)
	lines = [f"Modèle : {os.path.basename(model)} ({os.path.getsize(model) / 1e6:.1f} Mo)"]
	mesh_report(lines, meshes)
	skeleton_report(lines, armatures)
	skin_report(lines, meshes, armatures)
	material_report(lines, meshes)
	animation_report(lines)
	os.makedirs(folder, exist_ok=True)
	report = os.path.join(folder, "rapport.txt")
	with open(report, "w", encoding="utf-8") as f:
		f.write("\n".join(lines) + "\n")
	print("\n".join(lines))

	if renders:
		for arm in armatures:
			arm.animation_data_clear()
			for bone in arm.pose.bones:
				bone.rotation_mode = "QUATERNION"
				bone.rotation_quaternion = (1, 0, 0, 0)
				bone.location = (0, 0, 0)
		cam = setup_render(folder)
		for name, angle in [("face", 0), ("profil", 90), ("dos", 180), ("trois_quarts", 35)]:
			render_view(cam, angle, os.path.join(folder, f"vue_{name}.png"))
		for arm in armatures:
			apply_control_pose(arm)
		bpy.context.view_layer.update()
		render_view(cam, 35, os.path.join(folder, "vue_pose_controle.png"))
		render_view(cam, 20, os.path.join(folder, "vue_visage.png"), height=1.52, distance=1.25)


main()
