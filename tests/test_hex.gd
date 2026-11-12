extends TestCase


func test_six_voisines_distinctes() -> void:
	for cell in [Vector2i(13, 12), Vector2i(13, 11)]:
		var n := Hex.neighbors(cell)
		assert_eq(n.size(), 6)
		for v in n:
			assert_eq(Hex.distance(cell, v), 1, str(cell, " ", v))


func test_ligne_impaire_decalee_a_droite() -> void:
	# Depuis une ligne paire, le nord-est garde la colonne ; depuis une ligne impaire, le nord-ouest.
	assert_eq(Hex.step(Vector2i(13, 12), "nord_est"), Vector2i(13, 11))
	assert_eq(Hex.step(Vector2i(13, 12), "nord_ouest"), Vector2i(12, 11))
	assert_eq(Hex.step(Vector2i(13, 11), "nord_ouest"), Vector2i(13, 10))
	assert_eq(Hex.step(Vector2i(13, 11), "sud_est"), Vector2i(14, 12))


func test_aller_retour() -> void:
	var opposite := {"nord_ouest": "sud_est", "nord_est": "sud_ouest", "est": "ouest"}
	for cell in [Vector2i(5, 6), Vector2i(5, 7)]:
		for d in opposite:
			assert_eq(Hex.step(Hex.step(cell, d), opposite[d]), cell, d)
			assert_eq(Hex.opposite(d), opposite[d])
			assert_eq(Hex.opposite(opposite[d]), d)


func test_distance() -> void:
	# Les deux gardes sont à six lignes d'écart dans la même colonne.
	assert_eq(Hex.distance(Vector2i(13, 12), Vector2i(13, 18)), 6)
	assert_eq(Hex.distance(Vector2i(13, 12), Vector2i(16, 12)), 3)
	assert_eq(Hex.distance(Vector2i(3, 3), Vector2i(3, 3)), 0)
