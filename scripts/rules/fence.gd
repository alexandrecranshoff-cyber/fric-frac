class_name Fence
extends RefCounted
## Le « passage chez le receleur » : ce que vaut le butin d'un voleur sorti du plateau.


## Compte du butin d'un voleur : argent compté en entier, reste divisé selon sa conduite.
static func payout(state: GameState, thief: Pawn) -> Dictionary:
	var cash := 0
	var goods := 0
	if thief.status == Pawn.Status.ESCAPED:
		for item in thief.loot:
			var object: Dictionary = state.data.butin["objets"][item]
			if object["argent"]:
				cash += int(object["valeur"])
			else:
				goods += int(object["valeur"])
	var divisors: Dictionary = state.data.butin["receleur"]["diviseur"]
	var conduct := "a_tue" if thief.has_killed else ("a_assomme" if thief.has_knocked_out else "pas_vu")
	var divisor := int(divisors[conduct])
	return {"id": thief.id, "argent": cash, "negociable": goods, "conduite": conduct, "diviseur": divisor,
		"total": cash + goods / divisor}


## Les voleurs du plus riche au plus pauvre. Le premier gagne (tour de rôle).
static func ranking(state: GameState) -> Array:
	var result := []
	for t in state.thieves():
		result.append(payout(state, t))
	result.sort_custom(func(a, b): return a["total"] > b["total"])
	return result


## Butin total de la bande (solo), et nombre de paliers atteints.
static func band_score(state: GameState) -> Dictionary:
	var total := 0
	for t in state.thieves():
		total += int(payout(state, t)["total"])
	var tiers := 0
	for threshold in state.data.regles["solo"]["paliers"]:
		if total >= int(threshold):
			tiers += 1
	return {"total": total, "paliers": tiers}
