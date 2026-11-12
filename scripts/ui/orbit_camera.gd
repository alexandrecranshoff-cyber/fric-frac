class_name OrbitCamera
extends Camera3D
## Caméra de maquette : vue en perspective, à longue focale, qui tourne autour d'un point du plateau.
## Clic droit glissé : tourner et incliner. Clic gauche ou molette enfoncée glissés, flèches : déplacer.
## Molette : zoom. Q et E : tourner d'un sixième de tour (un côté de case). Début : vue de départ.
## Écran tactile : un doigt déplace, deux doigts zooment (écarter) et tournent (pivoter).

const ZOOM_MIN := 5.0
const ZOOM_MAX := 40.0
const TILT_MIN := 0.3
const TILT_MAX := 8.0
const ROTATE_STEP := 60.0
const PAN_SPEED := 12.0
const WIDE_ASPECT := 16.0 / 9.0
## Angle de vue étroit, comme un téléobjectif : la perspective reste douce et le plateau lisible.
const FIELD_OF_VIEW := 28.0

var target := Vector3.ZERO
var angle := 20.0
var tilt := 1.1
var zoom := 26.0
## Zone que le point visé ne quitte pas.
var limits := Rect2(0, 0, 26, 21)
## Le clic gauche glissé déplace la vue. En partie, le clic gauche sert aux gestes : on déplace
## alors la vue au bouton du milieu, aux flèches ou au doigt.
var left_pans := true

var _home: Array = []
var _rotating := false
var _panning := false
## Doigts posés sur l'écran : numéro du doigt -> position.
var _touches: Dictionary = {}


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = FIELD_OF_VIEW
	get_viewport().size_changed.connect(refresh)
	refresh()


## Vue de départ, retrouvée avec la touche Début.
func set_home(new_target: Vector3, new_angle: float, new_tilt: float, new_zoom: float) -> void:
	_home = [new_target, new_angle, new_tilt, new_zoom]
	go_home()


func go_home() -> void:
	if _home.is_empty():
		return
	target = _home[0]
	angle = _home[1]
	tilt = _home[2]
	zoom = _home[3]
	refresh()


func refresh() -> void:
	tilt = clampf(tilt, TILT_MIN, TILT_MAX)
	zoom = clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	target.x = clampf(target.x, limits.position.x, limits.end.x)
	target.z = clampf(target.z, limits.position.y, limits.end.y)
	# Le zoom compte la hauteur visible ; sur un écran étroit ou tenu debout, on élargit le champ
	# pour garder la même largeur de plateau qu'en 16/9.
	var screen := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var height := zoom * maxf(1.0, WIDE_ASPECT * screen.y / maxf(screen.x, 1.0))
	# Le zoom dit quelle hauteur de plateau tient à l'écran, au point visé.
	var distance := height * 0.5 / tan(deg_to_rad(FIELD_OF_VIEW) * 0.5)
	var direction := Vector3(sin(deg_to_rad(angle)), tilt, cos(deg_to_rad(angle))).normalized()
	position = target + direction * distance
	# Plans de coupe serrés autour du plateau : la profondeur reste précise, rien ne scintille.
	near = maxf(1.0, distance * 0.35)
	far = distance + 260.0
	look_at(target, Vector3.UP)


func _process(delta: float) -> void:
	var move := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if move != Vector2.ZERO:
		_pan(move * PAN_SPEED * delta * zoom / 26.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
	elif event is InputEventScreenDrag:
		_drag_touch(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom -= 1.5
				refresh()
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom += 1.5
				refresh()
			MOUSE_BUTTON_RIGHT:
				_rotating = button.pressed
			MOUSE_BUTTON_MIDDLE:
				_panning = button.pressed
			MOUSE_BUTTON_LEFT:
				if left_pans:
					_panning = button.pressed
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _rotating:
			angle -= motion.relative.x * 0.35
			tilt += motion.relative.y * 0.012 * maxf(tilt, 0.5)
			refresh()
		elif _panning and _touches.size() < 2:
			_pan(-motion.relative * zoom / float(get_viewport().get_visible_rect().size.y))
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_Q, KEY_A:
				angle -= ROTATE_STEP
				refresh()
			KEY_E:
				angle += ROTATE_STEP
				refresh()
			KEY_PAGEUP:
				tilt *= 1.3
				refresh()
			KEY_PAGEDOWN:
				tilt /= 1.3
				refresh()
			KEY_HOME:
				go_home()


## Deux doigts : leur écartement règle le zoom, leur pivotement fait tourner la vue.
func _drag_touch(drag: InputEventScreenDrag) -> void:
	if not _touches.has(drag.index):
		return
	if _touches.size() != 2:
		_touches[drag.index] = drag.position
		return
	var other: Vector2 = drag.position
	for index in _touches:
		if index != drag.index:
			other = _touches[index]
	var before: Vector2 = _touches[drag.index] - other
	var after: Vector2 = drag.position - other
	_touches[drag.index] = drag.position
	if before.length() < 1.0 or after.length() < 1.0:
		return
	zoom *= before.length() / after.length()
	angle += rad_to_deg(before.angle_to(after))
	refresh()


## Déplace le point visé : x vers la droite de l'écran, y vers le bas de l'écran.
func _pan(offset: Vector2) -> void:
	var right := global_transform.basis.x
	var forward := Vector3(right.z, 0.0, -right.x)
	# Le sol est vu en biais : un même geste vertical couvre plus de terrain quand la vue est rasante.
	var slant := sqrt(1.0 + tilt * tilt) / tilt
	target += right * offset.x - forward * offset.y * slant
	refresh()
