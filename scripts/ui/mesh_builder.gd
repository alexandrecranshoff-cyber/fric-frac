class_name MeshBuilder
extends RefCounted
## Assemble beaucoup de petits volumes (dalles, murs, poteaux) en un seul maillage coloré par sommet,
## pour que toute la villa se dessine en très peu d'appels : indispensable dans un navigateur.

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()


func is_empty() -> bool:
	return _vertices.is_empty()


## Face horizontale tournée vers le haut. Points donnés sur le plan (x vers l'est, y vers le sud).
func top(points: PackedVector2Array, height: float, color: Color) -> void:
	var pts := _clockwise(points)
	for i in range(1, pts.size() - 1):
		_triangle(_up(pts[0], height), _up(pts[i], height), _up(pts[i + 1], height), Vector3.UP, color)


## Volume droit posé sur le plan : contour quelconque (convexe), de la hauteur `low` à `high`.
func prism(points: PackedVector2Array, low: float, high: float, side: Color, cap: Color) -> void:
	var pts := _clockwise(points)
	top(pts, high, cap)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var edge := b - a
		var normal := Vector3(edge.y, 0.0, -edge.x).normalized()
		_triangle(_up(b, high), _up(a, high), _up(a, low), normal, side)
		_triangle(_up(b, high), _up(a, low), _up(b, low), normal, side)


## Mur droit entre deux points du plan.
func wall(a: Vector2, b: Vector2, thickness: float, low: float, high: float, side: Color, cap: Color) -> void:
	var across := (b - a).normalized().orthogonal() * thickness * 0.5
	prism(PackedVector2Array([a - across, b - across, b + across, a + across]), low, high, side, cap)


## Poteau à six pans, pour fermer proprement les angles entre deux murs.
func post(at: Vector2, radius: float, low: float, high: float, side: Color, cap: Color) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i + 30.0)
		pts.append(at + Vector2(sin(angle), -cos(angle)) * radius)
	prism(pts, low, high, side, cap)


func build() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	_vertices.append(a)
	_vertices.append(b)
	_vertices.append(c)
	for i in 3:
		_normals.append(normal)
		_colors.append(color)


static func _up(p: Vector2, height: float) -> Vector3:
	return Vector3(p.x, height, p.y)


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
