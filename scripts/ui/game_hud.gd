class_name GameHud
extends CanvasLayer
## L'interface de la partie, dessinée en code : menu de départ, bandeau des voleurs, horloge,
## gestes possibles, curseur d'effraction, dés, carnet du casse, écran « passez la main » et
## bilan chez le receleur. Elle ne connaît pas les règles : l'écran de jeu lui dit quoi montrer et
## écoute ses signaux.

signal mode_chosen(mode: String, players: int, open_board: bool)
signal visit_pressed
signal end_turn_pressed
signal lock_pressed(index: int)
signal break_in_confirmed(points: int, open_now: bool)
signal break_in_cancelled
signal break_in_changed(points: int)
signal attack_pressed(id: int, mode: String)
signal leave_pressed
signal ready_pressed
signal replay_pressed
signal menu_pressed
signal card_pressed(id: int)

const INK := Color("f3ead6")
const DIM := Color("b9ad96")
const PAPER := Color(0.1, 0.085, 0.07, 0.86)
const ACCENT := Color("d9a441")
const DANGER := Color("d8553f")
const FONT_SIZE := 20

var _cards: HBoxContainer
var _clock: Label
var _alarm: Label
var _hint: Label
var _actions: HBoxContainer
var _log: RichTextLabel
var _banner: Label
var _dice_panel: PanelContainer
var _dice_row: HBoxContainer
var _dice_text: Label
var _break_panel: PanelContainer
var _break_title: Label
var _break_slider: HSlider
var _break_text: Label
var _break_open: Button
var _pass_panel: Control
var _pass_text: Label
var _end_panel: Control
var _end_text: RichTextLabel
var _menu: Control
var _players_box: SpinBox
var _open_box: CheckBox
var _game_root: Control
var _banner_tween: Tween


func _ready() -> void:
	layer = 5
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)
	_game_root = Control.new()
	_game_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_game_root)
	_build_top()
	_build_bottom()
	_build_log()
	_build_banner()
	_build_dice()
	_build_break_in()
	_build_pass(root)
	_build_end(root)
	_build_menu(root)
	show_menu()


# --- Ce que montre l'écran de jeu ---

func show_menu() -> void:
	_game_root.visible = false
	_end_panel.visible = false
	_pass_panel.visible = false
	_menu.visible = true


func show_game() -> void:
	_menu.visible = false
	_end_panel.visible = false
	_game_root.visible = true


## Cartes des voleurs : {"id", "name", "status", "ap", "ap_max", "equipment", "loot", "current"}.
func set_cards(cards: Array) -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for c in cards:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _box(PAPER.lightened(0.08) if c["current"] else PAPER, ACCENT if c["current"] else Color(0, 0, 0, 0)))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		panel.add_child(box)
		var title := Label.new()
		title.text = c["name"]
		title.add_theme_color_override("font_color", ACCENT if c["current"] else INK)
		title.add_theme_font_size_override("font_size", 22)
		box.add_child(title)
		var pips := Label.new()
		var ap: int = c["ap"]
		pips.text = c["status"] if c["status"] != "" else "●".repeat(ap) + "○".repeat(maxi(int(c["ap_max"]) - ap, 0))
		pips.add_theme_color_override("font_color", DANGER if c["status"] != "" else INK)
		box.add_child(pips)
		var gear := Label.new()
		gear.text = c["equipment"]
		gear.add_theme_color_override("font_color", DIM)
		gear.add_theme_font_size_override("font_size", 16)
		box.add_child(gear)
		var loot := Label.new()
		loot.text = c["loot"]
		loot.add_theme_font_size_override("font_size", 16)
		box.add_child(loot)
		var id: int = c["id"]
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				card_pressed.emit(id))
		_cards.add_child(panel)


func set_clock(text: String, alarm: bool) -> void:
	_clock.text = text
	_alarm.visible = alarm


func set_hint(text: String) -> void:
	_hint.text = text


## Gestes proposés : liste de {"label", "kind", et selon le cas "index", "id", "mode"}.
func set_actions(actions: Array) -> void:
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	for a in actions:
		var button := Button.new()
		button.text = a["label"]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", _box(PAPER, ACCENT if a["kind"] == "end" else Color(0, 0, 0, 0)))
		match a["kind"]:
			"lock":
				var index: int = a["index"]
				button.pressed.connect(func(): lock_pressed.emit(index))
			"attack":
				var id: int = a["id"]
				var mode: String = a["mode"]
				button.pressed.connect(func(): attack_pressed.emit(id, mode))
			"leave":
				button.pressed.connect(func(): leave_pressed.emit())
			"end":
				button.pressed.connect(func(): end_turn_pressed.emit())
		_actions.add_child(button)


func set_actions_enabled(enabled: bool) -> void:
	for child in _actions.get_children():
		(child as Button).disabled = not enabled


