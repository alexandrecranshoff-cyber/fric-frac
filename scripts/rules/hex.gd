class_name Hex
extends RefCounted
## Grille d'hexagones « pointe en haut », en lignes. Une case est un Vector2i(colonne, ligne),
## origine en haut à gauche ; les lignes impaires sont décalées d'une demi-case vers la droite.

const DIRECTIONS: Array[String] = ["nord_ouest", "nord_est", "est", "sud_est", "sud_ouest", "ouest"]

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
