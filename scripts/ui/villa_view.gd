class_name VillaView
extends Node3D
## Maquette 3D de la villa, construite entièrement depuis le plan (VillaPlan) : sols, murs coupés à
## mi-hauteur, portes, fenêtres, mur d'enceinte, arbres et gardes. Aucune règle ici, seulement du dessin.
## Repère : une case fait 1 de large, x vers l'est, z vers le sud, y vers le haut.

const WALL_HEIGHT := 0.55
const OUTER_WALL_THICKNESS := 0.16
const INNER_WALL_THICKNESS := 0.09
const ENCLOSURE_HEIGHT := 0.8
const GATE_HEIGHT := 0.6
const SILL_HEIGHT := 0.2
## Part du mur laissée pleine de chaque côté d'une porte ou d'une fenêtre.
const JAMB := 0.24
## Les dalles sont un peu plus petites que leur case : le joint, plus sombre, dessine le quadrillage.
const FLOOR_INSET := 0.93
const JOINT_DEPTH := 0.004
const JOINT_DARKENING := 0.22

const FLOOR_COLORS := {
	"bleu": Color("cfe6e2"), "parquet": Color("e9cf5c"), "blanc": Color("efeee2"),
	"rose": Color("f6cdb0"), "carrelage": Color("e9e6c4"), "creme": Color("f3e3b0"),
}
const OUTDOOR_COLORS := {
	".": Color("8fbf4f"), ",": Color("c9cda3"), "~": Color("e8d9a0"), "_": Color("e8d9a0"), "/": Color("d2b87c"),
}
const BASE_COLOR := Color("2a2622")
const WALL_COLOR := Color("f4efe4")
const OUTER_WALL_COLOR := Color("e6dcc6")
const WALL_CAP_COLOR := Color("40362e")
const BRICK_COLOR := Color("b9774d")
const BRICK_CAP_COLOR := Color("8f5636")
const GATE_COLOR := Color("2f6b3a")
const DOOR_COLOR := Color("f29a1f")
const OUTER_DOOR_COLOR := Color("d8402a")
const GLASS_COLOR := Color(0.35, 0.72, 0.9, 0.55)
const TRUNK_COLOR := Color("7a5230")
const LEAF_COLOR := Color("3f8f3a")
const GUARD_COLOR := Color("24365e")

## Côté de case qui part de chaque sommet, dans l'ordre de Hex.VERTICES.
const _EDGE_DIRECTIONS: Array[String] = ["nord_est", "est", "sud_est", "sud_ouest", "ouest", "nord_ouest"]

var plan: VillaPlan
var _solid := MeshBuilder.new()
var _glass := MeshBuilder.new()
## Poteaux aux bouts des murs : position arrondie -> {"at", "thickness"}.
var _posts: Dictionary = {}
var _labels: Array[Label3D] = []


func build(villa_plan: VillaPlan) -> void:
	plan = villa_plan
	_build_base()
	for c in plan.cells():
		if plan.is_enclosure(c):
			_build_enclosure(c)
		elif plan.is_opening(c):
			_build_opening(c)
		else:
			_build_floor(_hexagon(c, 1.0), _hexagon(c, FLOOR_INSET), _floor_color(c))
	for edge in plan.wall_edges():
		_build_wall_edge(edge["cell"], edge["direction"])
	for p in _posts.values():
		var outer: bool = p["thickness"] > INNER_WALL_THICKNESS
		_solid.post(p["at"], p["thickness"] * 0.58, 0.0, WALL_HEIGHT,
				OUTER_WALL_COLOR if outer else WALL_COLOR, WALL_CAP_COLOR)
	_add_mesh(_solid, _solid_material())
	_add_mesh(_glass, _glass_material())
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


func _build_base() -> void:
	var size := plan.size()
	var last := Hex.center(Vector2i(size.x - 1, size.y - 1))
	var margin := 0.9
	_solid.prism(PackedVector2Array([
		Vector2(-margin, -margin), Vector2(last.x + 0.5 + margin, -margin),
		Vector2(last.x + 0.5 + margin, last.y + margin), Vector2(-margin, last.y + margin),
	]), -0.3, -0.01, BASE_COLOR, BASE_COLOR)


