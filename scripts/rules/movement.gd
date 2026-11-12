class_name Movement
extends RefCounted
## Déplacement des voleurs : pas à pas, entrée par le mur ou la grille, sortie du plateau.
## Un point d'action par case ; le bruit des pas porte aussi loin que le voleur a marché dans son tour.


## Coût en points d'action du pas d'un voleur vers une case voisine, ou -1 si le pas est impossible.
## `side` est le côté du mur où il se tient, s'il part d'une porte, d'une fenêtre ou de la grille.
static func step_cost(state: GameState, from: Vector2i, side: int, to: Vector2i) -> int:
	var plan := state.plan
	var d := Hex.direction_to(from, to)
	if d == "" or state.furniture_at.has(to) or state.pawn_at(to) != null:
		return -1
	var cost := state.data.cost("case")
	# La grille : on y entre depuis la cour, on en sort vers la cour une fois la grille forcée.
	if plan.is_gate(from):
		return cost if side == 1 and plan.zone(to) == VillaPlan.OUTSIDE else -1
	if plan.is_gate(to):
		return cost if plan.zone(from) == VillaPlan.OUTSIDE else -1
	if plan.is_enclosure(from) or plan.is_enclosure(to):
		return -1
	if plan.is_opening(from) and plan.opening_side(from, d) != side:
		return -1
	if not plan.passable(from, to):
		return -1
	if plan.is_balustrade(from, to):
		return state.data.cost("balustrade")
	# Livret : les fenêtres sans arbre voisin « coûtent deux points de déplacement pour entrer ».
	if plan.opening_type(to) == "fenetre" and not plan.near_tree(to) \
			and plan.side_zone(to, Hex.opposite(d)) == VillaPlan.OUTSIDE:
		return state.data.cost("fenetre_sans_arbre")
	return cost


## Côté du mur où se retrouve un voleur qui entre sur `to` en venant de `from`.
static func side_after(state: GameState, from: Vector2i, to: Vector2i) -> int:
	if state.plan.is_gate(to):
		return 1
	if state.plan.is_opening(to):
		return state.plan.opening_side(to, Hex.opposite(Hex.direction_to(from, to)))
	return -1


## Déplace le voleur le long d'un chemin de cases voisines. Il s'arrête de lui-même quand il découvre
## un meuble (le joueur choisit alors de rester ou de repartir), quand les points manquent ou quand
## le pas est impossible. Renvoie les événements, liste vide si aucun pas n'a été fait.
static func move(state: GameState, thief: Pawn, path: Array) -> Array:
	if thief.status != Pawn.Status.ACTIVE or state.plan.is_wall(thief.pos):
		return []
	var events: Array = []
	var steps: Array[Vector2i] = []
	var from := thief.pos
	for cell in path:
		var cost := step_cost(state, thief.pos, thief.side, cell)
		if cost < 0 or cost > thief.ap:
			break
		var jumps := _leaves_by_window(state, thief, cell)
		var previous := thief.pos
		thief.side = side_after(state, previous, cell)
		thief.pos = cell
		thief.ap -= cost
		thief.moved += 1
		thief.crossed = false
		_drop_work(thief)
		steps.append(cell)
		var found := _look_around(state, thief, events)
		Guards.update_sight(state, events)
		if jumps and not _land(state, thief, events):
			break
		if found:
			break
	if steps.is_empty():
		return []
	events.push_front({"type": "move", "id": thief.id, "from": from, "path": steps})
	_footsteps(state, thief, events)
	return events


## Monte sur une case du mur d'enceinte, depuis la rue ou depuis le jardin. Le voleur y passe le
## reste de son tour : il sautera ou sortira au tour suivant (livret).
static func climb(state: GameState, thief: Pawn, wall: Vector2i) -> Array:
	if not state.plan.is_wall(wall) or state.pawn_at(wall) != null or thief.ap <= 0:
		return []
	var from := thief.pos
	if thief.status == Pawn.Status.OUTSIDE:
		if landing_cells(state, wall).is_empty():
			return []
		thief.status = Pawn.Status.ACTIVE
	elif thief.status != Pawn.Status.ACTIVE or state.plan.is_opening(thief.pos) \
			or state.plan.zone(thief.pos) != VillaPlan.OUTSIDE or Hex.direction_to(thief.pos, wall) == "":
		return []
	thief.pos = wall
	thief.side = -1
	thief.ap = 0
	_drop_work(thief)
	var events: Array = [{"type": "climb", "id": thief.id, "from": from, "to": wall}]
	_leave_furniture(state, thief, events)
	Guards.update_sight(state, events)
	return events


