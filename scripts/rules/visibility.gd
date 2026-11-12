class_name Visibility
extends RefCounted
## Ce que savent les voleurs d'un joueur. Le brouillard est une règle : l'affichage ne montre que
## ce que ces fonctions renvoient, sauf avec l'option « plateau ouvert ».


## Zones que voient ces voleurs : la pièce où ils se tiennent, les deux côtés d'une porte ou d'une
## fenêtre, le jardin depuis le mur d'enceinte ou la grille.
static func zones_seen(state: GameState, thieves: Array) -> Dictionary:
	var zones := {}
	for t in thieves:
		if t.status != Pawn.Status.ACTIVE:
			continue
		if state.plan.is_opening(t.pos):
			zones[state.plan.half_zone(t.pos, 0)] = true
			zones[state.plan.half_zone(t.pos, 1)] = true
		elif state.plan.is_enclosure(t.pos):
			zones[VillaPlan.OUTSIDE] = true
		else:
			zones[state.plan.zone(t.pos)] = true
	return zones


## Pions que ces voleurs voient. Un dormeur ne se voit que si son lit a été découvert.
static func pawns_seen(state: GameState, thieves: Array) -> Array[Pawn]:
	var zones := zones_seen(state, thieves)
	var result: Array[Pawn] = []
	for p in state.pawns:
		if not p.on_board():
			continue
		if p.is_sleeper() and not state.get_furniture(p.furniture_id).revealed:
			continue
		for z in state.zones_of(p):
			if zones.has(z):
				result.append(p)
				break
	return result


## Meubles que ces voleurs voient, retournés ou non.
static func furniture_seen(state: GameState, thieves: Array) -> Array[Furniture]:
	var zones := zones_seen(state, thieves)
	var result: Array[Furniture] = []
	for f in state.furniture:
		if zones.has(state.plan.zone(f.head())):
			result.append(f)
	return result


## Gardes hors de vue que ces voleurs entendent marcher : à 6 cases, 12 s'ils courent (réglages).
## Renvoie des {"id", "cell"}.
static func guards_heard(state: GameState, thieves: Array) -> Array:
	var seen := pawns_seen(state, thieves)
	var rules: Dictionary = state.data.regles["gardes"]
	var result := []
	for g in state.guards():
		if g.status != Pawn.Status.ACTIVE or not g.moved_last_phase or seen.has(g):
			continue
		var reach := int(rules["ecoute_voleurs_alerte"] if g.alerted else rules["ecoute_voleurs"])
		for t in thieves:
			if t.status == Pawn.Status.ACTIVE and Hex.distance(t.pos, g.pos) <= reach:
				result.append({"id": g.id, "cell": g.pos})
				break
	return result
