class_name BoardOverlay
extends Node3D
## Calques de cases posés sur le sol de la villa : brouillard, cases atteignables, chemin visé,
## onde de bruit, pièce où un garde voit. Chaque calque est un maillage refait à la demande, une
## tuile hexagonale par case, à la forme redressée de la maquette. Aucune règle ici.

## Hauteur de chaque calque au-dessus du sol, du plus bas au plus haut.
const LAYERS := {
	"brouillard": 0.032,
	"piece": 0.036,
	"portee": 0.04,
	"bruit": 0.046,
	"chemin": 0.052,
	"survol": 0.058,
}
## Part de la case couverte par une tuile : un liseré de sol reste visible entre deux tuiles.
const INSET := {"brouillard": 1.0, "piece": 1.0, "portee": 0.86, "bruit": 0.92, "chemin": 0.7, "survol": 0.94}

var outline: VillaOutline
var _meshes: Dictionary = {}


func setup(villa_outline: VillaOutline) -> void:
	outline = villa_outline
	for layer in LAYERS:
		var instance := MeshInstance3D.new()
		instance.name = layer
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.material_override = _material(layer)
		add_child(instance)
		_meshes[layer] = instance


## Peint un calque : case -> couleur. Un dictionnaire vide efface le calque.
func paint(layer: String, cells: Dictionary) -> void:
	var instance: MeshInstance3D = _meshes[layer]
	if cells.is_empty():
		instance.mesh = null
		return
	var builder := MeshBuilder.new()
	var height: float = LAYERS[layer]
	for c: Vector2i in cells:
		builder.top(tile(c, INSET[layer]), height, cells[c])
	instance.mesh = builder.build()


func clear(layer: String) -> void:
	paint(layer, {})


## Contour d'une case, rétréci vers son centre selon `inset`, dans le repère du sol (x, z).
func tile(c: Vector2i, inset := 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var middle := Vector2.ZERO
	for v in Hex.VERTICES:
		var p := outline.corner(c, v)
		points.append(p)
		middle += p
	middle /= 6.0
	for i in points.size():
		points[i] = middle + (points[i] - middle) * inset
	return points


static func _material(layer: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Les calques se lisent par-dessus le sol mais restent cachés par les murs et les pions.
	m.render_priority = LAYERS.keys().find(layer)
	return m
