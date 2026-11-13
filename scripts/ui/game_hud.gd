class_name GameHud
extends CanvasLayer
## L'interface de la partie, dessinée en code : menu de départ, bandeau des voleurs, horloge,
## gestes possibles, curseur d'effraction, dés, carnet du casse, écran « passez la main » et
## bilan chez le receleur. Elle ne connaît pas les règles : l'écran de jeu lui dit quoi montrer et
## écoute ses signaux.

signal mode_chosen(mode: String, players: int, open_board: bool)
signal visit_pressed
## Les dés sont lancés (pour leur bruit).
signal dice_thrown
## Les dés viennent de s'arrêter et leur résultat est affiché (pour les images de contrôle).
signal dice_settled
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
const FONT_SIZE := 22
## Encre sur le papier du rapport de fin, et sur le laiton des boutons.
const SEPIA := Color("2e2013")
## Habillage : bois verni à filets de laiton, papier vergé, plaques de laiton (images Higgsfield,
## voir assets/references/LISEZMOI.md), Garamond pour le texte et Cormorant pour les titres.
const UI := "res://assets/ui/%s"
const BODY_FONT := "res://assets/fonts/eb_garamond.ttf"
const TITLE_FONT := "res://assets/fonts/cormorant_garamond.ttf"
## Largeur en pixels des coins ornés de chaque image, que le panneau ne doit pas étirer.
const WOOD_MARGIN := 30
const PAPER_MARGIN := 80
const BRASS_MARGIN := Vector2(26, 22)

var _cards: HBoxContainer
var _clock: Label
var _alarm: Label
var _hint: Label
var _actions: HBoxContainer
var _log: RichTextLabel
var _banner: Label
var _dice_panel: PanelContainer
var _dice_tray: DiceTray
var _dice_text: Label
var _dice_result: Label
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
	var theme := _make_theme()
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
		var style := _wood()
		if c["current"]:
			style.modulate_color = Color(1.35, 1.2, 1.0)
		panel.add_theme_stylebox_override("panel", style)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		panel.add_child(box)
		var title := Label.new()
		title.text = c["name"]
		title.add_theme_color_override("font_color", ACCENT if c["current"] else INK)
		title.add_theme_font_size_override("font_size", 25)
		box.add_child(title)
		var pips := Label.new()
		var ap: int = c["ap"]
		pips.text = c["status"] if c["status"] != "" else "●".repeat(ap) + "○".repeat(maxi(int(c["ap_max"]) - ap, 0))
		pips.add_theme_color_override("font_color", DANGER if c["status"] != "" else INK)
		box.add_child(pips)
		var gear := Label.new()
		gear.text = c["equipment"]
		gear.add_theme_color_override("font_color", DIM)
		gear.add_theme_font_size_override("font_size", 18)
		box.add_child(gear)
		var loot := Label.new()
		loot.text = c["loot"]
		loot.add_theme_font_size_override("font_size", 18)
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
		if a["kind"] == "end":
			button.add_theme_color_override("font_color", Color("5a1a10"))
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


