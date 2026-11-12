class_name BreakIn
extends RefCounted
## Effraction (tableau 1) et butin (tableau 3). Livret : « plus on va vite, plus on fait de bruit.
## Chaque tour passé sur place diminue la portée du bruit. » Ici, un point d'action vaut un tour.
##
## Une cible est un dictionnaire : {"cell": case} pour la porte, la fenêtre ou la grille où se tient
## le voleur, {"furniture": numéro} pour un meuble qu'il touche.


## Ligne du tableau d'effraction pour cette cible, ou "" si le voleur ne peut pas la forcer.
static func kind_of(state: GameState, thief: Pawn, target: Dictionary) -> String:
	if thief.status != Pawn.Status.ACTIVE:
		return ""
	if target.has("furniture"):
		var f := state.get_furniture(int(target["furniture"]))
		if f == null or not f.revealed or f.emptied or not state.has_loot(f.type) or not state.touches_furniture(thief, f):
			return ""
		return f.type
	# Livret : pour franchir une porte ou une fenêtre, il faut être sur la case où se trouve l'obstacle.
	if not target.has("cell") or target["cell"] != thief.pos:
		return ""
	if state.plan.is_gate(thief.pos):
		return "grille"
	return state.plan.opening_type(thief.pos)


static func key_of(target: Dictionary) -> String:
	return "meuble:%d" % int(target["furniture"]) if target.has("furniture") else "case:%d,%d" % [target["cell"].x, target["cell"].y]


## Colonne du tableau atteinte avec `points` points passés sur la serrure : un passe-partout se lit
## comme un ou deux tours déjà passés sur place.
static func column_for(state: GameState, thief: Pawn, points: int) -> int:
	var bonus := 0
	for item in thief.equipment:
		bonus = maxi(bonus, int(state.data.equipement["objets"][item].get("tours_gagnes", 0)))
	return mini(points + bonus, int(state.data.effraction["tours_max"]))


## Colonne du tableau où en est le voleur sur sa serrure en cours.
static func column(state: GameState, thief: Pawn) -> int:
	return column_for(state, thief, thief.work_points)


## Portée du bruit si le voleur forçait la serrure après y avoir passé `extra` points de plus.
## -1 si la cible ne peut pas être forcée.
static func noise_preview(state: GameState, thief: Pawn, target: Dictionary, extra: int = 0) -> int:
	var kind := kind_of(state, thief, target)
	if kind == "":
		return -1
	var points := (thief.work_points if thief.work_target == key_of(target) else 0) + extra
	return state.data.break_in_noise(kind, column_for(state, thief, maxi(points, 1)))


## Passe des points d'action sur une serrure, sans l'ouvrir encore. Les points s'ajoutent d'un tour
## à l'autre tant que le voleur ne bouge pas et ne change pas de serrure.
static func work(state: GameState, thief: Pawn, target: Dictionary, points: int) -> Array:
	if kind_of(state, thief, target) == "" or points < 1 or points > thief.ap:
		return []
	var key := key_of(target)
	if thief.work_target != key:
		thief.work_target = key
		thief.work_points = 0
	thief.ap -= points
	thief.work_points += points
	return [{"type": "work", "id": thief.id, "target": target, "points": points, "total": thief.work_points,
		"column": column(state, thief)}]


## Force la serrure : le bruit dépend de la colonne atteinte. Une porte, une fenêtre ou la grille
## laisse passer le voleur de l'autre côté ; un meuble livre son butin.
static func open(state: GameState, thief: Pawn, target: Dictionary) -> Array:
	var kind := kind_of(state, thief, target)
	if kind == "" or thief.work_target != key_of(target) or thief.work_points < 1:
		return []
	var col := column(state, thief)
	var noise := state.data.break_in_noise(kind, col)
	thief.work_target = ""
	thief.work_points = 0
	var events: Array = [{"type": "break_in", "id": thief.id, "kind": kind, "target": target, "column": col, "noise": noise}]
	if target.has("furniture"):
		var f := state.get_furniture(int(target["furniture"]))
		NoiseRules.emit(state, f.head(), noise, "effraction", events)
		f.forced = true
		_search(state, thief, f, events)
		f.emptied = true
	else:
		NoiseRules.emit(state, thief.pos, noise, "effraction", events)
		thief.side = 1 - thief.side
		thief.crossed = true
	Guards.update_sight(state, events)
	return events


## Livret : un tirage pour un secrétaire, deux pour une armoire, trois pour un coffre-fort. Deux dés
## lancés l'un après l'autre, dizaines puis unités ; le résultat s'applique tout de suite.
static func _search(state: GameState, thief: Pawn, f: Furniture, events: Array) -> void:
	for i in int(state.data.butin["tirages_par_meuble"][f.type]):
		var roll := state.dice.d66("butin")
		var entry := state.data.loot_entry(roll["total"])
		var effect: String = entry["effet"]
		events.append({"type": "loot", "id": thief.id, "furniture": f.id, "roll": roll, "effect": effect, "entry": entry})
		match effect:
			"butin":
				thief.loot.append(entry["objet"])
			"bruit":
				NoiseRules.emit(state, f.head(), int(entry["portee"]), "butin", events)
			"alarme":
				var reach := state.dice.roll(int(entry["des"]), 0, "signal d'alarme")
				events.append({"type": "alarm_bell", "roll": reach})
				NoiseRules.emit(state, f.head(), reach["total"], "signal d'alarme", events)
			"gaz":
				thief.stunned_turns = maxi(thief.stunned_turns, int(entry["tours"]))
				thief.ap = 0
			"gardes":
				Guards.advance(state, int(entry["cases"]), events)
			"passage_secret":
				thief.secret_passages.append(f.id)
