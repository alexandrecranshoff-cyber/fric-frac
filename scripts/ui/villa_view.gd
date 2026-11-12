class_name VillaView
extends Node3D
## Maquette 3D de la villa, construite entièrement depuis le plan (VillaPlan) et son tracé redressé
## (VillaOutline) : sols en vraies matières, murs coupés à hauteur d'appui, portes, fenêtres, tapis,
## mur d'enceinte et grille, trottoir, arbres et gardes. Aucune règle ici, seulement du dessin.
## Repère : une case fait 1 mètre de large, x vers l'est, z vers le sud, y vers le haut.

const WALL_HEIGHT := 0.85
const OUTER_THICKNESS := 0.24
const INNER_THICKNESS := 0.15
const SILL_HEIGHT := 0.38
const ENCLOSURE_HEIGHT := 1.05
const ENCLOSURE_THICKNESS := 0.26
const PILLAR_SPACING := 3.5
const SIDEWALK_WIDTH := 1.8
const SIDEWALK_HEIGHT := 0.045
const ROAD_WIDTH := 7.0
## Le quadrillage du jeu, tracé finement par-dessus les sols.
const GRID_WIDTH := 0.022
const GRID_HEIGHT := 0.012
const RUG_HEIGHT := 0.006

const TEXTURES: Array[String] = [
	"herbe", "gravier", "dallage", "parquet", "carrelage", "moquette", "crepi", "pierre", "brique", "bois",
	"asphalte", "feuillage",
]
const CARPET_COLORS := {
	"bleu": Color("b3cccd"), "rose": Color("e2bca6"), "blanc": Color("e9e5d9"), "creme": Color("e8d8ac"),
}
## Tapis des salons : fond, bande claire, bordure, et rotation en degrés.
const RUGS := {
	"rouge": {"field": Color("9a3a2d"), "band": Color("d8b98c"), "border": Color("5c2018"), "turn": 0.0},
	"jaune": {"field": Color("d6b24a"), "band": Color("f0e3ad"), "border": Color("a07c26"), "turn": 24.0},
	"brun": {"field": Color("86583a"), "band": Color("c9a676"), "border": Color("523320"), "turn": 0.0},
	"rond": {"field": Color("e3c462"), "band": Color("f3e6b6"), "border": Color("bf9338"), "turn": 0.0},
}
const PLASTER_COLOR := Color("f1ede4")
const FACADE_COLOR := Color("ead8b4")
const CUT_COLOR := Color("8c847a")
const STONE_COLOR := Color("efe9da")
const BASEBOARD_COLOR := Color("8a6a48")
const FRAME_COLOR := Color("6f4a2a")
const DOOR_COLOR := Color("c08a4a")
const OUTER_DOOR_COLOR := Color("8c2f25")
const BRASS_COLOR := Color("c9a24a")
const WINDOW_FRAME_COLOR := Color("f4f2ec")
const GLASS_COLOR := Color(0.62, 0.8, 0.9, 0.42)
const IRON_COLOR := Color("1c2622")
const SIDEWALK_COLOR := Color("b3afa6")
const SURROUNDINGS_COLOR := Color("b4b3a8")
const GRID_COLOR := Color(0.1, 0.08, 0.05, 0.26)
const TRUNK_COLOR := Color("6b4a2e")
const UNIFORM_COLOR := Color("27375f")
const SKIN_COLOR := Color("e2b48c")

## Côté de case qui part de chaque sommet, dans l'ordre de Hex.VERTICES.
const _EDGE_DIRECTIONS: Array[String] = ["nord_est", "est", "sud_est", "sud_ouest", "ouest", "nord_ouest"]

var plan: VillaPlan
var outline: VillaOutline
## Un maillage par matière : nom -> MeshBuilder.
var _builders: Dictionary = {}
## Angles des murs à arrondir : position arrondie -> {"at", "outer"}.
var _posts: Dictionary = {}
var _labels: Array[Label3D] = []


