class_name TurnFlow
extends RefCounted
## Enchaînement des tours. Livret : chaque joueur joue son voleur, puis déplace les gardes.
## Ici, la maison joue après chaque voleur, et les gardes parcourent en un tour de table la même
## distance qu'un voleur (le double en alerte), comme dans le livret.


static func start_game(state: GameState) -> Array:
	state.table_round = 1
	state.turn_index = 0
	state.over = state.order.is_empty()
	var events: Array = []
	if not state.over:
		_begin_round(state)
		_begin_turn(state, events)
	return events


## Termine le tour du voleur en cours : les pions qu'il a assommés récupèrent, la maison joue, puis
## le voleur suivant commence son tour. Renvoie les événements à afficher.
static func end_turn(state: GameState) -> Array:
	var events: Array = []
	var thief := state.current_thief()
	if thief == null:
		return events
	_recover(state, events, thief.id)
	state.turns_done += 1
	var next := _next_index(state)
	var wraps := next <= state.turn_index
	Guards.house_phase(state, _guard_steps(state, wraps), events)
	if wraps:
		_recover(state, events, -1)
		state.table_round += 1
		_begin_round(state)
		# Lever du jour : tout voleur encore dans la propriété est pris.
		if state.max_rounds > 0 and state.table_round > state.max_rounds:
			_dawn(state, events)
	state.turn_index = next
	if not _anyone_playing(state):
		state.over = true
		events.append({"type": "game_over", "ranking": Fence.ranking(state)})
		return events
	if not state.get_pawn(state.order[state.turn_index]).in_play():
		state.turn_index = _next_index(state)
	_begin_turn(state, events)
	return events


static func _begin_round(state: GameState) -> void:
	state.turns_done = 0
	state.guard_steps_done = 0
	state.round_players = 0
	for id in state.order:
		if state.get_pawn(id).in_play():
			state.round_players += 1


static func _begin_turn(state: GameState, events: Array) -> void:
	var thief := state.current_thief()
	thief.moved = 0
	thief.has_attacked = false
	thief.skips_turn = false
	thief.ap = int(state.data.regles["points_action"])
	if thief.status == Pawn.Status.KO:
		thief.skips_turn = true
	elif thief.stunned_turns > 0:
		thief.stunned_turns -= 1
		thief.skips_turn = true
	if thief.skips_turn:
		thief.ap = 0
	events.append({"type": "turn", "id": thief.id, "round": state.table_round, "skipped": thief.skips_turn})


## Rang du prochain voleur qui joue encore, dans l'ordre du tour.
static func _next_index(state: GameState) -> int:
	var i := state.turn_index
	for n in state.order.size():
		i = (i + 1) % state.order.size()
		if state.get_pawn(state.order[i]).in_play():
			return i
	return state.turn_index


static func _anyone_playing(state: GameState) -> bool:
	for t in state.thieves():
		if t.in_play():
			return true
	return false


## Cases que les gardes parcourent après ce tour : leur trajet d'un tour de table est réparti entre
## les voleurs qui jouent, et soldé à la fin du tour de table.
static func _guard_steps(state: GameState, last: bool) -> int:
	var budget := int(state.data.regles["gardes"]["cases_par_tour_de_table"])
	var due := budget
	if not last:
		due = mini(budget, state.turns_done * budget / maxi(state.round_players, 1))
	var steps := maxi(due - state.guard_steps_done, 0)
	state.guard_steps_done += steps
	return steps


## Livret : un pion assommé reste sur place jusqu'à ce que l'attaquant ait pu jouer deux tours.
## `by` est le voleur qui vient de jouer ; -1 en fin de tour de table, pour les pions assommés
## par un garde ou par un voleur qui ne joue plus.
static func _recover(state: GameState, events: Array, by: int) -> void:
	for p in state.pawns:
		if p.status != Pawn.Status.KO:
			continue
		var attacker := state.get_pawn(p.ko_by)
		var counts := p.ko_by == by
		if by < 0:
			counts = attacker == null or not attacker.is_thief() or not attacker.in_play()
		if not counts:
			continue
		p.ko_turns -= 1
		if p.ko_turns > 0:
			continue
		p.status = Pawn.Status.ACTIVE
		p.ko_by = -1
		events.append({"type": "recovers", "id": p.id})
		# Un garde ou un dormeur qui revient à lui donne l'alarme.
		if not p.is_thief():
			p.awake = true
			NoiseRules.alarm(state, p.pos, events)


static func _dawn(state: GameState, events: Array) -> void:
	events.append({"type": "dawn"})
	for t in state.thieves():
		if t.status == Pawn.Status.ACTIVE or t.status == Pawn.Status.KO:
			Guards.arrest(state, t, events)
		elif t.status == Pawn.Status.OUTSIDE:
			t.status = Pawn.Status.ESCAPED
