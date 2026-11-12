class_name GameSetup
extends RefCounted
## Mise en place d'une partie : meubles tirés au hasard, gardes à leur poste, voleurs équipés dans la rue.

const PLACEMENT_TRIES := 200


## Crée une partie. `config` :
## - "voleurs" : liste de {"nom", "joueur", "equipement": [objets]} ;
## - "tours" : tours de table avant le lever du jour (0 ou absent : pas d'horloge) ;
## - "meubles" : liste de {"type", "cases": [[colonne, ligne], ...]} pour imposer le mobilier (tests),
##   absent pour le tirer au hasard comme le veut le livret.
## Renvoie null si un équipement dépasse les trois points du livret.
static func new_game(data: GameData, seed_value: int, config: Dictionary) -> GameState:
	for t in config.get("voleurs", []):
		if not data.valid_equipment(t.get("equipement", [])):
			return null
	var state := GameState.new(data, DiceRoller.new(seed_value))
	state.config = config.duplicate(true)
	state.max_rounds = int(config.get("tours", 0))
	for key in state.plan.guards:
		var g: Dictionary = state.plan.guards[key]
		var guard := state.add_pawn(Pawn.Kind.GUARD, key, cell_of(g["case"]))
		guard.directions = g["directions"]
	if config.has("meubles"):
		for m in config["meubles"]:
			var cells := []
			for c in m["cases"]:
				cells.append(cell_of(c))
			state.add_furniture(m["type"], cells)
	else:
		place_furniture(state)
	for f in state.furniture:
		if state.data.mobilier["types"][f.type].get("dormeur", false):
			var sleeper := state.add_pawn(Pawn.Kind.SLEEPER, "dormeur", f.head())
			sleeper.furniture_id = f.id
	for t in config.get("voleurs", []):
		var thief := state.add_pawn(Pawn.Kind.THIEF, t.get("nom", "voleur"))
		thief.status = Pawn.Status.OUTSIDE
		thief.player = int(t.get("joueur", 0))
		thief.equipment = t.get("equipement", []).duplicate()
		state.order.append(thief.id)
	return state


## Partie en solo du game design : la bande des trois tenues toutes faites, contre l'horloge.
static func solo_config(data: GameData) -> Dictionary:
	var thieves := []
	for key in data.regles["tenues"]:
		var outfit: Dictionary = data.regles["tenues"][key]
		thieves.append({"nom": outfit["nom"], "joueur": 0, "equipement": outfit["equipement"].duplicate()})
	return {"voleurs": thieves, "tours": int(data.regles["solo"]["tours"])}


static func cell_of(pair: Array) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))


## Livret : « on mélange les 36 pions mobilier et on les pose au hasard dans les pièces. On n'obstrue
## pas une porte, et on ne pose pas deux meubles sur des cases adjacentes. »
static func place_furniture(state: GameState) -> void:
	var types: Dictionary = state.data.mobilier["types"]
	var pieces: Array = []
	for type in types:
		for i in int(types[type]["nombre"]):
			pieces.append(type)
	var candidates: Array[Vector2i] = []
	var posts := {}
	for g in state.guards():
		posts[g.pos] = true
	for c in state.plan.cells():
		if state.plan.rooms.has(state.plan.cell(c)) and not posts.has(c):
			candidates.append(c)
	for attempt in PLACEMENT_TRIES:
		state.furniture.clear()
		state.furniture_at.clear()
		state.dice.shuffle(candidates)
		if _place_all(state, pieces, candidates) and _all_reachable(state):
			return
	assert(false, "Impossible de placer les meubles")


static func _place_all(state: GameState, pieces: Array, candidates: Array[Vector2i]) -> bool:
	var types: Dictionary = state.data.mobilier["types"]
	var room_cells := {}
	for c in candidates:
		room_cells[c] = true
	# Les meubles de deux cases d'abord : ils sont les plus difficiles à loger.
	var ordered: Array = pieces.filter(func(t): return int(types[t]["cases"]) == 2)
	ordered.append_array(pieces.filter(func(t): return int(types[t]["cases"]) != 2))
	for type in ordered:
		var placed := false
		for c in candidates:
			if not _is_free_spot(state, c):
				continue
			var cells := [c]
			if int(types[type]["cases"]) == 2:
				var second := _second_cell(state, c, room_cells)
				if second == Pawn.NO_CELL:
					continue
				cells.append(second)
			state.add_furniture(type, cells)
			placed = true
			break
		if not placed:
			return false
	return true


## Une case libre, dans une pièce, qui ne touche aucun meuble déjà posé.
static func _is_free_spot(state: GameState, c: Vector2i) -> bool:
	if state.furniture_at.has(c):
		return false
	for n in Hex.neighbors(c):
		if state.furniture_at.has(n):
			return false
	return true


## Seconde case d'une armoire ou d'un lit : une voisine de la même pièce, libre elle aussi.
static func _second_cell(state: GameState, c: Vector2i, room_cells: Dictionary) -> Vector2i:
	var dirs: Array = Hex.DIRECTIONS.duplicate()
	state.dice.shuffle(dirs)
	for d in dirs:
		var n := Hex.step(c, d)
		if room_cells.has(n) and state.plan.cell(n) == state.plan.cell(c) and _is_free_spot(state, n):
			return n
	return Pawn.NO_CELL


## Aucune porte obstruée : toutes les cases libres de la villa et du jardin communiquent encore,
## en traversant librement portes et fenêtres.
static func _all_reachable(state: GameState) -> bool:
	var start: Vector2i = state.guards()[0].pos
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in Hex.neighbors(c):
			if seen.has(n) or state.furniture_at.has(n) or not state.plan.passable(c, n):
				continue
			seen[n] = true
			queue.append(n)
	for c in state.plan.cells():
		if state.plan.is_enclosure(c) or state.furniture_at.has(c):
			continue
		if not seen.has(c):
			return false
	# Chaque porte et chaque fenêtre garde une case libre de chaque côté de son mur.
	for c in state.plan.openings:
		var free := [false, false]
		for d in Hex.DIRECTIONS:
			var n := Hex.step(c, d)
			if state.plan.passable(c, n) and not state.furniture_at.has(n):
				free[state.plan.opening_side(c, d)] = true
		if not (free[0] and free[1]):
			return false
	return true
