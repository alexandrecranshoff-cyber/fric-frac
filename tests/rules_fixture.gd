class_name RulesFixture
extends RefCounted
## Parties de test : mobilier imposé, voleurs posés à la main, dés imposés.


## Partie sans meubles tirés au hasard (seulement ceux de `meubles`), avec des voleurs aux
## équipements donnés. Le premier voleur a commencé son tour.
static func game(equipments: Array = [[]], meubles: Array = [], tours: int = 0) -> GameState:
	var thieves := []
	for i in equipments.size():
		thieves.append({"nom": "voleur %d" % (i + 1), "joueur": i, "equipement": equipments[i]})
	var state := GameSetup.new_game(GameData.load_default(), 1, {"voleurs": thieves, "meubles": meubles, "tours": tours})
	TurnFlow.start_game(state)
	return state


## Pose un voleur sur une case, debout, du côté `side` du mur s'il est sur une ouverture.
static func put(thief: Pawn, cell: Vector2i, side: int = -1) -> Pawn:
	thief.status = Pawn.Status.ACTIVE
	thief.pos = cell
	thief.side = side
	return thief


static func thief(state: GameState, index: int = 0) -> Pawn:
	return state.thieves()[index]


static func guard(state: GameState, key: String) -> Pawn:
	for g in state.guards():
		if g.name == key:
			return g
	return null


## Retire les gardes (tous, ou ceux nommés) : pour essayer une règle sans qu'ils interviennent.
static func without_guards(state: GameState, names: Array = []) -> GameState:
	var kept: Array[Pawn] = []
	for p in state.pawns:
		if not p.is_guard() or (not names.is_empty() and not names.has(p.name)):
			kept.append(p)
	state.pawns = kept
	return state


static func events_of(events: Array, type: String) -> Array:
	return events.filter(func(e): return e["type"] == type)