## Cases du jardin où l'on peut sauter depuis une case du mur d'enceinte.
static func landing_cells(state: GameState, wall: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for n in Hex.neighbors(wall):
		if state.plan.zone(n) == VillaPlan.OUTSIDE and not state.plan.is_opening(n) and state.pawn_at(n) == null:
			result.append(n)
	return result


## Saute du mur dans le jardin. Livret : on consulte la table de combat, colonne « saut ».
static func jump(state: GameState, thief: Pawn, dest: Vector2i) -> Array:
	var cost := state.data.cost("saut")
	if thief.status != Pawn.Status.ACTIVE or not state.plan.is_wall(thief.pos) or thief.ap < cost:
		return []
	if not landing_cells(state, thief.pos).has(dest):
		return []
	var from := thief.pos
	thief.pos = dest
	thief.ap -= cost
	thief.moved += 1
	var events: Array = [{"type": "jump", "id": thief.id, "from": from, "to": dest}]
	_land(state, thief, events)
	_footsteps(state, thief, events)
	Guards.update_sight(state, events)
	return events


## Se présente devant la grille, côté rue.
static func approach_gate(state: GameState, thief: Pawn, gate: Vector2i) -> Array:
	var cost := state.data.cost("grille")
	if thief.status != Pawn.Status.OUTSIDE or not state.plan.is_gate(gate) or state.pawn_at(gate) != null or thief.ap < cost:
		return []
	thief.status = Pawn.Status.ACTIVE
	thief.pos = gate
	thief.side = 0
	thief.ap -= cost
	return [{"type": "gate", "id": thief.id, "to": gate}]


## Par où le voleur peut-il quitter le plateau ? "mur", "grille", "passage" ou "".
static func exit_way(state: GameState, thief: Pawn) -> String:
	if thief.status != Pawn.Status.ACTIVE:
		return ""
	if state.plan.is_wall(thief.pos):
		return "mur"
	if state.plan.is_gate(thief.pos) and thief.side == 0:
		return "grille"
	for id in thief.secret_passages:
		if state.touches_furniture(thief, state.get_furniture(id)):
			return "passage"
	return ""


## Quitte le plateau avec son butin : c'est le « passage chez le receleur ».
static func leave(state: GameState, thief: Pawn) -> Array:
	var way := exit_way(state, thief)
	var cost := state.data.cost("sortie")
	if way == "" or thief.ap < cost:
		return []
	var from := thief.pos
	thief.ap = 0
	thief.status = Pawn.Status.ESCAPED
	thief.pos = Pawn.NO_CELL
	thief.side = -1
	_drop_work(thief)
	var events: Array = [{"type": "leave", "id": thief.id, "from": from, "way": way}]
	_leave_furniture(state, thief, events)
	return events


## Les meubles découverts par un voleur qui n'est plus là sont perdus (arrêté, sorti).
static func abandon_furniture(state: GameState, thief: Pawn, events: Array) -> void:
	_leave_furniture(state, thief, events)


## Retourne les meubles que le voleur touche, et abandonne ceux qu'il a découverts puis quittés.
## Renvoie vrai s'il vient de découvrir un meuble.
static func _look_around(state: GameState, thief: Pawn, events: Array) -> bool:
	var found := false
	for f in state.furniture:
		if f.revealed or not state.touches_furniture(thief, f):
			continue
		f.revealed = true
		f.discovered_by = thief.id
		found = true
		events.append({"type": "reveal", "id": thief.id, "furniture": f.id, "kind": f.type})
	_leave_furniture(state, thief, events)
	return found


## Livret : « dès que le pion qui a découvert un meuble s'en éloigne, le meuble est considéré comme
## vide, qu'il ait été forcé ou non ».
static func _leave_furniture(state: GameState, thief: Pawn, events: Array) -> void:
	for f in state.furniture:
		if f.discovered_by != thief.id or f.emptied:
			continue
		if thief.on_board() and state.touches_furniture(thief, f):
			continue
		f.emptied = true
		events.append({"type": "emptied", "furniture": f.id})


## Sort-il de la villa par une fenêtre sans arbre, qu'il vient de franchir ? Il faut alors sauter.
static func _leaves_by_window(state: GameState, thief: Pawn, to: Vector2i) -> bool:
	var plan := state.plan
	return thief.crossed and plan.opening_type(thief.pos) == "fenetre" and not plan.near_tree(thief.pos) \
		and plan.half_zone(thief.pos, thief.side) == VillaPlan.OUTSIDE and plan.zone(to) == VillaPlan.OUTSIDE


## Résultat d'un saut (colonne « saut ») : indemne, ou deux tours sur place. Renvoie vrai si indemne.
static func _land(state: GameState, thief: Pawn, events: Array) -> bool:
	var roll := state.dice.roll(1, 0, "saut")
	var result := state.data.combat_result("saut", roll["total"])
	events.append({"type": "landing", "id": thief.id, "roll": roll, "result": result})
	if result == "ok":
		return true
	thief.stunned_turns = int(state.data.combat["tours_ko"])
	thief.ap = 0
	return false


## Livret : un déplacement d'une case s'entend à une case du point d'arrivée, de deux cases à deux
## cases, et ainsi de suite. Aucun bruit avec les chaussures silencieuses.
static func _footsteps(state: GameState, thief: Pawn, events: Array) -> void:
	for item in thief.equipment:
		if state.data.equipement["objets"][item].get("deplacement_silencieux", false):
			return
	NoiseRules.emit(state, thief.pos, thief.moved, "pas", events)


static func _drop_work(thief: Pawn) -> void:
	thief.work_target = ""
	thief.work_points = 0
