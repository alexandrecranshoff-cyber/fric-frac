class_name GameScreen
extends Node3D
## L'écran de partie de la maquette grise : la villa de nuit, ses calques de cases, les pions et
## l'interface. Le joueur montre des cases et des boutons ; l'écran en fait des commandes pour
## `GameActions`, puis rejoue les événements renvoyés (pas, dés, bruit, gardes) avant de redessiner
## ce que savent ses voleurs. Aucune règle ici : tout ce qui est proposé vient de `TurnOptions`.
##
## Contrôle sans écran (après « -- » sur la ligne de commande) :
##   auto=N        joue N tours de voleur tout seul, en solo (graine=… pour la fixer)
##   vues=dossier  enregistre une image par tour joué, puis quitte
##   vitrine=dossier  plateau ouvert, un meuble sur deux découvert : gros plans des pièces, puis quitte

const NIGHT_COLOR := Color("0b1020")
const FOG_COLOR := Color(0.0, 0.004, 0.015, 0.9)
const REACH_COLOR := Color(0.42, 0.8, 0.5, 0.2)
const ENTRY_COLOR := Color(0.98, 0.76, 0.3, 0.45)
const LOCK_COLOR := Color(0.45, 0.66, 1.0, 0.45)
const PATH_COLOR := Color(1.0, 0.92, 0.66, 0.5)
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const NOISE_COLOR := Color(1.0, 0.55, 0.2)
const GUARD_ROOM_COLOR := Color(0.9, 0.18, 0.12, 0.14)
const GUARD_LINE_COLOR := Color(0.95, 0.25, 0.15, 0.4)
const OPENING_NAMES := {"porte_interieure": "la porte", "porte_exterieure": "la porte extérieure",
	"fenetre": "la fenêtre", "grille": "la grille"}
const STATUS_NAMES := {Pawn.Status.KO: "assommé", Pawn.Status.DEAD: "mort", Pawn.Status.ARRESTED: "pris",
	Pawn.Status.ESCAPED: "sorti"}
const CLICK_SLOP := 6.0
const SAVE_FOLDER := "user://casses"

var data: GameData
var state: GameState
var view: VillaView
var overlay: BoardOverlay
var pieces: PiecesView
var hud: GameHud
var camera: OrbitCamera

var mode := "solo"
var players := 1
var open_board := false
var seed_value := 0

## Joueur dont les voleurs regardent le plateau (tour de rôle) ; 0 en solo.
var _viewer := 0
## Ce que chaque joueur a vu : meubles aperçus, dernière place connue de chaque garde.
var _memory: Dictionary = {}
## Options du voleur dont c'est le tour, recalculées après chaque geste.
var _reach: Dictionary = {}
var _entries: Dictionary = {}
var _locks: Array = []
var _lock_cells: Dictionary = {}
var _hovered := Pawn.NO_CELL
var _busy := false
var _break_lock := -1
var _press_at := Vector2.ZERO
var _rooms_light: Node3D

# Partie automatique, pour les contrôles sans écran.
var _auto_turns := 0
var _auto_folder := ""
var _auto_shots := 0
var _auto_rng := RandomNumberGenerator.new()
var _auto_visited: Dictionary = {}
var _auto_actions := 0


func _ready() -> void:
	data = GameData.load_default()
	_build_night()
	view = VillaView.new()
	view.show_guards = false
	add_child(view)
	view.build(VillaPlan.new(data.villa))
	overlay = BoardOverlay.new()
	add_child(overlay)
	overlay.setup(view.outline)
	_build_room_lamps()
	camera = OrbitCamera.new()
	camera.left_pans = false
	var size := view.plan.size()
	camera.limits = Rect2(0, 0, size.x, Hex.center(Vector2i(0, size.y - 1)).y)
	add_child(camera)
	camera.set_home(view.middle(), 20.0, 1.1, 27.0)
	camera.make_current()
	hud = GameHud.new()
	add_child(hud)
	_connect_hud()
	var auto_seed := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("auto="):
			_auto_turns = int(argument.trim_prefix("auto="))
		elif argument.begins_with("vues="):
			_auto_folder = argument.trim_prefix("vues=")
		elif argument.begins_with("graine="):
			auto_seed = int(argument.trim_prefix("graine="))
		elif argument.begins_with("vitrine="):
			_showcase.call_deferred(argument.trim_prefix("vitrine="))
	if _auto_turns > 0:
		_auto_rng.seed = 7
		Engine.time_scale = 4.0
		if _auto_folder != "":
			DirAccess.make_dir_recursive_absolute(_auto_folder)
			# Une image du premier lancer de dés.
			hud.dice_settled.connect(func(): _auto_snapshot("des"), CONNECT_ONE_SHOT)
		seed_value = auto_seed if auto_seed >= 0 else 1982
		_start("solo", 1, false, seed_value)


