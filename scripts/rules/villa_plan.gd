class_name VillaPlan
extends RefCounted
## Le plan de la villa lu dans data/villa.json : cases, pièces, ouvertures et murs.
## Sert aux règles (peut-on passer d'une case à sa voisine ?) comme à l'affichage.

const OUTSIDE := "dehors"
const OUTSIDE_CHARS := ".,~_/"
const ENCLOSURE_CHARS := "#="

var rows: Array
var rooms: Dictionary
## Ouvertures par case : {"type", "relie": [zone, zone], "mur": [sommet, sommet]}.
var openings: Dictionary = {}
var trees: Dictionary = {}
var guards: Dictionary
var _half_cache: Dictionary = {}


func _init(data: Dictionary) -> void:
	rows = data["lignes"]
	rooms = data["pieces"]
	guards = data["gardes"]
	for o in data["ouvertures"]:
		openings[Vector2i(int(o["case"][0]), int(o["case"][1]))] = o
	for t in data["arbres"]:
		trees[Vector2i(int(t[0]), int(t[1]))] = true


func size() -> Vector2i:
	return Vector2i((rows[0] as String).length(), rows.size())


## Caractère du plan pour une case, ou " " hors plateau.
func cell(c: Vector2i) -> String:
	if c.y < 0 or c.y >= rows.size():
		return " "
	var row: String = rows[c.y]
	if c.x < 0 or c.x >= row.length():
		return " "
	return row[c.x]


## Toutes les cases du plateau, mur d'enceinte compris.
func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in rows.size():
		for x in (rows[y] as String).length():
			if rows[y][x] != " ":
				result.append(Vector2i(x, y))
	return result


## Zone d'une case : lettre de sa pièce, "dehors" pour le jardin, la cour, la terrasse et le perron,
## "" pour une ouverture, le mur d'enceinte ou le vide.
func zone(c: Vector2i) -> String:
	var ch := cell(c)
	if OUTSIDE_CHARS.contains(ch):
		return OUTSIDE
	if rooms.has(ch):
		return ch
	return ""


func is_opening(c: Vector2i) -> bool:
	return openings.has(c)


func is_enclosure(c: Vector2i) -> bool:
	return ENCLOSURE_CHARS.contains(cell(c))


## Zone qu'une case présente à sa voisine dans une direction donnée. Une case ordinaire n'a qu'une
## zone ; une porte ou une fenêtre est coupée en deux par son mur et présente, de chaque côté,
## la zone vers laquelle ce côté donne.
func side_zone(c: Vector2i, direction: String) -> String:
	if not is_opening(c):
		return zone(c)
	return _halves(c)[_half_index(c, direction)]


## Deux cases voisines communiquent-elles à pied, sans compter l'effraction ?
## Oui si elles se touchent du même côté des murs : on reste dans une même pièce ou dehors, et on ne
## change de zone qu'en traversant une case porte ou fenêtre.
## Le mur d'enceinte a ses propres règles (saut, grille) et ne communique pas ici.
func passable(a: Vector2i, b: Vector2i) -> bool:
	for d in Hex.DIRECTIONS:
		if Hex.step(a, d) == b:
			var side := side_zone(a, d)
			return side != "" and side == side_zone(b, Hex.opposite(d))
	return false


## Les côtés de case qui portent un mur : entre deux cases du terrain qui ne communiquent pas.
## Chaque mur est donné une seule fois, par sa case et la direction de la voisine.
func wall_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c in cells():
		if is_enclosure(c):
			continue
		for d in ["nord_est", "est", "sud_est"]:
			var n := Hex.step(c, d)
			if cell(n) == " " or is_enclosure(n) or passable(c, n):
				continue
			result.append({"cell": c, "direction": d})
	return result


## De quel côté de son mur (0 ou 1) se trouve le bord d'une ouverture tourné vers une direction.
func _half_index(c: Vector2i, direction: String) -> int:
	var wall: Array = openings[c]["mur"]
	var first := mini(Hex.VERTICES.find(wall[0]), Hex.VERTICES.find(wall[1]))
	var second := maxi(Hex.VERTICES.find(wall[0]), Hex.VERTICES.find(wall[1]))
	# Un côté de case part du sommet de même rang que lui dans le tour d'horloge.
	var start := Hex.VERTICES.find(Hex.EDGE_VERTICES[direction][0])
	return 0 if start >= first and start < second else 1


## Les zones des deux moitiés d'une ouverture : chacune est celle d'une case ordinaire qu'elle touche.
func _halves(c: Vector2i) -> Array:
	if _half_cache.has(c):
		return _half_cache[c]
	var linked: Array = openings[c]["relie"]
	var halves := ["", ""]
	for d in Hex.DIRECTIONS:
		var n := Hex.step(c, d)
		if not is_opening(n) and linked.has(zone(n)):
			halves[_half_index(c, d)] = zone(n)
	# Une moitié qui ne touche que d'autres ouvertures donne sur la zone que l'autre moitié n'a pas.
	for i in 2:
		if halves[i] == "":
			halves[i] = linked[1] if halves[1 - i] == linked[0] else linked[0]
	_half_cache[c] = halves
	return halves
