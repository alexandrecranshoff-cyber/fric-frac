extends Node3D
## Banc d'essai d'un personnage : le modèle sur un parquet, sous deux éclairages.
##   Atelier : lumière neutre, pour juger la texture telle qu'elle est.
##   Nuit : lampe à pétrole et clair de lune, l'ambiance prévue pour le jeu.
##
## Commandes : clic droit glissé pour tourner autour, molette pour le zoom,
## L pour changer d'éclairage, Espace pour arrêter ou relancer le tourniquet,
## P pour la pose de contrôle (bras levés, genou plié) qui fait travailler la peau,
## N ou 1 à 9 pour passer d'une animation à l'autre (attente au départ).
##
## Ligne de commande (après « -- ») :
##   modele=res://chemin.glb   personnage à charger (la Chatte par défaut)
##   vues=dossier              enregistre les vues de contrôle en PNG puis quitte
##   film=dossier              enregistre chaque animation image par image, puis quitte
##   animations=a,b            avec film : seulement ces animations

const DEFAULT_MODEL := "res://assets/models/personnages/chatte/chatte.glb"
const FLOOR_TEXTURE := "res://assets/textures/parquet.png"
const TURN_SPEED := 0.35
const FILM_FPS := 24
const FILM_MAX_SECONDS := 8.0
## Hauteur de l'articulation de la tête de la Chatte (1,65 m), sur laquelle sont réglés
## les cadrages : un personnage plus grand est cadré d'autant plus haut et plus loin.
const REFERENCE_HEAD_HEIGHT := 1.404
## Pose de contrôle : os et rotation (axe local, degrés), comme dans tools/blender/verifier_personnage.py.
const CONTROL_POSE := [
	["LeftArm", Vector3.BACK, 55.0],
	["RightArm", Vector3.BACK, -55.0],
	["LeftForeArm", Vector3.BACK, 60.0],
	["RightForeArm", Vector3.BACK, -60.0],
	["LeftUpLeg", Vector3.RIGHT, -45.0],
	["LeftLeg", Vector3.RIGHT, 70.0],
]
## Vues de contrôle : nom, éclairage, angle de la caméra, hauteur visée (ou os visé), distance, pose.
const CHECK_VIEWS := [
	["atelier_face", "atelier", 0.0, 0.9, 3.4, false],
	["atelier_trois_quarts", "atelier", 35.0, 0.9, 3.4, false],
	["atelier_dos", "atelier", 180.0, 0.9, 3.4, false],
	["atelier_visage", "atelier", 20.0, 1.5, 0.9, false],
	["atelier_pose", "atelier", 35.0, 0.9, 3.6, true],
	["nuit_trois_quarts", "nuit", 35.0, 0.9, 3.4, false],
	["nuit_visage", "nuit", 25.0, 1.5, 1.0, false],
	["atelier_main_gauche", "atelier", 60.0, "LeftHandDoigts", 0.45, false],
	["atelier_main_droite", "atelier", -60.0, "RightHandDoigts", 0.45, false],
]

var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var clips := PackedStringArray()
var clip_label: Label
var camera: Camera3D
var environment: Environment
var studio_lights: Array[Light3D] = []
var night_lights: Array[Light3D] = []
var yaw := 35.0
var pitch := 8.0
var distance := 3.4
var target_height := 0.9
var target_bone := ""
var size_factor := 1.0
var turning := true
var lighting := "atelier"


func _ready() -> void:
	var path := DEFAULT_MODEL
	var views_folder := ""
	var film_folder := ""
	var only := PackedStringArray()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("modele="):
			path = argument.trim_prefix("modele=")
		elif argument.begins_with("vues="):
			views_folder = argument.trim_prefix("vues=")
		elif argument.begins_with("film="):
			film_folder = argument.trim_prefix("film=")
		elif argument.begins_with("animations="):
			only = argument.trim_prefix("animations=").split(",")
	_build_environment()
	_build_floor()
	_build_lights()
	_load_model(path)
	camera = Camera3D.new()
	camera.fov = 35.0
	add_child(camera)
	_set_lighting("atelier")
	_update_camera()
	_build_label()
	_play(0)
	if views_folder != "":
		turning = false
		_save_check_views(views_folder)
	elif film_folder != "":
		turning = false
		_save_film(film_folder, only)


func _process(delta: float) -> void:
	if turning and model:
		model.rotate_y(TURN_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		yaw -= event.relative.x * 0.3
		pitch = clampf(pitch + event.relative.y * 0.2, -10.0, 60.0)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance * 0.9, 0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance * 1.1, 8.0)
		target_height = lerpf(1.5, 0.9, clampf((distance - 0.8) / 2.0, 0.0, 1.0))
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_L:
				_set_lighting("nuit" if lighting == "atelier" else "atelier")
			KEY_SPACE:
				turning = not turning
			KEY_P:
				_set_pose(not _is_posed())
			KEY_N:
				_play((clips.find(player.current_animation) + 1) % maxi(clips.size(), 1) if player else 0)
			_:
				if event.keycode >= KEY_1 and event.keycode <= KEY_9:
					_play(event.keycode - KEY_1)


