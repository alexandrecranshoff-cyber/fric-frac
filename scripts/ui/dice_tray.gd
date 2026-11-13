class_name DiceTray
extends SubViewportContainer
## Les dés lancés en 3D sur un tapis de jeu, dans leur propre petite scène. Les faces sont décidées
## par les règles (DiceRoller) avant le lancer : l'animation ne fait que rouler les dés jusqu'à
## elles. Le hasard de l'animation (trajectoires, tours) n'a donc aucun effet sur la partie.
##
## Dés d'os à l'ancienne : ivoire, points noirs, l'as en rouge. Faces opposées : 1-6, 2-5, 3-4.

const DIE_SIZE := 1.0
const SPACING := 1.55
const ROLL_SECONDS := 0.95
const FACE_PIXELS := 256
const IVORY := Color("efe6d2")
const PIP := Color("1c1612")
const ACE := Color("a3231b")
const FELT := Color("1f3d2c")
const RIM := Color("4a2c18")
## Normale de chaque face, dans le repère du dé.
const FACE_NORMALS := {
	1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3.RIGHT, 5: Vector3.LEFT, 3: Vector3.BACK, 4: Vector3.FORWARD,
}

var _viewport: SubViewport
var _dice_root: Node3D
var _die_mesh: ArrayMesh
var _random := RandomNumberGenerator.new()


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(460, 220)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	_build_scene()


## Lance les dés jusqu'aux faces données. À attendre (await).
func roll(faces: Array) -> void:
	for child in _dice_root.get_children():
		child.queue_free()
	var count := faces.size()
	var tweens: Array[Tween] = []
	for i in count:
		var die := MeshInstance3D.new()
		die.mesh = _die_mesh
		_dice_root.add_child(die)
		var rest := Vector3((i - (count - 1) * 0.5) * SPACING + _random.randf_range(-0.15, 0.15), DIE_SIZE * 0.5,
				_random.randf_range(-0.2, 0.2))
		var start := rest + Vector3(_random.randf_range(-3.5, -2.5), 2.6, _random.randf_range(0.8, 1.6))
		var target := Basis(Vector3.UP, _random.randf_range(-0.5, 0.5)) * _facing_up(int(faces[i]))
		var axis := Vector3(_random.randf_range(-1, 1), _random.randf_range(-1, 1), _random.randf_range(-1, 1)).normalized()
		var turns := _random.randf_range(2.5, 3.5) * TAU
		var tween := create_tween()
		tween.tween_method(_place.bind(die, start, rest, target, axis, turns), 0.0, 1.0,
				ROLL_SECONDS + _random.randf_range(0.0, 0.15))
		tweens.append(tween)
	for tween in tweens:
		if tween.is_running():
			await tween.finished


func _place(t: float, die: MeshInstance3D, start: Vector3, rest: Vector3, target: Basis, axis: Vector3, turns: float) -> void:
	# Trajet amorti : le dé tombe, rebondit deux fois en s'éloignant de moins en moins, et s'arrête.
	var ease := 1.0 - pow(1.0 - t, 2.2)
	var at := start.lerp(rest, ease)
	var bounce := absf(sin(t * PI * 3.0)) * pow(1.0 - t, 1.6) * 1.4
	at.y = rest.y + maxf(start.y * pow(1.0 - t, 3.0), bounce)
	die.position = at
	# Il tourne de moins en moins autour d'un axe tiré au hasard et finit exactement sur sa face.
	var left := turns * pow(1.0 - t, 1.8)
	die.basis = Basis(axis, left) * target


## Orientation du dé qui met la face voulue en haut.
static func _facing_up(face: int) -> Basis:
	var normal: Vector3 = FACE_NORMALS.get(face, Vector3.UP)
	if normal.is_equal_approx(Vector3.UP):
		return Basis.IDENTITY
	if normal.is_equal_approx(Vector3.DOWN):
		return Basis(Vector3.RIGHT, PI)
	return Basis(normal.cross(Vector3.UP).normalized(), normal.angle_to(Vector3.UP))