## Contrôle de l'habillage : meubles sous housse, découverts et vidés, gardes et dormeurs, vus de près.
func _showcase(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	await _start("solo", 1, true, 1982)
	for f in state.furniture:
		f.revealed = f.id % 2 == 0 or f.type == "lit"
		f.emptied = f.revealed and f.id % 4 == 0
	_refresh()
	hud.visible = false
	# Nom, case visée, angle, inclinaison, zoom.
	var views := [["ensemble", Vector2i(13, 11), 20.0, 1.1, 24.0], ["nord_ouest", Vector2i(7, 7), 35.0, 0.9, 8.0],
		["nord_est", Vector2i(19, 7), -30.0, 0.9, 8.0], ["hall", Vector2i(13, 14), 20.0, 0.9, 7.0],
		["sud_ouest", Vector2i(7, 15), 30.0, 0.9, 8.0], ["sud_est", Vector2i(19, 15), -25.0, 0.9, 8.0],
		["salon", Vector2i(10, 7), 15.0, 0.6, 4.5], ["grand_salon", Vector2i(16, 8), -20.0, 0.6, 5.0],
		["rue", Vector2i(13, 23), 10.0, 0.45, 7.0], ["jardin", Vector2i(23, 11), -40.0, 0.6, 6.0]]
	for v in views:
		camera.set_home(VillaView.to_world(v[1]), v[2], v[3], v[4])
		_auto_folder = folder
		await _auto_snapshot(v[0])
	get_tree().quit()


func _connect_hud() -> void:
	hud.mode_chosen.connect(func(m: String, n: int, open: bool): _start(m, n, open))
	hud.visit_pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	hud.end_turn_pressed.connect(_end_turn)
	hud.lock_pressed.connect(_open_lock)
	hud.break_in_changed.connect(_on_break_in_changed)
	hud.break_in_confirmed.connect(_on_break_in_confirmed)
	hud.break_in_cancelled.connect(func():
		hud.close_break_in()
		_break_lock = -1)
	hud.attack_pressed.connect(func(id: int, m: String): _send({"type": "attack", "target": id, "mode": m}))
	hud.leave_pressed.connect(func(): _send({"type": "leave"}))
	hud.ready_pressed.connect(func():
		hud.hide_pass()
		_refresh())
	hud.replay_pressed.connect(func(): _start(mode, players, open_board, seed_value if mode == "jour" else -1))
	hud.menu_pressed.connect(func():
		state = null
		_clear_board()
		hud.show_menu())
	hud.card_pressed.connect(func(id: int): _focus(state.get_pawn(id)))


# --- Mise en place ---

## Lance une partie. `forced_seed` négatif : graine tirée au hasard (ou de la date du jour).
func _start(new_mode: String, count: int, open: bool, forced_seed := -1) -> void:
	mode = new_mode
	players = count
	open_board = open
	if forced_seed >= 0:
		seed_value = forced_seed
	elif mode == "jour":
		seed_value = int(Time.get_date_string_from_system().replace("-", ""))
	else:
		seed_value = randi()
	var config: Dictionary
	if mode == "tour_de_role":
		var outfits := []
		var keys: Array = data.regles["tenues"].keys()
		for i in players:
			outfits.append(keys[i % keys.size()])
		config = GameSetup.hot_seat_config(data, outfits)
	else:
		config = GameSetup.solo_config(data)
	_clear_board()
	state = GameSetup.new_game(data, seed_value, config)
	pieces = PiecesView.new()
	add_child(pieces)
	pieces.setup(state)
	_memory.clear()
	_viewer = state.thieves()[0].player
	hud.show_game()
	hud.clear_log()
	var title: String = {"solo": "Le casse, en solo", "jour": "Le casse du jour", "tour_de_role": "Tour de rôle"}[mode]
	hud.add_log("[b]%s[/b] — graine %d" % [title, seed_value])
	if state.max_rounds > 0:
		hud.add_log("Le jour se lève dans %d tours. Entrez par la grille ou par le mur." % state.max_rounds)
	camera.set_home(VillaView.to_world(Vector2i(13, 20)), 0.0, 1.0, 16.0)
	await _play(TurnFlow.start_game(state))
	_refresh()
	_auto_next()


func _clear_board() -> void:
	if pieces:
		pieces.queue_free()
		pieces = null
	for layer in BoardOverlay.LAYERS:
		overlay.clear(layer)
	hud.close_break_in()
	_break_lock = -1


# --- Gestes du joueur ---

func _unhandled_input(event: InputEvent) -> void:
	if state == null or state.over or _busy:
		return
	if event is InputEventMouseMotion:
		_hover(_cell_under((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			_press_at = button.position
		elif button.position.distance_to(_press_at) < CLICK_SLOP:
			_click(_cell_under(button.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_end_turn()
			KEY_ESCAPE:
				hud.close_break_in()
				_break_lock = -1


## Case sous le pointeur : le rayon de la caméra coupe le sol, puis la case dont le centre est
## le plus proche. NO_CELL hors du plateau.
func _cell_under(at: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(at)
	var normal := camera.project_ray_normal(at)
	if absf(normal.y) < 0.001:
		return Pawn.NO_CELL
	var t := -origin.y / normal.y
	if t < 0:
		return Pawn.NO_CELL
	var hit := origin + normal * t
	var point := Vector2(hit.x, hit.z)
	var best := Pawn.NO_CELL
	var best_distance := 0.62
	for c in state.plan.cells():
		var d := Hex.center(c).distance_to(point)
		if d < best_distance:
			best_distance = d
			best = c
	return best


func _hover(c: Vector2i) -> void:
	if c == _hovered:
		return
	_hovered = c
	var thief := state.current_thief()
	overlay.clear("chemin")
	overlay.clear("bruit")
	if c == Pawn.NO_CELL or thief == null:
		overlay.clear("survol")
		hud.set_hint(_default_hint())
		return
	overlay.paint("survol", {c: HOVER_COLOR})
	if _reach.has(c):
		var option: Dictionary = _reach[c]
		var cells := {}
		for p: Vector2i in option["path"]:
			cells[p] = PATH_COLOR
		overlay.paint("chemin", cells)
		var radius: int = 0 if _silent(thief) else thief.moved + option["path"].size()
		_paint_noise(c, radius)
		var text := "Marcher : %s" % _points(int(option["cost"]))
		text += " · sans bruit (chaussures silencieuses)" if radius == 0 else " · bruit des pas à %s" % _cells(radius)
		hud.set_hint(text + _heard_warning(c, radius))
	elif _entries.has(c):
		hud.set_hint(_entries[c]["hint"])
	elif _lock_cells.has(c):
		hud.set_hint("Forcer %s : choisir les points à y passer" % _lock_name(_locks[_lock_cells[c]]))
	else:
		hud.set_hint(_default_hint())


func _click(c: Vector2i) -> void:
	if c == Pawn.NO_CELL or hud.is_break_in_open():
		return
	if _reach.has(c):
		var path := []
		for p: Vector2i in _reach[c]["path"]:
			path.append([p.x, p.y])
		_send({"type": "move", "path": path})
	elif _entries.has(c):
		_send({"type": _entries[c]["type"], "cell": [c.x, c.y]})
	elif _lock_cells.has(c):
		_open_lock(_lock_cells[c])


func _end_turn() -> void:
	if state == null or state.over or _busy:
		return
	hud.close_break_in()
	_break_lock = -1
	_send({"type": "end_turn"})


## Envoie une commande au moteur et rejoue ce qu'elle a produit.
func _send(command: Dictionary) -> void:
	if _busy or state == null or state.over:
		return
	var events := GameActions.apply(state, command)
	if events.is_empty() and command["type"] != "end_turn":
		hud.banner("Geste impossible", GameHud.DANGER, 1.0)
		_auto_next()
		return
	await _play(events)
	_refresh()
	_auto_next()


# --- Effraction ---

func _open_lock(index: int) -> void:
	if _busy or index < 0 or index >= _locks.size():
		return
	var thief := state.current_thief()
	var lock: Dictionary = _locks[index]
	_break_lock = index
	var worked: int = lock["worked"]
	var title := "Forcer %s" % _lock_name(lock)
	if worked > 0:
		title += " (%s déjà)" % _points(worked)
	hud.open_break_in(title, thief.ap, mini(thief.ap, 3), worked > 0)


func _on_break_in_changed(points: int) -> void:
	if _break_lock < 0:
		return
	var thief := state.current_thief()
	var lock: Dictionary = _locks[_break_lock]
	var total: int = lock["worked"] + points
	if total <= 0:
		hud.set_break_in_text("Passez au moins un point sur la serrure.", false)
		return
	var noise := BreakIn.noise_preview(state, thief, lock["target"], points)
	var column := BreakIn.column_for(state, thief, total)
	var text := "%s · colonne %d du tableau · " % [_points(points), column]
	text += "sans bruit" if noise == 0 else "bruit à %s" % _cells(noise)
	if column >= int(data.effraction["tours_max"]):
		text += "\nAu-delà, plus rien ne change."
	else:
		text += "\nPlus vous y passez de temps, moins vous faites de bruit."
	var cell: Vector2i = _lock_center(lock)
	_paint_noise(cell, noise)
	hud.set_break_in_text(text + _heard_warning(cell, noise), true)


func _on_break_in_confirmed(points: int, open_now: bool) -> void:
	if _break_lock < 0 or _busy:
		return
	var lock: Dictionary = _locks[_break_lock]
	var target := _command_target(lock["target"])
	hud.close_break_in()
	_break_lock = -1
	overlay.clear("bruit")
	var events: Array = []
	if points > 0:
		events.append_array(GameActions.apply(state, {"type": "work", "target": target, "points": points}))
	if open_now:
		events.append_array(GameActions.apply(state, {"type": "open", "target": target}))
	await _play(events)
	_refresh()
	_auto_next()


static func _command_target(target: Dictionary) -> Dictionary:
	if target.has("furniture"):
		return {"furniture": target["furniture"]}
	var c: Vector2i = target["cell"]
	return {"cell": [c.x, c.y]}


func _lock_name(lock: Dictionary) -> String:
	if lock["target"].has("furniture"):
		return "le " + _furniture_name(state.get_furniture(int(lock["target"]["furniture"])))
	return OPENING_NAMES.get(lock["kind"], "la serrure")


func _lock_center(lock: Dictionary) -> Vector2i:
	if lock["target"].has("furniture"):
		return state.get_furniture(int(lock["target"]["furniture"])).head()
	return lock["target"]["cell"]


# --- Ce que voit le joueur ---

## Redessine tout d'après l'état : pions, brouillard, options du tour, fiches, horloge.
func _refresh() -> void:
	if state == null:
		return
	pieces.sync_all()
	_update_fog()
	_update_options()
	_update_cards()
	_update_clock()
	_hovered = Pawn.NO_CELL
	_hover(_cell_under(get_viewport().get_mouse_position()))


func _viewer_thieves() -> Array:
	var result := []
	for t in state.thieves():
		if t.player == _viewer:
			result.append(t)
	return result


func _memory_of(player: int) -> Dictionary:
	if not _memory.has(player):
		_memory[player] = {"furniture": {}, "ghosts": {}}
	return _memory[player]


func _zones() -> Dictionary:
	return Visibility.zones_seen(state, _viewer_thieves())


func _cell_seen(c: Vector2i, zones: Dictionary) -> bool:
	if open_board:
		return true
	var plan := state.plan
	if plan.is_opening(c):
		return zones.has(plan.half_zone(c, 0)) or zones.has(plan.half_zone(c, 1))
	if plan.is_enclosure(c):
		return zones.has(VillaPlan.OUTSIDE)
	return zones.has(plan.zone(c))


## Brouillard, pions vus ou entendus, silhouettes des gardes perdus de vue, pièce où un garde voit.
func _update_fog() -> void:
	var zones := _zones()
	var thieves := _viewer_thieves()
	var memory := _memory_of(_viewer)
	var fog := {}
	if not open_board:
		for c in state.plan.cells():
			if not _cell_seen(c, zones):
				fog[c] = FOG_COLOR
	overlay.paint("brouillard", fog)
	var seen := Visibility.pawns_seen(state, thieves)
	for f in Visibility.furniture_seen(state, thieves):
		memory["furniture"][f.id] = true
	for f in state.furniture:
		pieces.set_furniture_visible(f, open_board or memory["furniture"].has(f.id))
	var heard := {}
	for h in Visibility.guards_heard(state, thieves):
		heard[h["id"]] = h["cell"]
	var guard_cells := {}
	for p in state.pawns:
		var shown := open_board or seen.has(p) or (p.is_thief() and (p.player == _viewer or p.status == Pawn.Status.OUTSIDE))
		pieces.set_pawn_visible(p, shown)
		if not p.is_guard():
			continue
		if shown and p.on_board():
			memory["ghosts"][p.id] = p.pos
			pieces.show_ghost(p.id, p.pos, false)
			if p.status == Pawn.Status.ACTIVE:
				_guard_watch(p, guard_cells)
		else:
			if heard.has(p.id):
				memory["ghosts"][p.id] = heard[p.id]
			var known: Vector2i = memory["ghosts"].get(p.id, Pawn.NO_CELL)
			pieces.show_ghost(p.id, known, known != Pawn.NO_CELL)
	overlay.paint("piece", guard_cells)


## Pièce que voit un garde, et la ligne droite de sa ronde jusqu'au prochain obstacle.
func _guard_watch(g: Pawn, cells: Dictionary) -> void:
	var zones := state.zones_of(g)
	for c in state.plan.cells():
		if zones.has(state.plan.zone(c)) and not cells.has(c):
			cells[c] = GUARD_ROOM_COLOR
	if g.heading == "" or g.alerted:
		return
	var at := g.pos
	for i in 14:
		var next := Hex.step(at, g.heading)
		if not Guards.can_walk(state, at, next, false):
			break
		cells[next] = GUARD_LINE_COLOR
		at = next


func _update_options() -> void:
	_reach.clear()
	_entries.clear()
	_locks.clear()
	_lock_cells.clear()
	var thief := state.current_thief()
	if thief == null or state.over:
		overlay.clear("portee")
		hud.set_actions([])
		return
	_reach = TurnOptions.reachable(state, thief)
	for c in TurnOptions.gate_cells(state, thief):
		_entries[c] = {"type": "gate", "hint": "Se présenter devant la grille : %s, puis la forcer" % _points(data.cost("grille"))}
	for c in TurnOptions.climb_cells(state, thief):
		_entries[c] = {"type": "climb", "hint": "Monter sur le mur d'enceinte : le tour s'achève là-haut"}
	for c in TurnOptions.jump_cells(state, thief):
		_entries[c] = {"type": "jump", "hint": "Sauter dans le jardin : %s, un dé pour la réception" % _points(data.cost("saut"))}
	_locks = TurnOptions.locks(state, thief)
	var cells := {}
	for c in _reach:
		cells[c] = REACH_COLOR
	for c in _entries:
		cells[c] = ENTRY_COLOR
	var actions := []
	for i in _locks.size():
		var lock: Dictionary = _locks[i]
		if lock["target"].has("furniture"):
			for c in state.get_furniture(int(lock["target"]["furniture"])).cells:
				_lock_cells[c] = i
				cells[c] = LOCK_COLOR
		else:
			_lock_cells[lock["target"]["cell"]] = i
		actions.append({"label": "Forcer %s" % _lock_name(lock), "kind": "lock", "index": i})
	for a in TurnOptions.attacks(state, thief):
		var target := state.get_pawn(int(a["id"]))
		# On ne propose pas de frapper un voleur de sa propre bande.
		if target.is_thief() and target.player == thief.player:
			continue
		for m in a["modes"]:
			actions.append({"label": "Attaquer %s (%s)" % [_pawn_name(target), data.combat["modes"][m]["nom"]],
				"kind": "attack", "id": target.id, "mode": m})
	if TurnOptions.can_leave(state, thief):
		actions.append({"label": "Quitter la propriété", "kind": "leave"})
	actions.append({"label": "Fin du tour  ⏎", "kind": "end"})
	overlay.paint("portee", cells)
	hud.set_actions(actions)
	hud.set_actions_enabled(not _busy)


func _update_cards() -> void:
	var cards := []
	var current := state.current_thief()
	for t in state.thieves():
		var gear := []
		for item in t.equipment:
			gear.append(data.equipement["objets"][item]["nom"])
		var status: String = STATUS_NAMES.get(t.status, "")
		if status == "" and t.skips_turn:
			status = "passe son tour"
		var title := t.name
		if mode == "tour_de_role":
			title = "Joueur %d : %s" % [t.player, t.name]
		cards.append({"id": t.id, "name": title, "status": status, "ap": t.ap,
			"ap_max": int(data.regles["points_action"]), "equipment": ", ".join(gear),
			"loot": _loot_text(t), "current": t == current})
	hud.set_cards(cards)


func _update_clock() -> void:
	var text := "Tour %d" % state.table_round
	if state.max_rounds > 0:
		var minutes := 60 + (mini(state.table_round, state.max_rounds) - 1) * 10
		text = "Tour %d / %d · %d h %02d" % [mini(state.table_round, state.max_rounds), state.max_rounds, minutes / 60, minutes % 60]
	hud.set_clock(text, state.alarm)


func _default_hint() -> String:
	var thief := state.current_thief() if state else null
	if thief == null:
		return ""
	if thief.skips_turn:
		return "%s passe son tour." % thief.name
	if thief.status == Pawn.Status.OUTSIDE:
		return "%s attend dans la rue : cliquez la grille ou une case du mur d'enceinte." % thief.name
	return "%s : %s. Cliquez une case éclairée · Entrée : fin du tour." % [thief.name, _points(thief.ap)]


func _paint_noise(center: Vector2i, radius: int, strength := 1.0) -> void:
	if radius <= 0:
		overlay.clear("bruit")
		return
	var cells := {}
	for c in state.plan.cells():
		var d := Hex.distance(c, center)
		if d <= radius:
			var color := NOISE_COLOR
			color.a = (0.38 - 0.22 * float(d) / maxf(radius, 1)) * strength
			cells[c] = color
	overlay.paint("bruit", cells)


## Un garde visible du joueur entendrait-il ce bruit ? On ne prévient que pour ce que l'on voit.
func _heard_warning(center: Vector2i, radius: int) -> String:
	if radius <= 0:
		return ""
	var seen := Visibility.pawns_seen(state, _viewer_thieves())
	for g in state.guards():
		if g.status == Pawn.Status.ACTIVE and (open_board or seen.has(g)) and Hex.distance(g.pos, center) <= radius:
			return "\nUn garde l'entendrait : alerte !"
	return ""


func _focus(p: Pawn) -> void:
	if p == null or pieces == null:
		return
	var goal := pieces.position_of(p) if p.status != Pawn.Status.ESCAPED else view.middle()
	goal.y = 0
	var tween := create_tween()
	tween.tween_method(func(v: Vector3):
		camera.target = v
		camera.refresh(), camera.target, goal, 0.5).set_trans(Tween.TRANS_SINE)


# --- Le film des événements ---

## Rejoue les événements d'un geste, dans l'ordre, en les attendant un à un.
func _play(events: Array) -> void:
	_busy = true
	hud.set_actions_enabled(false)
	overlay.clear("chemin")
	overlay.clear("survol")
	overlay.clear("bruit")
	for e in events:
		await _play_event(e)
	pieces.sync_all()
	_busy = false


func _play_event(e: Dictionary) -> void:
	var p: Pawn = state.get_pawn(int(e["id"])) if e.has("id") and e["id"] is int else null
	match e["type"]:
		"turn":
			await _on_turn(p, e)
		"move":
			await pieces.walk(p, e["from"], e["path"])
			_update_fog()
		"climb":
			hud.add_log("%s grimpe sur le mur." % p.name)
			await pieces.hop(p, pieces.cell_spot(e["to"]))
			_update_fog()
		"jump":
			await pieces.hop(p, pieces.cell_spot(e["to"]))
			_update_fog()
		"landing":
			var ok: bool = e["result"] == "ok"
			await hud.show_dice(e["roll"]["faces"], "%s saute" % p.name, "Réception sans mal" if ok else "Mauvaise chute : sonné deux tours")
			hud.add_log("%s saute dans le jardin%s." % [p.name, "" if ok else " et se fait mal"])
		"gate":
			hud.add_log("%s se présente devant la grille." % p.name)
			await pieces.hop(p, pieces.cell_spot(e["to"], 0))
			_update_fog()
		"leave":
			hud.add_log("[color=#d9a441]%s quitte la propriété avec son butin.[/color]" % p.name)
			hud.banner("%s est sorti" % p.name, GameHud.ACCENT)
			await get_tree().create_timer(0.5).timeout
		"reveal":
			var f := state.get_furniture(int(e["furniture"]))
			_memory_of(_viewer)["furniture"][f.id] = true
			pieces.refresh_furniture(f)
			pieces.set_furniture_visible(f, true)
			hud.add_log("%s découvre un %s." % [p.name, _furniture_name(f)])
			await get_tree().create_timer(0.3).timeout
		"emptied":
			pieces.refresh_furniture(state.get_furniture(int(e["furniture"])))
		"work":
			hud.add_log("%s travaille la serrure : %s (colonne %d)." % [p.name, _points(int(e["total"])), int(e["column"])])
			await pieces.gesture(p, "aux_aguets", 0.6)
		"break_in":
			var what: String = OPENING_NAMES.get(e["kind"], "")
			if what == "":
				what = "le " + data.mobilier["types"][e["kind"]]["nom"]
			hud.add_log("%s force %s%s." % [p.name, what, "" if int(e["noise"]) == 0 else " (bruit à %s)" % _cells(int(e["noise"]))])
			await pieces.gesture(p, "ramasser" if e["target"].has("furniture") else "ouvrir_porte", 1.3)
			pieces.place(p)
			_update_fog()
		"loot":
			var entry: Dictionary = e["entry"]
			var text := _loot_entry_text(entry)
			await hud.show_dice(e["roll"]["faces"], "Butin : %d" % int(e["roll"]["total"]), text)
			hud.add_log("Butin (%d) : %s" % [int(e["roll"]["total"]), text])
		"alarm_bell":
			await hud.show_dice(e["roll"]["faces"], "Signal d'alarme", "entendu à %s" % _cells(int(e["roll"]["total"])))
		"noise":
			await _noise_wave(e)
		"alarm":
			hud.banner("ALERTE !", GameHud.DANGER, 2.0)
			hud.add_log("[color=#d8553f]Alerte : les gardes courent vers le bruit.[/color]")
			_update_clock()
			await get_tree().create_timer(0.6).timeout
		"ronde":
			await hud.show_dice(e["roll"]["faces"], "La ronde commence", "Les gardes partent chacun dans sa direction")
			hud.add_log("Un voleur est entré : les gardes commencent leur ronde.")
		"guard_turn":
			var g := state.get_pawn(int(e["id"]))
			if _guard_shown(g, g.pos):
				hud.add_log("Le garde %s change de direction (dé %d)." % [g.name, int(e["roll"]["total"])])
		"guard_move":
			await _guard_move(state.get_pawn(int(e["id"])), e["from"], e["to"])
		"seen":
			var g := state.get_pawn(int(e["guard"]))
			hud.banner("%s est repéré !" % p.name, GameHud.DANGER)
			hud.add_log("[color=#d8553f]Le garde %s a vu %s.[/color]" % [g.name, p.name])
			await get_tree().create_timer(0.6).timeout
		"chase":
			hud.add_log("Le garde %s poursuit %s." % [state.get_pawn(int(e["guard"])).name, p.name])
		"corpse_found":
			hud.add_log("[color=#d8553f]Le garde %s a trouvé un corps.[/color]" % state.get_pawn(int(e["guard"])).name)
		"arrest":
			hud.banner("%s est pris !" % p.name, GameHud.DANGER, 2.2)
			hud.add_log("[color=#d8553f]%s est arrêté, son butin est perdu.[/color]" % p.name)
			await get_tree().create_timer(0.8).timeout
			pieces.place(p)
		"attack":
			hud.add_log("%s attaque %s %s." % [p.name, _pawn_name(state.get_pawn(int(e["target"]))), data.combat["modes"][e["mode"]]["nom"]])
		"strike":
			var target := state.get_pawn(int(e["target"]))
			var result: String = {"ok": "manqué", "ko": "assommé", "tue": "tué"}[e["result"]]
			var detail := ""
			if int(e["gap"]) + int(e["armor"]) > 0:
				detail = " (%d − %d)" % [int(e["roll"]["total"]), int(e["gap"]) + int(e["armor"])]
			await hud.show_dice(e["roll"]["faces"], "%s frappe %s" % [_pawn_name(p), _pawn_name(target)], result.capitalize() + detail)
			hud.add_log("%s → %s : %s." % [_pawn_name(p), _pawn_name(target), result])
			pieces.place(target)
		"loot_taken":
			hud.add_log("%s prend le butin de %s." % [p.name, _pawn_name(state.get_pawn(int(e["from"])))])
		"recovers":
			hud.add_log("%s revient à lui." % _pawn_name(p))
			pieces.place(p)
		"dawn":
			hud.banner("Le jour se lève", GameHud.ACCENT, 2.5)
			hud.add_log("[b]5 h : le jour se lève. Qui est encore dans la propriété est pris.[/b]")
			await get_tree().create_timer(1.0).timeout
		"game_over":
			_game_over()


func _on_turn(p: Pawn, e: Dictionary) -> void:
	_update_clock()
	if mode == "tour_de_role" and p.player != _viewer:
		_viewer = p.player
		pieces.sync_all()
		_update_fog()
		hud.show_pass("Joueur %d, à vous : %s.\nLes autres, détournez les yeux." % [p.player, p.name])
		if _auto_turns > 0:
			hud.hide_pass()
	_focus(p)
	if e["skipped"]:
		hud.add_log("%s passe son tour." % p.name)
		hud.banner("%s passe son tour" % p.name, GameHud.DIM, 1.4)
	else:
		hud.add_log("[color=#d9a441]— %s, tour %d —[/color]" % [p.name, int(e["round"])])
		hud.banner(_to(p.name), GameHud.ACCENT, 1.2)


func _guard_shown(g: Pawn, cell: Vector2i) -> bool:
	return open_board or _cell_seen(cell, _zones()) or state.zones_of(g).any(func(z): return _zones().has(z))


func _guard_move(g: Pawn, from: Vector2i, to: Vector2i) -> void:
	var zones := _zones()
	var shown := open_board or _cell_seen(from, zones) or _cell_seen(to, zones)
	pieces.show_ghost(g.id, to, false)
	pieces.set_pawn_visible(g, shown)
	if shown:
		await pieces.guard_step(g, to)
	else:
		pieces.nodes[g.id].position = pieces.cell_spot(to)


## Onde de bruit : les cases à portée s'allument de proche en proche, puis s'éteignent.
func _noise_wave(e: Dictionary) -> void:
	var radius: int = e["radius"]
	var center: Vector2i = e["cell"]
	for r in range(1, radius + 1):
		_paint_noise(center, r)
		await get_tree().create_timer(0.05).timeout
	var heard: Array = e["heard_by"]
	var cause: String = e["cause"]
	if not heard.is_empty():
		hud.add_log("[color=#d8553f]Bruit (%s, %s) : entendu ![/color]" % [cause, _cells(radius)])
	elif cause != "pas":
		hud.add_log("Bruit (%s, %s) : personne n'a entendu." % [cause, _cells(radius)])
	await get_tree().create_timer(0.45).timeout
	for i in 4:
		_paint_noise(center, radius, 1.0 - 0.25 * (i + 1))
		await get_tree().create_timer(0.05).timeout
	overlay.clear("bruit")


# --- Fin de partie ---

func _game_over() -> void:
	overlay.clear("portee")
	hud.set_actions([])
	var lines := ["[center][b]Fin du casse[/b][/center]", ""]
	for r in Fence.ranking(state):
		var t := state.get_pawn(int(r["id"]))
		var fate: String = STATUS_NAMES.get(t.status, "")
		var line := "[b]%s[/b] (%s) : %s F" % [t.name, fate, _money(int(r["total"]))]
		if t.status == Pawn.Status.ESCAPED and int(r["negociable"]) > 0:
			line += "  [color=#6e5c45](argent %s F, objets %s F divisés par %d)[/color]" % [
				_money(int(r["argent"])), _money(int(r["negociable"])), int(r["diviseur"])]
		lines.append(line)
	lines.append("")
	if mode == "tour_de_role":
		var best: Dictionary = Fence.ranking(state)[0]
		lines.append("[center]Le plus riche : [b]%s[/b][/center]" % state.get_pawn(int(best["id"])).name)
	else:
		var score := Fence.band_score(state)
		var stars := "★".repeat(int(score["paliers"])) + "☆".repeat(data.regles["solo"]["paliers"].size() - int(score["paliers"]))
		lines.append("[center]Butin de la bande : [b]%s F[/b]   %s[/center]" % [_money(int(score["total"])), stars])
	var path := _save()
	if path != "":
		lines.append("[center][color=#6e5c45]Casse enregistré : %s[/color][/center]" % path)
	hud.show_end("\n".join(lines))


## Enregistre la graine et les gestes : de quoi rejouer le casse à l'identique.
func _save() -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	var path := SAVE_FOLDER.path_join("casse_%s.json" % Time.get_datetime_string_from_system().replace(":", "-"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(SaveGame.to_json(state))
	return path


# --- Textes ---

static func _cells(n: int) -> String:
	return "%d case%s" % [n, "" if n == 1 else "s"]


func _points(n: int) -> String:
	return "%d point%s" % [n, "" if n == 1 else "s"]


## « À » devant un nom : au Gros bras, à la Chatte, à l'Apache.
static func _to(text: String) -> String:
	if text.begins_with("le "):
		return "Au " + text.substr(3)
	return "À " + text


func _pawn_name(p: Pawn) -> String:
	if p == null:
		return "?"
	match p.kind:
		Pawn.Kind.GUARD:
			return "le garde %s" % p.name
		Pawn.Kind.SLEEPER:
			return "le dormeur"
	return p.name


func _furniture_name(f: Furniture) -> String:
	return data.mobilier["types"][f.type]["nom"] if f.revealed else "meuble"


func _silent(t: Pawn) -> bool:
	for item in t.equipment:
		if data.equipement["objets"][item].get("deplacement_silencieux", false):
			return true
	return false


func _loot_text(t: Pawn) -> String:
	if t.loot.is_empty():
		return "Sans butin"
	var value := 0
	for item in t.loot:
		value += int(data.butin["objets"][item]["valeur"])
	return "Butin : %d objet%s, %s F" % [t.loot.size(), "" if t.loot.size() == 1 else "s", _money(value)]


func _loot_entry_text(entry: Dictionary) -> String:
	match entry["effet"]:
		"rien":
			return "rien"
		"butin":
			var object: Dictionary = data.butin["objets"][entry["objet"]]
			return "%s (%s F)" % [object["nom"], _money(int(object["valeur"]))]
		"passage_secret":
			return "un passage secret vers l'extérieur"
	return entry.get("texte", entry["effet"])


static func _money(n: int) -> String:
	var digits := str(n)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return out


# --- Lumière de nuit ---

func _build_night() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = NIGHT_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42, 0.5, 0.75)
	environment.ambient_light_energy = 0.16
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.ssao_enabled = true
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.0
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = NIGHT_COLOR
	environment.fog_depth_begin = 60.0
	environment.fog_depth_end = 160.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, 35, 0)
	moon.light_energy = 0.22
	moon.light_color = Color(0.66, 0.74, 1.0)
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.6
	moon.shadow_blur = 2.0
	moon.directional_shadow_max_distance = 120.0
	add_child(moon)
	get_viewport().msaa_3d = Viewport.MSAA_4X


## Une lampe à pétrole par pièce, chaude et basse, au milieu de ses cases.
func _build_room_lamps() -> void:
	_rooms_light = Node3D.new()
	_rooms_light.name = "lampes"
	add_child(_rooms_light)
	var sums := {}
	for c in view.plan.cells():
		var z := view.plan.zone(c)
		if z == "" or z == VillaPlan.OUTSIDE:
			continue
		if not sums.has(z):
			sums[z] = [Vector3.ZERO, 0]
		sums[z][0] += VillaView.to_world(c)
		sums[z][1] += 1
	for z in sums:
		var lamp := OmniLight3D.new()
		lamp.position = sums[z][0] / float(sums[z][1]) + Vector3(0, 1.6, 0)
		lamp.light_color = Color(1.0, 0.76, 0.48)
		lamp.light_energy = 0.9
		lamp.omni_range = 3.2 + sqrt(float(sums[z][1])) * 0.55
		lamp.omni_attenuation = 1.4
		_rooms_light.add_child(lamp)


# --- Partie automatique (contrôle sans écran) ---

func _auto_next() -> void:
	if _auto_turns <= 0 or state == null:
		return
	if state.over:
		await _auto_snapshot("fin")
		get_tree().quit()
		return
	_bot_play.call_deferred()


func _bot_play() -> void:
	var thief := state.current_thief()
	if thief == null:
		return
	if _auto_actions == 0:
		await _auto_snapshot("tour_%02d" % (_auto_shots + 1))
		_auto_shots += 1
		if _auto_shots > _auto_turns:
			get_tree().quit()
			return
	_auto_actions += 1
	if thief.skips_turn or _auto_actions > 5:
		_auto_actions = 0
		_send({"type": "end_turn"})
		return
	var lock_index := -1
	for i in _locks.size():
		if not _auto_visited.has([thief.id, _lock_center(_locks[i])]) or _locks[i]["target"].has("furniture"):
			lock_index = i
			break
	if lock_index >= 0 and thief.ap > 0:
		var lock: Dictionary = _locks[lock_index]
		_open_lock(lock_index)
		if not _auto_visited.has("effraction"):
			_auto_visited["effraction"] = true
			await _auto_snapshot("effraction")
		_auto_visited[[thief.id, _lock_center(lock)]] = true
		_on_break_in_confirmed(mini(thief.ap, 4), true)
		return
	var on_board := thief.status == Pawn.Status.ACTIVE and not state.plan.is_wall(thief.pos)
	if not _entries.is_empty() and not (on_board and not _reach.is_empty()):
		var best: Vector2i = _entries.keys()[0]
		for c: Vector2i in _entries:
			if Hex.distance(c, Vector2i(13, 12)) < Hex.distance(best, Vector2i(13, 12)):
				best = c
		_send({"type": _entries[best]["type"], "cell": [best.x, best.y]})
		return
	if not _reach.is_empty() and thief.ap > 0:
		var best := Pawn.NO_CELL
		var best_score := -1000.0
		for c: Vector2i in _reach:
			var score := _auto_rng.randf() * 2.0 - float(_reach[c]["cost"]) * 0.1
			if state.plan.is_opening(c) and not _auto_visited.has([thief.id, c]):
				score += 6.0
			for f in state.furniture:
				if not f.emptied and f.cells.any(func(fc): return Hex.distance(fc, c) == 1):
					score += 3.0
			score -= Hex.distance(c, Vector2i(13, 12)) * 0.15
			if score > best_score:
				best_score = score
				best = c
		if _auto_shots == 1:
			_hover(best)
			await _auto_snapshot("chemin")
		_auto_visited[[thief.id, best]] = true
		var path := []
		for p: Vector2i in _reach[best]["path"]:
			path.append([p.x, p.y])
		_send({"type": "move", "path": path})
		return
	_auto_actions = 0
	_send({"type": "end_turn"})


func _auto_snapshot(file: String) -> void:
	if _auto_folder == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_auto_folder.path_join(file + ".png"))
