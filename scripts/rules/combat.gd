class_name Combat
extends RefCounted
## Combats (tableau 2). Livret : « quand deux pions sont dans la même pièce, il peut y avoir combat ».
## Le voleur dont c'est le tour attaque ; si l'adversaire n'est pas neutralisé, il riposte, et ainsi
## de suite jusqu'à résolution.


## Façons d'attaquer dont dispose un pion : à main nue, plus celles de ses armes.
static func modes_of(state: GameState, p: Pawn) -> Array[String]:
	var result: Array[String] = []
	var modes: Dictionary = state.data.combat["modes"]
	for key in modes:
		if key.begins_with("_"):
			continue
		var item: String = modes[key].get("objet", "")
		if item == "" or _weapons(state, p).has(item):
			result.append(key)
	return result


## L'attaque est-elle possible ? Même pièce, et cases voisines pour le corps à corps.
static func can_strike(state: GameState, attacker: Pawn, target: Pawn, mode: String) -> bool:
	if attacker.status != Pawn.Status.ACTIVE or target.status != Pawn.Status.ACTIVE or attacker == target:
		return false
	if not modes_of(state, attacker).has(mode) or not state.same_room(attacker, target):
		return false
	if target.is_sleeper() and not state.get_furniture(target.furniture_id).revealed:
		return false
	return bool(state.data.combat["modes"][mode]["distance"]) or reach(state, attacker, target) == 1


## Distance en cases entre deux adversaires. Un dormeur occupe tout son lit.
static func reach(state: GameState, a: Pawn, b: Pawn) -> int:
	var best := Hex.distance(a.pos, b.pos)
	for p in [a, b]:
		if p.is_sleeper():
			var other: Pawn = b if p == a else a
			for c in state.get_furniture(p.furniture_id).cells:
				best = mini(best, Hex.distance(c, other.pos))
	return best


## Un voleur attaque. Coûte des points d'action, une fois par tour. Renvoie les événements.
static func attack(state: GameState, thief: Pawn, target: Pawn, mode: String) -> Array:
	var cost := state.data.cost("attaque")
	if not thief.is_thief() or thief.has_attacked or thief.ap < cost or not can_strike(state, thief, target, mode):
		return []
	thief.ap -= cost
	thief.has_attacked = true
	var events: Array = [{"type": "attack", "id": thief.id, "target": target.id, "mode": mode}]
	for i in int(state.data.regles["combat"]["echanges_max"]):
		if _strike(state, thief, target, mode, events) != "ok":
			break
		# Livret : sur un OK, le dormeur ne combat pas le voleur mais donne immédiatement l'alarme.
		if target.is_sleeper():
			target.awake = true
			NoiseRules.alarm(state, target.pos, events)
			break
		var reply := _reply_mode(state, target, thief)
		if reply == "" or _strike(state, target, thief, reply, events) != "ok":
			break
	_take_loot(thief, target, events)
	_take_loot(target, thief, events)
	Guards.update_sight(state, events)
	return events


## Un coup : un dé, moins un point par case qui sépare les adversaires pour une arme à distance,
## moins le pare-balles du défenseur. Un dé tombé sous 1 se lit comme un 1.
static func _strike(state: GameState, attacker: Pawn, target: Pawn, mode: String, events: Array) -> String:
	var rules: Dictionary = state.data.combat
	var def: Dictionary = rules["modes"][mode]
	var roll := state.dice.roll(1, 0, "combat")
	var gap := 0
	if bool(def["distance"]):
		gap = (reach(state, attacker, target) - 1) * int(rules["malus_par_case_d_ecart"])
	var armor := 0
	for item in target.equipment:
		armor = maxi(armor, int(state.data.equipement["objets"][item].get("malus_de_adverse", 0)))
	var value := maxi(1, roll["total"] - gap - armor)
	var result := state.data.combat_result(def["colonne"], value)
	events.append({"type": "strike", "id": attacker.id, "target": target.id, "mode": mode, "roll": roll,
		"gap": gap, "armor": armor, "value": value, "result": result})
	# Livret : le bruit d'un revolver s'entend dans toute la villa et donne immédiatement l'alarme.
	if def.get("alarme", false) and bool(rules["revolver_donne_l_alarme"]):
		NoiseRules.alarm(state, attacker.pos, events)
	if result == "ok":
		return result
	var violent := attacker.is_thief() and not target.is_thief()
	if result == "ko":
		target.status = Pawn.Status.KO
		target.ko_by = attacker.id
		# Le tour en cours ne compte pas : l'attaquant doit encore jouer deux tours entiers.
		target.ko_turns = int(rules["tours_ko"]) + 1
		target.ap = 0
		if violent:
			attacker.has_knocked_out = true
	else:
		target.status = Pawn.Status.DEAD
		target.ap = 0
		if violent:
			attacker.has_killed = true
	target.chase_id = -1
	target.target = Pawn.NO_CELL
	return result


## Riposte du défenseur : le garde tire au revolver ; un voleur prend son arme la plus sûre qui
## ne donne pas l'alarme, et ne sort le revolver que s'il n'a rien d'autre à cette distance.
static func _reply_mode(state: GameState, defender: Pawn, attacker: Pawn) -> String:
	if defender.status != Pawn.Status.ACTIVE:
		return ""
	var best := ""
	var best_rank := -1
	for mode in modes_of(state, defender):
		if not can_strike(state, defender, attacker, mode):
			continue
		var def: Dictionary = state.data.combat["modes"][mode]
		var column: Array = state.data.combat["resultats"][def["colonne"]]
		var rank := 0
		for face in column:
			rank += 0 if face == "ok" else 10
		if def.get("alarme", false) and not defender.is_guard():
			rank = 1
		if rank > best_rank:
			best = mode
			best_rank = rank
	return best


## Livret : le vainqueur peut s'emparer du butin de son adversaire.
static func _take_loot(winner: Pawn, loser: Pawn, events: Array) -> void:
	if not winner.is_thief() or not loser.is_thief() or winner.status != Pawn.Status.ACTIVE:
		return
	if loser.status != Pawn.Status.KO and loser.status != Pawn.Status.DEAD:
		return
	if loser.loot.is_empty():
		return
	events.append({"type": "loot_taken", "id": winner.id, "from": loser.id, "loot": loser.loot.duplicate()})
	winner.loot.append_array(loser.loot)
	loser.loot.clear()


## Armes d'un pion : celles de son équipement, ou le revolver d'un garde.
static func _weapons(state: GameState, p: Pawn) -> Array:
	if p.is_guard():
		return [state.data.combat["arme_des_gardes"]]
	var result := []
	for item in p.equipment:
		var weapon: String = state.data.equipement["objets"][item].get("arme", "")
		if weapon != "":
			result.append(weapon)
	return result
