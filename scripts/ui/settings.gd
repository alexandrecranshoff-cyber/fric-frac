extends Node
## Réglages du joueur (chargé d'office sous le nom « Settings ») : écran, qualité graphique, volumes.
## Gardés dans user://reglages.cfg d'une partie à l'autre, appliqués au lancement et à chaque changement.
##
## Les niveaux de qualité règlent ce qui coûte le plus à la carte graphique : ombres, occlusion ambiante
## (SSAO), lumière indirecte (SSIL), lissage des bords et définition du rendu 3D. « Maximale » est la
## qualité visée sur la machine de référence (RTX 3050) ; les autres laissent jouer sur une carte plus faible.

signal changed

const FILE := "user://reglages.cfg"
const QUALITIES := ["basse", "moyenne", "haute", "maximale"]
const QUALITY_NAMES := {"basse": "Basse", "moyenne": "Moyenne", "haute": "Haute", "maximale": "Maximale"}
## Par niveau : taille des cartes d'ombre, finesse de leur bord (0 à 5), SSAO, SSIL, lissage MSAA,
## halo des lampes, seuil des niveaux de détail (pixels).
const PRESETS := {
	"basse": {"shadow": 2048, "soft": 1, "ssao": false, "ssil": false, "msaa": Viewport.MSAA_DISABLED,
		"glow": false, "lod": 4.0},
	"moyenne": {"shadow": 4096, "soft": 2, "ssao": true, "ssil": false, "msaa": Viewport.MSAA_2X,
		"glow": true, "lod": 2.0},
	"haute": {"shadow": 4096, "soft": 3, "ssao": true, "ssil": true, "msaa": Viewport.MSAA_4X,
		"glow": true, "lod": 1.0},
	"maximale": {"shadow": 8192, "soft": 4, "ssao": true, "ssil": true, "msaa": Viewport.MSAA_4X,
		"glow": true, "lod": 1.0},
}
const DEFAULTS := {"plein_ecran": true, "synchro": true, "qualite": "maximale", "definition": 1.0,
	"musique": 0.8, "bruitages": 1.0, "images_par_seconde": false}
## Volume des bus à 100 % (dB) : la musique reste sous les bruitages.
const MUSIC_DB := -2.0
const EFFECTS_DB := 0.0

var values: Dictionary = DEFAULTS.duplicate()
var _environments: Array[Environment] = []


func _ready() -> void:
	var file := ConfigFile.new()
	if file.load(FILE) == OK:
		for key in DEFAULTS:
			var value: Variant = file.get_value("reglages", key, DEFAULTS[key])
			if typeof(value) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and value is int):
				values[key] = value
	if not QUALITIES.has(values["qualite"]):
		values["qualite"] = DEFAULTS["qualite"]
	ensure_buses()
	# Sans écran (tests, rendus de contrôle), on ne touche ni à la fenêtre ni au rendu.
	if DisplayServer.get_name() != "headless" and not Array(OS.get_cmdline_user_args()).any(_is_check_run):
		_apply_window()
	_apply_rendering()
	_apply_audio()


static func _is_check_run(argument: String) -> bool:
	return argument.begins_with("auto=") or argument.begins_with("vues=") or argument.begins_with("vitrine=") \
			or argument.begins_with("film=")


## Change un réglage, l'applique et l'enregistre.
func set_value(key: String, value: Variant) -> void:
	if values.get(key) == value:
		return
	values[key] = value
	match key:
		"plein_ecran", "synchro":
			_apply_window()
		"musique", "bruitages":
			_apply_audio()
		_:
			_apply_rendering()
	_save()
	changed.emit()


func preset() -> Dictionary:
	return PRESETS[values["qualite"]]


## Les scènes donnent ici l'environnement de leur monde : la qualité choisie y règle SSAO, SSIL et halo,
## maintenant et à chaque changement.
func register_environment(environment: Environment) -> void:
	_environments = _environments.filter(func(e): return is_instance_valid(e))
	_environments.append(environment)
	_apply_environment(environment)


func _apply_environment(environment: Environment) -> void:
	var p := preset()
	environment.ssao_enabled = p["ssao"]
	environment.ssil_enabled = p["ssil"]
	environment.glow_enabled = p["glow"]


func _apply_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values["plein_ecran"]
			else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["synchro"]
			else DisplayServer.VSYNC_DISABLED)


func _apply_rendering() -> void:
	var p := preset()
	var viewport := get_viewport()
	viewport.msaa_3d = p["msaa"]
	viewport.mesh_lod_threshold = p["lod"]
	viewport.positional_shadow_atlas_size = p["shadow"]
	# En dessous de la pleine définition, FSR 1 remet l'image 3D à la taille de l'écran.
	var scale: float = clampf(values["definition"], 0.5, 1.0)
	viewport.scaling_3d_scale = scale
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if scale >= 0.999 else Viewport.SCALING_3D_MODE_FSR
	RenderingServer.directional_shadow_atlas_set_size(p["shadow"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["soft"])
	RenderingServer.positional_soft_shadow_filter_set_quality(p["soft"])
	for environment in _environments:
		if is_instance_valid(environment):
			_apply_environment(environment)


## Les bus Musique et Bruitages, sous le bus principal.
static func ensure_buses() -> void:
	for bus in ["Musique", "Bruitages"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func _apply_audio() -> void:
	for pair in [["Musique", "musique", MUSIC_DB], ["Bruitages", "bruitages", EFFECTS_DB]]:
		var index := AudioServer.get_bus_index(pair[0])
		var level: float = values[pair[1]]
		AudioServer.set_bus_mute(index, level <= 0.001)
		AudioServer.set_bus_volume_db(index, pair[2] + linear_to_db(maxf(level, 0.001)))


func _save() -> void:
	var file := ConfigFile.new()
	for key in values:
		file.set_value("reglages", key, values[key])
	file.save(FILE)
