class_name GameState
extends RefCounted
## État complet d'une partie : plan, pions, meubles, tour, dés. Aucune dépendance aux scènes.

var plan: VillaPlan
var data: GameData
var dice: DiceRoller
var pawns: Array[Pawn] = []
var furniture: Array[Furniture] = []
## Case -> meuble qui l'occupe.
var furniture_at: Dictionary = {}

## Tour de table en cours, à partir de 1.
var table_round := 1
## Voleurs dans l'ordre du tour, par numéro de pion.
var order: Array[int] = []
## Rang dans `order` du voleur dont c'est le tour.
var turn_index := 0
## Voleurs qui jouaient au début du tour de table, et tours déjà finis dans ce tour de table.
var round_players := 1
var turns_done := 0
## Cases déjà parcourues par les gardes en ronde dans ce tour de table.
var guard_steps_done := 0

## La ronde commence dès qu'un voleur entre dans la villa.
var ronde_started := false
## L'alarme a été donnée au moins une fois.
var alarm := false
var over := false
## Nombre de tours de table avant le lever du jour ; 0 : pas d'horloge.
var max_rounds := 0

## Mise en place et gestes joués : de quoi rejouer la partie à l'identique.
var config: Dictionary = {}
var commands: Array = []

var _next_id := 1


func _init(p_data: GameData, p_dice: DiceRoller) -> void:
	data = p_data
	dice = p_dice
	plan = VillaPlan.new(p_data.villa)


func add_pawn(kind: Pawn.Kind, pawn_name: String, pos: Vector2i = Pawn.NO_CELL) -> Pawn:
	var p := Pawn.new()
	p.id = _next_id
	_next_id += 1
	p.kind = kind
	p.name = pawn_name
	p.pos = pos
	pawns.append(p)
	return p


func add_furniture(type: String, cells: Array) -> Furniture:
	var f := Furniture.new()
	f.id = furniture.size() + 1
	f.type = type
	for c in cells:
		f.cells.append(c)
		furniture_at[c] = f
	furniture.append(f)
	return f


func get_pawn(id: int) -> Pawn:
	for p in pawns:
		if p.id == id:
			return p
	return null


func get_furniture(id: int) -> Furniture:
	for f in furniture:
		if f.id == id:
			return f
	return null


func thieves() -> Array[Pawn]:
	return _of_kind(Pawn.Kind.THIEF)


func guards() -> Array[Pawn]:
	return _of_kind(Pawn.Kind.GUARD)


func sleepers() -> Array[Pawn]:
	return _of_kind(Pawn.Kind.SLEEPER)


func _of_kind(kind: Pawn.Kind) -> Array[Pawn]:
	var result: Array[Pawn] = []
	for p in pawns:
		if p.kind == kind:
			result.append(p)
	return result


## Voleur dont c'est le tour, ou null si la partie est finie.
func current_thief() -> Pawn:
	if over or order.is_empty():
		return null
	return get_pawn(order[turn_index])


## Pion debout ou assommé qui occupe une case. Les dormeurs sont dans leur lit, pas sur la case.
func pawn_at(c: Vector2i) -> Pawn:
	for p in pawns:
		if p.pos == c and not p.is_sleeper() and (p.status == Pawn.Status.ACTIVE or p.status == Pawn.Status.KO):
			return p
	return null


## Zones où se trouve un pion. Un voleur sur une porte ou une fenêtre est d'un seul côté du mur ;
## un garde sur une porte voit les deux pièces. Le mur d'enceinte et la grille n'appartiennent à aucune.
func zones_of(p: Pawn) -> Array:
	if not p.on_board():
		return []
	if plan.is_opening(p.pos):
		if p.is_thief() and p.side >= 0:
			return [plan.half_zone(p.pos, p.side)]
		return [plan.half_zone(p.pos, 0), plan.half_zone(p.pos, 1)]
	var z := plan.zone(p.pos)
	return [] if z == "" else [z]


func same_room(a: Pawn, b: Pawn) -> bool:
	var zb := zones_of(b)
	for z in zones_of(a):
		if zb.has(z):
			return true
	return false


## Un voleur placé sur `cell`, du côté `side` s'il est sur une ouverture, touche-t-il la case `other`
## sans mur entre les deux ?
func touches(cell: Vector2i, side: int, other: Vector2i) -> bool:
	var d := Hex.direction_to(cell, other)
	if d == "" or not plan.passable(cell, other):
		return false
	return not plan.is_opening(cell) or plan.opening_side(cell, d) == side


## Le voleur touche-t-il ce meuble, depuis sa pièce ?
func touches_furniture(thief: Pawn, f: Furniture) -> bool:
	for c in f.cells:
		if touches(thief.pos, thief.side, c):
			return true
	return false


## Le voleur est-il dans la villa, et non dans le jardin ou sur le mur ?
func is_inside(thief: Pawn) -> bool:
	for z in zones_of(thief):
		if z != VillaPlan.OUTSIDE:
			return true
	return false


func has_loot(type: String) -> bool:
	return data.butin["tirages_par_meuble"].has(type)


## Photographie de l'état, pour comparer deux parties rejouées.
func snapshot() -> Dictionary:
	var ps := []
	for p in pawns:
		ps.append([p.id, p.kind, p.status, p.pos, p.side, p.ap, p.loot.duplicate(), p.moved, p.stunned_turns,
			p.work_target, p.work_points, p.seen, p.has_knocked_out, p.has_killed, p.ko_turns, p.heading,
			p.alerted, p.target, p.chase_id, p.awake])
	var fs := []
	for f in furniture:
		fs.append([f.id, f.type, f.cells.duplicate(), f.revealed, f.forced, f.emptied, f.discovered_by])
	return {"round": table_round, "turn_index": turn_index, "alarm": alarm, "ronde": ronde_started, "over": over,
		"pawns": ps, "furniture": fs, "dice": dice.rng_state()}