func _build_enclosure(c: Vector2i) -> void:
	if plan.cell(c) == "#":
		_solid.prism(_hexagon(c, 1.0), 0.0, ENCLOSURE_HEIGHT, BRICK_COLOR, BRICK_CAP_COLOR)
		return
	# Grille d'entrée : un vantail vert en travers de la case, sur le sol de la cour.
	_build_floor(_hexagon(c, 1.0), _hexagon(c, FLOOR_INSET), OUTDOOR_COLORS[","])
	var at := Hex.center(c)
	_solid.wall(at - Vector2(0.5, 0.0), at + Vector2(0.5, 0.0), 0.08, 0.0, GATE_HEIGHT, GATE_COLOR, GATE_COLOR.darkened(0.3))


## Une porte ou une fenêtre occupe toute sa case : le mur la traverse d'un sommet à l'autre,
## avec un vantail ou une vitre au milieu, et chaque moitié de sol prend la couleur de son côté.
func _build_opening(c: Vector2i) -> void:
	var opening: Dictionary = plan.openings[c]
	var first := Hex.VERTICES.find(opening["mur"][0])
	var second := Hex.VERTICES.find(opening["mur"][1])
	if first > second:
		var swap := first
		first = second
		second = swap
	_build_half_floor(c, first, second)
	_build_half_floor(c, second, first + 6)

	var outer: bool = (opening["relie"] as Array).has(VillaPlan.OUTSIDE)
	var thickness := OUTER_WALL_THICKNESS if outer else INNER_WALL_THICKNESS
	var side := OUTER_WALL_COLOR if outer else WALL_COLOR
	var a := Hex.corner(c, Hex.VERTICES[first])
	var b := Hex.corner(c, Hex.VERTICES[second])
	var left := a.lerp(b, JAMB)
	var right := a.lerp(b, 1.0 - JAMB)
	_solid.wall(a, left, thickness, 0.0, WALL_HEIGHT, side, WALL_CAP_COLOR)
	_solid.wall(right, b, thickness, 0.0, WALL_HEIGHT, side, WALL_CAP_COLOR)
	_note_post(a, thickness)
	_note_post(b, thickness)
	if opening["type"] == "fenetre":
		_solid.wall(left, right, thickness, 0.0, SILL_HEIGHT, side, WALL_CAP_COLOR)
		_glass.wall(left, right, 0.03, SILL_HEIGHT, WALL_HEIGHT, GLASS_COLOR, GLASS_COLOR)
	else:
		var leaf := OUTER_DOOR_COLOR if opening["type"] == "porte_exterieure" else DOOR_COLOR
		_solid.wall(left, right, 0.05, 0.0, WALL_HEIGHT - 0.06, leaf, leaf.darkened(0.25))


## Moitié de dalle d'une case d'ouverture, entre deux sommets (indices dans Hex.VERTICES, le second
## pouvant dépasser 5 pour faire le tour). Sa couleur est celle de la zone sur laquelle elle donne.
func _build_half_floor(c: Vector2i, from: int, to: int) -> void:
	var at := Hex.center(c)
	var outline := PackedVector2Array()
	var slab := PackedVector2Array()
	for i in range(from, to + 1):
		var corner := Hex.corner(c, Hex.VERTICES[i % 6])
		outline.append(corner)
		slab.append(at + (corner - at) * FLOOR_INSET)
	var side := plan.side_zone(c, _EDGE_DIRECTIONS[from % 6])
	var color: Color = _room_color(side, c) if plan.rooms.has(side) else OUTDOOR_COLORS["."]
	# Dehors, on reprend le sol de la case voisine : herbe, terrasse, perron ou cour.
	for i in range(from, to):
		var neighbor := Hex.step(c, _EDGE_DIRECTIONS[i % 6])
		if not plan.is_opening(neighbor) and plan.zone(neighbor) == side:
			color = _floor_color(neighbor)
			break
	_build_floor(outline, slab, color)


## Une dalle et son joint : le contour entier un peu plus sombre, la dalle par-dessus.
func _build_floor(outline: PackedVector2Array, slab: PackedVector2Array, color: Color) -> void:
	_solid.top(outline, -JOINT_DEPTH, color.darkened(JOINT_DARKENING))
	_solid.top(slab, 0.0, color)


