class_name GameAudio
extends Node
## Sons de la partie : musique (menu, nuit, alerte) en fondu enchaîné, ambiance du jardin, bruitages
## ponctuels et pas en boucle pendant une marche. Les sons sortent de Higgsfield et sont mis au même
## volume perçu par tools/preparer_son.py : ici, seuls les deux bus (Musique, Bruitages) se règlent.
##
## Les sons n'ont aucun effet sur les règles : ils suivent les événements que rejoue l'écran de jeu.

const FOLDER := "res://assets/audio/"
const SOUNDS := ["pas_voleur", "pas_garde", "crochetage", "porte", "fenetre", "tiroir", "coffre_fort", "grille",
	"des", "butin", "sonnerie_alarme", "sifflet", "coup", "saut", "escalade", "aube", "horloge"]
const MUSICS := ["menu", "nuit", "alerte"]
const FADE_SECONDS := 2.0
const MUSIC_DB := -2.0
const EFFECTS_DB := 0.0
const AMBIENCE_DB := 0.0
const VOICES := 8

var _streams: Dictionary = {}
var _music: Array[AudioStreamPlayer] = []
var _music_index := 0
var _music_name := ""
var _ambience: AudioStreamPlayer
var _steps: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
## Hasard des sons (hauteur, reprise des pas), à part des dés des règles.
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_make_bus("Musique", MUSIC_DB)
	_make_bus("Bruitages", EFFECTS_DB)
	for name in SOUNDS:
		_streams[name] = load(FOLDER + "bruitages/%s.ogg" % name)
	for name in MUSICS:
		_streams["musique_" + name] = _looping(load(FOLDER + "musiques/%s.ogg" % name))
	# Les pas, l'ambiance et les musiques ont été fondus en boucle par preparer_son.py.
	for name in ["pas_voleur", "pas_garde"]:
		_streams[name] = _looping(_streams[name])
	for i in 2:
		_music.append(_player("Musique"))
	_ambience = _player("Bruitages", AMBIENCE_DB)
	_ambience.stream = _looping(load(FOLDER + "bruitages/ambiance_nuit.ogg"))
	for i in VOICES:
		_voices.append(_player("Bruitages"))


static func _looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream


static func _make_bus(bus: String, volume_db: float) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_volume_db(index, volume_db)
	AudioServer.set_bus_send(index, "Master")


func _player(bus: String, volume_db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = volume_db
	add_child(p)
	return p


## Joue un bruitage une fois. `pitch_spread` varie un peu la hauteur, pour qu'un son répété ne lasse pas.
func play(name: String, volume_db := 0.0, pitch_spread := 0.06) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _random.randf_range(-pitch_spread, pitch_spread)
	p.play()


## Pas en boucle tant que le pion marche ; `key` distingue les marcheurs (voleur, gardes).
func start_steps(key: int, name: String, volume_db := 0.0) -> void:
	var p: AudioStreamPlayer = _steps.get(key)
	if p == null:
		p = _player("Bruitages")
		_steps[key] = p
	if p.playing and p.stream == _streams.get(name):
		return
	p.stream = _streams.get(name)
	p.volume_db = volume_db
	# Chaque marche reprend la boucle ailleurs : deux pas de suite ne sonnent pas pareil.
	p.play(_random.randf() * p.stream.get_length())


func stop_steps(key: int) -> void:
	var p: AudioStreamPlayer = _steps.get(key)
	if p and p.playing:
		var tween := create_tween()
		tween.tween_property(p, "volume_db", p.volume_db - 30.0, 0.15)
		tween.tween_callback(p.stop)


func stop_all_steps() -> void:
	for p in _steps.values():
		p.stop()


## Passe à la musique donnée (menu, nuit, alerte ; vide pour le silence) en fondu enchaîné.
func music(name: String) -> void:
	if name == _music_name:
		return
	_music_name = name
	var old := _music[_music_index]
	_music_index = 1 - _music_index
	var new := _music[_music_index]
	if old.playing:
		var out := create_tween()
		out.tween_property(old, "volume_db", -60.0, FADE_SECONDS)
		out.tween_callback(old.stop)
	if name != "":
		new.stream = _streams["musique_" + name]
		new.volume_db = -40.0
		new.play()
		create_tween().tween_property(new, "volume_db", 0.0, FADE_SECONDS).set_ease(Tween.EASE_OUT)


## L'ambiance de nuit du jardin, sous la musique pendant la partie.
func ambience(on: bool) -> void:
	if on and not _ambience.playing:
		_ambience.play()
	elif not on:
		_ambience.stop()


## Arrête tout avant de quitter : un son qui joue encore à la fermeture resterait tenu par le serveur audio.
func _exit_tree() -> void:
	for p in find_children("", "AudioStreamPlayer", false, false):
		p.stop()
		p.stream = null
	_streams.clear()