func build(villa_plan: VillaPlan) -> void:
	plan = villa_plan
	outline = VillaOutline.new(plan)
	_build_surroundings()
	_build_floors()
	_build_grid()
	for segment in outline.segments:
		if segment["wall"]:
			_build_wall(segment["a"], segment["b"], segment["outer"])
			_note_post(segment["a"], segment["outer"])
			_note_post(segment["b"], segment["outer"])
		else:
			_build_edging(segment)
	for c in plan.openings:
		_build_opening(c)
	for post in _posts.values():
		_build_post(post["at"], post["outer"])
	_build_enclosure()
	_build_rugs()
	for surface in _builders:
		_add_mesh(surface, _builders[surface])
	_build_trees()
	_build_guards()
	_build_room_labels()


## Centre du plateau, là où la caméra regarde au départ.
func middle() -> Vector3:
	var size := plan.size()
	var last := Hex.center(Vector2i(size.x - 1, size.y - 1))
	return Vector3((last.x + 0.5) * 0.5, 0.0, last.y * 0.5)


## Affiche ou cache les lettres des pièces.
func set_labels_visible(shown: bool) -> void:
	for label in _labels:
		label.visible = shown


func labels_visible() -> bool:
	return not _labels.is_empty() and _labels[0].visible


static func to_world(cell: Vector2i, height := 0.0) -> Vector3:
	var p := Hex.center(cell)
	return Vector3(p.x, height, p.y)


# --- Sols ---

func _build_floors() -> void:
	for c in plan.cells():
		if not plan.is_opening(c):
			_lay_floor(_corners(c, 0, 5), outline.surface(c, "est"))
			continue
		# Une porte ou une fenêtre est à cheval sur son mur : chaque moitié prend le sol de son côté.
		var wall: Array = plan.openings[c]["mur"]
		var first := mini(Hex.VERTICES.find(wall[0]), Hex.VERTICES.find(wall[1]))
		var second := maxi(Hex.VERTICES.find(wall[0]), Hex.VERTICES.find(wall[1]))
		_lay_floor(_corners(c, first, second), outline.surface(c, _EDGE_DIRECTIONS[first]))
		_lay_floor(_corners(c, second, first + 6), outline.surface(c, _EDGE_DIRECTIONS[second % 6]))


