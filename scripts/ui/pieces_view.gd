class_name PiecesView
extends Node3D
## Les pions sur la maquette : voleurs en 3D animés, gardes et dormeurs en formes simples, meubles
## en volumes gris sous leur housse tant qu'ils ne sont pas découverts. Ne lit l'état que pour le
## montrer ; ce qui est caché au joueur (brouillard) est décidé par l'appelant.

const MODELS := "res://assets/models/personnages/%s/%s.glb"
const WALK_SECONDS := 0.42
const GUARD_STEP_SECONDS := 0.26
const BLEND := 0.2
const COVER_COLOR := Color("d8d2c4")
const EMPTY_COLOR := Color("6f675d")
## Meubles : couleur une fois découvert, hauteur, largeur et profondeur sur une case.
const FURNITURE_LOOK := {
	"secretaire": {"color": Color("8a5a34"), "height": 1.05, "size": Vector2(0.72, 0.46)},
	"coffre_fort": {"color": Color("4b5560"), "height": 0.8, "size": Vector2(0.6, 0.6)},
	"armoire": {"color": Color("6b4426"), "height": 1.25, "size": Vector2(0.62, 0.5)},
	"gueridon": {"color": Color("a77c4f"), "height": 0.7, "size": Vector2(0.5, 0.5)},
	"fauteuil": {"color": Color("7d2f2a"), "height": 0.85, "size": Vector2(0.62, 0.62)},
	"lit": {"color": Color("c9b48f"), "height": 0.55, "size": Vector2(0.8, 0.6)},
}
const GUARD_COLOR := Color("27375f")
const SLEEPER_COLOR := Color("e9e2d2")

var state: GameState
var data: GameData
## Numéro du pion -> son nœud.
var nodes: Dictionary = {}
## Numéro du pion -> son AnimationPlayer (voleurs en 3D).
var players: Dictionary = {}
## Numéro du meuble -> son nœud.
var furniture_nodes: Dictionary = {}
## Silhouettes des gardes perdus de vue, à leur dernière place connue.
var ghosts: Dictionary = {}
## Rang de chaque voleur dans la rue, pour les aligner devant la grille.
var _street_rank: Dictionary = {}


func setup(game: GameState) -> void:
	state = game
	data = game.data
	for p in state.pawns:
		var node: Node3D
		match p.kind:
			Pawn.Kind.THIEF:
				node = _thief_node(p)
				_street_rank[p.id] = _street_rank.size()
			Pawn.Kind.GUARD:
				# La figure regarde vers -z : on la retourne, tous les pions regardent vers +z.
				node = Node3D.new()
				var figure := VillaView.guard_figure(GUARD_COLOR)
				figure.rotation.y = PI
				figure.add_child(_lantern())
				node.add_child(figure)
			Pawn.Kind.SLEEPER:
				node = _sleeper_node()
		node.name = "pion_%d" % p.id
		add_child(node)
		nodes[p.id] = node
	for f in state.furniture:
		var node := Node3D.new()
		node.name = "meuble_%d" % f.id
		add_child(node)
		furniture_nodes[f.id] = node
		_dress_furniture(f)
	for g in state.guards():
		var ghost := VillaView.guard_figure(Color(0.6, 0.65, 0.75))
		_make_ghostly(ghost)
		ghost.visible = false
		add_child(ghost)
		ghosts[g.id] = ghost
	sync_all()


## Remet chaque pion et chaque meuble à sa place, sans animation.
func sync_all() -> void:
	for p in state.pawns:
		place(p)
	for f in state.furniture:
		_dress_furniture(f)


## Pose un pion sur sa case, couché s'il est assommé ou mort, caché s'il a quitté le plateau.
func place(p: Pawn) -> void:
	var node: Node3D = nodes[p.id]
	if p.is_sleeper():
		var f := state.get_furniture(p.furniture_id)
		node.position = _furniture_center(f) + Vector3(0, FURNITURE_LOOK["lit"]["height"], 0)
		node.rotation.y = _furniture_turn(f)
		node.visible = f.revealed and p.status != Pawn.Status.DEAD
		return
	var gone := p.status == Pawn.Status.ESCAPED or p.status == Pawn.Status.ARRESTED
	node.visible = not gone
	if gone:
		return
	node.position = position_of(p)
	var down := p.status == Pawn.Status.KO or p.status == Pawn.Status.DEAD
	node.rotation.x = -PI / 2 if down else 0.0
	if down:
		node.position.y += 0.15
	if p.status == Pawn.Status.OUTSIDE:
		node.rotation.y = PI  # dos à la rue, face à la villa
	if players.has(p.id) and not down:
		_idle(p.id)


