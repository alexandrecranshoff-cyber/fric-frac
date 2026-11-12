class_name MeshBuilder
extends RefCounted
## Assemble beaucoup de petits volumes (dalles, murs, poteaux) en un seul maillage, avec pour chaque
## sommet une couleur et une position dans la matière. Toute la villa se dessine ainsi en très peu
## d'appels : indispensable dans un navigateur.
## Les points sont donnés sur le plan : x vers l'est, y vers le sud. La matière se répète tous les
## `tile` mètres (une case fait un mètre de large).

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()


func is_empty() -> bool:
	return _vertices.is_empty()


## Face horizontale tournée vers le haut. `turn` fait pivoter la matière (en radians).
func top(points: PackedVector2Array, height: float, color := Color.WHITE, tile := 1.0, turn := 0.0) -> void:
	var pts := _clockwise(points)
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i], pts[i + 1]]:
			_vertex(Vector3(p.x, height, p.y), Vector3.UP, color, p.rotated(turn) / tile)


## Les faces verticales d'un contour, de la hauteur `low` à `high`.
func sides(points: PackedVector2Array, low: float, high: float, color := Color.WHITE, tile := 1.0) -> void:
	var pts := _clockwise(points)
	var along := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var edge := b - a
		var length := edge.length()
		var normal := Vector3(edge.y, 0.0, -edge.x).normalized()
		var corners := [
			[b, high, along + length], [a, high, along], [a, low, along],
			[b, high, along + length], [a, low, along], [b, low, along + length],
		]
		for corner in corners:
			var p: Vector2 = corner[0]
			_vertex(Vector3(p.x, corner[1], p.y), normal, color, Vector2(corner[2], -corner[1]) / tile)
		along += length


## Volume droit posé sur le plan : faces verticales et dessus dans la même matière.
func prism(points: PackedVector2Array, low: float, high: float, color := Color.WHITE, tile := 1.0) -> void:
	sides(points, low, high, color, tile)
	top(points, high, color, tile)


func build() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Contour d'une bande droite de largeur donnée entre deux points.
static func strip(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var across := (b - a).normalized().orthogonal() * width * 0.5
	return PackedVector2Array([a - across, b - across, b + across, a + across])


## Contour d'un rectangle centré, tourné de `turn` radians.
static func box(center: Vector2, half: Vector2, turn := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		points.append(center + (corner * half).rotated(turn))
	return points


## Contour d'un disque, en `count` pans.
static func disc(center: Vector2, radius: float, count := 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(center + Vector2.from_angle(TAU * i / count) * radius)
	return points


func _vertex(position: Vector3, normal: Vector3, color: Color, uv: Vector2) -> void:
	_vertices.append(position)
	_normals.append(normal)
	_colors.append(color)
	_uvs.append(uv)


## Remet un contour dans le sens des aiguilles d'une montre (vu de dessus, sud en bas).
static func _clockwise(points: PackedVector2Array) -> PackedVector2Array:
	var area := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	if area >= 0.0:
		return points
	var reversed := points.duplicate()
	reversed.reverse()
	return reversed