## Sommets d'une case après redressement, du rang `from` au rang `to` (qui peut dépasser 5).
func _corners(c: Vector2i, from: int, to: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(from, to + 1):
		points.append(outline.corner(c, Hex.VERTICES[i % 6]))
	return points


func _lay_floor(points: PackedVector2Array, kind: String) -> void:
	match kind:
		".":
			_surface("herbe").top(points, 0.0, Color.WHITE, 5.0)
		",":
			_surface("gravier").top(points, 0.0, Color.WHITE, 3.0)
		"~", "_":
			_surface("dallage").top(points, 0.0, Color.WHITE, 2.4)
		"/":
			_surface("dallage").top(points, 0.0, Color(0.84, 0.81, 0.76), 2.4)
		_:
			var floor_kind: String = plan.rooms[kind]["sol"]
			if floor_kind == "parquet":
				# Les lames ne courent pas dans le même sens d'un salon à l'autre.
				_surface("parquet").top(points, 0.0, Color.WHITE, 2.4, PI / 2 if "ci".contains(kind) else 0.0)
			elif floor_kind == "carrelage":
				_surface("carrelage").top(points, 0.0, Color.WHITE, 0.9, PI / 4)
			else:
				_surface("moquette").top(points, 0.0, CARPET_COLORS.get(floor_kind, Color.WHITE), 1.5)


func _build_grid() -> void:
	var lines := _surface("lignes")
	for c in plan.cells():
		if plan.is_enclosure(c):
			continue
		for i in 6:
			var neighbor := Hex.step(c, _EDGE_DIRECTIONS[i])
			# Chaque côté une seule fois : par la case de l'ouest, ou par la seule case jouable qui le touche.
			if i >= 3 and plan.cell(neighbor) != " " and not plan.is_enclosure(neighbor):
				continue
			var a := outline.corner(c, Hex.VERTICES[i])
			var b := outline.corner(c, Hex.VERTICES[(i + 1) % 6])
			if a.distance_to(b) > 0.02:
				lines.top(MeshBuilder.strip(a, b, GRID_WIDTH), GRID_HEIGHT, GRID_COLOR)


## Bordure de pierre le long d'une limite entre deux sols d'extérieur.
func _build_edging(segment: Dictionary) -> void:
	var kinds: Array = segment["kinds"]
	var paved := "~_/".contains(kinds[0]) or "~_/".contains(kinds[1])
	if paved:
		_surface("pierre").prism(MeshBuilder.strip(segment["a"], segment["b"], 0.14), 0.0, 0.06, STONE_COLOR, 1.5)
	elif kinds.has(","):
		_surface("pierre").prism(MeshBuilder.strip(segment["a"], segment["b"], 0.08), 0.0, 0.03, SIDEWALK_COLOR, 1.5)


func _build_rugs() -> void:
	for room in plan.rooms:
		var rug_name: String = plan.rooms[room].get("tapis", "")
		if not RUGS.has(rug_name):
			continue
		var rug: Dictionary = RUGS[rug_name]
		var cells: Array[Vector2i] = []
		var sum := Vector2.ZERO
		for c in plan.cells():
			if plan.zone(c) == room:
				cells.append(c)
				sum += Hex.center(c)
		var center := sum / float(cells.size())
		# Place libre autour du centre : jusqu'à la première case qui n'est plus dans la pièce.
		var free := 100.0
		for c in plan.cells():
			if plan.zone(c) != room and not plan.is_enclosure(c):
				free = minf(free, Hex.center(c).distance_to(center))
		free -= 0.75
		var carpet := _surface("moquette")
		var turn := deg_to_rad(rug["turn"])
		var layers := [[1.0, rug["border"]], [0.9, rug["band"]], [0.78, rug["field"]], [0.34, rug["band"]], [0.26, rug["border"]]]
		for i in layers.size():
			var scale: float = layers[i][0]
			var shape: PackedVector2Array
			if rug_name == "rond":
				shape = MeshBuilder.disc(center, free * 0.95 * scale, 40)
			elif i < 3:
				shape = MeshBuilder.box(center, Vector2(free * 1.05, free * 0.72) * scale, turn)
			else:
				# Le médaillon du centre, en losange.
				shape = MeshBuilder.box(center, Vector2.ONE * free * 0.9 * scale, turn + PI / 4)
			carpet.top(shape, RUG_HEIGHT + 0.0006 * i, layers[i][1], 0.9)


# --- Murs, portes, fenêtres ---

func _build_wall(a: Vector2, b: Vector2, outer: bool, high := WALL_HEIGHT, cut := true) -> void:
	if a.distance_to(b) < 0.001:
		return
	var thickness := OUTER_THICKNESS if outer else INNER_THICKNESS
	var shape := MeshBuilder.strip(a, b, thickness)
	_surface("crepi").sides(shape, 0.0, high, FACADE_COLOR if outer else PLASTER_COLOR, 2.0)
	if cut:
		_surface("uni").top(shape, high, CUT_COLOR)
	# Soubassement de pierre dehors, plinthe de bois dedans.
	var skirt := MeshBuilder.strip(a, b, thickness + 0.05)
	if outer:
		_surface("pierre").prism(skirt, 0.0, 0.16, STONE_COLOR, 1.5)
	else:
		_surface("bois").prism(skirt, 0.0, 0.08, BASEBOARD_COLOR, 1.0)


func _note_post(at: Vector2, outer: bool) -> void:
	var key := Vector2i(roundi(at.x * 1000.0), roundi(at.y * 1000.0))
	if not _posts.has(key) or outer:
		_posts[key] = {"at": at, "outer": outer}


## Arrondit l'angle entre deux murs par un fût de même épaisseur.
func _build_post(at: Vector2, outer: bool) -> void:
	var radius := (OUTER_THICKNESS if outer else INNER_THICKNESS) * 0.5
	var shape := MeshBuilder.disc(at, radius)
	_surface("crepi").sides(shape, 0.0, WALL_HEIGHT, FACADE_COLOR if outer else PLASTER_COLOR, 2.0)
	_surface("uni").top(shape, WALL_HEIGHT, CUT_COLOR)
	var skirt := MeshBuilder.disc(at, radius + 0.025)
	if outer:
		_surface("pierre").prism(skirt, 0.0, 0.16, STONE_COLOR, 1.5)
	else:
		_surface("bois").prism(skirt, 0.0, 0.08, BASEBOARD_COLOR, 1.0)


## Une porte ou une fenêtre occupe toute sa case : le mur la traverse d'un sommet à l'autre,
## avec la baie au milieu.
func _build_opening(c: Vector2i) -> void:
	var opening: Dictionary = plan.openings[c]
	var a := Hex.corner(c, opening["mur"][0])
	var b := Hex.corner(c, opening["mur"][1])
	var outer: bool = (opening["relie"] as Array).has(VillaPlan.OUTSIDE)
	var kind: String = opening["type"]
	var width := minf(0.86 if kind != "porte_interieure" else 0.78, a.distance_to(b) - 0.18)
	var along := (b - a).normalized()
	var left := (a + b) * 0.5 - along * width * 0.5
	var right := (a + b) * 0.5 + along * width * 0.5
	_build_wall(a, left, outer)
	_build_wall(right, b, outer)
	_note_post(a, outer)
	_note_post(b, outer)
	if kind == "fenetre":
		_build_window(left, right, outer)
	else:
		_build_door(left, right, kind == "porte_exterieure", outer)


func _build_door(left: Vector2, right: Vector2, exterior: bool, outer: bool) -> void:
	var along := (right - left).normalized()
	var depth := (OUTER_THICKNESS if outer else INNER_THICKNESS) + 0.05
	var wood := _surface("bois")
	# Les deux montants de l'huisserie, puis le vantail fermé entre eux.
	wood.prism(MeshBuilder.strip(left, left + along * 0.05, depth), 0.0, WALL_HEIGHT, FRAME_COLOR, 1.0)
	wood.prism(MeshBuilder.strip(right - along * 0.05, right, depth), 0.0, WALL_HEIGHT, FRAME_COLOR, 1.0)
	var leaf := 0.07 if exterior else 0.045
	wood.prism(MeshBuilder.strip(left + along * 0.05, right - along * 0.05, leaf), 0.0, WALL_HEIGHT - 0.03,
			OUTER_DOOR_COLOR if exterior else DOOR_COLOR, 0.8)
	var knob := right - along * 0.16
	_surface("uni").prism(MeshBuilder.strip(knob - along * 0.025, knob + along * 0.025, leaf + 0.08), 0.42, 0.46, BRASS_COLOR)
	if exterior:
		# Le seuil de pierre, qui dépasse du mur de chaque côté.
		_surface("pierre").prism(MeshBuilder.strip(left, right, depth + 0.26), 0.0, 0.04, STONE_COLOR, 1.5)


func _build_window(left: Vector2, right: Vector2, outer: bool) -> void:
	var along := (right - left).normalized()
	var thickness := OUTER_THICKNESS if outer else INNER_THICKNESS
	_build_wall(left, right, outer, SILL_HEIGHT, false)
	# L'appui de pierre, puis le dormant, le meneau et les vitres.
	_surface("pierre").prism(MeshBuilder.strip(left - along * 0.03, right + along * 0.03, thickness + 0.14),
			SILL_HEIGHT, SILL_HEIGHT + 0.05, STONE_COLOR, 1.5)
	var frame := _surface("uni")
	var bottom := SILL_HEIGHT + 0.05
	frame.prism(MeshBuilder.strip(left, right, 0.07), bottom, bottom + 0.045, WINDOW_FRAME_COLOR)
	var middle := (left + right) * 0.5
	for pair in [[left, left + along * 0.045], [middle - along * 0.02, middle + along * 0.02], [right - along * 0.045, right]]:
		frame.prism(MeshBuilder.strip(pair[0], pair[1], 0.07), bottom, WALL_HEIGHT, WINDOW_FRAME_COLOR)
	_surface("verre").prism(MeshBuilder.strip(left + along * 0.045, right - along * 0.045, 0.02), bottom + 0.045,
			WALL_HEIGHT - 0.02, GLASS_COLOR)


# --- Mur d'enceinte, grille, abords ---

## Coins du mur d'enceinte : il passe par le milieu des cases-mur du plan.
func _enclosure_rect() -> Rect2:
	var size := plan.size()
	return Rect2(0.75, 0.0, size.x - 1.5, Hex.center(Vector2i(0, size.y - 1)).y)


func _build_enclosure() -> void:
	var rect := _enclosure_rect()
	var gate_from := 1000.0
	var gate_to := -1000.0
	for c in plan.cells():
		if plan.cell(c) == "=":
			gate_from = minf(gate_from, Hex.center(c).x - 0.5)
			gate_to = maxf(gate_to, Hex.center(c).x + 0.5)
	var north_west := rect.position
	var north_east := Vector2(rect.end.x, rect.position.y)
	var south_west := Vector2(rect.position.x, rect.end.y)
	var south_east := rect.end
	var runs := [[north_west, north_east], [north_east, south_east], [north_west, south_west]]
	if gate_from < gate_to:
		runs.append([south_west, Vector2(gate_from, rect.end.y)])
		runs.append([Vector2(gate_to, rect.end.y), south_east])
		_build_gate(Vector2(gate_from, rect.end.y), Vector2(gate_to, rect.end.y))
	else:
		runs.append([south_west, south_east])
	for run in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		_surface("brique").sides(MeshBuilder.strip(a, b, ENCLOSURE_THICKNESS), 0.0, ENCLOSURE_HEIGHT, Color.WHITE, 1.0)
		_surface("pierre").prism(MeshBuilder.strip(a, b, ENCLOSURE_THICKNESS + 0.1), ENCLOSURE_HEIGHT,
				ENCLOSURE_HEIGHT + 0.07, STONE_COLOR, 1.5)
		var count := maxi(1, roundi(a.distance_to(b) / PILLAR_SPACING))
		for i in count + 1:
			_build_pillar(a.lerp(b, float(i) / count), 0.4, ENCLOSURE_HEIGHT + 0.2)


func _build_pillar(at: Vector2, width: float, height: float) -> void:
	var half := Vector2.ONE * width * 0.5
	_surface("brique").sides(MeshBuilder.box(at, half), 0.0, height, Color.WHITE, 1.0)
	_surface("pierre").prism(MeshBuilder.box(at, half + Vector2.ONE * 0.05), height, height + 0.08, STONE_COLOR, 1.5)
	_surface("pierre").prism(MeshBuilder.box(at, half * 0.6), height + 0.08, height + 0.16, STONE_COLOR, 1.5)


## Grille en fer forgé à deux vantaux, entre deux piliers plus hauts que les autres.
func _build_gate(a: Vector2, b: Vector2) -> void:
	_build_pillar(a - Vector2(0.12, 0.0), 0.56, 1.55)
	_build_pillar(b + Vector2(0.12, 0.0), 0.56, 1.55)
	var iron := _surface("uni")
	var from := a + Vector2(0.18, 0.0)
	var to := b - Vector2(0.18, 0.0)
	var middle := (from + to) * 0.5
	for leaf in [[from, middle - Vector2(0.015, 0.0)], [middle + Vector2(0.015, 0.0), to]]:
		var start: Vector2 = leaf[0]
		var end: Vector2 = leaf[1]
		iron.prism(MeshBuilder.strip(start, end, 0.045), 0.1, 0.15, IRON_COLOR)
		iron.prism(MeshBuilder.strip(start, end, 0.045), 1.08, 1.13, IRON_COLOR)
		var bars := 9
		for i in bars + 1:
			var at := start.lerp(end, float(i) / bars)
			# Les barreaux montent vers le milieu de la grille, en chapeau de gendarme.
			var rise := 1.0 - absf(at.x - middle.x) / (middle.x - from.x)
			iron.prism(MeshBuilder.box(at, Vector2.ONE * 0.016), 0.05, 1.2 + 0.28 * rise, IRON_COLOR)


## Ce qui entoure la propriété : trottoir au pied du mur, rue devant la grille, terrain au loin.
func _build_surroundings() -> void:
	var rect := _enclosure_rect()
	var outside := rect.grow(SIDEWALK_WIDTH)
	var far := rect.grow(170.0)
	_surface("uni").top(MeshBuilder.box(far.get_center(), far.size * 0.5), -0.06, SURROUNDINGS_COLOR)
	var road := Rect2(far.position.x, outside.end.y, far.size.x, ROAD_WIDTH)
	_surface("asphalte").top(MeshBuilder.box(road.get_center(), road.size * 0.5), -0.04, Color.WHITE, 3.0)
	var sidewalk := _surface("pierre")
	var bands := [
		Rect2(outside.position, Vector2(outside.size.x, SIDEWALK_WIDTH)),
		Rect2(outside.position.x, rect.end.y, outside.size.x, SIDEWALK_WIDTH),
		Rect2(outside.position.x, rect.position.y, SIDEWALK_WIDTH, rect.size.y),
		Rect2(rect.end.x, rect.position.y, SIDEWALK_WIDTH, rect.size.y),
	]
	for band in bands:
		sidewalk.prism(MeshBuilder.box(band.get_center(), band.size * 0.5), -0.06, SIDEWALK_HEIGHT, SIDEWALK_COLOR, 1.3)


# --- Arbres, gardes, repères ---

func _build_trees() -> void:
	if plan.trees.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.06
	trunk.bottom_radius = 0.1
	trunk.height = 1.2
	trunk.radial_segments = 8
	trunk.rings = 1
	var bark := StandardMaterial3D.new()
	bark.albedo_color = TRUNK_COLOR
	bark.albedo_texture = _texture("bois")
	bark.roughness = 1.0
	trunk.material = bark
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 0.9
	blob.radial_segments = 14
	blob.rings = 7
	var leaves := StandardMaterial3D.new()
	leaves.albedo_texture = _texture("feuillage")
	leaves.vertex_color_use_as_albedo = true
	leaves.uv1_scale = Vector3(2.0, 1.0, 1.0)
	leaves.roughness = 1.0
	blob.material = leaves
	var blobs_per_tree := 7
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk
	trunks.instance_count = plan.trees.size()
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.use_colors = true
	crowns.mesh = blob
	crowns.instance_count = plan.trees.size() * blobs_per_tree
	var index := 0
	var random := RandomNumberGenerator.new()
	for c in plan.trees:
		# Toujours les mêmes arbres d'un lancement à l'autre : le hasard part de la case.
		random.seed = c.x * 7919 + c.y * 104729
		var foot := to_world(c) + Vector3(random.randf_range(-0.15, 0.15), 0.0, random.randf_range(-0.15, 0.15))
		var size := random.randf_range(0.95, 1.35)
		var lean := Basis(Vector3(1, 0, 0), random.randf_range(-0.08, 0.08)) * Basis(Vector3(0, 0, 1), random.randf_range(-0.08, 0.08))
		trunks.set_instance_transform(index, Transform3D(lean.scaled(Vector3(size, size, size)), foot + Vector3(0, 0.6 * size, 0)))
		for i in blobs_per_tree:
			# Une touffe au sommet, les autres en couronne autour, toutes de tailles différentes.
			var offset := Vector3(0, 1.62, 0)
			var scale := 0.8
			if i > 0:
				var angle := TAU * (i + random.randf_range(-0.3, 0.3)) / (blobs_per_tree - 1)
				var reach := random.randf_range(0.26, 0.44)
				offset = Vector3(cos(angle) * reach, random.randf_range(1.12, 1.55), sin(angle) * reach)
				scale = random.randf_range(0.5, 0.75)
			var squash := Vector3(scale * random.randf_range(0.9, 1.15), scale * random.randf_range(0.75, 0.95), scale * random.randf_range(0.9, 1.15))
			var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(squash * size)
			crowns.set_instance_transform(index * blobs_per_tree + i, Transform3D(basis, foot + offset * size))
			var shade := random.randf_range(0.8, 1.1)
			crowns.set_instance_color(index * blobs_per_tree + i, Color(shade * random.randf_range(0.95, 1.08), shade, shade * random.randf_range(0.85, 0.98)))
		index += 1
	for multimesh in [trunks, crowns]:
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		add_child(node)


func _build_guards() -> void:
	for id in plan.guards:
		var at: Array = plan.guards[id]["case"]
		var c := Vector2i(int(at[0]), int(at[1]))
		var guard := Node3D.new()
		guard.position = to_world(c)
		add_child(guard)
		for side in [-1.0, 1.0]:
			guard.add_child(_part(_cylinder(0.065, 0.065, 0.8), UNIFORM_COLOR.darkened(0.15), Vector3(0.08 * side, 0.4, 0)))
			guard.add_child(_part(_cylinder(0.05, 0.045, 0.6), UNIFORM_COLOR, Vector3(0.21 * side, 1.02, 0)))
		guard.add_child(_part(_cylinder(0.15, 0.17, 0.62), UNIFORM_COLOR, Vector3(0, 1.08, 0)))
		var head := SphereMesh.new()
		head.radius = 0.105
		head.height = 0.23
		head.radial_segments = 12
		head.rings = 6
		guard.add_child(_part(head, SKIN_COLOR, Vector3(0, 1.52, 0)))
		# Le képi et sa visière.
		guard.add_child(_part(_cylinder(0.105, 0.115, 0.09), UNIFORM_COLOR.darkened(0.25), Vector3(0, 1.64, 0)))
		guard.add_child(_part(_cylinder(0.09, 0.09, 0.015), Color("15181f"), Vector3(0, 1.6, -0.08)))
		var label := Label3D.new()
		label.text = str(id)
		label.font_size = 96
		label.pixel_size = 0.0045
		label.outline_size = 24
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = Vector3(0, 2.05, 0)
		guard.add_child(label)


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh


static func _part(mesh: PrimitiveMesh, color: Color, at: Vector3) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	return node


## Une lettre couchée sur le sol de chaque pièce, pour s'y retrouver avec le plan dessiné (touche L).
func _build_room_labels() -> void:
	var sums: Dictionary = {}
	var members: Dictionary = {}
	for c in plan.cells():
		var z := plan.zone(c)
		if not plan.rooms.has(z):
			continue
		sums[z] = sums.get(z, Vector2.ZERO) + Hex.center(c)
		if not members.has(z):
			members[z] = []
		members[z].append(c)
	for z in members:
		var middle_point: Vector2 = sums[z] / float(members[z].size())
		var best: Vector2i = members[z][0]
		for c in members[z]:
			if Hex.center(c).distance_to(middle_point) < Hex.center(best).distance_to(middle_point):
				best = c
		var label := Label3D.new()
		label.text = z
		label.font_size = 96
		label.pixel_size = 0.006
		label.modulate = Color(0.15, 0.12, 0.1, 0.85)
		label.outline_size = 0
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = to_world(best, 0.03)
		label.visible = false
		add_child(label)
		_labels.append(label)


# --- Matières ---

func _surface(surface_name: String) -> MeshBuilder:
	if not _builders.has(surface_name):
		_builders[surface_name] = MeshBuilder.new()
	return _builders[surface_name]


func _add_mesh(surface_name: String, builder: MeshBuilder) -> void:
	if builder.is_empty():
		return
	var node := MeshInstance3D.new()
	node.name = surface_name.capitalize()
	node.mesh = builder.build()
	node.material_override = _material(surface_name)
	if surface_name == "lignes" or surface_name == "verre":
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


static func _texture(texture_name: String) -> Texture2D:
	return load("res://assets/textures/%s.png" % texture_name)


static func _material(surface_name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if TEXTURES.has(surface_name):
		material.albedo_texture = _texture(surface_name)
	match surface_name:
		"verre":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.roughness = 0.1
		"lignes":
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"carrelage":
			material.roughness = 0.45
		"parquet":
			material.roughness = 0.6
	return material
