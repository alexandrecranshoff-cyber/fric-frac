extends TestCase
## Les murs et les passages tirés du plan (VillaPlan).


func _plan() -> VillaPlan:
	return VillaPlan.new(GameData.load_default().villa)


func test_on_circule_dans_une_piece_et_dehors() -> void:
	var p := _plan()
	# Le garde A et la case « 3 » à sa droite sont dans le hall.
	assert_true(p.passable(Vector2i(13, 12), Vector2i(14, 12)))
	# Deux cases de jardin.
	assert_true(p.passable(Vector2i(5, 2), Vector2i(6, 2)))
	# Jardin et terrasse : on passe, la balustrade coûte seulement des points (Movement).
	assert_true(p.passable(Vector2i(4, 3), Vector2i(4, 4)))
	# Deux cases éloignées ne communiquent jamais directement.
	assert_false(p.passable(Vector2i(13, 12), Vector2i(15, 12)))


func test_un_mur_separe_deux_pieces() -> void:
	var p := _plan()
	# Pièce bleue du nord-ouest (a) et salon au tapis rouge (b), de part et d'autre du mur.
	assert_eq(p.zone(Vector2i(7, 6)), "a")
	assert_eq(p.zone(Vector2i(8, 6)), "b")
	assert_false(p.passable(Vector2i(7, 6), Vector2i(8, 6)))
	# Façade ouest : jardin contre pièce.
	assert_false(p.passable(Vector2i(2, 7), Vector2i(3, 7)))


func test_on_change_de_piece_par_une_porte() -> void:
	var p := _plan()
	var door := Vector2i(7, 7)
	assert_eq(p.openings[door]["type"], "porte_interieure")
	assert_true(p.passable(Vector2i(6, 7), door))
	assert_true(p.passable(door, Vector2i(8, 7)))


func test_une_ouverture_ne_donne_que_sur_ses_deux_zones() -> void:
	var p := _plan()
	# La porte extérieure ouest [3, 16] ouvre sur le salon au tapis jaune (i), pas sur la pièce rose (e) au-dessus.
	var door := Vector2i(3, 16)
	assert_eq(p.zone(Vector2i(3, 15)), "e")
	assert_false(p.passable(door, Vector2i(3, 15)))
	assert_true(p.passable(door, Vector2i(4, 16)))
	assert_true(p.passable(door, Vector2i(2, 16)))


func test_deux_ouvertures_voisines_se_touchent_par_un_cote_du_mur() -> void:
	var p := _plan()
	# La porte [22, 11] entre d et g touche la fenêtre [23, 10] par son côté d, et la porte
	# extérieure [23, 12] par son côté g : dans les deux cas, aucun mur entre elles.
	assert_eq(p.side_zone(Vector2i(22, 11), "nord_est"), "d")
	assert_eq(p.side_zone(Vector2i(23, 10), "sud_ouest"), "d")
	assert_true(p.passable(Vector2i(22, 11), Vector2i(23, 10)))
	assert_eq(p.side_zone(Vector2i(22, 11), "sud_est"), "g")
	assert_true(p.passable(Vector2i(22, 11), Vector2i(23, 12)))
	# Chaque moitié d'une ouverture donne sur une de ses deux zones, jamais deux fois la même.
	for c in p.openings:
		var sides := {}
		for d in Hex.DIRECTIONS:
			sides[p.side_zone(c, d)] = true
		assert_eq(sides.size(), 2, str(c))
		for z in p.openings[c]["relie"]:
			assert_true(sides.has(z), "%s : rien ne donne sur %s" % [c, z])


func test_les_passages_sont_les_memes_dans_les_deux_sens() -> void:
	var p := _plan()
	for c in p.cells():
		for d in Hex.DIRECTIONS:
			var n := Hex.step(c, d)
			assert_eq(p.passable(c, n), p.passable(n, c), "%s vers %s" % [c, d])


func test_le_mur_de_chaque_ouverture_separe_ses_deux_zones() -> void:
	var p := _plan()
	for c in p.openings:
		var o: Dictionary = p.openings[c]
		var from: Vector2 = Hex.corner(c, o["mur"][0])
		var to: Vector2 = Hex.corner(c, o["mur"][1])
		var sides := {}
		for n in Hex.neighbors(c):
			var z := p.zone(n)
			if not (o["relie"] as Array).has(z):
				continue
			var side := signf((to - from).cross(Hex.center(n) - from))
			assert_true(side != 0.0, str(c))
			if sides.has(z):
				assert_eq(sides[z], side, "%s : la zone %s est des deux côtés du mur" % [c, z])
			sides[z] = side
		assert_eq(sides.size(), 2, str(c))
		assert_true(sides[o["relie"][0]] != sides[o["relie"][1]], "%s : les deux zones sont du même côté" % [c])


func test_murs_fermes_autour_de_chaque_piece() -> void:
	var p := _plan()
	# Depuis le hall, sans passer par une ouverture, on ne sort pas du hall.
	var seen := {Vector2i(13, 12): true}
	var queue: Array[Vector2i] = [Vector2i(13, 12)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in Hex.neighbors(c):
			if not seen.has(n) and not p.is_opening(n) and p.passable(c, n):
				seen[n] = true
				queue.append(n)
	assert_eq(seen.size(), 34)
	for c in seen:
		assert_eq(p.zone(c), "h")


func test_coins_et_centres() -> void:
	# Deux cases voisines partagent les deux sommets de leur côté commun.
	var a := Vector2i(13, 12)
	var b := Hex.step(a, "est")
	var e: Array = Hex.EDGE_VERTICES["est"]
	var w: Array = Hex.EDGE_VERTICES["ouest"]
	assert_true(Hex.corner(a, e[0]).distance_to(Hex.corner(b, w[1])) < 0.0001)
	assert_true(Hex.corner(a, e[1]).distance_to(Hex.corner(b, w[0])) < 0.0001)
	assert_true(absf(Hex.center(a).distance_to(Hex.center(Hex.step(a, "sud_est"))) - 1.0) < 0.0001)