func _load_model(path: String) -> void:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Modèle introuvable : %s" % path)
		return
	model = scene.instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	if skeleton and skeleton.find_bone("Head") >= 0:
		var head := skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("Head"))
		size_factor = head.origin.y / REFERENCE_HEAD_HEIGHT
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		player = players.front() as AnimationPlayer
		for clip in player.get_animation_list():
			if clip != "RESET":
				clips.append(clip)


func _play(index: int, blend := 0.25) -> void:
	if player == null or index >= clips.size():
		return
	_set_pose(false)
	player.play(clips[index], blend)
	clip_label.text = "%d. %s   (N ou 1 à %d : autre animation)" % [index + 1, clips[index].replace("_", " "), clips.size()]


func _build_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	clip_label = Label.new()
	clip_label.position = Vector2(20, 16)
	clip_label.add_theme_font_size_override("font_size", 44)
	clip_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	clip_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(clip_label)


func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.ssao_enabled = true
	environment.ssao_radius = 0.6
	environment.ssao_intensity = 1.6
	environment.ssil_enabled = true
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)


func _build_floor() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(FLOOR_TEXTURE)
	material.uv1_scale = Vector3(3, 3, 1)
	material.roughness = 0.55
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	plane.material = material
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	add_child(floor_mesh)


func _build_lights() -> void:
	# Atelier : trois lumières neutres
	for spec in [[Vector3(-35, 30, 0), 1.6, Color(1, 0.98, 0.95)], [Vector3(-15, -60, 0), 0.5, Color(0.95, 0.97, 1)], [Vector3(-30, 160, 0), 1.0, Color(1, 1, 1)]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.light_color = spec[2]
		light.shadow_enabled = spec[1] > 1.5
		add_child(light)
		studio_lights.append(light)
	# Nuit : lampe à pétrole posée à hauteur de table, clair de lune par la fenêtre
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0.9, 1.0, 0.9)
	lamp.light_color = Color(1.0, 0.68, 0.36)
	lamp.light_energy = 2.2
	lamp.omni_range = 7.0
	lamp.omni_attenuation = 1.4
	lamp.shadow_enabled = true
	lamp.light_size = 0.08
	add_child(lamp)
	night_lights.append(lamp)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-40, -130, 0)
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	add_child(moon)
	night_lights.append(moon)


func _set_lighting(mode: String) -> void:
	lighting = mode
	var night := mode == "nuit"
	for light in studio_lights:
		light.visible = not night
	for light in night_lights:
		light.visible = night
	environment.background_color = Color("15120f") if night else Color("6b6863")
	environment.ambient_light_color = Color(0.35, 0.4, 0.55) if night else Color(1, 1, 1)
	environment.ambient_light_energy = 0.12 if night else 0.35
	environment.tonemap_exposure = 1.1 if night else 1.0


func _update_camera() -> void:
	var at := Vector3(0, target_height, 0)
	if target_bone != "" and skeleton and skeleton.find_bone(target_bone) >= 0:
		at = (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(target_bone))).origin
	var direction := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	var offset := direction * cos(deg_to_rad(pitch)) + Vector3.UP * sin(deg_to_rad(pitch))
	camera.position = at + offset * distance
	camera.look_at(at)


func _is_posed() -> bool:
	return skeleton != null and skeleton.has_meta("posed") and skeleton.get_meta("posed")


func _set_pose(posed: bool) -> void:
	if skeleton == null:
		return
	if posed and player:
		player.stop()
	skeleton.reset_bone_poses()
	if posed:
		for spec in CONTROL_POSE:
			var bone := skeleton.find_bone(spec[0])
			if bone >= 0:
				var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
				skeleton.set_bone_pose_rotation(bone, rest * Quaternion(spec[1], deg_to_rad(spec[2])))
	skeleton.set_meta("posed", posed)


func _save_check_views(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	clip_label.visible = false
	if player:
		# Première image de l'attente : la pose de repos du jeu, mains comprises.
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for v in CHECK_VIEWS:
		_set_lighting(v[1])
		model.rotation = Vector3.ZERO
		yaw = v[2]
		pitch = 4.0 if v[4] < 1.5 else 8.0
		target_bone = v[3] if v[3] is String else ""
		target_height = (v[3] if v[3] is float else 0.9) * size_factor
		distance = v[4] * size_factor
		_set_pose(v[5])
		if player and not v[5]:
			_play(0, 0.0)
			player.seek(0.0, true)
		_update_camera()
		for i in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder.path_join(v[0] + ".png"))
	get_tree().quit()


## Chaque animation vue de trois quarts, à 24 images par seconde, sous l'éclairage d'atelier.
func _save_film(folder: String, only: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	_set_lighting("atelier")
	model.rotation = Vector3.ZERO
	yaw = 35.0
	pitch = 6.0
	distance = 3.6 * size_factor
	target_height = 0.85 * size_factor
	_update_camera()
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i in clips.size():
		if not only.is_empty() and not only.has(clips[i]):
			continue
		# Sans fondu : en mode manuel, le fondu n'avancerait jamais et figerait la pose précédente.
		_play(i, 0.0)
		var length := minf(player.current_animation_length, FILM_MAX_SECONDS)
		for frame in int(length * FILM_FPS):
			player.seek(float(frame) / FILM_FPS, true)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(folder.path_join("%s_%03d.png" % [clips[i], frame]))
	get_tree().quit()