## Position d'un pion dans la maquette : sur sa case, sur le mur, du bon côté d'une porte, ou dans
## la rue devant la grille s'il n'est pas encore entré.
func position_of(p: Pawn) -> Vector3:
	if p.status == Pawn.Status.OUTSIDE:
		return _street_spot(_street_rank.get(p.id, 0))
	return cell_spot(p.pos, p.side)


func cell_spot(c: Vector2i, side := -1) -> Vector3:
	var plan := state.plan
	if plan.is_wall(c):
		return VillaView.to_world(c, VillaView.ENCLOSURE_HEIGHT)
	var at := VillaView.to_world(c)
	if plan.is_opening(c) and side >= 0:
		# Du côté du mur où il se tient : vers les cases voisines de ce côté.
		var lean := Vector3.ZERO
		for d in Hex.DIRECTIONS:
			if plan.opening_side(c, d) == side:
				lean += VillaView.to_world(Hex.step(c, d)) - at
		if lean.length() > 0.01:
			at += lean.normalized() * 0.27
	return at


## Fait marcher un voleur le long d'un chemin de cases. À attendre (await).
func walk(p: Pawn, from: Vector2i, path: Array) -> void:
	var node: Node3D = nodes[p.id]
	node.visible = true
	_play(p.id, "marche_furtive", 1.0)
	var previous := from
	for cell: Vector2i in path:
		var goal := cell_spot(cell, Movement.side_after(state, previous, cell))
		_face(node, goal)
		var tween := create_tween()
		tween.tween_property(node, "position", goal, WALK_SECONDS)
		await tween.finished
		previous = cell
	place(p)


## Saut ou escalade : un bond rapide vers la case d'arrivée.
func hop(p: Pawn, to: Vector3) -> void:
	var node: Node3D = nodes[p.id]
	node.visible = true
	_face(node, to)
	var start := node.position
	var tween := create_tween()
	tween.tween_method(func(t: float): node.position = start.lerp(to, t) + Vector3(0, sin(t * PI) * 0.6, 0), 0.0, 1.0, 0.5)
	await tween.finished


## Un pas de garde.
func guard_step(g: Pawn, to: Vector2i) -> void:
	var node: Node3D = nodes[g.id]
	var goal := cell_spot(to)
	_face(node, goal)
	var tween := create_tween()
	tween.tween_property(node, "position", goal, GUARD_STEP_SECONDS)
	await tween.finished


## Joue un geste du voleur (ouvrir une porte, ramasser), puis revient à l'attente.
func gesture(p: Pawn, animation: String, seconds := 1.4) -> void:
	if not players.has(p.id):
		await get_tree().create_timer(seconds * 0.5).timeout
		return
	_play(p.id, animation, 1.6)
	await get_tree().create_timer(seconds).timeout
	_idle(p.id)


## Tourne un pion vers un point.
func look_at_point(p: Pawn, at: Vector3) -> void:
	_face(nodes[p.id], at)


## Montre ou cache un pion (brouillard) et la silhouette d'un garde perdu de vue.
func set_pawn_visible(p: Pawn, shown: bool) -> void:
	var node: Node3D = nodes[p.id]
	var gone := p.status == Pawn.Status.ESCAPED or p.status == Pawn.Status.ARRESTED
	if p.is_sleeper():
		shown = shown and state.get_furniture(p.furniture_id).revealed and p.status != Pawn.Status.DEAD
	node.visible = shown and not gone


func show_ghost(guard_id: int, cell: Vector2i, shown: bool) -> void:
	var ghost: Node3D = ghosts[guard_id]
	ghost.visible = shown
	if shown:
		ghost.position = cell_spot(cell)


func set_furniture_visible(f: Furniture, shown: bool) -> void:
	furniture_nodes[f.id].visible = shown


## Redessine un meuble selon ce qu'on sait de lui : housse, découvert, forcé ou vidé.
func refresh_furniture(f: Furniture) -> void:
	_dress_furniture(f)


# --- Construction ---

func _thief_node(p: Pawn) -> Node3D:
	var model := _model_of(p)
	var root := Node3D.new()
	if model == "":
		# Pion gris, en attendant un modèle 3D.
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.2
		capsule.height = 1.65
		body.mesh = capsule
		body.position.y = 0.83
		body.material_override = _plain(Color("5a5048"))
		root.add_child(body)
		return root
	var scene := load(MODELS % [model, model]) as PackedScene
	var instance := scene.instantiate()
	root.add_child(instance)
	var found := instance.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		var player := found.front() as AnimationPlayer
		players[p.id] = player
		player.play("attente")
		# Chaque voleur respire à son rythme : ils ne bougent pas en même temps.
		player.seek(randf() * 3.0, true)
	return root


