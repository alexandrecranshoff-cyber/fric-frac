class_name Hex
extends RefCounted
## Grille d'hexagones « pointe en haut », en lignes. Une case est un Vector2i(colonne, ligne),
## origine en haut à gauche ; les lignes impaires sont décalées d'une demi-case vers la droite.

const DIRECTIONS: Array[String] = ["nord_ouest", "nord_est", "est", "sud_est", "sud_ouest", "ouest"]
## Les six sommets d'une case, dans le sens des aiguilles d'une montre.
const VERTICES: Array[String] = ["nord", "nord_est", "sud_est", "sud", "sud_ouest", "nord_ouest"]
## Sommets aux deux bouts du côté tourné vers chaque direction.
const EDGE_VERTICES := {
	"nord_est": ["nord", "nord_est"], "est": ["nord_est", "sud_est"], "sud_est": ["sud_est", "sud"],
	"sud_ouest": ["sud", "sud_ouest"], "ouest": ["sud_ouest", "nord_ouest"], "nord_ouest": ["nord_ouest", "nord"],
}
## Rayon d'une case (du centre à une pointe) quand sa largeur vaut 1.
const RADIUS := 0.5773502691896258

const _EVEN := {
	"nord_ouest": Vector2i(-1, -1), "nord_est": Vector2i(0, -1), "est": Vector2i(1, 0),
	"sud_est": Vector2i(0, 1), "sud_ouest": Vector2i(-1, 1), "ouest": Vector2i(-1, 0),
}
const _ODD := {
	"nord_ouest": Vector2i(0, -1), "nord_est": Vector2i(1, -1), "est": Vector2i(1, 0),
	"sud_est": Vector2i(1, 1), "sud_ouest": Vector2i(0, 1), "ouest": Vector2i(-1, 0),
}


## Case voisine dans une direction nommée.
static func step(cell: Vector2i, direction: String) -> Vector2i:
	var table: Dictionary = _ODD if cell.y % 2 != 0 else _EVEN
	return cell + (table[direction] as Vector2i)


## Direction contraire : celle par laquelle la voisine regarde la case d'où l'on vient.
static func opposite(direction: String) -> String:
	return DIRECTIONS[(DIRECTIONS.find(direction) + 3) % 6]


## Les six cases voisines, dans l'ordre de DIRECTIONS.
static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in DIRECTIONS:
		result.append(step(cell, d))
	return result


## Distance en cases entre deux cases, sans tenir compte des murs.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var ca := _to_cube(a)
	var cb := _to_cube(b)
	return maxi(maxi(absi(ca.x - cb.x), absi(ca.y - cb.y)), absi(ca.z - cb.z))


static func _to_cube(cell: Vector2i) -> Vector3i:
	var q := cell.x - (cell.y - (cell.y & 1)) / 2
	var r := cell.y
	return Vector3i(q, r, -q - r)


## Centre d'une case sur le plan : x vers l'est, y vers le sud, largeur d'une case = 1.
static func center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x + (0.5 if cell.y % 2 != 0 else 0.0), cell.y * 1.5 * RADIUS)


## Position d'un sommet nommé d'une case, dans le même repère que center().
static func corner(cell: Vector2i, vertex: String) -> Vector2:
	var angle := deg_to_rad(60.0 * VERTICES.find(vertex))
	return center(cell) + Vector2(sin(angle), -cos(angle)) * RADIUS