func add_log(text: String) -> void:
	_log.append_text(text + "\n")


func clear_log() -> void:
	_log.clear()


func banner(text: String, color := INK, seconds := 1.8) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner.visible = true
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


## Montre un lancer de dés : faces, ce qu'on jouait, et ce que donne le tableau. À attendre.
func show_dice(faces: Array, title: String, result: String, seconds := 1.3) -> void:
	for child in _dice_row.get_children():
		_dice_row.remove_child(child)
		child.queue_free()
	var labels: Array[Label] = []
	for f in faces:
		var die := Label.new()
		die.text = str(f)
		die.custom_minimum_size = Vector2(64, 64)
		die.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		die.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		die.add_theme_font_size_override("font_size", 38)
		die.add_theme_color_override("font_color", Color("1d1712"))
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f4efe3")
		style.set_corner_radius_all(10)
		style.set_border_width_all(2)
		style.border_color = Color("3b2f24")
		die.add_theme_stylebox_override("normal", style)
		_dice_row.add_child(die)
		labels.append(die)
	_dice_text.text = title + ("\n" + result if result != "" else "")
	_dice_panel.visible = true
	# Les dés roulent un instant avant de s'arrêter sur leurs faces.
	for i in 8:
		for die in labels:
			die.text = str(randi_range(1, 6))
		await get_tree().create_timer(0.05).timeout
	for i in labels.size():
		labels[i].text = str(faces[i])
	await get_tree().create_timer(seconds).timeout
	_dice_panel.visible = false


## Curseur d'effraction : de 1 au maximum de points, avec le texte que donne l'écran de jeu.
func open_break_in(title: String, max_points: int, start: int, can_open: bool) -> void:
	_break_title.text = title
	_break_slider.min_value = 0 if can_open else 1
	_break_slider.max_value = max_points
	_break_slider.value = clampi(start, int(_break_slider.min_value), max_points)
	_break_panel.visible = true
	break_in_changed.emit(int(_break_slider.value))


func set_break_in_text(text: String, can_open: bool) -> void:
	_break_text.text = text
	_break_open.disabled = not can_open


func close_break_in() -> void:
	_break_panel.visible = false


func is_break_in_open() -> bool:
	return _break_panel.visible


func show_pass(text: String) -> void:
	_pass_text.text = text
	_pass_panel.visible = true


func hide_pass() -> void:
	_pass_panel.visible = false


func show_end(bbcode: String) -> void:
	_end_text.clear()
	_end_text.append_text(bbcode)
	_end_panel.visible = true


# --- Construction ---

func _build_top() -> void:
	_cards = HBoxContainer.new()
	_cards.position = Vector2(16, 12)
	_cards.add_theme_constant_override("separation", 10)
	_game_root.add_child(_cards)
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -360
	right.offset_right = -16
	right.offset_top = 12
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	_game_root.add_child(right)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.add_theme_font_size_override("font_size", 26)
	_clock.add_theme_color_override("font_color", INK)
	_clock.add_theme_color_override("font_outline_color", Color.BLACK)
	_clock.add_theme_constant_override("outline_size", 6)
	right.add_child(_clock)
	_alarm = Label.new()
	_alarm.text = "ALERTE"
	_alarm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_alarm.add_theme_font_size_override("font_size", 26)
	_alarm.add_theme_color_override("font_color", DANGER)
	_alarm.add_theme_color_override("font_outline_color", Color.BLACK)
	_alarm.add_theme_constant_override("outline_size", 6)
	_alarm.visible = false
	right.add_child(_alarm)


func _build_bottom() -> void:
	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -120
	bottom.offset_bottom = -14
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_root.add_child(bottom)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", INK)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	bottom.add_child(_hint)
	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 10)
	bottom.add_child(_actions)


func _build_log() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(PAPER, 0.7), Color(0, 0, 0, 0)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -380
	panel.offset_right = -16
	panel.offset_top = 110
	panel.offset_bottom = -150
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Carnet du casse"
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_color_override("default_color", INK)
	_log.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_log)


func _build_banner() -> void:
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 150
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 36)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	_game_root.add_child(_banner)


