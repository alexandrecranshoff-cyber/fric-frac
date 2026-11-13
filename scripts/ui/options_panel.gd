class_name OptionsPanel
extends ColorRect
## Panneau des options, ouvert depuis le menu ou la pause : écran, qualité graphique, volumes.
## Chaque changement passe tout de suite par Settings, qui l'applique et l'enregistre.

signal closed

var _definition_value: Label


func _init(panel_style: StyleBox) -> void:
	color = Color(0.03, 0.03, 0.05, 0.75)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(720, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Options"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GameHud.ACCENT)
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)

	_row(grid, "Plein écran", _check("plein_ecran"))
	_row(grid, "Synchronisation verticale", _check("synchro"))
	var quality := OptionButton.new()
	for key in Settings.QUALITIES:
		quality.add_item(Settings.QUALITY_NAMES[key])
	quality.selected = Settings.QUALITIES.find(Settings.values["qualite"])
	quality.item_selected.connect(func(i: int): Settings.set_value("qualite", Settings.QUALITIES[i]))
	_row(grid, "Qualité graphique", quality)
	var definition := HBoxContainer.new()
	var slider := _slider("definition", 0.5, 1.0, 0.05)
	definition.add_child(slider)
	_definition_value = Label.new()
	_definition_value.custom_minimum_size = Vector2(70, 0)
	_definition_value.add_theme_color_override("font_color", GameHud.INK)
	definition.add_child(_definition_value)
	slider.value_changed.connect(func(_v): _show_definition())
	_show_definition()
	_row(grid, "Définition du rendu 3D", definition)
	_row(grid, "Musique", _slider("musique", 0.0, 1.0, 0.05))
	_row(grid, "Bruitages", _slider("bruitages", 0.0, 1.0, 0.05))
	_row(grid, "Images par seconde (F3)", _check("images_par_seconde"))

	var hint := Label.new()
	hint.text = "« Maximale » est réglée pour une carte du niveau d'une RTX 3050. Si l'image saccade, baissez la qualité, puis la définition."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(640, 0)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", GameHud.DIM)
	box.add_child(hint)
	var close := Button.new()
	close.text = "Fermer"
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(220, 48)
	close.pressed.connect(close_panel)
	box.add_child(close)
	Settings.changed.connect(_refresh)


func open() -> void:
	_refresh()
	visible = true


func close_panel() -> void:
	visible = false
	closed.emit()


func _row(grid: GridContainer, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", GameHud.INK)
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _check(key: String) -> CheckBox:
	var box := CheckBox.new()
	box.set_meta("key", key)
	box.button_pressed = Settings.values[key]
	box.toggled.connect(func(on: bool): Settings.set_value(key, on))
	return box


func _slider(key: String, low: float, high: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.set_meta("key", key)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = Settings.values[key]
	slider.custom_minimum_size = Vector2(260, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v: float): Settings.set_value(key, v))
	return slider


func _show_definition() -> void:
	_definition_value.text = "%d %%" % roundi(Settings.values["definition"] * 100.0)


## Remet les cases à jour quand un réglage change ailleurs (F3).
func _refresh() -> void:
	for control in find_children("", "Control", true, false):
		if control.has_meta("key"):
			var value: Variant = Settings.values[control.get_meta("key")]
			if control is CheckBox:
				control.set_pressed_no_signal(value)
			elif control is HSlider:
				control.set_value_no_signal(value)
	_show_definition()
