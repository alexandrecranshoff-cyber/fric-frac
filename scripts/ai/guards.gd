class_name Guards
extends RefCounted
## Les gardes, joués par les règles du livret : ronde en ligne droite au gré d'un dé, course vers
## la case suspecte dès l'alarme, poursuite du voleur qui partage leur pièce.

const MAX_REROLLS := 60


## La maison joue : chaque garde avance de `steps` cases, le double s'il est alerté.
static func house_phase(state: GameState, steps: int, events: Array) -> void:
	var factor := int(state.data.regles["gardes"]["facteur_alerte"])
	for g in state.guards():
		g.moved_last_phase = false
	for i in steps:
		for g in state.guards():
			for j in (factor if g.alerted else 1):
				step(state, g, events)


## Tableau de butin, 22 : « les gardes avancent de 3 cases ».
static func advance(state: GameState, cells: int, events: Array) -> void:
	for i in cells:
		for g in state.guards():
			step(state, g, events)


## Livret : « dès qu'un voleur entre dans la villa, les gardes commencent leur ronde. Le joueur
## lance un dé : il donne la direction prise par chacun des gardes, selon les chiffres imprimés
## autour de sa base de départ. »
static func start_ronde(state: GameState, events: Array) -> void:
	state.ronde_started = true
	var roll := state.dice.roll(1, 0, "ronde")
	for g in state.guards():
		g.heading = g.directions[str(roll["total"])]
	events.append({"type": "ronde", "roll": roll})


## Fait avancer un garde d'une case, selon son état : poursuite, alerte ou ronde.
static func step(state: GameState, g: Pawn, events: Array) -> void:
	if g.status != Pawn.Status.ACTIVE:
		return
	var prey := _prey(state, g)
	if prey != null:
		var path := find_path(state, g, prey.pos)
		if not path.is_empty():
			_move_to(state, g, path[0], events)
		return
	if g.target != Pawn.NO_CELL:
		var path := find_path(state, g, g.target)
		if not path.is_empty():
			_move_to(state, g, path[0], events)
			if path.size() > 1:
				return
		# Arrivé sur les lieux. S'il n'y trouve personne, il reprend sa marche au hasard.
		g.target = Pawn.NO_CELL
		g.heading = ""
		if not path.is_empty():
			return
	if not state.ronde_started and not g.alerted:
		return
	_ronde_step(state, g, events)


## Ce que voient les gardes : un voleur dans leur pièce est repéré et poursuivi « jusqu'à son
## arrestation, même dans le jardin » ; un cadavre dans la pièce donne l'alarme.
## À appeler après chaque déplacement, d'un voleur comme d'un garde.
static func update_sight(state: GameState, events: Array) -> void:
	if not state.ronde_started:
		for t in state.thieves():
			if t.on_board() and state.is_inside(t):
				start_ronde(state, events)
				break
	for g in state.guards():
		if g.status != Pawn.Status.ACTIVE:
			continue
		for p in state.pawns:
			if p.status == Pawn.Status.DEAD and not p.found and state.same_room(g, p):
				p.found = true
				events.append({"type": "corpse_found", "guard": g.id, "id": p.id})
				NoiseRules.alarm(state, p.pos, events)
		var nearest: Pawn = null
		for t in state.thieves():
			if t.status != Pawn.Status.ACTIVE and t.status != Pawn.Status.KO:
				continue
			if not state.same_room(g, t):
				continue
			if not t.seen:
				t.seen = true
				events.append({"type": "seen", "id": t.id, "guard": g.id})
			if nearest == null or Hex.distance(g.pos, t.pos) < Hex.distance(g.pos, nearest.pos):
				nearest = t
		if nearest != null:
			g.alerted = true
			if g.chase_id < 0:
				g.chase_id = nearest.id
				events.append({"type": "chase", "guard": g.id, "id": nearest.id})