func _build_dice() -> void:
	_dice_panel = PanelContainer.new()
	_dice_panel.add_theme_stylebox_override("panel", _box(PAPER, ACCENT))
	_dice_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dice_panel.offset_left = -220
	_dice_panel.offset_right = 220
	_dice_panel.offset_top = -170
	_dice_panel.offset_bottom = -30
	_dice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_panel.visible = false
	_game_root.add_child(_dice_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_panel.add_child(box)
	_dice_row = HBoxContainer.new()
	_dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_row.add_theme_constant_override("separation", 14)
	box.add_child(_dice_row)
	_dice_text = Label.new()
	_dice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dice_text.add_theme_color_override("font_color", INK)
	box.add_child(_dice_text)


func _build_break_in() -> void:
	_break_panel = PanelContainer.new()
	_break_panel.add_theme_stylebox_override("panel", _box(PAPER, ACCENT))
	_break_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_break_panel.offset_left = -330
	_break_panel.offset_right = 330
	_break_panel.offset_top = -330
	_break_panel.offset_bottom = -140
	_break_panel.visible = false
	_game_root.add_child(_break_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_break_panel.add_child(box)
	_break_title = Label.new()
	_break_title.add_theme_color_override("font_color", ACCENT)
	_break_title.add_theme_font_size_override("font_size", 24)
	box.add_child(_break_title)
	_break_slider = HSlider.new()
	_break_slider.step = 1
	_break_slider.tick_count = 9
	_break_slider.ticks_on_borders = true
	_break_slider.focus_mode = Control.FOCUS_NONE
	_break_slider.value_changed.connect(func(v: float): break_in_changed.emit(int(v)))
	box.add_child(_break_slider)
	_break_text = Label.new()
	_break_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_break_text.add_theme_color_override("font_color", INK)
	box.add_child(_break_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_break_open = Button.new()
	_break_open.text = "Forcer maintenant"
	_break_open.pressed.connect(func(): break_in_confirmed.emit(int(_break_slider.value), true))
	row.add_child(_break_open)
	var work := Button.new()
	work.text = "Travailler sans ouvrir"
	work.pressed.connect(func(): break_in_confirmed.emit(int(_break_slider.value), false))
	row.add_child(work)
	var cancel := Button.new()
	cancel.text = "Annuler"
	cancel.pressed.connect(func(): break_in_cancelled.emit())
	row.add_child(cancel)


func _build_pass(root: Control) -> void:
	_pass_panel = ColorRect.new()
	(_pass_panel as ColorRect).color = Color(0.04, 0.035, 0.03, 0.97)
	_pass_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pass_panel.visible = false
	root.add_child(_pass_panel)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -400
	box.offset_right = 400
	box.offset_top = -100
	box.offset_bottom = 100
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	_pass_panel.add_child(box)
	_pass_text = Label.new()
	_pass_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pass_text.add_theme_font_size_override("font_size", 34)
	_pass_text.add_theme_color_override("font_color", INK)
	box.add_child(_pass_text)
	var ready := Button.new()
	ready.text = "Je suis prêt"
	ready.pressed.connect(func(): ready_pressed.emit())
	box.add_child(ready)


func _build_end(root: Control) -> void:
	_end_panel = ColorRect.new()
	(_end_panel as ColorRect).color = Color(0.04, 0.035, 0.03, 0.9)
	_end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_panel.visible = false
	root.add_child(_end_panel)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -440
	box.offset_right = 440
	box.offset_top = -300
	box.offset_bottom = 300
	box.add_theme_constant_override("separation", 16)
	_end_panel.add_child(box)
	_end_text = RichTextLabel.new()
	_end_text.bbcode_enabled = true
	_end_text.fit_content = true
	_end_text.add_theme_font_size_override("normal_font_size", 22)
	_end_text.add_theme_font_size_override("bold_font_size", 30)
	_end_text.add_theme_color_override("default_color", INK)
	_end_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_end_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var again := Button.new()
	again.text = "Rejouer"
	again.pressed.connect(func(): replay_pressed.emit())
	row.add_child(again)
	var menu := Button.new()
	menu.text = "Menu"
	menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu)


func _build_menu(root: Control) -> void:
	_menu = ColorRect.new()
	(_menu as ColorRect).color = Color(0.05, 0.045, 0.04, 0.78)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_menu)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = -260
	box.offset_bottom = 260
	box.add_theme_constant_override("separation", 14)
	_menu.add_child(box)
	var title := Label.new()
	title.text = "Fric-Frac"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Maquette grise jouable"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", DIM)
	box.add_child(subtitle)
	box.add_child(_menu_button("Le casse, en solo", func(): mode_chosen.emit("solo", 1, _open_box.button_pressed)))
	box.add_child(_menu_button("Le casse du jour", func(): mode_chosen.emit("jour", 1, _open_box.button_pressed)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(_menu_button("Tour de rôle", func(): mode_chosen.emit("tour_de_role", int(_players_box.value), _open_box.button_pressed)))
	_players_box = SpinBox.new()
	_players_box.min_value = 2
	_players_box.max_value = 6
	_players_box.value = 2
	_players_box.suffix = "joueurs"
	row.add_child(_players_box)
	_open_box = CheckBox.new()
	_open_box.text = "Plateau ouvert (tout est visible)"
	box.add_child(_open_box)
	box.add_child(_menu_button("Visiter la villa", func(): visit_pressed.emit()))


func _menu_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	return button


static func _box(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	if border.a > 0:
		style.set_border_width_all(2)
		style.border_color = border
	return style
