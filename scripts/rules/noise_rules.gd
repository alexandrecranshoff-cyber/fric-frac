class_name NoiseRules
extends RefCounted
## Le bruit et l'alarme. Livret : « si un garde ou un dormeur se trouve à portée du bruit, l'alarme
## est donnée ». La portée se compte en cases, sans tenir compte des murs.


## Produit un bruit de portée `radius` autour d'une case. Renvoie vrai s'il a été entendu.
static func emit(state: GameState, cell: Vector2i, radius: int, cause: String, events: Array) -> bool:
	if radius <= 0:
		return false
	var heard: Array[int] = []
	for g in state.guards():
		if g.status == Pawn.Status.ACTIVE and Hex.distance(g.pos, cell) <= radius:
			heard.append(g.id)
	# Un dormeur n'entend que si son lit a été découvert : tant que le pion est face cachée,
	# personne ne sait qu'il y a là un lit.
	for s in state.sleepers():
		if s.status != Pawn.Status.ACTIVE or not state.get_furniture(s.furniture_id).revealed:
			continue
		if Hex.distance(s.pos, cell) <= radius:
			heard.append(s.id)
			s.awake = true
	events.append({"type": "noise", "cell": cell, "radius": radius, "cause": cause, "heard_by": heard})
	if heard.is_empty():
		return false
	alarm(state, cell, events)
	return true


## Donne l'alarme : les gardes courent vers la case suspecte, au double de leur allure, jusqu'à la
## fin de la partie. Une nouvelle alarme les détourne aussitôt de la précédente.
static func alarm(state: GameState, cell: Vector2i, events: Array) -> void:
	state.alarm = true
	for g in state.guards():
		if g.status != Pawn.Status.ACTIVE:
			continue
		g.alerted = true
		g.target = cell
	events.append({"type": "alarm", "cell": cell})
