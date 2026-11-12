class_name VillaOutline
extends RefCounted
## Tracé de la villa pour l'affichage. Sur le plateau, les murs suivent les côtés des cases, donc
## les murs est-ouest font des zigzags. Ici, chaque ligne de murs (et chaque limite entre deux sols)
## est redressée comme sur le poster : les sommets des zigzags sont ramenés sur une droite, et les
## cases qui la bordent sont rognées ou complétées d'autant. Les règles, elles, ne changent pas.

## Écart maximal entre un sommet et la droite qui le remplace. Un zigzag s'écarte de 0,29 case.
const TOLERANCE := 0.3

var plan: VillaPlan
## Tronçons droits : {"a", "b" : Vector2, "wall" : bool, "outer" : bool, "kinds" : [sol, sol]}.
var segments: Array[Dictionary] = []
var _moved: Dictionary = {}
var _edges: Array[Dictionary] = []
var _links: Dictionary = {}
var _fixed: Dictionary = {}


func _init(villa_plan: VillaPlan) -> void:
	plan = villa_plan
	_collect_edges()
	_mark_fixed_points()
	_straighten()


## Position d'un sommet de case une fois le tracé redressé.
func corner(cell: Vector2i, vertex: String) -> Vector2:
	var at := Hex.corner(cell, vertex)
	return _moved.get(_key(at), at)


## Nature du sol qu'une case présente vers une direction : lettre de la pièce, ou caractère du
## plan pour l'extérieur (. jardin, , cour, ~ terrasse, _ perron, / marches).
func surface(c: Vector2i, direction: String) -> String:
	var ch := plan.cell(c)
	if ch == "=":
		return ","
	if ch == "#":
		# Le mur d'enceinte est posé sur le sol qui le borde : la cour s'il la touche, sinon le jardin.
		for n in Hex.neighbors(c):
			if ",=".contains(plan.cell(n)) and plan.cell(n) != " ":
				return ","
		return "."
	if not plan.is_opening(c):
		return ch
	var zone := plan.side_zone(c, direction)
	if zone != VillaPlan.OUTSIDE:
		return zone
	var side := plan.opening_side(c, direction)
	for d in Hex.DIRECTIONS:
		var n := Hex.step(c, d)
		if plan.opening_side(c, d) == side and not plan.is_opening(n) and plan.zone(n) == VillaPlan.OUTSIDE:
			return plan.cell(n)
	return "."


func _collect_edges() -> void:
	for c in plan.cells():
		for d in ["nord_est", "est", "sud_est"]:
			var n := Hex.step(c, d)
			if plan.cell(n) == " ":
				continue
			var back := Hex.opposite(d)
			var kinds := [surface(c, d), surface(n, back)]
			var wall := not plan.is_enclosure(c) and not plan.is_enclosure(n) and not plan.passable(c, n)
			if not wall and kinds[0] == kinds[1]:
				continue
			var outer := wall and (plan.side_zone(c, d) == VillaPlan.OUTSIDE or plan.side_zone(n, back) == VillaPlan.OUTSIDE)
			var ends: Array = Hex.EDGE_VERTICES[d]
			var edge := {
				"a": Hex.corner(c, ends[0]), "b": Hex.corner(c, ends[1]),
				"wall": wall, "outer": outer, "kinds": kinds, "used": false,
			}
			for point in [edge["a"], edge["b"]]:
				var key := _key(point)
				if not _links.has(key):
					_links[key] = []
				_links[key].append(_edges.size())
			_edges.append(edge)


## Les points qui ne bougent pas : carrefours, bouts de ligne, changements de nature (mur
## extérieur, mur intérieur, simple limite de sol) et extrémités du mur de chaque ouverture.
func _mark_fixed_points() -> void:
	for c in plan.openings:
		for vertex in plan.openings[c]["mur"]:
			_fixed[_key(Hex.corner(c, vertex))] = true
	for key in _links:
		var around: Array = _links[key]
		if around.size() != 2 or _style(_edges[around[0]]) != _style(_edges[around[1]]):
			_fixed[key] = true


func _straighten() -> void:
	for key in _fixed:
		for index in _links.get(key, []):
			if not _edges[index]["used"]:
				_follow(key, index)
	# Une boucle sans carrefour : on la prend par un bout quelconque.
	for index in _edges.size():
		if not _edges[index]["used"]:
			_follow(_key(_edges[index]["a"]), index)


## Suit une ligne depuis un point fixe jusqu'au suivant, puis la remplace par des tronçons droits.
func _follow(start: Vector2i, first: int) -> void:
	var points: Array[Vector2] = []
	var key := start
	var index := first
	var model: Dictionary = _edges[first]
	while true:
		var edge: Dictionary = _edges[index]
		edge["used"] = true
		var from_a: bool = _key(edge["a"]) == key
		if points.is_empty():
			points.append(edge["a"] if from_a else edge["b"])
		var next: Vector2 = edge["b"] if from_a else edge["a"]
		points.append(next)
		key = _key(next)
		if _fixed.has(key) or key == start:
			break
		index = -1
		for other in _links[key]:
			if not _edges[other]["used"]:
				index = other
		if index < 0:
			break
	var kept := _simplify(points)
	for i in kept.size() - 1:
		var a := points[kept[i]]
		var b := points[kept[i + 1]]
		segments.append({"a": a, "b": b, "wall": model["wall"], "outer": model["outer"], "kinds": model["kinds"]})
		for k in range(kept[i] + 1, kept[i + 1]):
			_moved[_key(points[k])] = Geometry2D.get_closest_point_to_segment(points[k], a, b)


## Garde seulement les points qui s'écartent de la droite de plus que la tolérance (Douglas-Peucker).
static func _simplify(points: Array[Vector2]) -> Array[int]:
	var keep := {0: true, points.size() - 1: true}
	var pending: Array = [[0, points.size() - 1]]
	while not pending.is_empty():
		var span: Array = pending.pop_back()
		var worst := -1
		var worst_distance := TOLERANCE
		for k in range(span[0] + 1, span[1]):
			var on_line := Geometry2D.get_closest_point_to_segment(points[k], points[span[0]], points[span[1]])
			var distance := points[k].distance_to(on_line)
			if distance > worst_distance:
				worst = k
				worst_distance = distance
		if worst >= 0:
			keep[worst] = true
			pending.append([span[0], worst])
			pending.append([worst, span[1]])
	var result: Array[int] = []
	for k in points.size():
		if keep.has(k):
			result.append(k)
	return result


static func _style(edge: Dictionary) -> int:
	return 0 if not edge["wall"] else (2 if edge["outer"] else 1)


static func _key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 1000.0), roundi(point.y * 1000.0))
