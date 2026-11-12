extends TestCase
## Le tracé redressé de la villa (VillaOutline) : il ne sert qu'à l'affichage.


func _plan() -> VillaPlan:
	return VillaPlan.new(GameData.load_default().villa)


func test_les_murs_en_zigzag_deviennent_des_droites() -> void:
	var plan := _plan()
	var outline := VillaOutline.new(plan)
	var walls := 0
	var longest := 0.0
	for s in outline.segments:
		if s["wall"]:
			walls += 1
			longest = maxf(longest, (s["a"] as Vector2).distance_to(s["b"]))
	# Moins de tronçons que de côtés de case murés, et des tronçons longs de plusieurs cases.
	assert_true(walls < plan.wall_edges().size(), "%d tronçons" % walls)
	assert_true(longest > 2.5, "plus long tronçon : %f" % longest)


func test_aucun_sommet_ne_s_ecarte_de_plus_qu_un_zigzag() -> void:
	var plan := _plan()
	var outline := VillaOutline.new(plan)
	var moved := 0
	for c in plan.cells():
		for vertex in Hex.VERTICES:
			var shift := Hex.corner(c, vertex).distance_to(outline.corner(c, vertex))
			assert_true(shift <= VillaOutline.TOLERANCE, "%s %s" % [c, vertex])
			if shift > 0.0001:
				moved += 1
	assert_true(moved > 0)


func test_les_murs_des_ouvertures_ne_bougent_pas() -> void:
	var plan := _plan()
	var outline := VillaOutline.new(plan)
	for c in plan.openings:
		for vertex in plan.openings[c]["mur"]:
			assert_true(Hex.corner(c, vertex).distance_to(outline.corner(c, vertex)) < 0.0001, "%s %s" % [c, vertex])


func test_sol_de_chaque_cote_d_une_ouverture() -> void:
	var outline := VillaOutline.new(_plan())
	# La porte extérieure ouest [3, 16] : salon au tapis jaune d'un côté, jardin de l'autre.
	assert_eq(outline.surface(Vector2i(3, 16), "est"), "i")
	assert_eq(outline.surface(Vector2i(3, 16), "ouest"), ".")
	# Le mur d'enceinte repose sur le jardin, et sur la cour près de la grille.
	assert_eq(outline.surface(Vector2i(5, 0), "est"), ".")
	assert_eq(outline.surface(Vector2i(13, 24), "est"), ",")
	assert_eq(outline.surface(Vector2i(12, 24), "est"), ",")
