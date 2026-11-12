class_name TurnOptions
extends RefCounted
## Ce que peut faire le voleur dont c'est le tour : cases atteignables et leur chemin, entrées et
## sorties, serrures à forcer, adversaires à attaquer. Pur calcul sur l'état, sans le modifier :
## l'interface s'en sert pour proposer les gestes, le moteur reste seul juge en les appliquant.


## Cases que le voleur peut atteindre à pied ce tour-ci, sans rien forcer. Renvoie
## case -> {"cost": points, "path": [cases, départ exclu]}. Un voleur sur une porte ou une fenêtre
## ne repart que de son côté du mur.
static func reachable(state: GameState, thief: Pawn) -> Dictionary:
	var result := {}
	if thief.status != Pawn.Status.ACTIVE or thief.skips_turn or state.plan.is_wall(thief.pos):
		return result
	# Un état est une case et le côté du mur où l'on s'y tient (-1 hors des ouvertures).
	var start := Vector3i(thief.pos.x, thief.pos.y, thief.side)
	var best := {start: 0}
	var came := {}
	var open: Array[Vector3i] = [start]
	while not open.is_empty():
		# Les coûts sont petits (1 ou 2) : une recherche du plus proche suffit, sans tas.
		var index := 0
		for i in open.size():
			if best[open[i]] < best[open[index]]:
				index = i
		var current: Vector3i = open.pop_at(index)
		var here := Vector2i(current.x, current.y)
		var cost: int = best[current]
		for n in Hex.neighbors(here):
			var step := Movement.step_cost(state, here, current.z, n)
			if step < 0 or cost + step > thief.ap:
				continue
			var next := Vector3i(n.x, n.y, Movement.side_after(state, here, n))
			if best.has(next) and best[next] <= cost + step:
				continue
			best[next] = cost + step
			came[next] = current
			open.append(next)
	for key: Vector3i in best:
		var cell := Vector2i(key.x, key.y)
		if cell == thief.pos:
			continue
		if result.has(cell) and result[cell]["cost"] <= best[key]:
			continue
		var path: Array[Vector2i] = []
		var k := key
		while k != start:
			path.push_front(Vector2i(k.x, k.y))
			k = came[k]
		result[cell] = {"cost": best[key], "path": path, "side": key.z}
	return result


## Cases du mur d'enceinte où le voleur peut monter : depuis la rue, toute case du mur qui donne
## sur le jardin ; depuis le jardin, les cases du mur voisines.
static func climb_cells(state: GameState, thief: Pawn) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if thief.skips_turn or thief.ap <= 0:
		return result
	if thief.status == Pawn.Status.OUTSIDE:
		for c in state.plan.cells():
			if state.plan.is_wall(c) and state.pawn_at(c) == null and not Movement.landing_cells(state, c).is_empty():
				result.append(c)
	elif thief.status == Pawn.Status.ACTIVE and not state.plan.is_opening(thief.pos) \
			and state.plan.zone(thief.pos) == VillaPlan.OUTSIDE and not state.plan.is_enclosure(thief.pos):
		for n in Hex.neighbors(thief.pos):
			if state.plan.is_wall(n) and state.pawn_at(n) == null:
				result.append(n)
	return result


## Cases du jardin où sauter depuis le mur.
static func jump_cells(state: GameState, thief: Pawn) -> Array[Vector2i]:
	if thief.status != Pawn.Status.ACTIVE or thief.skips_turn or not state.plan.is_wall(thief.pos) \
			or thief.ap < state.data.cost("saut"):
		return [] as Array[Vector2i]
	return Movement.landing_cells(state, thief.pos)


## Cases de la grille où se présenter depuis la rue.
static func gate_cells(state: GameState, thief: Pawn) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if thief.status != Pawn.Status.OUTSIDE or thief.skips_turn or thief.ap < state.data.cost("grille"):
		return result
	for c in state.plan.cells():
		if state.plan.is_gate(c) and state.pawn_at(c) == null:
			result.append(c)
	return result


## Serrures que le voleur peut forcer d'où il est : l'ouverture sous ses pieds, les meubles
## découverts qu'il touche. Renvoie des {"target", "kind", "worked"} ; `worked` compte les points
## déjà passés sur cette serrure.
static func locks(state: GameState, thief: Pawn) -> Array:
	var result := []
	if thief.status != Pawn.Status.ACTIVE or thief.skips_turn:
		return result
	var targets := [{"cell": thief.pos}]
	for f in state.furniture:
		targets.append({"furniture": f.id})
	for target in targets:
		var kind := BreakIn.kind_of(state, thief, target)
		if kind == "":
			continue
		var worked := thief.work_points if thief.work_target == BreakIn.key_of(target) else 0
		result.append({"target": target, "kind": kind, "worked": worked})
	return result


## Adversaires que le voleur peut attaquer, avec les façons possibles. Renvoie des {"id", "modes"}.
static func attacks(state: GameState, thief: Pawn) -> Array:
	var result := []
	if thief.status != Pawn.Status.ACTIVE or thief.skips_turn or thief.has_attacked \
			or thief.ap < state.data.cost("attaque"):
		return result
	for p in state.pawns:
		if p == thief:
			continue
		var modes: Array[String] = []
		for mode in Combat.modes_of(state, thief):
			if Combat.can_strike(state, thief, p, mode):
				modes.append(mode)
		if not modes.is_empty():
			result.append({"id": p.id, "modes": modes})
	return result


## Le voleur peut-il quitter le plateau maintenant ?
static func can_leave(state: GameState, thief: Pawn) -> bool:
	return not thief.skips_turn and Movement.exit_way(state, thief) != "" and thief.ap >= state.data.cost("sortie")