func _build_scene() -> void:
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.transform = Transform3D.IDENTITY.looking_at(Vector3(0, -5.0, -3.7), Vector3.UP)
	camera.position = Vector3(0, 5.0, 3.9)
	_viewport.add_child(camera)
	var lamp := DirectionalLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 1.4
	lamp.shadow_enabled = true
	lamp.rotation_degrees = Vector3(-62, 28, 0)
	_viewport.add_child(lamp)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.5, 0.45)
	environment.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	# Le tapis de jeu : feutre vert dans un cadre de bois.
	var felt := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(5.6, 0.1, 2.6)
	felt.mesh = plane
	felt.position.y = -0.05
	felt.material_override = _plain(FELT, 1.0)
	_viewport.add_child(felt)
	for side in [-1.0, 1.0]:
		var long := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(5.9, 0.28, 0.16)
		long.mesh = bar
		long.position = Vector3(0, 0.04, side * 1.38)
		long.material_override = _plain(RIM, 0.55)
		_viewport.add_child(long)
		var short := MeshInstance3D.new()
		var end := BoxMesh.new()
		end.size = Vector3(0.16, 0.28, 2.6)
		short.mesh = end
		short.position = Vector3(side * 2.88, 0.04, 0)
		short.material_override = _plain(RIM, 0.55)
		_viewport.add_child(short)
	_dice_root = Node3D.new()
	_viewport.add_child(_dice_root)
	_die_mesh = _build_die()


static func _plain(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


## Un cube dont chaque face prend sa case d'une planche de 3 × 2 faces dessinée ici.
func _build_die() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [1, 2, 3, 4, 5, 6]
	for index in faces.size():
		var face: int = faces[index]
		var normal: Vector3 = FACE_NORMALS[face]
		var u := Vector3.RIGHT if absf(normal.x) < 0.9 else Vector3.BACK
		var v := normal.cross(u)
		var cell := Vector2(index % 3, index / 3)
		var corners := [[-1, -1], [1, -1], [1, 1], [-1, 1]]
		var points := []
		for c in corners:
			var p: Vector3 = (normal + u * c[0] + v * c[1]) * DIE_SIZE * 0.5
			var uv := (cell + Vector2((c[0] + 1) * 0.5, (c[1] + 1) * 0.5)) / Vector2(3, 2)
			points.append([p, uv])
		# Deux triangles, dans le sens qui fait regarder la face vers l'extérieur.
		var order := [0, 1, 2, 0, 2, 3]
		if (u.cross(v)).dot(normal) > 0.0:
			order = [0, 2, 1, 0, 3, 2]
		for k in order:
			tool.set_normal(normal)
			tool.set_uv(points[k][1])
			tool.add_vertex(points[k][0])
	tool.generate_tangents()
	var mesh := tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(_pip_sheet(faces))
	material.roughness = 0.38
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.surface_set_material(0, material)
	return mesh


## La planche des six faces : points creusés en noir (l'as en rouge), bords assombris pour
## donner l'arrondi des arêtes d'un dé d'os.
static func _pip_sheet(faces: Array) -> Image:
	var size := FACE_PIXELS
	var image := Image.create(size * 3, size * 2, true, Image.FORMAT_RGBA8)
	var layouts := {
		1: [Vector2(0.5, 0.5)],
		2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
		3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
		4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
		5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
		6: [Vector2(0.27, 0.25), Vector2(0.73, 0.25), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.75), Vector2(0.73, 0.75)],
	}
	for index in faces.size():
		var face: int = faces[index]
		var origin := Vector2i((index % 3) * size, (index / 3) * size)
		var radius := 0.13 if face == 1 else 0.085
		var pip_color := ACE if face == 1 else PIP
		for y in size:
			for x in size:
				var p := Vector2(x + 0.5, y + 0.5) / size
				var edge := minf(minf(p.x, 1.0 - p.x), minf(p.y, 1.0 - p.y))
				var color := IVORY.darkened(clampf((0.09 - edge) / 0.09, 0.0, 1.0) * 0.35)
				for pip in layouts[face]:
					var d: float = p.distance_to(pip)
					if d < radius:
						# Le fond du point est plus sombre que son bord : il a l'air creusé.
						color = pip_color.lightened(clampf((d / radius - 0.6) * 0.6, 0.0, 0.25))
				image.set_pixel(origin.x + x, origin.y + y, color)
	image.generate_mipmaps()
	return image