func _build_wall_edge(c: Vector2i, direction: String) -> void:
	var opposite := Hex.opposite(direction)
	var neighbor := Hex.step(c, direction)
	var outer := plan.side_zone(c, direction) == VillaPlan.OUTSIDE or plan.side_zone(neighbor, opposite) == VillaPlan.OUTSIDE
	var thickness := OUTER_WALL_THICKNESS if outer else INNER_WALL_THICKNESS
	var ends: Array = Hex.EDGE_VERTICES[direction]
	var a := Hex.corner(c, ends[0])
	var b := Hex.corner(c, ends[1])
	_solid.wall(a, b, thickness, 0.0, WALL_HEIGHT, OUTER_WALL_COLOR if outer else WALL_COLOR, WALL_CAP_COLOR)
	_note_post(a, thickness)
	_note_post(b, thickness)


func _note_post(at: Vector2, thickness: float) -> void:
	var key := Vector2i(roundi(at.x * 1000.0), roundi(at.y * 1000.0))
	if not _posts.has(key) or _posts[key]["thickness"] < thickness:
		_posts[key] = {"at": at, "thickness": thickness}


func _build_trees() -> void:
	if plan.trees.is_empty():
		return
	var trunks := MeshBuilder.new()
	var crown := SphereMesh.new()
	crown.radius = 0.42
	crown.height = 0.72
	crown.radial_segments = 12
	crown.rings = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = LEAF_COLOR
	material.roughness = 1.0
	crown.material = material
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.mesh = crown
	crowns.instance_count = plan.trees.size()
	var i := 0
	for c in plan.trees:
		trunks.post(Hex.center(c), 0.07, 0.0, 0.5, TRUNK_COLOR, TRUNK_COLOR)
		# Tailles un peu différentes d'un arbre à l'autre, toujours les mêmes d'un lancement à l'autre.
		var scale_factor := 0.85 + 0.3 * (float((c.x * 7 + c.y * 13) % 5) / 4.0)
		crowns.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * scale_factor), to_world(c, 0.72)))
		i += 1
	_add_mesh(trunks, _solid_material())
	var node := MultiMeshInstance3D.new()
	node.multimesh = crowns
	add_child(node)


func _build_guards() -> void:
	for id in plan.guards:
		var at: Array = plan.guards[id]["case"]
		var c := Vector2i(int(at[0]), int(at[1]))
		var body := CapsuleMesh.new()
		body.radius = 0.2
		body.height = 0.75
		body.radial_segments = 12
		body.rings = 4
		var material := StandardMaterial3D.new()
		material.albedo_color = GUARD_COLOR
		body.material = material
		var pawn := MeshInstance3D.new()
		pawn.mesh = body
		pawn.position = to_world(c, 0.38)
		add_child(pawn)
		var label := Label3D.new()
		label.text = str(id)
		label.font_size = 96
		label.pixel_size = 0.004
		label.outline_size = 24
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = to_world(c, 1.05)
		add_child(label)


## Une lettre couchée sur le sol de chaque pièce, pour s'y retrouver avec le plan dessiné.
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
		label.pixel_size = 0.005
		label.modulate = Color(0.2, 0.17, 0.14, 0.75)
		label.outline_size = 0
		label.rotation_degrees = Vector3(-90, 0, 0)
		label.position = to_world(best, 0.01)
		add_child(label)
		_labels.append(label)


func _floor_color(c: Vector2i) -> Color:
	var ch := plan.cell(c)
	if OUTDOOR_COLORS.has(ch):
		return OUTDOOR_COLORS[ch]
	if not plan.rooms.has(ch):
		return BASE_COLOR
	return _room_color(ch, c)


## Couleur du sol d'une pièce ; le carrelage du hall alterne deux tons, une case sur trois.
func _room_color(room: String, c: Vector2i) -> Color:
	var kind: String = plan.rooms[room]["sol"]
	var color: Color = FLOOR_COLORS.get(kind, Color.WHITE)
	if kind == "carrelage" and posmod(c.x - (c.y - (c.y & 1)) / 2 - c.y, 3) == 0:
		color = color.darkened(0.1)
	return color


func _hexagon(c: Vector2i, inset: float) -> PackedVector2Array:
	var at := Hex.center(c)
	var points := PackedVector2Array()
	for vertex in Hex.VERTICES:
		points.append(at + (Hex.corner(c, vertex) - at) * inset)
	return points


func _add_mesh(builder: MeshBuilder, material: Material) -> void:
	if builder.is_empty():
		return
	var node := MeshInstance3D.new()
	node.mesh = builder.build()
	node.material_override = material
	add_child(node)


static func _solid_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	return material


static func _glass_material() -> StandardMaterial3D:
	var material := _solid_material()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