## Un garde peut-il passer d'une case à sa voisine ? En ronde, il s'arrête devant « un mur, un meuble,
## une fenêtre ou une porte extérieure » (livret) et devant la balustrade ; les portes intérieures ne
## l'arrêtent pas. En poursuite, il franchit aussi les portes extérieures et la balustrade.
static func can_walk(state: GameState, from: Vector2i, to: Vector2i, pursuit: bool, goal: Vector2i = Pawn.NO_CELL) -> bool:
	var plan := state.plan
	if not plan.passable(from, to) or state.furniture_at.has(to):
		return false
	var other := state.pawn_at(to)
	if other != null and not other.is_thief():
		return false
	if to == goal:
		return true
	var type := plan.opening_type(to)
	if type == "fenetre" or (type == "porte_exterieure" and not pursuit):
		return false
	return pursuit or not plan.is_balustrade(from, to)


## Chemin le plus court d'un garde vers une case, premier pas compris, case de départ exclue.
## Si la case est hors d'atteinte (meuble, fenêtre), il va au plus près. Liste vide s'il y est déjà.
static func find_path(state: GameState, g: Pawn, goal: Vector2i) -> Array[Vector2i]:
	var came := {g.pos: g.pos}
	var dist := {g.pos: 0}
	var queue: Array[Vector2i] = [g.pos]
	var best := g.pos
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			best = c
			break
		var closer := Hex.distance(c, goal) < Hex.distance(best, goal)
		if closer or (Hex.distance(c, goal) == Hex.distance(best, goal) and dist[c] < dist[best]):
			best = c
		for n in Hex.neighbors(c):
			if came.has(n) or not can_walk(state, c, n, true, goal):
				continue
			came[n] = c
			dist[n] = dist[c] + 1
			queue.append(n)
	var path: Array[Vector2i] = []
	var c := best
	while c != g.pos:
		path.push_front(c)
		c = came[c]
	return path


## Voleur que le garde poursuit, s'il est encore à sa portée.
static func _prey(state: GameState, g: Pawn) -> Pawn:
	if g.chase_id < 0:
		return null
	var t := state.get_pawn(g.chase_id)
	if t == null or (t.status != Pawn.Status.ACTIVE and t.status != Pawn.Status.KO) or state.plan.is_enclosure(t.pos):
		g.chase_id = -1
		g.heading = ""
		return null
	return t


## Livret : « un garde avance en ligne droite jusqu'à un obstacle. On relance alors le dé pour sa
## nouvelle direction, jusqu'à en trouver une libre. »
static func _ronde_step(state: GameState, g: Pawn, events: Array) -> void:
	var free := false
	for d in Hex.DIRECTIONS:
		if can_walk(state, g.pos, Hex.step(g.pos, d), false):
			free = true
			break
	if not free:
		return
	var rerolls := 0
	while g.heading == "" or not can_walk(state, g.pos, Hex.step(g.pos, g.heading), false):
		var roll := state.dice.roll(1, 0, "garde %s" % g.name)
		g.heading = g.directions[str(roll["total"])]
		events.append({"type": "guard_turn", "id": g.id, "roll": roll, "heading": g.heading})
		rerolls += 1
		if rerolls >= MAX_REROLLS:
			return
	_move_to(state, g, Hex.step(g.pos, g.heading), events)


static func _move_to(state: GameState, g: Pawn, cell: Vector2i, events: Array) -> void:
	var from := g.pos
	var thief := state.pawn_at(cell)
	g.pos = cell
	g.moved_last_phase = true
	events.append({"type": "guard_move", "id": g.id, "from": from, "to": cell})
	# Livret : le but du garde est d'arrêter le voleur en se plaçant sur sa case.
	if thief != null and thief.is_thief():
		arrest(state, thief, events, g.id)
		g.chase_id = -1
		g.target = Pawn.NO_CELL
		g.heading = ""
	update_sight(state, events)


## La partie est terminée pour ce voleur, et son butin est perdu.
static func arrest(state: GameState, thief: Pawn, events: Array, guard_id: int = -1) -> void:
	thief.status = Pawn.Status.ARRESTED
	thief.loot.clear()
	thief.ap = 0
	events.append({"type": "arrest", "id": thief.id, "guard": guard_id, "cell": thief.pos})
	Movement.abandon_furniture(state, thief, events)