func _model_of(p: Pawn) -> String:
	var index := state.order.find(p.id)
	if index < 0 or index >= state.config.get("voleurs", []).size():
		return ""
	var key: String = state.config["voleurs"][index].get("tenue", "")
	if key == "" or not data.regles["tenues"].has(key):
		return ""
	return data.regles["tenues"][key].get("modele", "")


func _sleeper_node() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.17
	capsule.height = 1.4
	body.mesh = capsule
	body.rotation.z = PI / 2
	body.position.y = 0.12
	body.material_override = _plain(SLEEPER_COLOR)
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	head.mesh = sphere
	head.position = Vector3(-0.72, 0.16, 0)
	head.material_override = _plain(VillaView.SKIN_COLOR)
	root.add_child(head)
	return root


func _lantern() -> Node3D:
	var lantern := Node3D.new()
	lantern.position = Vector3(0.28, 0.85, -0.12)
	var glass := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.16, 0.1)
	glass.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffd98a")
	m.emission_enabled = true
	m.emission = Color("ffc860")
	m.emission_energy_multiplier = 2.5
	glass.material_override = m
	lantern.add_child(glass)
	var light := OmniLight3D.new()
	light.light_color = Color("ffc27a")
	light.light_energy = 1.6
	light.omni_range = 4.5
	light.shadow_enabled = false
	lantern.add_child(light)
	return lantern


func _dress_furniture(f: Furniture) -> void:
	var node: Node3D = furniture_nodes[f.id]
	for child in node.get_children():
		child.queue_free()
	var look: Dictionary = FURNITURE_LOOK.get(f.type, FURNITURE_LOOK["gueridon"])
	var color: Color = look["color"]
	var height: float = look["height"]
	var size: Vector2 = look["size"]
	if not f.revealed:
		# Sous la housse : même drap pâle pour tous, la forme ne trahit que la longueur.
		color = COVER_COLOR
		height = 0.9
		size = Vector2(0.66, 0.6)
	elif f.emptied or f.forced:
		color = color.lerp(EMPTY_COLOR, 0.55)
	node.position = _furniture_center(f)
	node.rotation.y = _furniture_turn(f)
	var length := size.x + (Hex.center(f.cells[0]).distance_to(Hex.center(f.cells[1])) if f.cells.size() > 1 else 0.0)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, height, size.y)
	body.mesh = box
	body.position.y = height * 0.5
	body.material_override = _plain(color, 0.85 if not f.revealed else 0.6)
	node.add_child(body)
	if f.revealed:
		var label := Label3D.new()
		var kind: String = data.mobilier["types"][f.type]["nom"]
		label.text = kind + ("\n(vide)" if f.emptied or f.forced else "")
		label.font_size = 64
		label.pixel_size = 0.004
		label.outline_size = 16
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = height + 0.35
		label.modulate = Color(1, 0.96, 0.85)
		node.add_child(label)


func _furniture_center(f: Furniture) -> Vector3:
	var sum := Vector3.ZERO
	for c in f.cells:
		sum += VillaView.to_world(c)
	return sum / f.cells.size()


func _furniture_turn(f: Furniture) -> float:
	if f.cells.size() < 2:
		return 0.0
	var a := VillaView.to_world(f.cells[0])
	var b := VillaView.to_world(f.cells[1])
	return -atan2(b.z - a.z, b.x - a.x)


func _street_spot(rank: int) -> Vector3:
	var gates: Array[Vector2i] = []
	for c in state.plan.cells():
		if state.plan.is_gate(c):
			gates.append(c)
	var middle := Vector3.ZERO
	for c in gates:
		middle += VillaView.to_world(c)
	middle /= maxf(gates.size(), 1)
	# Dans la rue, au sud de la grille, en rang.
	return middle + Vector3((rank - 1) * 0.9 - 0.4 * (rank % 2), 0, 1.7 + 0.5 * (rank / 3))


func _face(node: Node3D, at: Vector3) -> void:
	var d := at - node.position
	if Vector2(d.x, d.z).length() > 0.01:
		node.rotation.y = atan2(d.x, d.z)


func _play(id: int, animation: String, speed := 1.0) -> void:
	var player: AnimationPlayer = players.get(id)
	if player and player.has_animation(animation):
		player.play(animation, BLEND, speed)


func _idle(id: int) -> void:
	var player: AnimationPlayer = players.get(id)
	if player and player.current_animation != "attente" and player.current_animation != "aux_aguets":
		player.play("attente", BLEND)


static func _plain(color: Color, roughness := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


static func _make_ghostly(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.45, 0.55, 0.8, 0.22)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			child.material_override = m
