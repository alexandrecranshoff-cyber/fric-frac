extends Node3D
## Scène de départ : pour l'instant, la maquette 3D de la villa à visiter avec la caméra.
##
## Contrôle visuel sans écran (après « -- » sur la ligne de commande) :
##   vues=dossier   enregistre les vues de contrôle en PNG puis quitte
##   film=dossier   enregistre un tour complet de la villa, image par image, puis quitte

const HELP := "Clic droit glissé : tourner et incliner   ·   Clic gauche glissé ou flèches : déplacer   ·   Molette : zoom\nQ / E : tourner d'un côté de case   ·   L : lettres des pièces   ·   Début : vue de départ   ·   Tactile : un doigt déplace, deux doigts zooment et tournent"
## Vues de contrôle : nom, angle, inclinaison, zoom, point visé (ou null pour le milieu du plateau).
const CHECK_VIEWS := [
	["vue_generale", 20.0, 1.1, 27.0, null],
	["vue_de_dessus", 0.0, 8.0, 25.0, null],
	["vue_nord", 180.0, 0.8, 24.0, null],
	["vue_ouest", -70.0, 0.9, 24.0, null],
	["detail_hall", 35.0, 0.9, 11.0, Vector2(13.5, 13.5)],
	["detail_terrasse", 150.0, 0.8, 12.0, Vector2(10.0, 5.6)],
	["detail_perron", -25.0, 0.7, 10.0, Vector2(13.5, 16.3)],
	["dessus_nord_ouest", 0.0, 8.0, 9.0, Vector2(7.5, 7.0)],
	["dessus_nord_est", 0.0, 8.0, 9.0, Vector2(18.5, 7.0)],
	["dessus_sud_ouest", 0.0, 8.0, 9.0, Vector2(7.5, 15.0)],
	["dessus_sud_est", 0.0, 8.0, 9.0, Vector2(18.5, 15.0)],
]
const FILM_FRAMES := 180
const HAZE_COLOR := Color("c9d6e2")

var view: VillaView
var camera: OrbitCamera


func _ready() -> void:
	_build_light()
	var data := GameData.load_default()
	view = VillaView.new()
	add_child(view)
	view.build(VillaPlan.new(data.villa))
	camera = OrbitCamera.new()
	var size := view.plan.size()
	camera.limits = Rect2(0, 0, size.x, Hex.center(Vector2i(0, size.y - 1)).y)
	add_child(camera)
	camera.set_home(view.middle(), 20.0, 1.1, 27.0)
	camera.make_current()
	_build_help()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("vues="):
			_save_check_views(argument.trim_prefix("vues="))
		elif argument.begins_with("film="):
			_save_film(argument.trim_prefix("film="))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_L:
		view.set_labels_visible(not view.labels_visible())


func _build_light() -> void:
	# Fin d'après-midi : soleil bas et chaud, ombres longues, ciel clair qui débouche les ombres.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = HAZE_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.87, 1.0)
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.92
	environment.adjustment_contrast = 1.04
	# La brume fond le terrain lointain dans le ciel.
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = HAZE_COLOR
	environment.fog_depth_begin = 70.0
	environment.fog_depth_end = 190.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -52, 0)
	sun.light_energy = 0.4
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.75
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 130.0
	add_child(sun)
	get_viewport().msaa_3d = Viewport.MSAA_4X


func _build_help() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Aide"
	add_child(layer)
	var label := Label.new()
	label.text = HELP
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 24
	label.offset_right = -24
	label.offset_bottom = -16
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)


func _save_check_views(folder: String) -> void:
	get_node("Aide").visible = false
	DirAccess.make_dir_recursive_absolute(folder)
	for v in CHECK_VIEWS:
		var at: Vector3 = view.middle() if v[4] == null else Vector3(v[4].x, 0.0, v[4].y)
		camera.set_home(at, v[1], v[2], v[3])
		await _snapshot(folder.path_join(v[0] + ".png"))
	get_tree().quit()


func _save_film(folder: String) -> void:
	get_node("Aide").visible = false
	DirAccess.make_dir_recursive_absolute(folder)
	for i in FILM_FRAMES:
		var turn := float(i) / FILM_FRAMES
		# Un tour complet, en s'approchant puis en s'éloignant.
		camera.set_home(view.middle(), 20.0 + 360.0 * turn, 0.95 + 0.25 * cos(TAU * turn), 23.0 + 4.0 * cos(TAU * turn))
		await _snapshot(folder.path_join("image_%03d.png" % i))
	get_tree().quit()


func _snapshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