## Montre un lancer de dés : les dés roulent en 3D jusqu'à leurs faces, puis ce qu'on jouait et ce
## que donne le tableau. À attendre.
func show_dice(faces: Array, title: String, result: String, seconds := 1.3) -> void:
	_dice_text.text = title
	_dice_result.text = ""
	_dice_panel.visible = true
	dice_thrown.emit()
	await _dice_tray.roll(faces)
	var total := 0
	for f in faces:
		total += int(f)
	_dice_result.text = ("%s = %d" % [" + ".join(faces.map(func(f): return str(f))), total] if faces.size() > 1 else "") + \
			("\n" + result if result != "" else "")
	dice_settled.emit()
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
	panel.add_theme_stylebox_override("panel", _wood(Color(1, 1, 1, 0.92)))
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
	_log.add_theme_font_size_override("normal_font_size", 18)
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
	_dice_panel.add_theme_stylebox_override("panel", _wood())
	_dice_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dice_panel.offset_left = -250
	_dice_panel.offset_right = 250
	_dice_panel.offset_top = -300
	_dice_panel.offset_bottom = -20
	_dice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_panel.visible = false
	_game_root.add_child(_dice_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_panel.add_child(box)
	_dice_text = Label.new()
	_dice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dice_text.add_theme_color_override("font_color", ACCENT)
	_dice_text.add_theme_font_size_override("font_size", 24)
	box.add_child(_dice_text)
	_dice_tray = DiceTray.new()
	box.add_child(_dice_tray)
	_dice_result = Label.new()
	_dice_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dice_result.add_theme_color_override("font_color", INK)
	_dice_result.custom_minimum_size = Vector2(0, 56)
	box.add_child(_dice_result)


func _build_break_in() -> void:
	_break_panel = PanelContainer.new()
	_break_panel.add_theme_stylebox_override("panel", _wood())
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
	# Le rapport du casse, imprimé sur papier.
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", _paper())
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sheet.offset_left = -470
	sheet.offset_right = 470
	sheet.offset_top = -330
	sheet.offset_bottom = 330
	_end_panel.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	sheet.add_child(box)
	_end_text = RichTextLabel.new()
	_end_text.bbcode_enabled = true
	_end_text.fit_content = true
	_end_text.add_theme_font_size_override("normal_font_size", 22)
	_end_text.add_theme_font_size_override("bold_font_size", 30)
	_end_text.add_theme_color_override("default_color", SEPIA)
	_end_text.add_theme_font_override("bold_font", _font(TITLE_FONT, 700))
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
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_menu)
	# La villa la nuit, et un voile sombre à gauche, sous le titre et les boutons.
	var picture := TextureRect.new()
	picture.texture = _ui_texture("menu_fond.jpg")
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(picture)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.03, 0.03, 0.05, 0.88))
	gradient.set_color(1, Color(0.03, 0.03, 0.05, 0.0))
	var ramp := GradientTexture2D.new()
	ramp.gradient = gradient
	ramp.fill_to = Vector2(1, 0)
	shade.texture = ramp
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 900
	_menu.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	box.offset_left = 110
	box.offset_right = 610
	box.offset_top = -300
	box.offset_bottom = 300
	box.add_theme_constant_override("separation", 14)
	_menu.add_child(box)
	var title := Label.new()
	title.text = "Fric-Frac"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font(TITLE_FONT, 700))
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Un cambriolage à Neuilly"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", _font(TITLE_FONT, 500, true))
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.add_theme_color_override("font_color", INK)
	box.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	box.add_child(gap)
	box.add_child(_menu_button("Le casse, en solo", func(): mode_chosen.emit("solo", 1, _open_box.button_pressed)))
	box.add_child(_menu_button("Le casse du jour", func(): mode_chosen.emit("jour", 1, _open_box.button_pressed)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var turns := _menu_button("Tour de rôle", func(): mode_chosen.emit("tour_de_role", int(_players_box.value), _open_box.button_pressed))
	turns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(turns)
	_players_box = SpinBox.new()
	_players_box.min_value = 2
	_players_box.max_value = 6
	_players_box.value = 2
	_players_box.suffix = "joueurs"
	row.add_child(_players_box)
	_open_box = CheckBox.new()
	_open_box.text = "Plateau ouvert (tout est visible)"
	_open_box.add_theme_color_override("font_color", INK)
	box.add_child(_open_box)
	box.add_child(_menu_button("Visiter la villa", func(): visit_pressed.emit()))


func _menu_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	return button


## Panneau de bois verni à filets de laiton. Sans son image, un aplat sombre.
static func _wood(tint := Color.WHITE) -> StyleBox:
	var texture := _ui_texture("panneau_bois.png")
	if texture == null:
		return _flat(PAPER, Color(0, 0, 0, 0))
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(WOOD_MARGIN)
	style.set_content_margin_all(30)
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.modulate_color = tint
	return style


## Feuille de papier vergé à filet double, pour le rapport de fin.
static func _paper() -> StyleBox:
	var texture := _ui_texture("panneau_papier.png")
	if texture == null:
		return _flat(Color("efe4cc"), Color(0, 0, 0, 0))
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_texture_margin_all(PAPER_MARGIN)
	style.set_content_margin_all(70)
	return style


## Plaque de laiton d'un bouton, plus claire au survol, plus sombre quand on appuie.
static func _brass(tint: Color) -> StyleBox:
	var texture := _ui_texture("bouton_laiton.png")
	if texture == null:
		return _flat(PAPER.lightened(0.1), ACCENT)
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = BRASS_MARGIN.x
	style.texture_margin_right = BRASS_MARGIN.x
	style.texture_margin_top = BRASS_MARGIN.y
	style.texture_margin_bottom = BRASS_MARGIN.y
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.modulate_color = tint
	return style


static func _flat(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	if border.a > 0:
		style.set_border_width_all(2)
		style.border_color = border
	return style


static func _ui_texture(file: String) -> Texture2D:
	var path := UI % file
	return load(path) if ResourceLoader.exists(path) else null


## Police à graisse réglable (fichier variable), en romain ou en italique simulée.
static func _font(path: String, weight: int, slanted := false) -> Font:
	if not ResourceLoader.exists(path):
		return ThemeDB.fallback_font
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {"wght": weight}
	if slanted:
		font.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	return font


## Le thème de tout l'écran : Garamond, boutons de laiton, curseurs et cases à cocher assortis.
static func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = _font(BODY_FONT, 500)
	theme.default_font_size = FONT_SIZE
	theme.set_stylebox("normal", "Button", _brass(Color.WHITE))
	theme.set_stylebox("hover", "Button", _brass(Color(1.18, 1.12, 1.0)))
	theme.set_stylebox("pressed", "Button", _brass(Color(0.78, 0.72, 0.64)))
	theme.set_stylebox("disabled", "Button", _brass(Color(0.55, 0.52, 0.5, 0.8)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", SEPIA)
	theme.set_color("font_disabled_color", "Button", Color(SEPIA, 0.55))
	theme.set_font("font", "Button", _font(BODY_FONT, 600))
	theme.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	for state in ["font_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "CheckBox", INK)
	theme.set_color("font_hover_color", "CheckBox", ACCENT)
	theme.set_font("bold_font", "RichTextLabel", _font(BODY_FONT, 700))
	theme.set_font("italics_font", "RichTextLabel", _font(BODY_FONT, 500, true))
	return theme
